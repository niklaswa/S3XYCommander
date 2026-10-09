import Foundation

// Reverse-engineered field numbers from the Enhauto firmware's compiled
// proto descriptors (see README §Reversing-Notes). Everything in this file
// is internal - public API lives in Client.swift and VehicleData.swift.

// MARK: - Field numbers

enum F {
    // SessionData (session.proto)
    static let SD_sec_ver = 2, SD_sec1 = 11
    // Sec1Payload (sec1.proto)
    static let S1_msg = 1
    static let S1_sc0 = 20, S1_sr0 = 21, S1_sc1 = 22, S1_sr1 = 23
    // SessionCmd0 / Resp0 / Cmd1 / Resp1
    static let SC0_client_pubkey = 1, SC0_enhance_security_flags = 2
    static let SR0_status = 1, SR0_device_pubkey = 2, SR0_device_random = 3, SR0_confirm_security_flags = 4
    static let SC1_client_verify_data = 2, SC1_device_type = 3
    static let SR1_status = 1, SR1_device_verify_data = 3
    // EnhApiPayloadHolder (enhapi.proto)
    static let EP_msgType = 1
    static let EP_pReqSendUUID = 43, EP_pRespSendUUID = 44
    static let EP_pReqSubscribeVehicleData = 135, EP_pRespSubscribeVehicleData = 136
    static let EP_pReqSubscribeVehicleEventsData = 163, EP_pRespSubscribeVehicleEventsData = 164
    // ReqSendUUID / ReqSubscribeVehicleData
    static let RSU_UUID = 1
    static let RSV_subscribe_fields = 13, RSV_unsubscribe_fields = 14
    static let RSV_subscribe_all = 1, RSV_unsubscribe_all = 2
    // EnhApiPushPayloadHolder (enhapipush.proto)
    static let EPP_pushType = 1
    static let EPP_pPushVehicleDataHolder = 25
    static let EPP_pPushVehicleEventsDataHolder = 28
}

// MARK: - Enums

enum MsgType {
    static let ReqSendUUID: UInt32 = 32, RespSendUUID: UInt32 = 33
    static let ReqSubscribeVehicleData: UInt32 = 124, RespSubscribeVehicleData: UInt32 = 125
}
enum PushType {
    static let VehicleDataHolder: UInt32 = 16
    static let VehicleEventsDataHolder: UInt32 = 19
}
enum Sec1Msg {
    static let Command0: UInt32 = 0, Response0: UInt32 = 1
    static let Command1: UInt32 = 2, Response1: UInt32 = 3
}
enum SecVer { static let SecScheme1: UInt32 = 1 }
enum SecFlags {
    static let AllIsEncrypted: UInt32 = 0
    static let DisablePushEncryption: UInt32 = 1
}

/// Status enum returned by every Resp* message (from `constants.proto`).
public enum CommanderStatus: UInt32, Sendable, CustomStringConvertible {
    case success = 0
    case invalidSecScheme = 1
    case invalidProto = 2
    case tooManySessions = 3
    case invalidArgument = 4
    case internalError = 5
    case cryptoError = 6
    case invalidSession = 7
    case notSupported = 8
    public var description: String {
        switch self {
        case .success:          return "Success"
        case .invalidSecScheme: return "InvalidSecScheme"
        case .invalidProto:     return "InvalidProto"
        case .tooManySessions:  return "TooManySessions"
        case .invalidArgument:  return "InvalidArgument"
        case .internalError:    return "InternalError"
        case .cryptoError:      return "CryptoError"
        case .invalidSession:   return "InvalidSession"
        case .notSupported:     return "NotSupported"
        }
    }
}

// MARK: - Builders

enum Build {
    static func sessionData_sec1(_ sec1Payload: Data) -> Data {
        var w = ProtoWriter()
        w.writeUInt32(F.SD_sec_ver, SecVer.SecScheme1)
        w.writeMessage(F.SD_sec1, sec1Payload)
        return w.data
    }
    static func sec1_cmd0(clientPubkey: Data, flags: UInt32) -> Data {
        var sc0 = ProtoWriter()
        sc0.writeBytes(F.SC0_client_pubkey, clientPubkey)
        sc0.writeUInt32(F.SC0_enhance_security_flags, flags)
        var p = ProtoWriter()
        p.writeUInt32(F.S1_msg, Sec1Msg.Command0)
        p.writeMessage(F.S1_sc0, sc0.data)
        return p.data
    }
    static func sec1_cmd1(clientVerifyData: Data, deviceType: Int32) -> Data {
        var sc1 = ProtoWriter()
        sc1.writeBytes(F.SC1_client_verify_data, clientVerifyData)
        sc1.writeInt32(F.SC1_device_type, deviceType)
        var p = ProtoWriter()
        p.writeUInt32(F.S1_msg, Sec1Msg.Command1)
        p.writeMessage(F.S1_sc1, sc1.data)
        return p.data
    }
    static func sendUUID(_ uuid: String) -> Data {
        var inner = ProtoWriter(); inner.writeString(F.RSU_UUID, uuid)
        var outer = ProtoWriter()
        outer.writeUInt32(F.EP_msgType, MsgType.ReqSendUUID)
        outer.writeMessage(F.EP_pReqSendUUID, inner.data)
        return outer.data
    }
    static func subscribeVehicleData(fields: [UInt64]? = nil) -> Data {
        var inner = ProtoWriter()
        if let fields = fields {
            inner.writePackedVarints(F.RSV_subscribe_fields, fields)
        } else {
            inner.writeBool(F.RSV_subscribe_all, true)
        }
        var outer = ProtoWriter()
        outer.writeUInt32(F.EP_msgType, MsgType.ReqSubscribeVehicleData)
        outer.writeMessage(F.EP_pReqSubscribeVehicleData, inner.data)
        return outer.data
    }
    static func unsubscribeAll() -> Data {
        var inner = ProtoWriter()
        inner.writeBool(F.RSV_unsubscribe_all, true)
        var outer = ProtoWriter()
        outer.writeUInt32(F.EP_msgType, MsgType.ReqSubscribeVehicleData)
        outer.writeMessage(F.EP_pReqSubscribeVehicleData, inner.data)
        return outer.data
    }
}

// MARK: - Parsers

struct SessionResp0 {
    var status: UInt32 = 0; var devicePubkey = Data(); var deviceRandom = Data(); var confirmFlags: UInt32 = 0
}
struct SessionResp1 {
    var status: UInt32 = 0; var deviceVerifyData = Data()
}

enum Parse {
    static func sessionData(_ data: Data) throws -> (msg: UInt32, inner: Data) {
        var r = ProtoReader(data); var sec1: Data?
        while !r.atEnd {
            let t = try r.readTag()
            if t.field == F.SD_sec1 && t.wire == 2 { sec1 = try r.readBytes() }
            else { try r.skip(wire: t.wire) }
        }
        guard let s = sec1 else { throw ProtoError.truncated }
        var r2 = ProtoReader(s); var msg: UInt32 = 0; var inner = Data()
        while !r2.atEnd {
            let t = try r2.readTag()
            switch (t.field, t.wire) {
            case (F.S1_msg, 0): msg = UInt32(truncatingIfNeeded: try r2.readVarint())
            case (F.S1_sr0, 2), (F.S1_sr1, 2): inner = try r2.readBytes()
            default: try r2.skip(wire: t.wire)
            }
        }
        return (msg, inner)
    }
    static func sessionResp0(_ data: Data) throws -> SessionResp0 {
        var r = ProtoReader(data); var o = SessionResp0()
        while !r.atEnd {
            let t = try r.readTag()
            switch (t.field, t.wire) {
            case (F.SR0_status, 0): o.status = UInt32(truncatingIfNeeded: try r.readVarint())
            case (F.SR0_device_pubkey, 2): o.devicePubkey = try r.readBytes()
            case (F.SR0_device_random, 2): o.deviceRandom = try r.readBytes()
            case (F.SR0_confirm_security_flags, 0): o.confirmFlags = UInt32(truncatingIfNeeded: try r.readVarint())
            default: try r.skip(wire: t.wire)
            }
        }
        return o
    }
    static func sessionResp1(_ data: Data) throws -> SessionResp1 {
        var r = ProtoReader(data); var o = SessionResp1()
        while !r.atEnd {
            let t = try r.readTag()
            switch (t.field, t.wire) {
            case (F.SR1_status, 0): o.status = UInt32(truncatingIfNeeded: try r.readVarint())
            case (F.SR1_device_verify_data, 2): o.deviceVerifyData = try r.readBytes()
            default: try r.skip(wire: t.wire)
            }
        }
        return o
    }
    /// Decode an EnhApiPayloadHolder response. Returns msgType + inner Status.
    static func respStatus(_ data: Data) throws -> (msgType: UInt32, status: CommanderStatus) {
        var r = ProtoReader(data); var msg: UInt32 = 0; var inner = Data()
        while !r.atEnd {
            let t = try r.readTag()
            switch (t.field, t.wire) {
            case (F.EP_msgType, 0): msg = UInt32(truncatingIfNeeded: try r.readVarint())
            case (_, 2):             inner = try r.readBytes()
            default: try r.skip(wire: t.wire)
            }
        }
        var r2 = ProtoReader(inner); var statusVal: UInt32 = 0
        while !r2.atEnd {
            let t = try r2.readTag()
            if t.field == 1 && t.wire == 0 { statusVal = UInt32(truncatingIfNeeded: try r2.readVarint()) }
            else { try r2.skip(wire: t.wire) }
        }
        return (msg, CommanderStatus(rawValue: statusVal) ?? .internalError)
    }
    /// Decode an EnhApiPushPayloadHolder into the raw PushVehicleDataHolder payload bytes
    /// (nil if the push type is not VehicleData).
    static func vehicleDataPushPayload(_ data: Data) throws -> Data? {
        var r = ProtoReader(data); var pushType: UInt32 = 0; var payload: Data?
        while !r.atEnd {
            let t = try r.readTag()
            switch (t.field, t.wire) {
            case (F.EPP_pushType, 0): pushType = UInt32(truncatingIfNeeded: try r.readVarint())
            case (F.EPP_pPushVehicleDataHolder, 2): payload = try r.readBytes()
            default: try r.skip(wire: t.wire)
            }
        }
        return pushType == PushType.VehicleDataHolder ? payload : nil
    }
}

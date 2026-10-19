import Foundation

/// One field of a protobuf message as it is on the wire, schema or not.
struct WireField {
    let number: UInt64
    /// 0 varint, 1 fixed64, 2 length-delimited, 5 fixed32.
    let wire: Int
    let varint: UInt64
    let bytes: Data
}

/// Just enough protobuf to read anything the Commander sends and to build the few requests the
/// probe makes — without the library's internal reader.
enum Wire {
    /// The fields of `data`, or nil when it is no valid message.
    static func fields(_ data: Data) -> [WireField]? {
        let bytes = [UInt8](data)
        var i = 0, out: [WireField] = []
        func varint() -> UInt64? {
            var result: UInt64 = 0, shift: UInt64 = 0
            while i < bytes.count, shift < 64 {
                let b = bytes[i]; i += 1
                result |= UInt64(b & 0x7F) << shift
                if b & 0x80 == 0 { return result }
                shift += 7
            }
            return nil
        }
        while i < bytes.count {
            guard let tag = varint(), tag >> 3 > 0 else { return nil }
            let wire = Int(tag & 7), number = tag >> 3
            switch wire {
            case 0:
                guard let v = varint() else { return nil }
                out.append(WireField(number: number, wire: 0, varint: v, bytes: Data()))
            case 1, 5:
                let size = wire == 1 ? 8 : 4
                guard i + size <= bytes.count else { return nil }
                let chunk = Data(bytes[i..<i + size]); i += size
                let v = chunk.reversed().reduce(UInt64(0)) { $0 << 8 | UInt64($1) }
                out.append(WireField(number: number, wire: wire, varint: v, bytes: chunk))
            case 2:
                guard let length = varint(), i + Int(length) <= bytes.count else { return nil }
                out.append(WireField(number: number, wire: 2, varint: 0, bytes: Data(bytes[i..<i + Int(length)])))
                i += Int(length)
            default:
                return nil
            }
        }
        return out
    }

    // MARK: Writing

    static func varint(_ value: UInt64) -> Data {
        var v = value, out = Data()
        repeat {
            var b = UInt8(v & 0x7F); v >>= 7
            if v != 0 { b |= 0x80 }
            out.append(b)
        } while v != 0
        return out
    }

    static func uint(_ field: Int, _ value: UInt64) -> Data { varint(UInt64(field << 3)) + varint(value) }

    static func message(_ field: Int, _ body: Data) -> Data {
        varint(UInt64(field << 3 | 2)) + varint(UInt64(body.count)) + body
    }

    /// An `EnhApiPayloadHolder`: the message type and the request in its payload field.
    static func request(msgType: UInt64, payloadField: Int, body: Data = Data()) -> Data {
        uint(1, msgType) + message(payloadField, body)
    }

    // MARK: Reading values

    /// A field's value as the schema says it is; without one, as the wire suggests.
    static func render(_ field: WireField, as type: ProtoType?) -> String {
        switch (type, field.wire) {
        case (.sint32?, 0):
            let v = Int64(bitPattern: field.varint >> 1) ^ -Int64(bitPattern: field.varint & 1)
            return String(v)
        case (.int32?, 0):
            return String(Int32(truncatingIfNeeded: field.varint))
        case (.bool?, 0):
            return field.varint == 0 ? "false" : "true"
        case (.enumeration(let name)?, 0):
            let label = Schema.enums[name]?[field.varint]
            return label.map { "\($0) (\(field.varint))" } ?? "\(field.varint) (\(name)?)"
        case (_, 5):
            let f = Float(bitPattern: UInt32(truncatingIfNeeded: field.varint))
            return type == .uint32 ? String(field.varint) : String(format: "%.6g", f)
        case (_, 1):
            return String(format: "%.9g", Double(bitPattern: field.varint))
        case (_, 0):
            return String(field.varint)
        case (.string?, 2):
            return "\"\(String(decoding: field.bytes, as: UTF8.self))\""
        default:
            return describe(field.bytes)
        }
    }

    /// Bytes of unknown meaning: a nested message if they read as one, else text, else hex.
    static func describe(_ data: Data, depth: Int = 0) -> String {
        if data.isEmpty { return "{}" }
        if depth < 6, let nested = fields(data), !nested.isEmpty {
            return "{" + nested.map { "\($0.number): \(describeValue($0, depth: depth + 1))" }.joined(separator: ", ") + "}"
        }
        if let text = String(data: data, encoding: .utf8), text.allSatisfy({ !$0.isASCII || $0.isLetter || $0.isNumber || $0.isPunctuation || $0.isSymbol || $0 == " " }) {
            return "\"\(text)\""
        }
        return "0x" + hex(data)
    }

    private static func describeValue(_ field: WireField, depth: Int) -> String {
        switch field.wire {
        case 0: return String(field.varint)
        case 5: return String(format: "%.6g", Float(bitPattern: UInt32(truncatingIfNeeded: field.varint)))
        case 1: return String(format: "%.9g", Double(bitPattern: field.varint))
        default: return describe(field.bytes, depth: depth)
        }
    }

    static func hex(_ data: Data) -> String { data.map { String(format: "%02x", $0) }.joined() }
}

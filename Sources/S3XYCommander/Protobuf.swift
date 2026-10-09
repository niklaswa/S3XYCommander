import Foundation

// Minimal hand-rolled protobuf wire-format codec. No external dependencies.
// Only covers the subset of wire types the Enhauto Commander uses.

struct ProtoWriter {
    private(set) var data = Data()
    mutating func writeVarint(_ v: UInt64) {
        var x = v
        while x >= 0x80 { data.append(UInt8((x & 0x7F) | 0x80)); x >>= 7 }
        data.append(UInt8(x))
    }
    private mutating func writeTag(_ field: Int, wire: Int) { writeVarint(UInt64((field << 3) | wire)) }
    mutating func writeUInt32(_ field: Int, _ v: UInt32) { writeTag(field, wire: 0); writeVarint(UInt64(v)) }
    mutating func writeInt32(_ field: Int, _ v: Int32)   { writeTag(field, wire: 0); writeVarint(UInt64(bitPattern: Int64(v))) }
    mutating func writeBool(_ field: Int, _ v: Bool)     { writeTag(field, wire: 0); writeVarint(v ? 1 : 0) }
    mutating func writeBytes(_ field: Int, _ v: Data)    { writeTag(field, wire: 2); writeVarint(UInt64(v.count)); data.append(v) }
    mutating func writeString(_ field: Int, _ v: String) { writeBytes(field, Data(v.utf8)) }
    mutating func writeMessage(_ field: Int, _ v: Data)  { writeBytes(field, v) }
    mutating func writePackedVarints(_ field: Int, _ values: [UInt64]) {
        var inner = ProtoWriter()
        for v in values { inner.writeVarint(v) }
        writeBytes(field, inner.data)
    }
}

struct ProtoReader {
    let data: Data
    private var i: Int
    init(_ data: Data) { self.data = data; self.i = 0 }
    var atEnd: Bool { i >= data.count }
    mutating func readVarint() throws -> UInt64 {
        var r: UInt64 = 0; var s: UInt64 = 0
        while i < data.count {
            let b = data[data.startIndex + i]; i += 1
            r |= UInt64(b & 0x7F) << s
            if b & 0x80 == 0 { return r }
            s += 7; if s > 63 { throw ProtoError.varintOverflow }
        }
        throw ProtoError.truncated
    }
    mutating func readTag() throws -> (field: Int, wire: Int) {
        let k = try readVarint(); return (Int(k >> 3), Int(k & 7))
    }
    mutating func readBytes() throws -> Data {
        let len = Int(try readVarint())
        guard i + len <= data.count else { throw ProtoError.truncated }
        let s = data.startIndex + i
        let out = data.subdata(in: s..<(s+len))
        i += len
        return out
    }
    mutating func readFixed32() throws -> UInt32 {
        guard i + 4 <= data.count else { throw ProtoError.truncated }
        let s = data.startIndex + i
        let b0 = UInt32(data[s]); let b1 = UInt32(data[s+1]) << 8
        let b2 = UInt32(data[s+2]) << 16; let b3 = UInt32(data[s+3]) << 24
        i += 4
        return b0 | b1 | b2 | b3
    }
    mutating func skip(wire: Int) throws {
        switch wire {
        case 0: _ = try readVarint()
        case 1: guard i + 8 <= data.count else { throw ProtoError.truncated }; i += 8
        case 2: _ = try readBytes()
        case 5: _ = try readFixed32()
        default: throw ProtoError.unknownWireType(wire)
        }
    }
}

enum ProtoError: Error, CustomStringConvertible {
    case truncated, varintOverflow, unknownWireType(Int)
    var description: String {
        switch self {
        case .truncated: return "truncated"
        case .varintOverflow: return "varint overflow"
        case .unknownWireType(let w): return "unknown wire type \(w)"
        }
    }
}

// Decode a signed int that was encoded as a bare varint (NOT zigzag),
// matching how proto's `sint32`/`int32` fields are serialised by the
// Enhauto firmware's `sint32` entries in PushVehicleDataHolder.
@inline(__always)
func varintAsInt32(_ v: UInt64) -> Int32 { Int32(truncatingIfNeeded: v) }

import Foundation

enum InstallerSecret {
    static func reveal() -> String {
        let list: [UInt8] = [
            0xF2, 0xE5, 0xEE, 0xF3,
            0xEC, 0xE9, 0xF0, 0xAD,
            0xE1, 0xE9, 0xF2, 0xEF,
            0xF4, 0xE3, 0xE9, 0xF6
        ]
        let num: UInt8 = 0x80
        let bytes = list.reversed().map { $0 &- num }
        return String(decoding: bytes, as: UTF8.self)
    }
}


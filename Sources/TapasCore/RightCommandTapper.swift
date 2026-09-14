public enum KeyEvent: Equatable, Sendable {
    case down(code: UInt16, isRepeat: Bool)
    case up(code: UInt16)
}

public enum RightCommandTapper {
    public static let rightCommand: UInt16 = 54
    public static let leftCommand: UInt16 = 55
}

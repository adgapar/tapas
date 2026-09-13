public enum KeyEvent: Equatable, Sendable {
    case down(code: UInt16, isRepeat: Bool)
    case up(code: UInt16)
}

public struct RightCommandTapper: Sendable {
    public static let rightCommand: UInt16 = 54
    public static let leftCommand: UInt16 = 55

    private var pending = false
    private var chorded = false

    public init() {}

    public mutating func handle(_ event: KeyEvent) -> Bool {
        switch event {
        case .down(let code, _):
            if code == Self.rightCommand {
                pending = true
                chorded = false
                return false
            }
            if pending { chorded = true }
            return false
        case .up(let code):
            let fired = code == Self.rightCommand && pending && !chorded
            pending = false
            chorded = false
            return fired
        }
    }
}

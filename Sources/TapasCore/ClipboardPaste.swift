public protocol Pasteboard: AnyObject, Sendable {
    var string: String? { get set }
}

public protocol CommandV: Sendable {
    func commandV() async throws
}

public struct ClipboardPaster: TextPaster {
    public var board: any Pasteboard
    public var typer: any CommandV

    public init(board: any Pasteboard, typer: any CommandV) {
        self.board = board
        self.typer = typer
    }

    public func paste(_ text: String) async throws {
        let previous = board.string
        board.string = text
        defer { board.string = previous }
        try await typer.commandV()
    }
}

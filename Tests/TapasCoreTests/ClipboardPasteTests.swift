import Testing
@testable import TapasCore

final class FakeBoard: Pasteboard, @unchecked Sendable {
    var string: String?
}

final class FakeTyper: CommandV, @unchecked Sendable {
    var typed = 0
    func commandV() async throws {
        typed += 1
    }
}

@Test func restoresPreviousClipboard() async throws {
    let board = FakeBoard()
    board.string = "previous"
    let typer = FakeTyper()
    let paster = ClipboardPaster(board: board, typer: typer)
    try await paster.paste("hello")
    #expect(typer.typed == 1)
    #expect(board.string == "previous")
}

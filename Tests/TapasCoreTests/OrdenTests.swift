import Testing
@testable import TapasCore

@Test func v1AlwaysReturnsDictado() {
    #expect(Orden.classify("create screenshot of this") == .dictado)
    #expect(Orden.classify("hola qué tal") == .dictado)
    #expect(Orden.classify("") == .dictado)
}

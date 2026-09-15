import Testing
@testable import TapasApp

@Test func microphoneActivityReadsProcessFlagsWithoutStartingCapture() throws {
    let processes = try MicrophoneActivity.read()
    #expect(processes.allSatisfy { $0.pid > 0 })
}

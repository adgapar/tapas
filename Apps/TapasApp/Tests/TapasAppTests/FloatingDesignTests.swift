import AppKit
import SwiftUI
import Testing
@testable import TapasApp

@MainActor @Test func fittedScrollViewSurvivesInitialLayoutAndResize() throws {
    _ = NSApplication.shared
    let preferred = NSSize(width: 710, height: 770)
    let window = FloatingWindow(contentRect: NSRect(origin: .zero, size: preferred),
                                styleMask: [.borderless, .closable, .miniaturizable], backing: .buffered, defer: false)
    configureFloatingWindow(window)
    defer { window.close() }
    let surface = FittedSurface(width: preferred.width, height: preferred.height) {
        ScrollView {
            VStack {
                ForEach(0..<30) { Text("Row \($0)") }
            }
        }
    }
    let host = NSHostingController(rootView: surface.frame(width: 0, height: 0))
    window.contentViewController = host
    let content = try #require(window.contentView)
    // Exercise the launch path before the window has ever been ordered onscreen.
    placeFloatingWindow(window, preferred: preferred)
    for size in [NSSize.zero, NSSize(width: 0, height: 770), NSSize(width: 710, height: 0),
                 NSSize(width: 590, height: 640), preferred] {
        host.rootView = surface.frame(width: size.width, height: size.height)
        window.setContentSize(size)
        content.layoutSubtreeIfNeeded()
    }
    #expect(content.bounds.size == preferred)
}

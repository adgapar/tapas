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

@Test func counterPerspectiveKeepsFarEdgeFixedAndBringsNearEdgeForward() {
    let size = CGSize(width: 352, height: 460)
    let projection = CounterPerspective(degrees: 10).effectValue(size: size)
    func project(_ point: CGPoint) -> CGPoint {
        let w = point.x * projection.m13 + point.y * projection.m23 + projection.m33
        return CGPoint(x: (point.x * projection.m11 + point.y * projection.m21 + projection.m31) / w,
                       y: (point.x * projection.m12 + point.y * projection.m22 + projection.m32) / w)
    }
    #expect(project(.zero) == .zero)
    #expect(project(CGPoint(x: size.width, y: 0)) == CGPoint(x: size.width, y: 0))
    let nearLeft = project(CGPoint(x: 0, y: size.height))
    let nearRight = project(CGPoint(x: size.width, y: size.height))
    #expect(nearLeft.x < 0)
    #expect(nearRight.x > size.width)
    #expect(abs((nearLeft.x + nearRight.x) / 2 - size.width / 2) < 0.001)
    #expect(nearLeft.y.isFinite && nearLeft.y > 0)
    #expect(nearLeft.y < 505) // Leaves room for the counter edge in the seated composition.
}

@MainActor @Test func toolsReceiptCanExpandForWorkAndReturnToCompactHome() throws {
    _ = NSApplication.shared
    let model = PlateModel()
    let actions = PlateActions(talk: {}, setup: {}, setHotkey: { _ in }, recordHotkey: {}, preferencesChanged: {}, folder: {}, copy: { _ in }, export: { _ in }, dismiss: {}, retryPaste: {}, retrySave: {}, cancel: {}, quit: {})
    let controller = PlateWindowController(model: model, actions: actions)
    let window = try #require(controller.window)
    defer { window.close() }
    controller.resizeForCurrentPage()
    let compact = window.frame.size
    model.selectedTool = "Acta"
    controller.resizeForCurrentPage()
    #expect(window.frame.height > compact.height)
    #expect(model.selectedTool == "Acta")
    model.selectedTool = nil
    model.tab = "Preferences"
    controller.resizeForCurrentPage()
    #expect(window.frame.height > compact.height)
    model.tab = "Tools"
    controller.resizeForCurrentPage()
    #expect(window.frame.size == compact)
    #expect(window.contentView != nil)
}

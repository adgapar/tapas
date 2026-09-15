import Foundation
import CoreGraphics
import Testing
@testable import TapasCore

@Test func receiptExpiresWithoutChangingDeliveryOrReturningAfterSuppression() {
    var presentation = DictadoPresentation()
    let listening = OverlaySnapshot(isVisible: true, phase: .listening)
    let delivered = OverlaySnapshot(isVisible: false, phase: .delivered)
    #expect(presentation.isVisible(for: listening, suppressed: false, now: 0) == true)
    #expect(presentation.isVisible(for: delivered, suppressed: false, now: 1) == true)
    #expect(presentation.isVisible(for: delivered, suppressed: false, now: 2.5) == true)
    #expect(presentation.isVisible(for: delivered, suppressed: false, now: 2.61) == false)
    #expect(presentation.isVisible(for: delivered, suppressed: false, now: 10) == false)
    #expect(presentation.isVisible(for: listening, suppressed: false, now: 11) == true)
    #expect(presentation.isVisible(for: delivered, suppressed: false, now: 12) == true)
    #expect(presentation.isVisible(for: delivered, suppressed: true, now: 12.1) == false)
    #expect(presentation.isVisible(for: delivered, suppressed: false, now: 12.2) == false)
}

@Test func practiceDeliveryNeverLeaksOutOfSetup() {
    var presentation = DictadoPresentation()
    #expect(presentation.isVisible(for: .init(isVisible: true, phase: .finishing), suppressed: true, now: 0) == false)
    #expect(presentation.isVisible(for: .init(phase: .delivered), suppressed: false, now: 1) == false)
    #expect(presentation.isVisible(for: .init(phase: .delivered), suppressed: false, now: 1.5) == false)
}

@Test func cancellationHidesImmediatelyAndRecoveryDoesNotExpire() {
    var presentation = DictadoPresentation()
    for phase in [DictationPhase.starting, .listening, .finishing] {
        #expect(presentation.isVisible(for: .init(isVisible: true, phase: phase), suppressed: false, now: 0) == true)
    }
    #expect(presentation.isVisible(for: .init(), suppressed: false, now: 1) == false)
    for phase in [DictationPhase.failed, .recovery] {
        let snapshot = OverlaySnapshot(isVisible: true, committedText: "Retained words", phase: phase)
        #expect(presentation.isVisible(for: snapshot, suppressed: false, now: 2) == true)
        #expect(presentation.isVisible(for: snapshot, suppressed: false, now: 10_000) == true)
        #expect(presentation.isVisible(for: snapshot, suppressed: true, now: 10_001) == false)
        #expect(presentation.isVisible(for: snapshot, suppressed: false, now: 10_002) == true)
    }
}

@Test func aNewTakeInterruptsTheReceipt() {
    var presentation = DictadoPresentation()
    _ = presentation.isVisible(for: .init(isVisible: true, phase: .listening), suppressed: false, now: 0)
    _ = presentation.isVisible(for: .init(phase: .delivered), suppressed: false, now: 1)
    #expect(presentation.isVisible(for: .init(isVisible: true, phase: .starting), suppressed: false, now: 1.1) == true)
    #expect(presentation.isVisible(for: .init(isVisible: true, phase: .listening), suppressed: false, now: 4) == true)
}

@Test func placementClearsTheMenuAndCameraIncludingHiddenMenuAndSecondaryDisplays() {
    let size = CGSize(width: 124, height: 28)
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let menuVisible = CGRect(x: 0, y: 70, width: 1512, height: 874)
    let notched = DictadoPlacement.frame(size: size, screen: screen, visible: menuVisible, safeTopInset: 32)
    #expect(notched.maxY == 938) // Menu bottom 944 minus six.
    #expect(notched.midX == screen.midX)
    let fullscreen = DictadoPlacement.frame(size: size, screen: screen, visible: screen, safeTopInset: 32)
    #expect(fullscreen.maxY == 944) // Camera bottom 950 minus six even with the menu hidden.
    let external = CGRect(x: -1920, y: -300, width: 1920, height: 1080)
    let externalVisible = CGRect(x: -1920, y: -300, width: 1920, height: 1056)
    let regular = DictadoPlacement.frame(size: size, screen: external, visible: externalVisible, safeTopInset: 0)
    #expect(regular == CGRect(x: -1022, y: 722, width: 124, height: 28))
    let caption = DictadoPlacement.frame(size: .init(width: 340, height: 62), screen: screen, visible: menuVisible, safeTopInset: 32, offset: 36)
    #expect(caption.maxY == notched.minY - 8)
}

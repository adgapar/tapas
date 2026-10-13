import CoreGraphics
import Testing
import TapasCore
@testable import TapasApp

@Test func restingPintxoKeepsItsTiltedOrder() {
    let pieces = PintxoLayout.pieces(.resting)
    #expect(pieces.map(\.length) == PintxoLayout.lengths)
    #expect(pieces.allSatisfy { $0.degrees == PintxoLayout.tilt })
    // Saffron at the top, olive at the bottom, drifting right along the tilted pick.
    #expect(zip(pieces, pieces.dropFirst()).allSatisfy { $0.center.y < $1.center.y && $0.center.x < $1.center.x })
}

@Test func standingPiecesStayInOrderOnAFlatPick() {
    let pieces = PintxoLayout.pieces(.standing(split: false), levels: [0.2, 0.4, 0.6, 0.8])
    #expect(PintxoLayout.pickDegrees(.standing(split: false)) == PintxoLayout.upright)
    #expect(pieces.allSatisfy { $0.degrees == PintxoLayout.upright && $0.center.y == 75 })
    #expect(zip(pieces, pieces.dropFirst()).allSatisfy { $0.center.x < $1.center.x })
    // The first piece keeps its rounder corner.
    #expect(pieces[0].corner > pieces[1].corner)
}

@Test func standingPiecesGrowWithTheVoiceAndRestAsBeads() {
    let quiet = PintxoLayout.pieces(.standing(split: false), levels: [0, 0, 0, 0])
    let loud = PintxoLayout.pieces(.standing(split: false), levels: [1, 1, 1, 1])
    #expect(quiet.allSatisfy { $0.length == 22 })
    #expect(zip(quiet, loud).allSatisfy { $0.length < $1.length })
    let clamped = PintxoLayout.pieces(.standing(split: false), levels: [3, -1, 1, 1])
    #expect(clamped[0].length == loud[0].length && clamped[1].length == quiet[1].length)
}

@Test func aCallSplitsYouFromOthers() {
    let together = PintxoLayout.pieces(.standing(split: false))
    let split = PintxoLayout.pieces(.standing(split: true))
    let gap = { (p: [PintxoPiece]) in p[2].center.x - p[1].center.x }
    #expect(gap(split) > gap(together))
}

@Test func piecesFillInOrderWhileDownloading() {
    #expect(PintxoLayout.fill(progress: 0, index: 0) == 0)
    #expect(PintxoLayout.fill(progress: 0.375, index: 0) == 1)
    #expect(PintxoLayout.fill(progress: 0.375, index: 1) == 0.5)
    #expect(PintxoLayout.fill(progress: 0.375, index: 2) == 0)
    #expect((0..<4).allSatisfy { PintxoLayout.fill(progress: 1, index: $0) == 1 })
}

@Test func dictadoPhasesMapToPintxoForms() {
    #expect(DictationPhase.listening.pintxoForm == .standing(split: false))
    #expect(DictationPhase.starting.pintxoForm == .working)
    #expect(DictationPhase.finishing.pintxoForm == .working)
    #expect(DictationPhase.delivered.pintxoForm == .resting)
}

@Test func dictadoSurfacesKeepFixedSizesAndStack() {
    #expect(DictadoMetrics.signal == CGSize(width: 155, height: 44))
    #expect(DictadoMetrics.captionOffset(controlsShown: false) < DictadoMetrics.captionOffset(controlsShown: true))
    #expect(DictadoMetrics.captionOffset(controlsShown: true) >= DictadoMetrics.controlsOffset + DictadoMetrics.controls.height)
}

@MainActor @Test func captionMarksOnlyTheNewestWords() {
    let model = OverlayModel()
    model.snapshot = OverlaySnapshot(isVisible: true, committedText: "te paso el borrador con los cambios", phase: .listening)
    #expect(model.captionParts.older == "te paso el borrador")
    #expect(model.captionParts.newest == "con los cambios")
    model.snapshot.committedText = "Hola"
    #expect(model.captionParts.older.isEmpty && model.captionParts.newest == "Hola")
    #expect(model.label == "Dictado" || model.label == "Listening")
}

@Test func frauncesTagsAreFourCharacterCodes() {
    #expect(FrauncesFonts.tag("wght").uint32Value == 0x7767_6874)
    #expect(FrauncesFonts.tag("SOFT").uint32Value == 0x534F_4654)
}

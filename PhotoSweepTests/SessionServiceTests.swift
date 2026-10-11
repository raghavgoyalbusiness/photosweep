#if SWIFT_PACKAGE
import Testing
@testable import PhotoSweepLogic

@Suite("Session service")
struct SessionServiceTests {
    @Test func deleteDecisionUpdatesCountsAndUndoRestoresUnreviewed() {
        runDeleteDecisionUpdatesCountsAndUndoRestoresUnreviewed()
    }

    @Test func changingDeleteToKeepAdjustsStorageAndCounts() {
        runChangingDeleteToKeepAdjustsStorageAndCounts()
    }
}
#else
import XCTest
@testable import PhotoSweep

final class SessionServiceTests: XCTestCase {
    func testDeleteDecisionUpdatesCountsAndUndoRestoresUnreviewed() {
        runDeleteDecisionUpdatesCountsAndUndoRestoresUnreviewed()
    }

    func testChangingDeleteToKeepAdjustsStorageAndCounts() {
        runChangingDeleteToKeepAdjustsStorageAndCounts()
    }
}
#endif

private func runDeleteDecisionUpdatesCountsAndUndoRestoresUnreviewed() {
    let service = SessionService()
    var session = service.startSession(title: "Quick Clean")
    var asset = PhotoAsset(
        localIdentifier: "asset-1",
        type: .photo,
        estimatedSize: 42_000_000
    )

    let action = service.recordDecision(for: &asset, decision: .delete, in: &session)

    photosweepExpect(asset.status == .delete)
    photosweepExpect(session.reviewedCount == 1)
    photosweepExpect(session.deleteCount == 1)
    photosweepExpect(session.keptCount == 0)
    photosweepExpect(session.estimatedStorageFreed == 42_000_000)

    service.undo(action: action, asset: &asset, session: &session)

    photosweepExpect(asset.status == .unreviewed)
    photosweepExpect(session.reviewedCount == 0)
    photosweepExpect(session.deleteCount == 0)
    photosweepExpect(session.estimatedStorageFreed == 0)
}

private func runChangingDeleteToKeepAdjustsStorageAndCounts() {
    let service = SessionService()
    var session = service.startSession(title: "Storage Rescue")
    var asset = PhotoAsset(
        localIdentifier: "asset-2",
        type: .video,
        estimatedSize: 900_000_000
    )

    _ = service.recordDecision(for: &asset, decision: .delete, in: &session)
    _ = service.recordDecision(for: &asset, decision: .keep, in: &session)

    photosweepExpect(asset.status == .keep)
    photosweepExpect(session.reviewedCount == 1)
    photosweepExpect(session.deleteCount == 0)
    photosweepExpect(session.keptCount == 1)
    photosweepExpect(session.estimatedStorageFreed == 0)
}

private func photosweepExpect(
    _ condition: @autoclosure () -> Bool
) {
    #if SWIFT_PACKAGE
    #expect(condition())
    #else
    XCTAssertTrue(condition())
    #endif
}

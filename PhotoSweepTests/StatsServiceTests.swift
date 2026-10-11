#if SWIFT_PACKAGE
import Testing
@testable import PhotoSweepLogic

@Suite("Stats service")
struct StatsServiceTests {
    @Test func statsAwardXPForReviewedDeletedAndCompletedSession() {
        runStatsAwardXPForReviewedDeletedAndCompletedSession()
    }
}
#else
import Foundation
import XCTest
@testable import PhotoSweep

final class StatsServiceTests: XCTestCase {
    func testStatsAwardXPForReviewedDeletedAndCompletedSession() {
        runStatsAwardXPForReviewedDeletedAndCompletedSession()
    }

    func testConsecutiveCleanupDaysIncreaseStreak() throws {
        try runConsecutiveCleanupDaysIncreaseStreak()
    }
}
#endif

private func runStatsAwardXPForReviewedDeletedAndCompletedSession() {
    let service = StatsService()
    var session = CleanupSession(title: "Camera Roll Detox")
    session.reviewedCount = 47
    session.keptCount = 31
    session.deleteCount = 16

    let stats = service.applyingSession(session, to: UserStats())

    photosweepExpect(stats.totalReviewed == 47)
    photosweepExpect(stats.totalDeleted == 16)
    photosweepExpect(stats.xp == 137)
    photosweepExpect(stats.level == 2)
    photosweepExpect(stats.currentStreak == 1)
}

#if !SWIFT_PACKAGE
private func runConsecutiveCleanupDaysIncreaseStreak() throws {
    let service = StatsService()
    var session = CleanupSession(title: "Quick Clean")
    session.reviewedCount = 50

    let calendar = Calendar(identifier: .gregorian)
    let dayOne = try photosweepRequire(calendar.date(from: DateComponents(year: 2026, month: 5, day: 12)))
    let dayTwo = try photosweepRequire(calendar.date(from: DateComponents(year: 2026, month: 5, day: 13)))

    let first = service.applyingSession(session, to: UserStats(), on: dayOne)
    let second = service.applyingSession(session, to: first, on: dayTwo)

    photosweepExpect(second.currentStreak == 2)
    photosweepExpect(second.todayReviewed == 50)
}
#endif

private func photosweepRequire<T>(
    _ value: T?
) throws -> T {
    #if SWIFT_PACKAGE
    return try #require(value)
    #else
    return try XCTUnwrap(value)
    #endif
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

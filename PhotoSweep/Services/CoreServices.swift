import Foundation

final class SessionService {
    func startSession(title: String, date: Date = Date()) -> CleanupSession {
        CleanupSession(title: title, startDate: date)
    }

    @discardableResult
    func recordDecision(
        for asset: inout PhotoAsset,
        decision: PhotoAssetStatus,
        in session: inout CleanupSession
    ) -> ReviewAction {
        let previous = asset.status
        let action = ReviewAction(
            assetID: asset.localIdentifier,
            previousStatus: previous,
            newStatus: decision,
            estimatedSize: asset.estimatedSize
        )

        applyDelta(from: previous, to: decision, size: asset.estimatedSize, session: &session)
        asset.status = decision
        return action
    }

    func undo(action: ReviewAction, asset: inout PhotoAsset, session: inout CleanupSession) {
        guard asset.localIdentifier == action.assetID else { return }
        applyDelta(from: asset.status, to: action.previousStatus, size: action.estimatedSize, session: &session)
        asset.status = action.previousStatus
    }

    func complete(session: inout CleanupSession, endDate: Date = Date()) {
        session.endDate = endDate
    }

    private func applyDelta(
        from oldStatus: PhotoAssetStatus,
        to newStatus: PhotoAssetStatus,
        size: Int64?,
        session: inout CleanupSession
    ) {
        guard oldStatus != newStatus else { return }

        if oldStatus == .unreviewed && newStatus != .unreviewed {
            session.reviewedCount += 1
        } else if oldStatus != .unreviewed && newStatus == .unreviewed {
            session.reviewedCount = max(0, session.reviewedCount - 1)
        }

        adjustCount(for: oldStatus, by: -1, size: size, session: &session)
        adjustCount(for: newStatus, by: 1, size: size, session: &session)
    }

    private func adjustCount(
        for status: PhotoAssetStatus,
        by delta: Int,
        size: Int64?,
        session: inout CleanupSession
    ) {
        switch status {
        case .keep:
            session.keptCount = max(0, session.keptCount + delta)
        case .delete:
            session.deleteCount = max(0, session.deleteCount + delta)
            let sizeDelta = Int64(delta) * (size ?? 0)
            session.estimatedStorageFreed = max(0, session.estimatedStorageFreed + sizeDelta)
        case .maybeLater:
            session.maybeLaterCount = max(0, session.maybeLaterCount + delta)
        case .unreviewed:
            break
        }
    }
}

final class StatsService {
    let dailyGoal = 50

    func applyingSession(_ session: CleanupSession, to stats: UserStats, on date: Date = Date()) -> UserStats {
        var updated = stats
        updated.totalReviewed += session.reviewedCount
        updated.totalDeleted += session.deleteCount
        updated.todayReviewed = reviewedToday(existing: stats, adding: session.reviewedCount, on: date)
        updated.currentStreak = streak(existing: stats, sessionDate: date)
        updated.lastCleanupDate = date
        updated.lifetimeStorageFreed += session.estimatedStorageFreed
        updated.xp += xpEarned(for: session)
        updated.level = level(forXP: updated.xp)
        updated.achievements = AchievementRules.achievements(for: updated)
        return updated
    }

    func xpEarned(for session: CleanupSession) -> Int {
        guard session.reviewedCount > 0 else { return 0 }
        return session.reviewedCount + (session.deleteCount * 5) + 10
    }

    func progressToDailyGoal(reviewedToday: Int) -> Double {
        min(1, max(0, Double(reviewedToday) / Double(dailyGoal)))
    }

    func level(forXP xp: Int) -> Int {
        max(1, (xp / 100) + 1)
    }

    private func reviewedToday(existing stats: UserStats, adding reviewed: Int, on date: Date) -> Int {
        guard let lastCleanupDate = stats.lastCleanupDate else { return reviewed }
        if Calendar.current.isDate(lastCleanupDate, inSameDayAs: date) {
            return stats.todayReviewed + reviewed
        }
        return reviewed
    }

    private func streak(existing stats: UserStats, sessionDate: Date) -> Int {
        guard let lastCleanupDate = stats.lastCleanupDate else { return 1 }
        if Calendar.current.isDate(lastCleanupDate, inSameDayAs: sessionDate) {
            return max(1, stats.currentStreak)
        }
        if let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: sessionDate),
           Calendar.current.isDate(lastCleanupDate, inSameDayAs: yesterday) {
            return stats.currentStreak + 1
        }
        return 1
    }
}

final class SmartGroupingService {
    func groupForDeleteReview(_ assets: [PhotoAsset]) -> [(title: String, assets: [PhotoAsset])] {
        let buckets: [(String, (PhotoAsset) -> Bool)] = [
            ("Screenshots", { $0.type == .screenshot }),
            ("Blurry", { $0.badges.contains(.possiblyBlurry) }),
            ("Duplicates", { $0.badges.contains(.duplicateCandidate) || $0.badges.contains(.similarCandidate) }),
            ("Videos", { $0.type == .video }),
            ("Old photos", { asset in
                guard let date = asset.creationDate else { return false }
                return Calendar.current.dateComponents([.year], from: date, to: Date()).year ?? 0 >= 1
            }),
            ("Other", { _ in true })
        ]

        var remaining = assets
        var grouped: [(String, [PhotoAsset])] = []
        for (title, matcher) in buckets {
            let matched = remaining.filter(matcher)
            guard !matched.isEmpty else { continue }
            grouped.append((title, matched))
            let matchedIDs = Set(matched.map(\.localIdentifier))
            remaining.removeAll { matchedIDs.contains($0.localIdentifier) }
        }
        return grouped
    }

    func similarGroups(from assets: [PhotoAsset]) -> [SimilarPhotoGroup] {
        let grouped = Dictionary(grouping: assets.filter { $0.type != .video }) { asset in
            let day = asset.creationDate.map { Calendar.current.startOfDay(for: $0) } ?? Date.distantPast
            let sizeBucket = (asset.estimatedSize ?? 0) / (512 * 1024)
            return "\(day.timeIntervalSince1970)-\(sizeBucket)"
        }

        return grouped.values
            .filter { $0.count > 1 }
            .map { candidates in
                let recommended = candidates.max { ($0.estimatedSize ?? 0) < ($1.estimatedSize ?? 0) }
                let marked = candidates.map { asset in
                    var copy = asset
                    copy.badges.insert(.similarCandidate)
                    if copy.localIdentifier == recommended?.localIdentifier {
                        copy.badges.insert(.recommendedKeep)
                    }
                    return copy
                }
                return SimilarPhotoGroup(
                    title: "\(candidates.count) similar shots",
                    assets: marked,
                    recommendedAssetID: recommended?.localIdentifier
                )
            }
    }
}

enum PersonalityMessageService {
    static func message(for session: CleanupSession) -> String {
        if session.deleteCount == 0 { return "Tiny cleanup, big peace." }
        if session.estimatedStorageFreed > 800 * 1024 * 1024 { return "Storage rescued." }
        if session.title.localizedCaseInsensitiveContains("screenshot") { return "Screenshot graveyard cleared." }
        return "Your camera roll is breathing again."
    }

    static func songsEquivalent(for bytes: Int64) -> String {
        let songs = max(1, Int(bytes / (3 * 1024 * 1024)))
        return "You just saved enough space for \(songs) songs."
    }
}

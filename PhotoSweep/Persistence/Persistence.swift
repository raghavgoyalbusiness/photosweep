import Foundation
import SwiftData

@Model
final class ReviewedAssetRecord {
    @Attribute(.unique) var localIdentifier: String
    var typeRaw: String
    var creationDate: Date?
    var estimatedSize: Int64?
    var statusRaw: String
    var reviewedAt: Date?
    var badgesRaw: String = ""
    var sourceHintRaw: String?

    init(asset: PhotoAsset, status: PhotoAssetStatus, reviewedAt: Date = Date()) {
        self.localIdentifier = asset.localIdentifier
        self.typeRaw = asset.type.rawValue
        self.creationDate = asset.creationDate
        self.estimatedSize = asset.estimatedSize
        self.statusRaw = status.rawValue
        self.reviewedAt = reviewedAt
        self.badgesRaw = asset.badges.map(\.rawValue).sorted().joined(separator: ",")
        self.sourceHintRaw = asset.sourceHint?.rawValue
    }

    var status: PhotoAssetStatus {
        PhotoAssetStatus(rawValue: statusRaw) ?? .unreviewed
    }

    var badges: Set<AssetBadge> {
        Set(
            badgesRaw
                .split(separator: ",")
                .compactMap { AssetBadge(rawValue: String($0)) }
        )
    }

    var sourceHint: AssetSourceHint? {
        sourceHintRaw.flatMap { AssetSourceHint(rawValue: $0) }
    }
}

@Model
final class CleanupSessionRecord {
    @Attribute(.unique) var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date?
    var reviewedCount: Int
    var keptCount: Int
    var deleteCount: Int
    var maybeLaterCount: Int = 0
    var estimatedStorageFreed: Int64
    var storageGoalBytes: Int64?
    var timerDuration: TimeInterval?

    init(session: CleanupSession) {
        self.id = session.id
        self.title = session.title
        self.startDate = session.startDate
        self.endDate = session.endDate
        self.reviewedCount = session.reviewedCount
        self.keptCount = session.keptCount
        self.deleteCount = session.deleteCount
        self.maybeLaterCount = session.maybeLaterCount
        self.estimatedStorageFreed = session.estimatedStorageFreed
        self.storageGoalBytes = session.storageGoal?.targetBytes
        self.timerDuration = session.timerDuration
    }
}

@Model
final class UserStatsRecord {
    @Attribute(.unique) var id: UUID
    var totalReviewed: Int
    var totalDeleted: Int
    var currentStreak: Int
    var xp: Int
    var level: Int
    var todayReviewed: Int
    var lastCleanupDate: Date?
    var lifetimeStorageFreed: Int64 = 0
    var achievementsRaw: String = ""

    init(stats: UserStats = UserStats()) {
        self.id = stats.id
        self.totalReviewed = stats.totalReviewed
        self.totalDeleted = stats.totalDeleted
        self.currentStreak = stats.currentStreak
        self.xp = stats.xp
        self.level = stats.level
        self.todayReviewed = stats.todayReviewed
        self.lastCleanupDate = stats.lastCleanupDate
        self.lifetimeStorageFreed = stats.lifetimeStorageFreed
        self.achievementsRaw = stats.achievements.map(\.rawValue).sorted().joined(separator: ",")
    }

    var value: UserStats {
        UserStats(
            id: id,
            totalReviewed: totalReviewed,
            totalDeleted: totalDeleted,
            currentStreak: currentStreak,
            xp: xp,
            level: level,
            todayReviewed: todayReviewed,
            lastCleanupDate: lastCleanupDate,
            lifetimeStorageFreed: lifetimeStorageFreed,
            achievements: Set(
                achievementsRaw
                    .split(separator: ",")
                    .compactMap { Achievement(rawValue: String($0)) }
            )
        )
    }

    func update(with stats: UserStats) {
        totalReviewed = stats.totalReviewed
        totalDeleted = stats.totalDeleted
        currentStreak = stats.currentStreak
        xp = stats.xp
        level = stats.level
        todayReviewed = stats.todayReviewed
        lastCleanupDate = stats.lastCleanupDate
        lifetimeStorageFreed = stats.lifetimeStorageFreed
        achievementsRaw = stats.achievements.map(\.rawValue).sorted().joined(separator: ",")
    }
}

enum ModelContainerFactory {
    @MainActor
    static func make() throws -> ModelContainer {
        let schema = Schema([
            ReviewedAssetRecord.self,
            CleanupSessionRecord.self,
            UserStatsRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @MainActor
    static func preview() throws -> ModelContainer {
        let schema = Schema([
            ReviewedAssetRecord.self,
            CleanupSessionRecord.self,
            UserStatsRecord.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}

@MainActor
enum PersistenceBridge {
    static func statusMap(from records: [ReviewedAssetRecord]) -> [String: PhotoAssetStatus] {
        Dictionary(uniqueKeysWithValues: records.map { ($0.localIdentifier, $0.status) })
    }

    static func setStatus(_ status: PhotoAssetStatus, for asset: PhotoAsset, in context: ModelContext) {
        if status == .unreviewed {
            deleteRecord(for: asset.localIdentifier, in: context)
            return
        }

        let localIdentifier = asset.localIdentifier
        let descriptor = FetchDescriptor<ReviewedAssetRecord>(
            predicate: #Predicate { $0.localIdentifier == localIdentifier }
        )

        if let existing = try? context.fetch(descriptor).first {
            existing.typeRaw = asset.type.rawValue
            existing.creationDate = asset.creationDate
            existing.estimatedSize = asset.estimatedSize
            existing.statusRaw = status.rawValue
            existing.reviewedAt = Date()
            existing.badgesRaw = asset.badges.map(\.rawValue).sorted().joined(separator: ",")
            existing.sourceHintRaw = asset.sourceHint?.rawValue
        } else {
            context.insert(ReviewedAssetRecord(asset: asset, status: status))
        }
        try? context.save()
    }

    static func saveSession(_ session: CleanupSession, in context: ModelContext) {
        context.insert(CleanupSessionRecord(session: session))
        try? context.save()
    }

    static func getOrCreateStats(in context: ModelContext) -> UserStatsRecord {
        let descriptor = FetchDescriptor<UserStatsRecord>()
        if let existing = try? context.fetch(descriptor).first {
            return existing
        }
        let created = UserStatsRecord()
        context.insert(created)
        try? context.save()
        return created
    }

    static func deleteRecord(for localIdentifier: String, in context: ModelContext) {
        let identifier = localIdentifier
        let descriptor = FetchDescriptor<ReviewedAssetRecord>(
            predicate: #Predicate { $0.localIdentifier == identifier }
        )
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
            try? context.save()
        }
    }

    static func deleteRecords(for localIdentifiers: Set<String>, in context: ModelContext) {
        let descriptor = FetchDescriptor<ReviewedAssetRecord>()
        guard let records = try? context.fetch(descriptor) else { return }
        records
            .filter { localIdentifiers.contains($0.localIdentifier) }
            .forEach { context.delete($0) }
        try? context.save()
    }
}

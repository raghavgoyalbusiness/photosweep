import Foundation

#if canImport(UIKit)
import UIKit
#endif

enum AssetKind: String, Codable, CaseIterable, Identifiable {
    case photo
    case video
    case screenshot

    var id: String { rawValue }

    var label: String {
        switch self {
        case .photo: return "Photo"
        case .video: return "Video"
        case .screenshot: return "Screenshot"
        }
    }
}

enum PhotoAssetStatus: String, Codable, CaseIterable {
    case unreviewed
    case keep
    case delete
    case maybeLater
}

struct PhotoAsset: Identifiable, Equatable {
    let id: String
    let localIdentifier: String
    var type: AssetKind
    var creationDate: Date?
    var estimatedSize: Int64?
    var duration: TimeInterval?
    var isFavorite: Bool
    var status: PhotoAssetStatus
    var badges: Set<AssetBadge>
    var sourceHint: AssetSourceHint?

    #if canImport(UIKit)
    var thumbnail: UIImage?
    #endif

    init(
        localIdentifier: String,
        type: AssetKind,
        creationDate: Date? = nil,
        estimatedSize: Int64? = nil,
        duration: TimeInterval? = nil,
        isFavorite: Bool = false,
        status: PhotoAssetStatus = .unreviewed,
        badges: Set<AssetBadge> = [],
        sourceHint: AssetSourceHint? = nil
    ) {
        self.id = localIdentifier
        self.localIdentifier = localIdentifier
        self.type = type
        self.creationDate = creationDate
        self.estimatedSize = estimatedSize
        self.duration = duration
        self.isFavorite = isFavorite
        self.status = status
        self.badges = badges
        self.sourceHint = sourceHint
        #if canImport(UIKit)
        self.thumbnail = nil
        #endif
    }

    static func == (lhs: PhotoAsset, rhs: PhotoAsset) -> Bool {
        lhs.localIdentifier == rhs.localIdentifier &&
            lhs.type == rhs.type &&
            lhs.creationDate == rhs.creationDate &&
            lhs.estimatedSize == rhs.estimatedSize &&
            lhs.duration == rhs.duration &&
            lhs.isFavorite == rhs.isFavorite &&
            lhs.status == rhs.status &&
            lhs.badges == rhs.badges &&
            lhs.sourceHint == rhs.sourceHint
    }
}

enum AssetBadge: String, Codable, CaseIterable, Identifiable, Hashable {
    case possiblyBlurry
    case recommendedKeep
    case oldMemory
    case largeVideo
    case duplicateCandidate
    case similarCandidate
    case documentLike
    case memeLike
    case selfie

    var id: String { rawValue }

    var label: String {
        switch self {
        case .possiblyBlurry: return "Possibly blurry"
        case .recommendedKeep: return "Recommended keep"
        case .oldMemory: return "Old memory"
        case .largeVideo: return "Large video"
        case .duplicateCandidate: return "Duplicate?"
        case .similarCandidate: return "Similar"
        case .documentLike: return "Document"
        case .memeLike: return "Meme"
        case .selfie: return "Selfie"
        }
    }
}

enum AssetSourceHint: String, Codable, CaseIterable, Identifiable {
    case camera
    case screenshot
    case downloaded
    case whatsapp
    case album

    var id: String { rawValue }
}

struct CleanupSession: Identifiable, Equatable {
    var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date?
    var reviewedCount: Int
    var keptCount: Int
    var deleteCount: Int
    var maybeLaterCount: Int
    var estimatedStorageFreed: Int64
    var storageGoal: StorageGoal?
    var timerDuration: TimeInterval?

    init(
        id: UUID = UUID(),
        title: String = CleanupFilter.randomCleanup.sessionTitle,
        startDate: Date = Date(),
        endDate: Date? = nil,
        reviewedCount: Int = 0,
        keptCount: Int = 0,
        deleteCount: Int = 0,
        maybeLaterCount: Int = 0,
        estimatedStorageFreed: Int64 = 0,
        storageGoal: StorageGoal? = nil,
        timerDuration: TimeInterval? = nil
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.reviewedCount = reviewedCount
        self.keptCount = keptCount
        self.deleteCount = deleteCount
        self.maybeLaterCount = maybeLaterCount
        self.estimatedStorageFreed = estimatedStorageFreed
        self.storageGoal = storageGoal
        self.timerDuration = timerDuration
    }
}

struct StorageGoal: Codable, Equatable, Identifiable, Hashable {
    var id: String { label }
    var label: String
    var targetBytes: Int64

    static let options: [StorageGoal] = [
        StorageGoal(label: "Free 500 MB", targetBytes: 500 * 1024 * 1024),
        StorageGoal(label: "Free 1 GB", targetBytes: 1024 * 1024 * 1024),
        StorageGoal(label: "Free 5 GB", targetBytes: 5 * 1024 * 1024 * 1024)
    ]

    static func custom(bytes: Int64) -> StorageGoal {
        StorageGoal(label: "Custom goal", targetBytes: bytes)
    }
}

struct UserStats: Identifiable, Equatable {
    var id: UUID
    var totalReviewed: Int
    var totalDeleted: Int
    var currentStreak: Int
    var xp: Int
    var level: Int
    var todayReviewed: Int
    var lastCleanupDate: Date?
    var lifetimeStorageFreed: Int64
    var achievements: Set<Achievement>

    init(
        id: UUID = UUID(),
        totalReviewed: Int = 0,
        totalDeleted: Int = 0,
        currentStreak: Int = 0,
        xp: Int = 0,
        level: Int = 1,
        todayReviewed: Int = 0,
        lastCleanupDate: Date? = nil,
        lifetimeStorageFreed: Int64 = 0,
        achievements: Set<Achievement> = []
    ) {
        self.id = id
        self.totalReviewed = totalReviewed
        self.totalDeleted = totalDeleted
        self.currentStreak = currentStreak
        self.xp = xp
        self.level = level
        self.todayReviewed = todayReviewed
        self.lastCleanupDate = lastCleanupDate
        self.lifetimeStorageFreed = lifetimeStorageFreed
        self.achievements = achievements
    }

    var levelTitle: String {
        AchievementRules.levelTitle(for: level)
    }
}

enum CleanupFilter: String, CaseIterable, Identifiable, Hashable {
    case all
    case screenshots
    case videos
    case photos
    case largeFiles
    case thisMonth
    case randomCleanup
    case recentlyAdded
    case olderThanOneYear
    case duplicatePhotos
    case similarPhotos
    case blurryPhotos
    case oldPhotos
    case largeVideos
    case downloadedImages
    case selfies
    case receiptsDocuments
    case memes
    case randomFiveMinuteClean
    case maybeLater

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "Start Cleaning"
        case .screenshots: return "Screenshots"
        case .videos: return "Videos"
        case .photos: return "Photos"
        case .largeFiles: return "Large Files"
        case .thisMonth: return "This Month"
        case .randomCleanup: return "Random Cleanup"
        case .recentlyAdded: return "Recently Added"
        case .olderThanOneYear: return "Older Than 1 Year"
        case .duplicatePhotos: return "Duplicate Photos"
        case .similarPhotos: return "Similar Photos"
        case .blurryPhotos: return "Blurry Photos"
        case .oldPhotos: return "Old Photos"
        case .largeVideos: return "Large Videos"
        case .downloadedImages: return "WhatsApp/Downloads"
        case .selfies: return "Selfies"
        case .receiptsDocuments: return "Receipts/Documents"
        case .memes: return "Memes"
        case .randomFiveMinuteClean: return "Random 5-Minute Clean"
        case .maybeLater: return "Maybe Later"
        }
    }

    var sessionTitle: String {
        switch self {
        case .all: return "Camera Roll Detox"
        case .screenshots: return "Screenshot Slayer"
        case .videos: return "Storage Rescue"
        case .photos: return "Quick Clean"
        case .largeFiles: return "Storage Rescue"
        case .thisMonth: return "Quick Clean"
        case .randomCleanup: return "Random Cleanup"
        case .recentlyAdded: return "Quick Clean"
        case .olderThanOneYear: return "Camera Roll Detox"
        case .duplicatePhotos: return "Duplicate Detective"
        case .similarPhotos: return "Best Shot Picker"
        case .blurryPhotos: return "Blur Patrol"
        case .oldPhotos: return "Memory Check"
        case .largeVideos: return "Storage Rescue"
        case .downloadedImages: return "Downloads Detox"
        case .selfies: return "Selfie Sweep"
        case .receiptsDocuments: return "Paper Trail Cleanup"
        case .memes: return "Meme Tidy"
        case .randomFiveMinuteClean: return "5-Minute Rescue"
        case .maybeLater: return "Maybe Later"
        }
    }

    var explanation: String {
        switch self {
        case .all:
            return "Review your newest non-favorite photos and videos one card at a time."
        case .screenshots:
            return "Clear old screenshots quickly. Favorites and hidden items stay protected."
        case .videos:
            return "Review videos, usually the fastest way to reclaim meaningful space."
        case .photos:
            return "A simple photo-only cleanup pass."
        case .largeFiles:
            return "Prioritize assets with larger estimated file sizes."
        case .thisMonth:
            return "Review photos and videos added this month."
        case .randomCleanup:
            return "A shuffled cleanup run when you just want momentum."
        case .recentlyAdded:
            return "Review recently added photos without digging through your full library."
        case .olderThanOneYear:
            return "Go gently through older memories. PhotoSweep will warn before deletion decisions."
        case .duplicatePhotos:
            return "Find duplicate candidates locally and review groups manually. Nothing is deleted automatically."
        case .similarPhotos:
            return "Group visually similar shots and recommend the strongest one to keep."
        case .blurryPhotos:
            return "Surface low-quality candidates with a subtle blur badge for manual review."
        case .oldPhotos:
            return "Review photos older than a year with softer memory warnings."
        case .largeVideos:
            return "Hunt the biggest videos first for fast storage wins."
        case .downloadedImages:
            return "Focus on imported and downloaded images, including likely messaging app clutter."
        case .selfies:
            return "Review selfies while keeping the final delete confirmation in place."
        case .receiptsDocuments:
            return "Find document-like photos that may no longer be useful."
        case .memes:
            return "Tidy meme-like screenshots and downloaded images."
        case .randomFiveMinuteClean:
            return "Start a timed five-minute cleanup sprint."
        case .maybeLater:
            return "Revisit photos you skipped with the upward swipe."
        }
    }

    var usesSmartAnalysis: Bool {
        switch self {
        case .duplicatePhotos, .similarPhotos, .blurryPhotos, .receiptsDocuments, .memes:
            return true
        default:
            return false
        }
    }
}

enum FeatureFlag: String, CaseIterable, Identifiable {
    case smartCleanupModes
    case duplicateAndSimilarDetection
    case blurryDetection
    case storageGoals
    case protectedPhotos
    case undoTimeline
    case memoryWarnings
    case bestPhotoRecommendation
    case quickCleanTimer
    case dailyChallenges
    case levelsAndAchievements
    case beforeAfterDashboard
    case smartSearch
    case albumCleanup
    case privateMode
    case maybeLaterSwipe
    case smartDeleteReview
    case monthlyReports
    case monetizationDesign
    case personalityMessages

    var id: String { rawValue }
}

enum FeatureFlags {
    static let mvp: Set<FeatureFlag> = []
    static let bonus: Set<FeatureFlag> = Set(FeatureFlag.allCases).subtracting([.privateMode])
    static let enabled: Set<FeatureFlag> = mvp.union(bonus)

    static func isEnabled(_ flag: FeatureFlag) -> Bool {
        enabled.contains(flag)
    }
}

enum Achievement: String, Codable, CaseIterable, Identifiable, Hashable {
    case first100Reviewed
    case first1GBCleared
    case sevenDayStreak
    case hundredScreenshotsDeleted
    case fiveHundredReviewed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .first100Reviewed: return "First 100 photos reviewed"
        case .first1GBCleared: return "First 1 GB cleared"
        case .sevenDayStreak: return "7-day streak"
        case .hundredScreenshotsDeleted: return "100 screenshots deleted"
        case .fiveHundredReviewed: return "500 photos reviewed"
        }
    }
}

enum DailyChallenge: String, CaseIterable, Identifiable {
    case review50
    case delete10Screenshots
    case clear500MB
    case clean20OldPhotos

    var id: String { rawValue }

    var title: String {
        switch self {
        case .review50: return "Review 50 photos"
        case .delete10Screenshots: return "Delete 10 screenshots"
        case .clear500MB: return "Clear 500 MB"
        case .clean20OldPhotos: return "Clean 20 old photos"
        }
    }
}

enum MonetizationTier: String, CaseIterable, Identifiable {
    case free
    case pro

    var id: String { rawValue }

    var features: [String] {
        switch self {
        case .free:
            return ["Basic swipe cleanup", "Screenshot cleanup", "Delete queue"]
        case .pro:
            return ["Duplicate detection", "Blurry detection", "Storage goals", "Face/album protection", "Monthly reports", "Advanced smart filters"]
        }
    }
}

enum AchievementRules {
    static func levelTitle(for level: Int) -> String {
        switch level {
        case 1: return "Photo Rookie"
        case 2: return "Storage Saver"
        case 3: return "Screenshot Slayer"
        case 4: return "Camera Roll Cleaner"
        default: return "Digital Minimalist"
        }
    }

    static func achievements(for stats: UserStats) -> Set<Achievement> {
        var unlocked = stats.achievements
        if stats.totalReviewed >= 100 { unlocked.insert(.first100Reviewed) }
        if stats.lifetimeStorageFreed >= 1024 * 1024 * 1024 { unlocked.insert(.first1GBCleared) }
        if stats.currentStreak >= 7 { unlocked.insert(.sevenDayStreak) }
        if stats.totalReviewed >= 500 { unlocked.insert(.fiveHundredReviewed) }
        return unlocked
    }
}

struct SimilarPhotoGroup: Identifiable, Equatable {
    let id: UUID
    var title: String
    var assets: [PhotoAsset]
    var recommendedAssetID: String?

    init(id: UUID = UUID(), title: String, assets: [PhotoAsset], recommendedAssetID: String? = nil) {
        self.id = id
        self.title = title
        self.assets = assets
        self.recommendedAssetID = recommendedAssetID
    }
}

struct MonthlyCameraRollReport: Equatable {
    var photosAdded: Int
    var videosAdded: Int
    var storageUsed: Int64
    var mostCommonCategory: String
    var recommendation: String
}

struct AlbumSummary: Identifiable, Equatable {
    var id: String
    var title: String
    var assetCount: Int
}

enum PhotoAuthorizationState: Equatable {
    case notDetermined
    case authorized
    case limited
    case denied
    case restricted

    var canReadLibrary: Bool {
        self == .authorized || self == .limited
    }
}

struct ReviewAction: Equatable {
    let assetID: String
    let previousStatus: PhotoAssetStatus
    let newStatus: PhotoAssetStatus
    let estimatedSize: Int64?
}

enum AppError: LocalizedError, Identifiable, Equatable {
    case permissionDenied
    case restrictedAccess
    case emptyLibrary
    case deletionFailed(String)
    case assetUnavailable
    case unknown(String)

    var id: String { errorDescription ?? "unknown" }

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Photo access is denied. Enable Photos access in Settings to use PhotoSweep."
        case .restrictedAccess:
            return "Photo access is restricted on this device."
        case .emptyLibrary:
            return "No photos or videos were found for this cleanup."
        case .deletionFailed(let message):
            return "Deletion failed: \(message)"
        case .assetUnavailable:
            return "This photo is no longer available in your library."
        case .unknown(let message):
            return message
        }
    }
}

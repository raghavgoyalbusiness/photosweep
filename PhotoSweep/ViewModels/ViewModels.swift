import Foundation
import SwiftUI

@MainActor
final class HomeDashboardViewModel: ObservableObject {
    @Published var permissionState: PhotoAuthorizationState = .notDetermined
    @Published var totalAvailable: Int = 0
    @Published var albums: [AlbumSummary] = []
    @Published var monthlyReport: MonthlyCameraRollReport?
    @Published var isLoading = false
    @Published var error: AppError?

    let photoService: PhotoLibraryProviding

    init(photoService: PhotoLibraryProviding = PhotoLibraryService()) {
        self.photoService = photoService
        self.permissionState = photoService.authorizationState()
    }

    func refresh() async {
        permissionState = photoService.authorizationState()
        guard permissionState.canReadLibrary else { return }

        isLoading = true
        error = nil
        do {
            totalAvailable = try await photoService.fetchAssets(filter: .all).count
            albums = (try? await photoService.fetchAlbums()) ?? []
            monthlyReport = try? await buildMonthlyReport()
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
        isLoading = false
    }

    func connectPhotos() async {
        isLoading = true
        permissionState = await photoService.requestAuthorization()
        isLoading = false
        await refresh()
    }

    private func buildMonthlyReport() async throws -> MonthlyCameraRollReport {
        let assets = try await photoService.fetchAssets(filter: .thisMonth)
        let photos = assets.filter { $0.type != .video }
        let videos = assets.filter { $0.type == .video }
        let storage = assets.reduce(Int64(0)) { $0 + ($1.estimatedSize ?? 0) }
        let mostCommon = videos.count > photos.count ? "Videos" : "Photos"
        let recommendation = assets.filter { $0.type == .screenshot }.count > 20
            ? "Screenshots look like the easiest cleanup area."
            : "Large videos are a good next place to check."
        return MonthlyCameraRollReport(
            photosAdded: photos.count,
            videosAdded: videos.count,
            storageUsed: storage,
            mostCommonCategory: mostCommon,
            recommendation: recommendation
        )
    }
}

@MainActor
final class SwipeViewModel: ObservableObject {
    @Published var assets: [PhotoAsset] = []
    @Published var currentIndex = 0
    @Published var session: CleanupSession
    @Published var isLoading = false
    @Published var error: AppError?
    @Published var didFinishSession = false
    @Published var secondsRemaining: Int?

    let filter: CleanupFilter
    let photoService: PhotoLibraryProviding
    private let sessionService: SessionService
    private var history: [ReviewAction] = []
    private var timerTask: Task<Void, Never>?

    init(
        filter: CleanupFilter,
        storageGoal: StorageGoal? = nil,
        timerDuration: TimeInterval? = nil,
        photoService: PhotoLibraryProviding = PhotoLibraryService(),
        sessionService: SessionService = SessionService()
    ) {
        self.filter = filter
        self.photoService = photoService
        self.sessionService = sessionService
        self.session = sessionService.startSession(title: filter.sessionTitle)
        self.session.storageGoal = storageGoal
        self.session.timerDuration = timerDuration ?? (filter == .randomFiveMinuteClean ? 5 * 60 : nil)
        if let timerDuration = self.session.timerDuration {
            self.secondsRemaining = Int(timerDuration)
        }
    }

    var currentAsset: PhotoAsset? {
        guard currentIndex < assets.count else { return nil }
        return assets[currentIndex]
    }

    var progressText: String {
        "\(min(currentIndex + 1, assets.count)) / \(assets.count)"
    }

    var deleteQueue: [PhotoAsset] {
        assets.filter { $0.status == .delete }
    }

    var storageGoalRemainingText: String? {
        guard let goal = session.storageGoal else { return nil }
        let remaining = max(0, goal.targetBytes - session.estimatedStorageFreed)
        return "You're \(DisplayFormatters.shortStorage(remaining)) away from your goal."
    }

    func load(statuses: [String: PhotoAssetStatus]) async {
        guard assets.isEmpty else { return }
        isLoading = true
        error = nil

        do {
            var fetched: [PhotoAsset]
            if filter == .maybeLater {
                let identifiers = statuses
                    .filter { $0.value == .maybeLater }
                    .map(\.key)
                fetched = try await photoService.fetchAssets(localIdentifiers: identifiers)
            } else {
                fetched = try await photoService.fetchAssets(filter: filter)
            }
            fetched = fetched.map { asset in
                var updated = asset
                updated.status = filter == .maybeLater ? .unreviewed : (statuses[asset.localIdentifier] ?? .unreviewed)
                return updated
            }
            assets = fetched.filter { $0.status == .unreviewed }
            if assets.isEmpty {
                error = .emptyLibrary
            } else {
                startTimerIfNeeded()
            }
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .unknown(error.localizedDescription)
        }

        isLoading = false
    }

    @discardableResult
    func decideCurrent(_ status: PhotoAssetStatus) -> PhotoAsset? {
        guard currentIndex < assets.count else { return nil }
        var asset = assets[currentIndex]
        let action = sessionService.recordDecision(for: &asset, decision: status, in: &session)
        assets[currentIndex] = asset
        history.append(action)
        currentIndex += 1

        if currentIndex >= assets.count {
            finishSession()
        }

        return asset
    }

    func undo() -> PhotoAsset? {
        guard let action = history.popLast() else { return nil }
        let index = max(0, currentIndex - 1)
        guard index < assets.count else { return nil }
        currentIndex = index
        var asset = assets[index]
        sessionService.undo(action: action, asset: &asset, session: &session)
        assets[index] = asset
        didFinishSession = false
        return asset
    }

    func finishSession() {
        guard session.endDate == nil else { return }
        sessionService.complete(session: &session)
        didFinishSession = true
    }

    func continueCleaning() {
        didFinishSession = false
    }

    func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func startTimerIfNeeded() {
        guard let timerDuration = session.timerDuration, timerTask == nil else { return }
        secondsRemaining = Int(timerDuration)
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    guard let self, let remaining = self.secondsRemaining else { return }
                    if remaining <= 1 {
                        self.secondsRemaining = 0
                        self.finishSession()
                        self.stopTimer()
                    } else {
                        self.secondsRemaining = remaining - 1
                    }
                }
            }
        }
    }

    deinit {
        timerTask?.cancel()
    }
}

@MainActor
final class DeleteReviewViewModel: ObservableObject {
    @Published var assets: [PhotoAsset]
    @Published var selectedIDs: Set<String>
    @Published var isLoading = false
    @Published var isDeleting = false
    @Published var error: AppError?
    @Published var deletedCount: Int?

    let photoService: PhotoLibraryProviding
    private let deletionService: DeletionServing
    private let groupingService = SmartGroupingService()

    init(
        assets: [PhotoAsset] = [],
        photoService: PhotoLibraryProviding = PhotoLibraryService(),
        deletionService: DeletionServing = DeletionService()
    ) {
        self.assets = assets
        self.selectedIDs = Set(assets.map(\.localIdentifier))
        self.photoService = photoService
        self.deletionService = deletionService
    }

    var selectedAssets: [PhotoAsset] {
        assets.filter { selectedIDs.contains($0.localIdentifier) }
    }

    var estimatedStorage: Int64 {
        selectedAssets.reduce(0) { $0 + ($1.estimatedSize ?? 0) }
    }

    var groupedReviewAssets: [(title: String, assets: [PhotoAsset])] {
        groupingService.groupForDeleteReview(assets)
    }

    func loadIfNeeded(localIdentifiers: [String]) async {
        guard assets.isEmpty, !localIdentifiers.isEmpty else { return }
        isLoading = true
        error = nil
        do {
            assets = try await photoService.fetchAssets(localIdentifiers: localIdentifiers)
            selectedIDs = Set(assets.map(\.localIdentifier))
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
        isLoading = false
    }

    func toggle(_ asset: PhotoAsset) {
        if selectedIDs.contains(asset.localIdentifier) {
            selectedIDs.remove(asset.localIdentifier)
        } else {
            selectedIDs.insert(asset.localIdentifier)
        }
    }

    func applyPersistedMetadata(records: [ReviewedAssetRecord]) {
        let metadataByID = Dictionary(uniqueKeysWithValues: records.map { ($0.localIdentifier, $0) })
        assets = assets.map { asset in
            guard let record = metadataByID[asset.localIdentifier] else { return asset }
            var copy = asset
            copy.badges.formUnion(record.badges)
            copy.sourceHint = copy.sourceHint ?? record.sourceHint
            copy.status = record.status
            return copy
        }
    }

    func deleteSelected() async -> Set<String> {
        let selected = selectedAssets
        guard !selected.isEmpty else { return [] }

        isDeleting = true
        error = nil
        do {
            let count = try await deletionService.deleteAssets(selected)
            deletedCount = count
            isDeleting = false
            return Set(selected.map(\.localIdentifier))
        } catch let appError as AppError {
            error = appError
        } catch {
            self.error = .unknown(error.localizedDescription)
        }
        isDeleting = false
        return []
    }
}

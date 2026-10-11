import SwiftUI
import SwiftData
import UIKit

struct HomeDashboardView: View {
    @ObservedObject var viewModel: HomeDashboardViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var reviewedRecords: [ReviewedAssetRecord]
    @Query private var statsRecords: [UserStatsRecord]

    private let statsService = StatsService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                limitedAccessBanner
                metricGrid
                progressSection
                dailyChallengeSection
                filterButtons
                bonusSections
                errorView
            }
            .padding(20)
        }
        .navigationTitle("PhotoSweep")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                NavigationLink {
                    SessionHistoryView(photoService: viewModel.photoService)
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .accessibilityLabel("Session History")
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await viewModel.refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .accessibilityLabel("Refresh")
            }
        }
        .navigationDestination(for: CleanupFilter.self) { filter in
            ModeIntroView(filter: filter, photoService: viewModel.photoService)
        }
        .task {
            _ = PersistenceBridge.getOrCreateStats(in: modelContext)
            await viewModel.refresh()
        }
    }

    private var stats: UserStats {
        statsRecords.first?.value ?? UserStats()
    }

    private var deleteRecords: [ReviewedAssetRecord] {
        reviewedRecords.filter { $0.status == .delete }
    }

    private var estimatedStorage: Int64 {
        deleteRecords.reduce(0) { $0 + ($1.estimatedSize ?? 0) }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Make space without the slog.")
                .font(.system(size: 30, weight: .black, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Text("Everything runs locally on this iPhone. Photos are never uploaded.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var limitedAccessBanner: some View {
        if viewModel.permissionState == .limited {
            VStack(alignment: .leading, spacing: 10) {
                Label("Limited Photos Access", systemImage: "lock.rectangle.stack")
                    .font(.headline)
                Text("PhotoSweep can only clean the photos you allowed. You can add more from the system picker.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Button {
                    if let root = UIApplication.shared.activeRootViewController {
                        viewModel.photoService.presentLimitedLibraryPicker(from: root)
                    }
                } label: {
                    Label("Choose More Photos", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }
            .padding(16)
            .background(Color.yellow.opacity(0.14))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
    }

    private var metricGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            MetricTile(title: "Available", value: "\(viewModel.totalAvailable)", systemImage: "photo.stack")
            MetricTile(title: "Reviewed", value: "\(stats.totalReviewed)", systemImage: "checkmark.circle")
            MetricTile(title: "Delete Queue", value: "\(deleteRecords.count)", systemImage: "trash")
            MetricTile(title: "Selected Space", value: DisplayFormatters.shortStorage(estimatedStorage), systemImage: "externaldrive")
        }
    }

    private var progressSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Level \(stats.level)")
                        .font(.headline)
                    Text("\(stats.levelTitle) • \(stats.xp) XP • \(stats.currentStreak) day streak")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                    .font(.title2)
            }

            HStack(spacing: 18) {
                ProgressRing(
                    title: "Today",
                    value: "\(stats.todayReviewed)/50",
                    progress: statsService.progressToDailyGoal(reviewedToday: stats.todayReviewed),
                    tint: .black
                )
                ProgressRing(
                    title: "Queued",
                    value: DisplayFormatters.shortStorage(estimatedStorage),
                    progress: min(1, Double(estimatedStorage) / Double(1024 * 1024 * 1024)),
                    tint: .green
                )
            }
        }
        .padding(18)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private var filterButtons: some View {
        VStack(spacing: 12) {
            NavigationLink(value: CleanupFilter.all) {
                Label("Start Cleaning", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                filterLink(.screenshots, "rectangle.on.rectangle.angled")
                filterLink(.videos, "video.fill")
                filterLink(.largeFiles, "externaldrive.fill")
                filterLink(.thisMonth, "calendar")
                filterLink(.randomCleanup, "shuffle")
                filterLink(.olderThanOneYear, "clock.arrow.circlepath")
            }
        }
    }

    private var dailyChallengeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Daily Challenge")
                .font(.headline)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(DailyChallenge.allCases) { challenge in
                    Text(challenge.title)
                        .font(.caption.weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .padding(.horizontal, 10)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }
        }
    }

    private var bonusSections: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Smart Cleanup")
                    .font(.headline)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    filterLink(.duplicatePhotos, "square.on.square")
                    filterLink(.similarPhotos, "rectangle.3.group")
                    filterLink(.blurryPhotos, "camera.filters")
                    filterLink(.oldPhotos, "archivebox")
                    filterLink(.largeVideos, "video.badge.waveform")
                    filterLink(.downloadedImages, "arrow.down.circle")
                    filterLink(.selfies, "person.crop.square")
                    filterLink(.receiptsDocuments, "doc.text.viewfinder")
                    filterLink(.memes, "text.bubble")
                    filterLink(.randomFiveMinuteClean, "timer")
                    filterLink(.maybeLater, "tray.and.arrow.down")
                }
            }

            if let report = viewModel.monthlyReport {
                MonthlyReportCard(report: report)
            }

            if !viewModel.albums.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Albums")
                        .font(.headline)
                    ForEach(viewModel.albums.prefix(5)) { album in
                        HStack {
                            Text(album.title)
                            Spacer()
                            Text("\(album.assetCount)")
                                .foregroundStyle(.secondary)
                        }
                        .font(.callout)
                    }
                }
                .padding(16)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            NavigationLink {
                FreemiumPlanView()
            } label: {
                Label("Freemium Plan", systemImage: "sparkles")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.bordered)
        }
    }

    private func filterLink(_ filter: CleanupFilter, _ image: String) -> some View {
        NavigationLink(value: filter) {
            Label(filter.title, systemImage: image)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .tint(.primary)
    }

    @ViewBuilder
    private var errorView: some View {
        if let error = viewModel.error {
            Text(error.localizedDescription)
                .font(.footnote)
                .foregroundStyle(.red)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct ModeIntroView: View {
    let filter: CleanupFilter
    let photoService: PhotoLibraryProviding
    @State private var selectedGoal: StorageGoal?
    @State private var selectedTimer: TimeInterval?

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            Spacer(minLength: 12)
            Image(systemName: icon)
                .font(.system(size: 46, weight: .bold))
            Text(filter.title)
                .font(.system(size: 34, weight: .black, design: .rounded))
                .fixedSize(horizontal: false, vertical: true)
            Text(filter.explanation)
                .font(.body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            if FeatureFlags.isEnabled(.storageGoals) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Storage Goal")
                        .font(.headline)
                    HStack {
                        ForEach(StorageGoal.options) { goal in
                            Button(goal.label.replacingOccurrences(of: "Free ", with: "")) {
                                selectedGoal = goal
                            }
                            .buttonStyle(.bordered)
                            .tint(selectedGoal == goal ? .green : .primary)
                        }
                    }
                }
            }

            if FeatureFlags.isEnabled(.quickCleanTimer) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Timer")
                        .font(.headline)
                    HStack {
                        ForEach([60, 180, 300, 600], id: \.self) { seconds in
                            Button("\(seconds / 60)m") {
                                selectedTimer = TimeInterval(seconds)
                            }
                            .buttonStyle(.bordered)
                            .tint(selectedTimer == TimeInterval(seconds) ? .black : .primary)
                        }
                    }
                }
            }

            Spacer()

            NavigationLink {
                SwipeView(
                    filter: filter,
                    storageGoal: selectedGoal,
                    timerDuration: selectedTimer,
                    photoService: photoService
                )
            } label: {
                Label("Start", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
        }
        .padding(22)
        .navigationTitle("Cleanup Mode")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var icon: String {
        switch filter {
        case .duplicatePhotos, .similarPhotos: return "rectangle.3.group"
        case .blurryPhotos: return "camera.filters"
        case .largeVideos, .videos: return "video.fill"
        case .screenshots: return "rectangle.on.rectangle.angled"
        case .randomFiveMinuteClean: return "timer"
        case .maybeLater: return "tray.and.arrow.down"
        default: return "sparkles.rectangle.stack"
        }
    }
}

struct MonthlyReportCard: View {
    let report: MonthlyCameraRollReport

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Monthly Camera Roll Report")
                .font(.headline)
            Text("You added \(report.photosAdded) photos and \(report.videosAdded) videos this month.")
                .font(.callout)
            Text("Storage used: \(DisplayFormatters.shortStorage(report.storageUsed))")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text(report.recommendation)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct FreemiumPlanView: View {
    var body: some View {
        List {
            ForEach(MonetizationTier.allCases) { tier in
                Section(tier.rawValue.capitalized) {
                    ForEach(tier.features, id: \.self) { feature in
                        Label(feature, systemImage: tier == .free ? "checkmark.circle" : "sparkles")
                    }
                }
            }
        }
        .navigationTitle("Plan Design")
    }
}

struct SessionHistoryView: View {
    let photoService: PhotoLibraryProviding
    @Query(sort: \CleanupSessionRecord.startDate, order: .reverse) private var sessions: [CleanupSessionRecord]
    @Query private var reviewed: [ReviewedAssetRecord]

    var body: some View {
        List {
            Section("Undo Timeline") {
                ForEach(sortedReviewed.prefix(80), id: \.localIdentifier) { record in
                    HStack {
                        Image(systemName: icon(for: record.status))
                            .foregroundStyle(color(for: record.status))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(record.status.rawValue.capitalized)
                                .font(.headline)
                            Text(record.reviewedAt.map(DisplayFormatters.date) ?? "Date unavailable")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(DisplayFormatters.storage(record.estimatedSize))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Sessions") {
                ForEach(sessions) { session in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(session.title)
                            .font(.headline)
                        Text(DisplayFormatters.date(session.startDate))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Label("\(session.reviewedCount)", systemImage: "checkmark.circle")
                            Label("\(session.deleteCount)", systemImage: "trash")
                            Label(DisplayFormatters.shortStorage(session.estimatedStorageFreed), systemImage: "externaldrive")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .navigationTitle("History")
    }

    private func icon(for status: PhotoAssetStatus) -> String {
        switch status {
        case .keep: return "heart.fill"
        case .delete: return "trash.fill"
        case .maybeLater: return "tray.and.arrow.down.fill"
        case .unreviewed: return "circle"
        }
    }

    private var sortedReviewed: [ReviewedAssetRecord] {
        reviewed.sorted {
            ($0.reviewedAt ?? .distantPast) > ($1.reviewedAt ?? .distantPast)
        }
    }

    private func color(for status: PhotoAssetStatus) -> Color {
        switch status {
        case .keep: return .green
        case .delete: return .red
        case .maybeLater: return .orange
        case .unreviewed: return .secondary
        }
    }
}

import SwiftUI
import SwiftData

struct SwipeView: View {
    @StateObject private var viewModel: SwipeViewModel
    @Environment(\.modelContext) private var modelContext
    @Query private var reviewedRecords: [ReviewedAssetRecord]
    @Query private var statsRecords: [UserStatsRecord]

    @State private var dragOffset: CGSize = .zero
    @State private var showPreview = false
    @State private var showInfo = false
    @State private var didPersistSession = false
    @State private var pendingOldMemoryDelete = false

    private let haptics = HapticsService()
    private let statsService = StatsService()

    init(
        filter: CleanupFilter,
        storageGoal: StorageGoal? = nil,
        timerDuration: TimeInterval? = nil,
        photoService: PhotoLibraryProviding = PhotoLibraryService()
    ) {
        _viewModel = StateObject(
            wrappedValue: SwipeViewModel(
                filter: filter,
                storageGoal: storageGoal,
                timerDuration: timerDuration,
                photoService: photoService
            )
        )
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if viewModel.isLoading {
                ProgressView("Loading photos...")
            } else if let error = viewModel.error {
                EmptyStateView(title: "Nothing to sweep", message: error.localizedDescription, systemImage: "photo.stack")
            } else {
                swipeContent
            }
        }
        .navigationTitle(viewModel.session.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if let seconds = viewModel.secondsRemaining {
                    Text(timerText(seconds))
                        .font(.caption.bold())
                        .foregroundStyle(seconds < 30 ? .red : .secondary)
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Text(viewModel.progressText)
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }
        }
        .task {
            await viewModel.load(statuses: PersistenceBridge.statusMap(from: reviewedRecords))
        }
        .onChange(of: viewModel.didFinishSession) { _, didFinish in
            if didFinish {
                persistCompletedSessionIfNeeded()
            }
        }
        .navigationDestination(isPresented: $viewModel.didFinishSession) {
            SessionSummaryView(
                session: viewModel.session,
                deleteQueue: viewModel.deleteQueue,
                photoService: viewModel.photoService,
                onContinue: { viewModel.continueCleaning() }
            )
        }
        .sheet(isPresented: $showPreview) {
            if let asset = viewModel.currentAsset {
                FullPreviewView(asset: asset, service: viewModel.photoService)
            }
        }
        .sheet(isPresented: $showInfo) {
            if let asset = viewModel.currentAsset {
                AssetInfoView(asset: asset)
                    .presentationDetents([.medium])
            }
        }
        .alert("Old memory", isPresented: $pendingOldMemoryDelete) {
            Button("Keep", role: .cancel) { }
            Button("Add to Delete Queue", role: .destructive) {
                animateCommit(.delete)
            }
        } message: {
            Text("This photo is from an earlier year. Are you sure you want to remove it?")
        }
    }

    private var swipeContent: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 8)

            if let asset = viewModel.currentAsset {
                PhotoCardView(
                    asset: asset,
                    service: viewModel.photoService,
                    offset: dragOffset
                )
                .offset(dragOffset)
                .rotationEffect(.degrees(Double(dragOffset.width / 22)))
                .gesture(dragGesture)
                .onTapGesture { showPreview = true }
                .animation(.spring(response: 0.35, dampingFraction: 0.82), value: dragOffset)
                .padding(.horizontal, 18)

                metadataBar(asset)
                if let goalText = viewModel.storageGoalRemainingText {
                    Text(goalText)
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.green)
                }
            }

            bottomControls
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                dragOffset = value.translation
                if abs(value.translation.width) > 90 {
                    haptics.selection()
                }
            }
            .onEnded { value in
                if value.translation.width < -120 {
                    commit(.delete)
                } else if value.translation.width > 120 {
                    commit(.keep)
                } else if value.translation.height < -120, FeatureFlags.isEnabled(.maybeLaterSwipe) {
                    commit(.maybeLater)
                } else {
                    dragOffset = .zero
                }
            }
    }

    private var bottomControls: some View {
        HStack(spacing: 14) {
            controlButton("Undo", "arrow.uturn.backward", tint: .secondary) {
                if let asset = viewModel.undo() {
                    PersistenceBridge.setStatus(asset.status, for: asset, in: modelContext)
                    haptics.selection()
                }
            }
            controlButton("Delete", "trash.fill", tint: .red) { commit(.delete) }
            controlButton("Later", "tray.and.arrow.down.fill", tint: .orange) { commit(.maybeLater) }
            controlButton("Keep", "heart.fill", tint: .green) { commit(.keep) }
            controlButton("Info", "info.circle", tint: .primary) { showInfo = true }
        }
    }

    private func controlButton(_ title: String, _ image: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: image)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 48, height: 48)
                    .background(tint.opacity(0.12))
                    .clipShape(Circle())
                Text(title)
                    .font(.caption2.weight(.semibold))
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .foregroundStyle(tint)
    }

    private func metadataBar(_ asset: PhotoAsset) -> some View {
        HStack(spacing: 12) {
            Label(DisplayFormatters.date(asset.creationDate), systemImage: "calendar")
            Label(DisplayFormatters.storage(asset.estimatedSize), systemImage: "externaldrive")
            Label(asset.type.label, systemImage: asset.type == .video ? "video" : "photo")
        }
        .font(.caption)
        .lineLimit(1)
        .minimumScaleFactor(0.72)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .padding(.horizontal, 20)
        .overlay(alignment: .top) {
            if !asset.badges.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(asset.badges), id: \.self) { badge in
                            Text(badge.label)
                                .font(.caption2.bold())
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(badge == .recommendedKeep ? Color.green.opacity(0.18) : Color.black.opacity(0.08))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 24)
                    .offset(y: -30)
                }
            }
        }
    }

    private func commit(_ status: PhotoAssetStatus) {
        if status == .delete,
           FeatureFlags.isEnabled(.memoryWarnings),
           shouldWarnBeforeDeleting(viewModel.currentAsset) {
            pendingOldMemoryDelete = true
            return
        }
        animateCommit(status)
    }

    private func animateCommit(_ status: PhotoAssetStatus) {
        haptics.decision(status)
        withAnimation(.spring(response: 0.28, dampingFraction: 0.8)) {
            switch status {
            case .delete:
                dragOffset = CGSize(width: -900, height: 40)
            case .keep:
                dragOffset = CGSize(width: 900, height: 40)
            case .maybeLater:
                dragOffset = CGSize(width: 0, height: -900)
            case .unreviewed:
                dragOffset = .zero
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.16) {
            if let asset = viewModel.decideCurrent(status) {
                PersistenceBridge.setStatus(status, for: asset, in: modelContext)
            }
            dragOffset = .zero
        }
    }

    private func persistCompletedSessionIfNeeded() {
        guard !didPersistSession, viewModel.session.reviewedCount > 0 else { return }
        didPersistSession = true
        PersistenceBridge.saveSession(viewModel.session, in: modelContext)
        let record = PersistenceBridge.getOrCreateStats(in: modelContext)
        record.update(with: statsService.applyingSession(viewModel.session, to: record.value))
        try? modelContext.save()
        haptics.success()
    }

    private func timerText(_ seconds: Int) -> String {
        "\(seconds / 60):" + String(format: "%02d", seconds % 60)
    }

    private func shouldWarnBeforeDeleting(_ asset: PhotoAsset?) -> Bool {
        guard let asset else { return false }
        if asset.badges.contains(.oldMemory) { return true }
        guard let creationDate = asset.creationDate else { return false }
        return Calendar.current.dateComponents([.year], from: creationDate, to: Date()).year ?? 0 >= 1
    }
}

struct PhotoCardView: View {
    let asset: PhotoAsset
    let service: PhotoLibraryProviding
    let offset: CGSize

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                AsyncThumbnailView(
                    asset: asset,
                    service: service,
                    targetSize: CGSize(width: proxy.size.width * 2, height: proxy.size.height * 2)
                )

                HStack {
                    swipeLabel("DELETE", color: .red, opacity: deleteOpacity)
                    Spacer()
                    swipeLabel("KEEP", color: .green, opacity: keepOpacity)
                }
                .padding(22)
                VStack {
                    swipeLabel("LATER", color: .orange, opacity: laterOpacity)
                    Spacer()
                }
                .padding(22)
            }
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .shadow(color: .black.opacity(0.18), radius: 22, x: 0, y: 14)
        }
        .aspectRatio(0.72, contentMode: .fit)
    }

    private var deleteOpacity: Double {
        min(1, max(0, Double(-offset.width / 120)))
    }

    private var keepOpacity: Double {
        min(1, max(0, Double(offset.width / 120)))
    }

    private var laterOpacity: Double {
        min(1, max(0, Double(-offset.height / 120)))
    }

    private func swipeLabel(_ text: String, color: Color, opacity: Double) -> some View {
        Text(text)
            .font(.system(size: 24, weight: .black, design: .rounded))
            .foregroundStyle(color)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.white.opacity(0.86))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(color, lineWidth: 3)
            )
            .opacity(opacity)
    }
}

struct AssetInfoView: View {
    let asset: PhotoAsset

    var body: some View {
        NavigationStack {
            List {
                LabeledContent("Type", value: asset.type.label)
                LabeledContent("Date", value: DisplayFormatters.date(asset.creationDate))
                LabeledContent("Estimated Size", value: DisplayFormatters.storage(asset.estimatedSize))
                if let duration = asset.duration {
                    LabeledContent("Duration", value: "\(Int(duration)) sec")
                }
                LabeledContent("Favorite", value: asset.isFavorite ? "Yes" : "No")
            }
            .navigationTitle("Photo Info")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

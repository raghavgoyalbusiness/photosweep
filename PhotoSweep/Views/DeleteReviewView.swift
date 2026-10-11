import SwiftUI
import SwiftData

struct DeleteReviewView: View {
    @StateObject private var viewModel: DeleteReviewViewModel
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var reviewedRecords: [ReviewedAssetRecord]

    @State private var showConfirmation = false
    @State private var showDeletedAlert = false

    init(initialAssets: [PhotoAsset] = [], photoService: PhotoLibraryProviding = PhotoLibraryService()) {
        _viewModel = StateObject(
            wrappedValue: DeleteReviewViewModel(assets: initialAssets, photoService: photoService)
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                ProgressView("Loading delete queue...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.assets.isEmpty {
                EmptyStateView(
                    title: "Queue is empty",
                    message: "Photos you swipe left on will appear here before anything is deleted.",
                    systemImage: "trash"
                )
            } else {
                queueGrid
                footer
            }
        }
        .navigationTitle("Delete Queue")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let identifiers = reviewedRecords
                .filter { $0.status == .delete }
                .map(\.localIdentifier)
            await viewModel.loadIfNeeded(localIdentifiers: identifiers)
            viewModel.applyPersistedMetadata(records: reviewedRecords)
        }
        .alert("Delete Selected?", isPresented: $showConfirmation) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Selected", role: .destructive) {
                Task {
                    let deletedIDs = await viewModel.deleteSelected()
                    if !deletedIDs.isEmpty {
                        PersistenceBridge.deleteRecords(for: deletedIDs, in: modelContext)
                        showDeletedAlert = true
                    }
                }
            }
        } message: {
            Text("This will delete \(viewModel.selectedAssets.count) photos from your Photos library. You may still be able to recover them from Recently Deleted depending on your device settings.")
        }
        .alert("Deleted", isPresented: $showDeletedAlert) {
            Button("Done") { dismiss() }
        } message: {
            Text("\(viewModel.deletedCount ?? 0) items were deleted from Photos.")
        }
        .overlay(alignment: .bottom) {
            if viewModel.isDeleting {
                ProgressView("Deleting from Photos...")
                    .padding(16)
                    .background(.thinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .padding(.bottom, 92)
            }
        }
    }

    private var queueGrid: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 18) {
                ForEach(viewModel.groupedReviewAssets, id: \.title) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(group.title)
                            .font(.headline)
                            .padding(.horizontal, 12)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 104), spacing: 8)], spacing: 8) {
                            ForEach(group.assets) { asset in
                                assetTile(asset)
                            }
                        }
                    }
                }
            }
            .padding(12)
        }
    }

    private func assetTile(_ asset: PhotoAsset) -> some View {
        Button {
            viewModel.toggle(asset)
        } label: {
            ZStack(alignment: .topTrailing) {
                AsyncThumbnailView(
                    asset: asset,
                    service: viewModel.photoService,
                    targetSize: CGSize(width: 260, height: 260)
                )
                .aspectRatio(1, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

                Image(systemName: viewModel.selectedIDs.contains(asset.localIdentifier) ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(viewModel.selectedIDs.contains(asset.localIdentifier) ? .red : .white)
                    .padding(6)
                    .shadow(radius: 8)
            }
        }
        .buttonStyle(.plain)
    }

    private var footer: some View {
        VStack(spacing: 12) {
            if let error = viewModel.error {
                Text(error.localizedDescription)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(viewModel.selectedAssets.count) selected")
                        .font(.headline)
                    Text(DisplayFormatters.shortStorage(viewModel.estimatedStorage))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    showConfirmation = true
                } label: {
                    Label("Delete Selected", systemImage: "trash.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .tint(.red)
                .disabled(viewModel.selectedAssets.isEmpty || viewModel.isDeleting)
            }
        }
        .padding(16)
        .background(.regularMaterial)
    }
}

import SwiftUI

struct SessionSummaryView: View {
    let session: CleanupSession
    let deleteQueue: [PhotoAsset]
    let photoService: PhotoLibraryProviding
    let onContinue: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 26) {
            Spacer()

            ZStack {
                CelebrationView()
                    .frame(width: 220, height: 220)
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 72, weight: .bold))
                    .foregroundStyle(.green)
            }

            VStack(spacing: 10) {
                Text("You reviewed \(session.reviewedCount) photos")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .multilineTextAlignment(.center)
                Text("+\(StatsService().xpEarned(for: session)) XP")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text(PersonalityMessageService.message(for: session))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                summaryRow("Kept", "\(session.keptCount)", "heart.fill")
                summaryRow("Selected for deletion", "\(session.deleteCount)", "trash.fill")
                summaryRow("Maybe later", "\(session.maybeLaterCount)", "tray.and.arrow.down.fill")
                summaryRow("Estimated space to free", DisplayFormatters.shortStorage(session.estimatedStorageFreed), "externaldrive.fill")
                if session.estimatedStorageFreed > 0 {
                    summaryRow("Fun comparison", PersonalityMessageService.songsEquivalent(for: session.estimatedStorageFreed), "music.note")
                }
                if let timerDuration = session.timerDuration {
                    summaryRow("Timer", "You cleared \(DisplayFormatters.shortStorage(session.estimatedStorageFreed)) in \(Int(timerDuration / 60)) minutes.", "timer")
                }
            }
            .padding(18)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            VStack(spacing: 12) {
                NavigationLink {
                    DeleteReviewView(initialAssets: deleteQueue, photoService: photoService)
                } label: {
                    Label("Review Delete Queue", systemImage: "square.grid.2x2")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.black)
                .disabled(deleteQueue.isEmpty)

                Button {
                    onContinue()
                    dismiss()
                } label: {
                    Label("Continue Cleaning", systemImage: "play.fill")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.bordered)

                Button("Finish") {
                    dismiss()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(22)
        .navigationTitle("Session Complete")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func summaryRow(_ title: String, _ value: String, _ image: String) -> some View {
        HStack {
            Label(title, systemImage: image)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.headline)
        }
    }
}

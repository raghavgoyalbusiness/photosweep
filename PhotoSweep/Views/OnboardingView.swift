import SwiftUI

struct OnboardingView: View {
    @ObservedObject var viewModel: HomeDashboardViewModel

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            VStack(spacing: 14) {
                Image(systemName: "sparkles.rectangle.stack.fill")
                    .font(.system(size: 58, weight: .semibold))
                    .symbolRenderingMode(.hierarchical)

                Text("PhotoSweep")
                    .font(.system(size: 44, weight: .black, design: .rounded))
                    .minimumScaleFactor(0.8)

                Text("Clear your camera roll like a game.")
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)

                Text("Swipe left to delete, right to keep, undo anytime.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 12) {
                Text("We only access photos you allow. Nothing is uploaded.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                CapsuleButton(title: viewModel.isLoading ? "Connecting..." : "Connect Photos", systemImage: "photo.on.rectangle") {
                    Task { await viewModel.connectPhotos() }
                }
                .disabled(viewModel.isLoading)
            }

            permissionMessage

            Spacer()
        }
        .padding(24)
        .background(Color(.systemBackground))
    }

    @ViewBuilder
    private var permissionMessage: some View {
        switch viewModel.permissionState {
        case .denied:
            Text("Photo access is currently denied. Open Settings and allow Photos access for PhotoSweep.")
                .font(.footnote)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        case .restricted:
            Text("Photos access is restricted on this device.")
                .font(.footnote)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
        default:
            EmptyView()
        }
    }
}

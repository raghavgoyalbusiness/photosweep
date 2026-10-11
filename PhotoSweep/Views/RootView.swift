import SwiftUI
import SwiftData
import LocalAuthentication

struct RootView: View {
    @StateObject private var viewModel = HomeDashboardViewModel()
    @Environment(\.scenePhase) private var scenePhase
    @State private var isPrivacyUnlocked = !FeatureFlags.isEnabled(.privateMode)

    var body: some View {
        Group {
            if FeatureFlags.isEnabled(.privateMode), !isPrivacyUnlocked {
                PrivacyLockView {
                    authenticate()
                }
            } else if viewModel.permissionState.canReadLibrary {
                NavigationStack {
                    HomeDashboardView(viewModel: viewModel)
                }
            } else {
                OnboardingView(viewModel: viewModel)
            }
        }
        .task {
            await viewModel.refresh()
            if FeatureFlags.isEnabled(.privateMode) {
                authenticate()
            }
        }
        .blur(radius: scenePhase == .background ? 18 : 0)
        .overlay {
            if scenePhase == .background {
                Color(.systemBackground)
                    .opacity(0.96)
                    .ignoresSafeArea()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard FeatureFlags.isEnabled(.privateMode) else { return }
            if phase == .active, !isPrivacyUnlocked {
                authenticate()
            } else if phase != .active {
                isPrivacyUnlocked = false
            }
        }
    }

    private func authenticate() {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            isPrivacyUnlocked = true
            return
        }
        context.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock PhotoSweep") { success, _ in
            Task { @MainActor in
                isPrivacyUnlocked = success
            }
        }
    }
}

struct PrivacyLockView: View {
    let unlock: () -> Void

    var body: some View {
        VStack(spacing: 18) {
            Image(systemName: "lock.fill")
                .font(.system(size: 48, weight: .bold))
            Text("PhotoSweep is locked")
                .font(.title2.bold())
            Button("Unlock") {
                unlock()
            }
            .buttonStyle(.borderedProminent)
            .tint(.black)
        }
        .padding()
    }
}

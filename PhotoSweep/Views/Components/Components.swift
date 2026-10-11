import SwiftUI
import AVKit
import UIKit

struct MetricTile: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 20, weight: .semibold))
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(.thinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct ProgressRing: View {
    let title: String
    let value: String
    let progress: Double
    let tint: Color

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(.gray.opacity(0.18), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: min(1, max(0, progress)))
                    .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.65)
                    .lineLimit(1)
            }
            .frame(width: 116, height: 116)

            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

struct CapsuleButton: View {
    let title: String
    let systemImage: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 16, weight: .semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 15)
        }
        .buttonStyle(.borderedProminent)
        .tint(.black)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}

struct AsyncThumbnailView: View {
    let asset: PhotoAsset
    let service: PhotoLibraryProviding
    let targetSize: CGSize
    var contentMode: ContentMode = .fill

    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.gray.opacity(0.14))

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
                    .transition(.opacity)
            } else {
                ProgressView()
                    .tint(.secondary)
            }

            if asset.type == .video {
                Image(systemName: "play.fill")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundStyle(.white)
                    .shadow(radius: 12)
            }
        }
        .clipped()
        .task(id: asset.localIdentifier) {
            image = await service.requestThumbnail(for: asset, targetSize: targetSize)
        }
    }
}

struct EmptyStateView: View {
    let title: String
    let message: String
    let systemImage: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: systemImage)
                .font(.system(size: 44, weight: .semibold))
            Text(title)
                .font(.title2.bold())
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(28)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CelebrationView: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0..<24, id: \.self) { index in
                Circle()
                    .fill([Color.black, .green, .blue, .orange][index % 4])
                    .frame(width: 8, height: 8)
                    .offset(
                        x: animate ? CGFloat((index % 8) - 4) * 34 : 0,
                        y: animate ? CGFloat((index / 4) - 3) * 48 : 0
                    )
                    .opacity(animate ? 0 : 1)
                    .scaleEffect(animate ? 0.4 : 1)
            }
        }
        .allowsHitTesting(false)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.78)) {
                animate = true
            }
        }
    }
}

struct FullPreviewView: View {
    let asset: PhotoAsset
    let service: PhotoLibraryProviding
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?
    @State private var playerItem: AVPlayerItem?

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                if asset.type == .video, let playerItem {
                    VideoPlayer(player: AVPlayer(playerItem: playerItem))
                        .ignoresSafeArea()
                } else if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .ignoresSafeArea()
                } else {
                    ProgressView()
                        .tint(.white)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.white)
                }
            }
        }
        .task {
            if asset.type == .video {
                playerItem = await service.requestPlayerItem(for: asset)
            }
            image = await service.requestPreviewImage(
                for: asset,
                targetSize: CGSize(width: 1800, height: 1800)
            )
        }
    }
}

extension UIApplication {
    var activeRootViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController
    }
}

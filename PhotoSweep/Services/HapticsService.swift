import UIKit

final class HapticsService {
    func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func decision(_ status: PhotoAssetStatus) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle = status == .delete ? .heavy : .medium
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }

    func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

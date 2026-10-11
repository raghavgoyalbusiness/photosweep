import Foundation
import Photos

protocol DeletionServing {
    func deleteAssets(_ assets: [PhotoAsset]) async throws -> Int
}

final class DeletionService: DeletionServing {
    func deleteAssets(_ assets: [PhotoAsset]) async throws -> Int {
        let state = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        guard state == .authorized || state == .limited else {
            throw AppError.permissionDenied
        }

        let identifiers = assets.map(\.localIdentifier)
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: identifiers, options: nil)
        guard fetchResult.count > 0 else { throw AppError.assetUnavailable }

        return try await withCheckedThrowingContinuation { continuation in
            // PhotoSweep never calls this method until after the user reviews the queue
            // and accepts the final confirmation. PhotoKit will then perform the native
            // library mutation and show any system-level deletion UI required by iOS.
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.deleteAssets(fetchResult)
            } completionHandler: { success, error in
                if let error {
                    continuation.resume(throwing: AppError.deletionFailed(error.localizedDescription))
                } else if success {
                    continuation.resume(returning: fetchResult.count)
                } else {
                    continuation.resume(throwing: AppError.deletionFailed("The Photos library did not complete the deletion."))
                }
            }
        }
    }
}

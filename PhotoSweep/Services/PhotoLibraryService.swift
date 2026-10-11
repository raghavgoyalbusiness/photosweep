import Foundation
import Photos
import UIKit
import AVFoundation

protocol PhotoLibraryProviding {
    func authorizationState() -> PhotoAuthorizationState
    func requestAuthorization() async -> PhotoAuthorizationState
    func fetchAssets(filter: CleanupFilter) async throws -> [PhotoAsset]
    func fetchAssets(localIdentifiers: [String]) async throws -> [PhotoAsset]
    func requestThumbnail(for asset: PhotoAsset, targetSize: CGSize) async -> UIImage?
    func requestPreviewImage(for asset: PhotoAsset, targetSize: CGSize) async -> UIImage?
    func requestPlayerItem(for asset: PhotoAsset) async -> AVPlayerItem?
    func fetchAlbums() async throws -> [AlbumSummary]
    func presentLimitedLibraryPicker(from viewController: UIViewController)
}

final class PhotoLibraryService: PhotoLibraryProviding {
    private let imageManager = PHCachingImageManager()

    func authorizationState() -> PhotoAuthorizationState {
        map(status: PHPhotoLibrary.authorizationStatus(for: .readWrite))
    }

    func requestAuthorization() async -> PhotoAuthorizationState {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                continuation.resume(returning: self.map(status: status))
            }
        }
    }

    func fetchAssets(filter: CleanupFilter) async throws -> [PhotoAsset] {
        let state = authorizationState()
        guard state.canReadLibrary else {
            if state == .restricted { throw AppError.restrictedAccess }
            throw AppError.permissionDenied
        }

        let options = PHFetchOptions()
        options.includeHiddenAssets = false
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = predicate(for: filter)

        let fetchResult = PHAsset.fetchAssets(with: options)
        var assets: [PhotoAsset] = []
        assets.reserveCapacity(fetchResult.count)

        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(self.map(asset: asset))
        }

        if filter == .largeFiles {
            assets = assets
                .filter { ($0.estimatedSize ?? 0) > 20 * 1024 * 1024 }
                .sorted { ($0.estimatedSize ?? 0) > ($1.estimatedSize ?? 0) }
        } else if filter == .largeVideos {
            assets = assets
                .filter { $0.type == .video && ($0.estimatedSize ?? 0) > 50 * 1024 * 1024 }
                .sorted { ($0.estimatedSize ?? 0) > ($1.estimatedSize ?? 0) }
        } else if filter == .randomCleanup {
            assets.shuffle()
        } else if filter == .randomFiveMinuteClean {
            assets.shuffle()
            assets = Array(assets.prefix(120))
        } else if filter.usesSmartAnalysis {
            assets = await LocalPhotoAnalysisService(photoService: self).annotate(assets: assets, mode: filter)
        }

        return assets
    }

    func fetchAssets(localIdentifiers: [String]) async throws -> [PhotoAsset] {
        let state = authorizationState()
        guard state.canReadLibrary else { throw AppError.permissionDenied }

        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: localIdentifiers, options: nil)
        var assets: [PhotoAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(self.map(asset: asset))
        }
        return assets
    }

    func requestThumbnail(for asset: PhotoAsset, targetSize: CGSize) async -> UIImage? {
        await requestImage(for: asset, targetSize: targetSize, deliveryMode: .fastFormat)
    }

    func requestPreviewImage(for asset: PhotoAsset, targetSize: CGSize) async -> UIImage? {
        await requestImage(for: asset, targetSize: targetSize, deliveryMode: .highQualityFormat)
    }

    func requestPlayerItem(for asset: PhotoAsset) async -> AVPlayerItem? {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [asset.localIdentifier], options: nil)
        guard let phAsset = result.firstObject, phAsset.mediaType == .video else { return nil }

        let options = PHVideoRequestOptions()
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = false

        return await withCheckedContinuation { continuation in
            imageManager.requestPlayerItem(forVideo: phAsset, options: options) { playerItem, _ in
                continuation.resume(returning: playerItem)
            }
        }
    }

    func fetchAlbums() async throws -> [AlbumSummary] {
        let state = authorizationState()
        guard state.canReadLibrary else { throw AppError.permissionDenied }

        var summaries: [AlbumSummary] = []
        let options = PHFetchOptions()
        options.includeHiddenAssets = false
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: nil)
        collections.enumerateObjects { collection, _, _ in
            let count = PHAsset.fetchAssets(in: collection, options: options).count
            guard count > 0 else { return }
            summaries.append(
                AlbumSummary(
                    id: collection.localIdentifier,
                    title: collection.localizedTitle ?? "Album",
                    assetCount: count
                )
            )
        }
        return summaries.sorted { $0.assetCount > $1.assetCount }
    }

    func presentLimitedLibraryPicker(from viewController: UIViewController) {
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: viewController)
    }

    private func requestImage(
        for asset: PhotoAsset,
        targetSize: CGSize,
        deliveryMode: PHImageRequestOptionsDeliveryMode
    ) async -> UIImage? {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [asset.localIdentifier], options: nil)
        guard let phAsset = result.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.deliveryMode = deliveryMode
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = false

        return await withCheckedContinuation { continuation in
            imageManager.requestImage(
                for: phAsset,
                targetSize: targetSize,
                contentMode: .aspectFill,
                options: options
            ) { image, _ in
                continuation.resume(returning: image)
            }
        }
    }

    private func predicate(for filter: CleanupFilter) -> NSPredicate? {
        let favoritesExcluded = NSPredicate(format: "favorite == NO")

        switch filter {
        case .all, .randomCleanup, .randomFiveMinuteClean:
            return favoritesExcluded
        case .screenshots:
            return NSCompoundPredicate(andPredicateWithSubpredicates: [
                favoritesExcluded,
                NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue),
                NSPredicate(format: "(mediaSubtype & %d) != 0", Int(PHAssetMediaSubtype.photoScreenshot.rawValue))
            ])
        case .videos, .largeVideos:
            return NSCompoundPredicate(andPredicateWithSubpredicates: [
                favoritesExcluded,
                NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
            ])
        case .photos, .largeFiles, .recentlyAdded, .duplicatePhotos, .similarPhotos, .blurryPhotos, .downloadedImages, .receiptsDocuments, .memes:
            return NSCompoundPredicate(andPredicateWithSubpredicates: [
                favoritesExcluded,
                NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
            ])
        case .selfies:
            return NSCompoundPredicate(andPredicateWithSubpredicates: [
                favoritesExcluded,
                NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue),
                NSPredicate(format: "(mediaSubtype & %d) != 0", Int(PHAssetMediaSubtype.photoSelfie.rawValue))
            ])
        case .thisMonth:
            let start = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) ?? Date()
            return NSCompoundPredicate(andPredicateWithSubpredicates: [
                favoritesExcluded,
                NSPredicate(format: "creationDate >= %@", start as NSDate)
            ])
        case .olderThanOneYear, .oldPhotos:
            let cutoff = Calendar.current.date(byAdding: .year, value: -1, to: Date()) ?? Date()
            return NSCompoundPredicate(andPredicateWithSubpredicates: [
                favoritesExcluded,
                NSPredicate(format: "creationDate < %@", cutoff as NSDate)
            ])
        case .maybeLater:
            return favoritesExcluded
        }
    }

    private func map(status: PHAuthorizationStatus) -> PhotoAuthorizationState {
        switch status {
        case .notDetermined: return .notDetermined
        case .restricted: return .restricted
        case .denied: return .denied
        case .authorized: return .authorized
        case .limited: return .limited
        @unknown default: return .denied
        }
    }

    private func map(asset: PHAsset) -> PhotoAsset {
        let kind: AssetKind
        if asset.mediaType == .video {
            kind = .video
        } else if asset.mediaSubtypes.contains(.photoScreenshot) {
            kind = .screenshot
        } else {
            kind = .photo
        }

        let size = estimatedSize(for: asset)
        var badges: Set<AssetBadge> = []
        if asset.mediaType == .video, size ?? 0 > 50 * 1024 * 1024 {
            badges.insert(.largeVideo)
        }
        if asset.mediaSubtypes.contains(.photoSelfie) {
            badges.insert(.selfie)
        }
        if let creationDate = asset.creationDate,
           Calendar.current.dateComponents([.year], from: creationDate, to: Date()).year ?? 0 >= 5 {
            badges.insert(.oldMemory)
        }

        return PhotoAsset(
            localIdentifier: asset.localIdentifier,
            type: kind,
            creationDate: asset.creationDate,
            estimatedSize: size,
            duration: asset.mediaType == .video ? asset.duration : nil,
            isFavorite: asset.isFavorite,
            status: .unreviewed,
            badges: badges,
            sourceHint: kind == .screenshot ? .screenshot : .camera
        )
    }

    private func estimatedSize(for asset: PHAsset) -> Int64? {
        let sizes = PHAssetResource.assetResources(for: asset)
            .compactMap { resource -> Int64? in
                // PhotoKit does not expose a stable public byte-size API for every asset.
                // This optional value is used only for user-facing estimates; deletion still uses PhotoKit assets.
                if let number = resource.value(forKey: "fileSize") as? NSNumber {
                    return number.int64Value
                }
                return resource.value(forKey: "fileSize") as? Int64
            }
        guard !sizes.isEmpty else { return nil }
        return sizes.reduce(0, +)
    }
}

final class LocalPhotoAnalysisService {
    private let photoService: PhotoLibraryProviding
    private let groupingService = SmartGroupingService()

    init(photoService: PhotoLibraryProviding) {
        self.photoService = photoService
    }

    func annotate(assets: [PhotoAsset], mode: CleanupFilter) async -> [PhotoAsset] {
        switch mode {
        case .duplicatePhotos, .similarPhotos:
            let groupedIDs = Set(groupingService.similarGroups(from: assets).flatMap { $0.assets.map(\.localIdentifier) })
            return assets.compactMap { asset in
                guard groupedIDs.contains(asset.localIdentifier) else { return nil }
                var copy = asset
                copy.badges.insert(mode == .duplicatePhotos ? .duplicateCandidate : .similarCandidate)
                return copy
            }
        case .blurryPhotos:
            var blurry: [PhotoAsset] = []
            for asset in assets.prefix(300) {
                guard let image = await photoService.requestThumbnail(for: asset, targetSize: CGSize(width: 160, height: 160)),
                      Self.blurScore(for: image) < 18 else { continue }
                var copy = asset
                copy.badges.insert(.possiblyBlurry)
                blurry.append(copy)
            }
            return blurry
        case .receiptsDocuments:
            return assets.filter { $0.type == .screenshot || ($0.estimatedSize ?? 0) < 3 * 1024 * 1024 }
                .map { asset in
                    var copy = asset
                    copy.badges.insert(.documentLike)
                    return copy
                }
        case .memes:
            return assets.filter { $0.type == .screenshot || $0.sourceHint == .downloaded }
                .map { asset in
                    var copy = asset
                    copy.badges.insert(.memeLike)
                    return copy
                }
        default:
            return assets
        }
    }

    private static func blurScore(for image: UIImage) -> Double {
        guard let cgImage = image.cgImage else {
            return 100
        }

        let width = 64
        let height = 64
        let bytesPerRow = width * 4
        var pixels = [UInt8](repeating: 0, count: height * bytesPerRow)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return 100 }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var total = 0.0
        var count = 0.0
        let step = 2
        for y in stride(from: step, to: height - step, by: step) {
            for x in stride(from: step, to: width - step, by: step) {
                let center = luma(bytes: pixels, row: bytesPerRow, x: x, y: y)
                let left = luma(bytes: pixels, row: bytesPerRow, x: x - step, y: y)
                let right = luma(bytes: pixels, row: bytesPerRow, x: x + step, y: y)
                let up = luma(bytes: pixels, row: bytesPerRow, x: x, y: y - step)
                let down = luma(bytes: pixels, row: bytesPerRow, x: x, y: y + step)
                total += abs((4 * center) - left - right - up - down)
                count += 1
            }
        }
        return count == 0 ? 100 : total / count
    }

    private static func luma(bytes: [UInt8], row: Int, x: Int, y: Int) -> Double {
        let offset = (y * row) + (x * 4)
        let red = Double(bytes[offset])
        let green = Double(bytes[offset + 1])
        let blue = Double(bytes[offset + 2])
        return (0.299 * red) + (0.587 * green) + (0.114 * blue)
    }
}

//
//  Image+WebP.swift
//  Pods
//
//  Created by yeatse on 2016/10/19.
//
//

import Kingfisher
import CoreGraphics
import Foundation

#if SWIFT_PACKAGE
import KingfisherWebP_ObjC
#endif

// MARK: - Image Representation
extension KingfisherWrapper where Base: KFCrossPlatformImage {
    /// isLossy  (0=lossy , 1=lossless (default)).
    /// Note that the default values are isLossy= false and quality=75.0f
    public func webpRepresentation(isLossy: Bool = false, quality: Float = 75.0) -> Data? {
        if let result = animatedWebPRepresentation(isLossy: isLossy, quality: quality) {
            return result
        }
        #if os(macOS)
        if let cgImage = base.cgImage(forProposedRect: nil, context: nil, hints: nil) {
            return WebPDataCreateWithImage(cgImage, isLossy, quality) as Data?
        }
        #else
        if let cgImage = base.cgImage {
            return WebPDataCreateWithImage(cgImage, isLossy, quality) as Data?
        }
        #endif
        return nil
    }

    /// isLossy  (0=lossy , 1=lossless (default)).
    /// Note that the default values are isLossy= false and quality=75.0f
    private func animatedWebPRepresentation(isLossy: Bool = false, quality: Float = 75.0) -> Data? {
        #if os(macOS)
        return nil
        #else
        guard let images = base.images?.compactMap({ $0.cgImage }) else {
            return nil
        }
        let imageInfo = [ kWebPAnimatedImageFrames: images,
                          kWebPAnimatedImageDuration: NSNumber(value: base.duration) ] as [CFString : Any]
        return WebPDataCreateWithAnimatedImageInfo(imageInfo as CFDictionary, isLossy, quality) as Data?
        #endif
    }
}

// MARK: - Create image from WebP data
extension KingfisherWrapper where Base: KFCrossPlatformImage {
    public static func image(webpData: Data, scale: CGFloat, onlyFirstFrame: Bool) -> KFCrossPlatformImage? {
        let frameCount = WebPImageFrameCountGetFromData(webpData as CFData)
        if (frameCount == 0) {
            return nil
        }
        
        #if os(macOS)
        guard let cgImage = WebPImageCreateWithData(webpData as CFData) else {
            return nil
        }
        return KFCrossPlatformImage(cgImage: cgImage, size: .zero)
        #else
        if (frameCount == 1 || onlyFirstFrame) {
            guard let cgImage = WebPImageCreateWithData(webpData as CFData) else {
                return nil
            }
            return KFCrossPlatformImage(cgImage: cgImage, scale: scale, orientation: .up)
        }

        // MARK: Animated images
        guard let animationInfo = WebPAnimatedImageInfoCreateWithData(webpData as CFData) as Dictionary? else {
            return nil
        }
        guard let cgFrames = animationInfo[kWebPAnimatedImageFrames] as? [CGImage] else {
            return nil
        }
        let uiFrames = cgFrames.map { KFCrossPlatformImage(cgImage: $0, scale: scale, orientation: .up) }
        let duration = (animationInfo[kWebPAnimatedImageDuration] as? NSNumber).flatMap { $0.doubleValue as TimeInterval } ?? 0.1 * TimeInterval(frameCount)
        return KFCrossPlatformImage.animatedImage(with: uiFrames, duration: duration)
        #endif
    }
}

// MARK: - WebP Format Testing
extension Data {
    public var isWebPFormat: Bool {
        if count < 12 {
            return false
        }

        let endIndex = index(startIndex, offsetBy: 12)
        let testData = subdata(in: startIndex..<endIndex)
        guard let testString = String(data: testData, encoding: .ascii) else {
            return false
        }

        if testString.hasPrefix("RIFF") && testString.hasSuffix("WEBP") {
            return true
        } else {
            return false
        }
    }
}

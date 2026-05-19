import SwiftUI
import AppKit
import CoreGraphics

struct NoteImageProcessor {
    
    /// 针对黑底高亮手写笔记优化的透明背景提取算法 (Max-RGB 提取)
    static func extractNotes(from image: NSImage, noiseThreshold: CGFloat = 0.0) async -> NSImage? {
        return await Task.detached {
            // 在 Mac 上获取 CGImage
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
            
            let width = cgImage.width
            let height = cgImage.height
            let colorSpace = CGColorSpaceCreateDeviceRGB()
            
            let bytesPerPixel = 4
            let bytesPerRow = bytesPerPixel * width
            let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
            
            guard let context = CGContext(data: nil,
                                          width: width,
                                          height: height,
                                          bitsPerComponent: 8,
                                          bytesPerRow: bytesPerRow,
                                          space: colorSpace,
                                          bitmapInfo: bitmapInfo) else {
                return nil
            }
            
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            
            guard let data = context.data else { return nil }
            let buffer = data.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)
            
            let threshold = UInt8(max(0, min(1, noiseThreshold)) * 255.0)
            
            for i in stride(from: 0, to: width * height * bytesPerPixel, by: bytesPerPixel) {
                let r = buffer[i]
                let g = buffer[i+1]
                let b = buffer[i+2]
                
                let maxChannel = max(r, max(g, b))
                
                if maxChannel <= threshold {
                    buffer[i] = 0
                    buffer[i+1] = 0
                    buffer[i+2] = 0
                    buffer[i+3] = 0
                } else {
                    buffer[i+3] = maxChannel
                }
            }
            
            guard let outputCGImage = context.makeImage() else { return nil }
            // 组装成 Mac 的 NSImage
            return NSImage(cgImage: outputCGImage, size: NSSize(width: width, height: height))
        }.value
    }
    
    /// 批量并发处理图片 (利用 Mac 多核性能)
    static func processBatch(images: [NSImage], noiseThreshold: CGFloat) async -> [TransparentNote] {
        return await withTaskGroup(of: (Int, NSImage?).self) { group in
            for (index, image) in images.enumerated() {
                group.addTask {
                    let processed = await extractNotes(from: image, noiseThreshold: noiseThreshold)
                    return (index, processed)
                }
            }
            
            var results: [(Int, NSImage?)] = []
            for await result in group {
                results.append(result)
            }
            
            return results
                .sorted(by: { $0.0 < $1.0 })
                .compactMap { $0.1 }
                .map { TransparentNote(image: $0) }
        }
    }
}

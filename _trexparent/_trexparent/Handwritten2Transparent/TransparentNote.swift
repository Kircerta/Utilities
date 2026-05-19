import SwiftUI
import AppKit
import CoreTransferable
import UniformTypeIdentifiers

/// 包装处理后的图片，并提供无损 PNG 数据转换
struct TransparentNote: Identifiable {
    let id = UUID()
    let image: NSImage
}

// 给 NSImage 增加导出 PNG 的底层方法
extension NSImage {
    func pngData() -> Data? {
        // 获取 CGImage
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
        // 转换为位图并输出 PNG 格式数据
        let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
        return bitmapRep.representation(using: .png, properties: [:])
    }
}

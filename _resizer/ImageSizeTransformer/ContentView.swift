import SwiftUI
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers


enum ResizePreset: String, CaseIterable, Identifiable {
    case iphone = "iOS"
    case macbook = "MacOS"
    case custom = "Custom"
    
    var id: String { self.rawValue }
    
    var size: CGSize? {
        switch self {
        case .iphone: return CGSize(width: 1242, height: 2688)
        case .macbook: return CGSize(width: 2560, height: 1600)
        case .custom: return nil
        }
    }
}

struct ContentView: View {
    @State private var inputFolderURL: URL?
    @State private var outputFolderURL: URL?
    @State private var processingStatus: String = "Ready"
    @State private var isProcessing: Bool = false
    
    @State private var selectedPreset: ResizePreset = .iphone
    @State private var customWidth: String = "1920"
    @State private var customHeight: String = "1080"
    
    private var targetWidth: Int {
        if let size = selectedPreset.size {
            return Int(size.width)
        }
        return Int(customWidth) ?? 1920
    }
    
    private var targetHeight: Int {
        if let size = selectedPreset.size {
            return Int(size.height)
        }
        return Int(customHeight) ?? 1080
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 8, height: 8)
                            .shadow(color: statusColor.opacity(0.5), radius: 4, x: 0, y: 0)
                        
                        Text(processingStatus)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                    )
                }
                
                .padding(.horizontal, 24)
                .padding(.top, 10)
                .padding(.bottom, 20)
                

                ScrollView {
                    VStack(spacing: 16) {
                        // Input Row
                        PathRow(
                            label: "INPUT",
                            text: inputFolderURL?.lastPathComponent ?? "Select Input Folder",
                            isActive: inputFolderURL != nil,
                            icon: "arrow.down.doc.fill",
                            color: .blue
                        ) {
                            selectFolder { inputFolderURL = $0 }
                        }
                        
                        // Output Row
                        PathRow(
                            label: "OUTPUT",
                            text: outputFolderURL?.lastPathComponent ?? "Select Destination",
                            isActive: outputFolderURL != nil,
                            icon: "folder.fill.badge.plus",
                            color: .orange
                        ) {
                            selectFolder { outputFolderURL = $0 }
                        }
                        
                        
                        // Resolution Row
                        ResolutionRow
                    }
                    .padding(.horizontal, 24)
                }
                .scrollDisabled(true)
                
                Spacer()
                

                Button(action: startProcessing) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .controlSize(.small)
                                .padding(.trailing, 6)
                                .tint(.white)
                        }
                        Text(isProcessing ? "Processing..." : "Resize to \(targetWidth) × \(targetHeight)")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    )
                    .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .disabled(isProcessing || inputFolderURL == nil || outputFolderURL == nil)
                .opacity((isProcessing || inputFolderURL == nil || outputFolderURL == nil) ? 0.6 : 1.0)
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .frame(width: 420, height: 440) // Window Size Fixed
        .background(.regularMaterial)
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willUpdateNotification), perform: { _ in
            // Window style handling
        })
    }
    
    // MARK: - Components
    
    private var ResolutionRow: some View {
        VStack(spacing: 12) {
            // Preset Selector
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(Color.purple.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.purple)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    Text("RESOLUTION")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary.opacity(0.8))
                        .tracking(0.5)
                    
                    Menu {
                        ForEach(ResizePreset.allCases) { preset in
                            Button(preset.rawValue) {
                                selectedPreset = preset
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedPreset.rawValue)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(Color.primary.opacity(0.3))
                        }
                    }
                    .menuStyle(.borderlessButton)
                    .frame(height: 20)
                }
                
                Spacer()
            }
            .padding(12)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
            )
            
            // Custom Inputs (Conditional)
            if selectedPreset == .custom {
                HStack(spacing: 12) {
                    CustomTextField(label: "Width", text: $customWidth)
                    Text("×")
                        .foregroundStyle(.secondary)
                        .padding(.top, 16)
                    CustomTextField(label: "Height", text: $customHeight)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedPreset)
    }
    
    // MARK: - Subviews
    
    @ViewBuilder
    private func PathRow(label: String, text: String, isActive: Bool, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(color)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary.opacity(0.8))
                    .tracking(0.5)
                
                Text(text)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isActive ? Color.primary.opacity(0.9) : Color.secondary.opacity(0.6))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            
            Spacer()
            
            Image(systemName: "ellipsis")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(.secondary.opacity(0.5))
        }
        .padding(12)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.4), lineWidth: 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture { action() }
    }
    
    private func CustomTextField(label: String, text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
                .padding(.leading, 4)
            
            TextField("", text: text)
                .textFieldStyle(.plain)
                .font(.system(size: 13, design: .monospaced))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.2), lineWidth: 0.5)
                )
        }
    }
    
    // MARK: - Logic Helpers
    
    private var statusColor: Color {
        if isProcessing { return .yellow }
        if processingStatus.contains("Success") { return .green }
        if processingStatus.contains("Error") { return .red }
        return .secondary
    }
    
    private func selectFolder(completion: @escaping (URL) -> Void) {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Select"
        panel.begin { response in
            if response == .OK, let url = panel.url { completion(url) }
        }
    }
    
    private func startProcessing() {
        guard let inputURL = inputFolderURL, let outputURL = outputFolderURL else { return }
        isProcessing = true
        processingStatus = "Working..."
        
        let tWidth = self.targetWidth
        let tHeight = self.targetHeight
        
        DispatchQueue.global(qos: .userInitiated).async {
            let inputAccess = inputURL.startAccessingSecurityScopedResource()
            let outputAccess = outputURL.startAccessingSecurityScopedResource()
            
            defer {
                if inputAccess { inputURL.stopAccessingSecurityScopedResource() }
                if outputAccess { outputURL.stopAccessingSecurityScopedResource() }
            }
            
            let fileManager = FileManager.default
            let supportedExtensions = ["png", "jpg", "jpeg", "tiff", "bmp"]
            var count = 0
            var errorCount = 0
            
            do {
                let fileURLs = try fileManager.contentsOfDirectory(at: inputURL, includingPropertiesForKeys: nil)
                for fileURL in fileURLs {
                    if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                        let destinationURL = outputURL.appendingPathComponent(fileURL.lastPathComponent)
                        if self.resizeImage(at: fileURL, to: destinationURL, width: tWidth, height: tHeight) {
                            count += 1
                        } else {
                            errorCount += 1
                        }
                    }
                }
                DispatchQueue.main.async {
                    self.processingStatus = errorCount > 0 ? "Done with errors" : "Success (\(count))"
                    self.isProcessing = false
                }
            } catch {
                DispatchQueue.main.async {
                    self.processingStatus = "Error"
                    self.isProcessing = false
                }
            }
        }
    }
    
    private func resizeImage(at sourceURL: URL, to destinationURL: URL, width: Int, height: Int) -> Bool {
        guard let imageSource = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
              let originalImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return false
        }
        
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return false }
        
        context.draw(originalImage, in: CGRect(x: 0, y: 0, width: CGFloat(width), height: CGFloat(height)))
        
        guard let resizedImage = context.makeImage(),
              let destination = CGImageDestinationCreateWithURL(destinationURL as CFURL, UTType.png.identifier as CFString, 1, nil) else {
            return false
        }
        
        CGImageDestinationAddImage(destination, resizedImage, nil)
        return CGImageDestinationFinalize(destination)
    }
}

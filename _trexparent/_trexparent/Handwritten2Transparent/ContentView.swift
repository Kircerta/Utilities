import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var inputImages: [NSImage] = []
    @State private var outputNotes: [TransparentNote] = []
    
    @State private var isProcessing: Bool = false
    @State private var noiseThreshold: Double = 0.0
    
    // 控制 Mac 文件选择面板的显示
    @State private var showFileImporter = false
    
    var body: some View {
        VStack(spacing: 20) {
            
            // --- 预览区 ---
            ZStack {
                CheckerboardView()
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                
                if !outputNotes.isEmpty {
                    // Mac 友好的横向滚动预览
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(spacing: 30) {
                            ForEach(outputNotes) { note in
                                Image(nsImage: note.image)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(maxHeight: 450)
                                    .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 5)
                            }
                        }
                        .padding()
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "macwindow.on.rectangle")
                            .font(.system(size: 50))
                        Text("支持批量导入黑底彩色笔记")
                            .font(.title2)
                        Text("点击下方按钮，或者直接将多张图片拖拽到此处")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .foregroundColor(.gray)
                }
                
                if isProcessing {
                    VStack {
                        ProgressView()
                            .scaleEffect(1.5)
                            .padding(.bottom, 8)
                        Text("正在调用多核提取矢量边缘...")
                            .font(.caption)
                    }
                    .padding(30)
                    .background(.regularMaterial)
                    .cornerRadius(16)
                }
            }
            .frame(minHeight: 400)
            .padding()
            
            // --- 参数调节区 ---
            VStack(alignment: .leading, spacing: 8) {
                Text("背景杂讯过滤: \(noiseThreshold, specifier: "%.3f")")
                    .font(.headline)
                Slider(value: $noiseThreshold, in: 0...0.1, step: 0.005)
                    .onChange(of: noiseThreshold) { _ in
                        runBatchProcessing()
                    }
                Text("如果你导入的是直接从笔记软件导出的原图，请保持 0 以获得最完美的渐变笔锋。")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .disabled(inputImages.isEmpty || isProcessing)
            
            Spacer()
            
            // --- 操作区 ---
            HStack(spacing: 20) {
                // 1. 导入按钮
                Button {
                    showFileImporter = true
                } label: {
                    Label("导入黑底笔记 (支持多选)", systemImage: "photo.on.rectangle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .fileImporter(
                    isPresented: $showFileImporter,
                    allowedContentTypes: [.image],
                    allowsMultipleSelection: true
                ) { result in
                    handleFileImport(result: result)
                }
                
                // 2. 导出按钮
                if !outputNotes.isEmpty {
                    Button {
                        exportAllImages()
                    } label: {
                        Label("批量导出至文件夹...", systemImage: "folder.badge.plus")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding()
        }
        .frame(minWidth: 800, minHeight: 650) // 设定 Mac 窗口的合适尺寸
        .navigationTitle("Mac 矢量笔记提取器")
        // 支持将图片直接拖入软件窗口
        .onDrop(of: [.image], isTargeted: nil) { providers in
            loadDroppedImages(providers: providers)
            return true
        }
    }
    
    // MARK: - Mac 专属逻辑
    
    /// 处理点击导入的文件
    private func handleFileImport(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            isProcessing = true
            Task {
                var loaded: [NSImage] = []
                for url in urls {
                    // Mac 沙盒机制：需要请求安全访问权限
                    if url.startAccessingSecurityScopedResource() {
                        if let image = NSImage(contentsOf: url) {
                            loaded.append(image)
                        }
                        url.stopAccessingSecurityScopedResource()
                    }
                }
                await MainActor.run {
                    self.inputImages = loaded
                    self.runBatchProcessing()
                }
            }
        case .failure(let error):
            print("导入失败: \(error)")
        }
    }
    
    /// 处理直接拖拽进窗口的文件
    private func loadDroppedImages(providers: [NSItemProvider]) {
        isProcessing = true
        Task {
            var loaded: [NSImage] = []
            for provider in providers {
                if let item = try? await provider.loadItem(forTypeIdentifier: UTType.image.identifier, options: nil) {
                    if let url = item as? URL, let image = NSImage(contentsOf: url) {
                        loaded.append(image)
                    } else if let data = item as? Data, let image = NSImage(data: data) {
                        loaded.append(image)
                    }
                }
            }
            await MainActor.run {
                if !loaded.isEmpty {
                    self.inputImages = loaded
                    self.runBatchProcessing()
                } else {
                    self.isProcessing = false
                }
            }
        }
    }
    
    /// 运行底层多核处理
    private func runBatchProcessing() {
        guard !inputImages.isEmpty else { return }
        isProcessing = true
        
        Task {
            let results = await NoteImageProcessor.processBatch(images: inputImages, noiseThreshold: noiseThreshold)
            await MainActor.run {
                self.outputNotes = results
                self.isProcessing = false
            }
        }
    }
    
    /// Mac 原生：呼出文件夹选择窗口进行保存
    private func exportAllImages() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false       // 不能选文件
        panel.canChooseDirectories = true  // 只能选文件夹
        panel.canCreateDirectories = true  // 允许新建文件夹
        panel.prompt = "保存到这里"
        panel.message = "请选择一个文件夹来保存生成的 \(outputNotes.count) 张透明 PNG"
        
        panel.begin { response in
            if response == .OK, let folderURL = panel.url {
                saveImages(to: folderURL)
            }
        }
    }
    
    /// 将生成的 PNG 写入指定的硬盘路径
    private func saveImages(to folderURL: URL) {
        for (index, note) in outputNotes.enumerated() {
            if let pngData = note.image.pngData() {
                // 自动按序号命名
                let fileURL = folderURL.appendingPathComponent("透明笔记_\(index + 1).png")
                do {
                    try pngData.write(to: fileURL)
                } catch {
                    print("保存第 \(index + 1) 张失败: \(error)")
                }
            }
        }
    }
}

// 透明棋盘格背景 (同上)
// 辅助视图：透明棋盘格背景 (修复 macOS 初始布局闪退问题)
struct CheckerboardView: View {
    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let size: CGFloat = 15
                
                // 1. 增加安全校验：确保宽高是有限的实数，防止 NaN 或 Infinity 导致 Int() 转换崩溃
                let safeWidth = geometry.size.width.isFinite ? max(0, geometry.size.width) : 0
                let safeHeight = geometry.size.height.isFinite ? max(0, geometry.size.height) : 0
                
                // 2. 如果尺寸为 0，则暂时不绘制，等待下一帧布局
                guard safeWidth > 0 && safeHeight > 0 else { return }
                
                let columns = Int(safeWidth / size) + 1
                let rows = Int(safeHeight / size) + 1
                
                for row in 0..<rows {
                    for col in 0..<columns {
                        if (row + col).isMultiple(of: 2) {
                            path.addRect(CGRect(x: CGFloat(col) * size, y: CGFloat(row) * size, width: size, height: size))
                        }
                    }
                }
            }
            .fill(Color(white: 0.9))
            .background(Color.white)
        }
    }
}

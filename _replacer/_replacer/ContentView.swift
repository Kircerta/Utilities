import SwiftUI
import AppKit

enum ProgrammingLanguage: String, CaseIterable, Identifiable {
    case swift = "Swift"
    case python = "Python"
    case r = "R"
    
    var id: String { self.rawValue }
}

struct ContentView: View {
    @State private var inputText: String = """
    """
    
    @State private var findText: String = ""
    @State private var replaceText: String = ""
    @State private var outputText: String = ""
    
    @State private var selectedLanguage: ProgrammingLanguage = .swift

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color(nsColor: .windowBackgroundColor), Color.blue.opacity(0.1)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {

                LiquidGlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Source Text", systemImage: "doc.text.fill")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            Text("\(inputText.count) chars")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                                .padding(.horizontal, 8)
                                .background(.ultraThinMaterial, in: Capsule())
                            
                            if !inputText.isEmpty {
                                Button(action: { inputText = "" }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 12))
                                }
                                .buttonStyle(GlassButtonStyle(role: .destructive))
                                .help("Clear Input")
                            }
                        }
                        
                        Divider().opacity(0.3)
                        
                        TextEditor(text: $inputText)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                    }
                }


                LiquidGlassBar {
                    HStack(spacing: 16) {

                        HStack(spacing: 10) {
                            GlassTextField(icon: "magnifyingglass", placeholder: "Find", text: $findText)
                                .frame(width: 140)
                            
                            Image(systemName: "arrow.right")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                            
                            GlassTextField(icon: "pencil", placeholder: "Replace", text: $replaceText)
                                .frame(width: 140)
                        }
                        
                        Button("Done", action: performReplacement)
                        .buttonStyle(GlassButtonStyle())
                        
                        Spacer()
                        
                        HStack(spacing: 8) {
                            Button("Non-ASCII", action: removeChineseCharacters)
                            .buttonStyle(GlassButtonStyle())
                            .help("Remove Non-ASCII")
                            
                            Button(action: removeComments) {
                                Image(systemName: "text.badge.xmark")
                            }
                            .buttonStyle(GlassButtonStyle())
                            .help("Remove Comments")
                            
                            Picker("", selection: $selectedLanguage) {
                                ForEach(ProgrammingLanguage.allCases) { lang in
                                    Text(lang.rawValue).tag(lang)
                                }
                            }
                            .labelsHidden()
                            .frame(width: 100)
                            .pickerStyle(.menu)
                            .tint(.primary)
                        }
                        
                        Spacer()
                        
                        
                    }
                }


                LiquidGlassCard {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Label("Processed Output", systemImage: "terminal.fill")
                                .font(.headline)
                                .foregroundStyle(.secondary)
                            
                            Spacer()
                            
                            if !outputText.isEmpty {
                                Button(action: copyToClipboard) {
                                    Label("Copy Result", systemImage: "doc.on.doc")
                                }

                                .buttonStyle(GlassButtonStyle(tint: .blue))
                            }
                        }
                        
                        Divider().opacity(0.3)
                        
                        TextEditor(text: .constant(outputText))
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(outputText.isEmpty ? .secondary : .primary)
                            .scrollContentBackground(.hidden)
                            .frame(minHeight: 120)
                    }
                }
            }
            .padding(24)
        }
        .frame(minWidth: 700, minHeight: 650)
    }

    // MARK: - Logic Implementation

    func performReplacement() {
        outputText = inputText.replacingOccurrences(of: findText, with: replaceText)
    }
    
    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(outputText, forType: .string)
    }
    
    func removeChineseCharacters() {
        outputText = inputText.replacingOccurrences(
            of: "[\\u4e00-\\u9fa5]",
            with: "",
            options: .regularExpression
        )
    }
    
    func removeComments() {
        var pattern = ""
        
        switch selectedLanguage {
        case .swift:
            pattern = "(//.*)|(/\\*[\\s\\S]*?\\*/)"
        case .python, .r:
            pattern = "#.*"
        }
        
        let textWithoutComments = inputText.replacingOccurrences(
            of: pattern,
            with: "",
            options: .regularExpression
        )

        let lines = textWithoutComments.components(separatedBy: .newlines)
        
        let cleanedLines = lines.filter { line in
            !line.trimmingCharacters(in: .whitespaces).isEmpty
        }
        
        outputText = cleanedLines.joined(separator: "\n")
    }
}

struct LiquidGlassCard<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
            
            RoundedRectangle(cornerRadius: 16)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.5), .white.opacity(0.1), .clear],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            
            content
                .padding(16)
        }
    }
}

struct LiquidGlassBar<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        ZStack {
            Capsule()
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.05), radius: 5, x: 0, y: 2)
            
            Capsule()
                .stroke(.white.opacity(0.2), lineWidth: 1)
            
            content
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
        }
        .frame(height: 60)
    }
}

struct GlassTextField: View {
    var icon: String
    var placeholder: String
    @Binding var text: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .font(.caption)
            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
        }
        .padding(8)
        .background {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.black.opacity(0.05))
        }
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(.black.opacity(0.05), lineWidth: 0.5)
        )
    }
}

// 修正后的 GlassButtonStyle
struct GlassButtonStyle: ButtonStyle {
    var role: ButtonRole? = nil
    var tint: Color? = nil
    
    func makeBody(configuration: Configuration) -> some View {
        let isDestructive = role == .destructive
        
        let backgroundColor: Color
        if isDestructive {
            backgroundColor = Color.red.opacity(0.1)
        } else if let tint = tint {
            backgroundColor = tint.opacity(0.1)
        } else {
            backgroundColor = Color.white.opacity(0.2)
        }
        
        return configuration.label
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background {
                backgroundColor
            }
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay {
                RoundedRectangle(cornerRadius: 10)
                    .stroke(.white.opacity(configuration.isPressed ? 0.8 : 0.3), lineWidth: 1)
            }
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
            .foregroundStyle(isDestructive ? Color.red : (tint ?? Color.primary))
    }
}

struct GlassProminentButtonStyle: ButtonStyle {
    var isDisabled: Bool
    
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            LinearGradient(colors: isDisabled ? [.gray] : [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                .opacity(isDisabled ? 0.3 : 0.8)
            
            LinearGradient(colors: [.white.opacity(0.4), .clear], startPoint: .top, endPoint: .bottom)
        }
        .mask(Circle())
        .frame(width: 36, height: 36)
        .overlay(
            Circle()
                .stroke(.white.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: isDisabled ? .clear : .blue.opacity(0.4), radius: 5, x: 0, y: 3)
        .overlay(
            configuration.label
                .foregroundStyle(.white)
                .font(.system(size: 14, weight: .bold))
        )
        .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
        .animation(.easeOut(duration: 0.2), value: configuration.isPressed)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

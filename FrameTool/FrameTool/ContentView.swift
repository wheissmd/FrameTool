//  ContentView.swift
//  FrameTool
//
//  Created by wheissmd on 17/04/2025.

import UniformTypeIdentifiers
import AVFoundation
import SwiftUI
import AppKit

// MARK: - Tooltip Window Identifier

@inline(__always)
func tooltipHostWindow() -> NSWindow? {
    let mouse = NSEvent.mouseLocation
    let windows = NSApp.windows
        .filter { $0.isVisible && $0.alphaValue > 0.01 }
        .sorted { $0.level.rawValue > $1.level.rawValue }

    for w in windows {
        if w.ignoresMouseEvents { continue }
        if w.frame.contains(mouse) { return w }
    }
    return NSApp.keyWindow ?? NSApp.mainWindow
}

// MARK: - Blur text field outline
@inline(__always)
private func blurFirstResponder() {
    NSApp.keyWindow?.makeFirstResponder(nil)
}

// MARK: - Spinner & GIF

struct CustomSpinner: View {
    @State private var isAnimating = false
    var color: Color
    var size: CGFloat = 24

    var body: some View {
        Circle()
            .trim(from: 0.2, to: 1)
            .stroke(color, lineWidth: 4)
            .frame(width: size, height: size)
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
            .onAppear { isAnimating = true }
    }
}

struct GIFImage: NSViewRepresentable {
    let gifName: String
    var isResizable: Bool = false

    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()

        if let path = Bundle.main.path(forResource: gifName, ofType: "gif"),
           let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
           let image = NSImage(data: data) {
            imageView.image = image
        }

        imageView.animates = true
        imageView.imageScaling = isResizable ? .scaleProportionallyUpOrDown : .scaleNone

        imageView.translatesAutoresizingMaskIntoConstraints = false

        imageView.setContentHuggingPriority(.defaultLow, for: .horizontal)
        imageView.setContentHuggingPriority(.defaultLow, for: .vertical)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)

        return imageView
    }

    func updateNSView(_ nsView: NSImageView, context: Context) {
        nsView.imageScaling = isResizable ? .scaleProportionallyUpOrDown : .scaleNone
    }

    func resizable() -> GIFImage {
        var copy = self
        copy.isResizable = true
        return copy
    }
}

// MARK: - Corner helpers

enum RectCorner { case topLeft, topRight, bottomLeft, bottomRight }

extension View {
    func cornerRadius(_ radius: CGFloat, corners: [RectCorner]) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

extension QueueItem {
    func effectiveOutput(using main: OutputSettings, position: Int) -> OutputSettings {
        var result = perItemOutput ?? main

        // Handle file name
        if fileNameEdited {
            // keep custom value from perItemOutput
            if let custom = perItemOutput?.fileName {
                result.fileName = custom
            }
        } else {
            // dynamic suffix
            result.fileName = "\(main.fileName)-\(position + 1)"
        }
        return result
    }
}


struct RoundedCorner: Shape {
    var radius: CGFloat
    var corners: [RectCorner]

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let topLeft = corners.contains(.topLeft) ? radius : 0
        let topRight = corners.contains(.topRight) ? radius : 0
        let bottomLeft = corners.contains(.bottomLeft) ? radius : 0
        let bottomRight = corners.contains(.bottomRight) ? radius : 0

        path.move(to: CGPoint(x: rect.minX + topLeft, y: rect.minY))

        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        if topRight > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
                        radius: topRight, startAngle: .degrees(-90), endAngle: .degrees(0), clockwise: false)
        }

        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        if bottomRight > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
                        radius: bottomRight, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        }

        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        if bottomLeft > 0 {
            path.addArc(center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
                        radius: bottomLeft, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        }

        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        if topLeft > 0 {
            path.addArc(center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
                        radius: topLeft, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Color helpers

extension Color {
    static let selectorUnselected = Color(red: 60/255, green: 60/255, blue: 60/255)

    static func selectorBackground(selected: Bool,
                                       customThemeEnabled: Bool,
                                       themeType: String,
                                       colorScheme: ColorScheme) -> Color {
            // Theme overrides
            if customThemeEnabled {
                if themeType == "Hatsune Miku" {
                    return selected
                    ? Color(red: 226/255, green: 244/255, blue: 254/255)   // light Miku
                    : Color(red: 101/255, green: 137/255, blue: 173/255)   // Miku blue-gray
                } else if themeType == "Megurine Luka" {
                    return selected
                    ? Color(red: 245/255, green: 191/255, blue: 218/255)   // light Luka
                    : Color(red: 182/255, green: 115/255, blue: 143/255)   // Luka pink
                }
            }

            // System style
            if selected {
                // light chip in Light Mode, subtle light chip in Dark Mode
                return colorScheme == .dark
                    ? Color.white.opacity(0.16)
                    : Color.white
            } else {
                // gentle unselected fill
                return colorScheme == .dark
                    ? Color.white.opacity(0.06)
                    : Color.black.opacity(0.08)
            }
        }

    static func selectorText(selected: Bool,
                                 customThemeEnabled: Bool,
                                 themeType: String,
                                 colorScheme: ColorScheme) -> Color {
            // Themed chips are light → use black when selected
            if customThemeEnabled && (themeType == "Hatsune Miku" || themeType == "Megurine Luka") {
                return selected ? .black : (colorScheme == .dark ? .white : .black)
            }

            // System style: selected is WHITE in Dark Mode, BLACK in Light Mode
            if selected {
                return colorScheme == .dark ? .white : .black
            } else {
                return colorScheme == .dark ? .white.opacity(0.9) : .black
            }
        }

    static func tooltipBackground(customThemeEnabled: Bool, themeType: String) -> Color {
        if customThemeEnabled && themeType == "Hatsune Miku" {
            return Color(red: 110/255, green: 170/255, blue: 200/255)
        } else if customThemeEnabled && themeType == "Megurine Luka" {
            return Color(red: 191/255, green: 116/255, blue: 141/255)
        } else {
            return Color(NSColor.textBackgroundColor)
        }
    }
}

// MARK: - ColorSelect

struct ColorSelect {
    static func fromHex(_ hex: String) -> Color? {
        var s = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard s.count == 6 || s.count == 8 else { return nil }
        if s.count == 6 { s += "FF" }
        guard let v = UInt32(s, radix: 16) else { return nil }
        let r = Double((v >> 24) & 0xFF) / 255.0
        let g = Double((v >> 16) & 0xFF) / 255.0
        let b = Double((v >>  8) & 0xFF) / 255.0
        let a = Double((v >>  0) & 0xFF) / 255.0
        return Color(.sRGB, red: r, green: g, blue: b, opacity: a)
    }

    static func toHex(_ color: Color, includeAlpha: Bool = true) -> String? {
        let ns = NSColor(color)
        guard let rgb = ns.usingColorSpace(.sRGB) else { return nil }
        let r = max(0, min(255, Int(round(rgb.redComponent   * 255))))
        let g = max(0, min(255, Int(round(rgb.greenComponent * 255))))
        let b = max(0, min(255, Int(round(rgb.blueComponent  * 255))))
        let a = max(0, min(255, Int(round(rgb.alphaComponent * 255))))
        return includeAlpha
            ? String(format: "#%02X%02X%02X%02X", r, g, b, a)
            : String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Config

struct AppConfig: Codable, Equatable {
    var exportPath: String = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.path
    var output = OutputSettings()
    var performance = PerformanceSettings()
    var app = AppSettings()
}

struct OutputSettings: Codable, Equatable {
    var enable250ms: Bool = false

    var fileName: String = "Output"
    var exportCsvFrametimes: Bool = false

    enum CsvMode: String, Codable, CaseIterable { case general = "General", detailed = "Detailed" }
    var exportCsvSummary: Bool = false
    var csvSummaryMode: CsvMode = .general

    var exportImage: Bool = false
    var exportInteractive: Bool = false
    var exportAnimated: Bool = false

    var graphColorHex: String = "#33B170FF"

    var overlayScale: CGFloat = 100
    var renderOneSideOnly: Bool = false
    enum OverlaySide: String, Codable, CaseIterable { case left = "Left", middle = "Middle", right = "Right" }
    var overlayPosition: OverlaySide = .left

    var tearingDetection: Bool = false
}


struct PerformanceSettings: Codable, Equatable {
    var multithreadingEnabled: Bool = false
    var multithreadingChunkSize: Int = 1500   // 500…2000
    enum OverlayCodec: String, Codable, CaseIterable { case h264 = "H.264 (CPU)", prores422 = "ProRes 422 (CPU)" }
    var animatedOverlayCodec: OverlayCodec = .h264
}

struct AppSettings: Codable, Equatable {
    var measureProcessingTime: Bool = false
    var useCustomTheme: Bool = false
    enum Theme: String, Codable, CaseIterable { case miku = "Hatsune Miku", luka = "Megurine Luka", soon = "Coming Soon" }
    var theme: Theme = .miku
}

// MARK: - ContentView

struct ContentView: View {

    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingMusic = false
    @State private var isAnalyzing = false
    @State private var isRunning = false
    @State private var outputText: String = ""
    @State private var droppedFilePath: String? = nil
    @State private var processingDuration = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var config = AppConfig()
    @State private var showSettings = false
    @State private var showQueue = false
    @State private var queueItems: [QueueItem] = []
    
    

    var themeArtAttribution: String {
        if config.app.useCustomTheme && config.app.theme == .miku {
            return #"Art: "Snow Miku 2023" by nibeさん (piapro)"#
        } else if config.app.useCustomTheme && config.app.theme == .luka {
            return #"Art: "Megurine Luka 14th Anniversary" by なっつみかんさん (piapro)"#
        } else { return "" }
    }

    var musicAttribution: String {
        if isPlayingMusic && config.app.useCustomTheme {
            switch config.app.theme {
            case .miku: return #"Music: "MICHRONICLE" by 厚寝巻 (piapro)"#
            case .luka: return #"Music: "Ghost Rule" by Tsubaki_Kun (piapro)"#
            case .soon: return ""
            }
        }
        return ""
    }

    var primaryTextColor: Color {
        if config.app.useCustomTheme && (config.app.theme == .miku || config.app.theme == .luka) { return .black }
        return Color.primary
    }

    var settingsIconColor: Color {
        if config.app.useCustomTheme && (config.app.theme == .miku || config.app.theme == .luka) { return .black }
        return Color.primary
    }

    func toggleMusic() {
        if isPlayingMusic { audioPlayer?.stop(); isPlayingMusic = false; return }
        var musicFileName: String?
        switch config.app.theme {
        case .miku: musicFileName = "Thick_nightgown_Miku-MICHRONICLE"
        case .luka: musicFileName = "Tsubaki_Kun-Luka-Ghost_Rule"
        case .soon: musicFileName = nil
        }
        if let fileName = musicFileName, let path = Bundle.main.path(forResource: fileName, ofType: "mp3") {
            let url = URL(fileURLWithPath: path)
            do { audioPlayer = try AVAudioPlayer(contentsOf: url); audioPlayer?.play(); isPlayingMusic = true } catch {
                print("Failed to play music: \(error.localizedDescription)")
            }
        } else { print("Music file not found") }
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(spacing: 8) {
                // Settings
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gearshape")
                        .imageScale(.large)
                        .padding(6)
                        .foregroundColor(settingsIconColor)
                        .help("Settings")
                }
                // Queue
                Button(action: { showQueue.toggle() }) {
                    Image(systemName: "list.bullet.rectangle")
                        .imageScale(.large)
                        .padding(6)
                        .foregroundColor(settingsIconColor)
                        .help("Render queue")
                }
            }
            .offset(x: -120, y: 12)
            .onChange(of: showSettings) { isOpening in
                if isOpening {
                    var t = Transaction(); t.disablesAnimations = true
                    withTransaction(t) { showQueue = false }   // hide queue instantly → no flicker
                }
            }
            .onChange(of: showQueue) { isOpening in
                if isOpening {
                    var t = Transaction(); t.disablesAnimations = true
                    withTransaction(t) { showSettings = false } // hide settings instantly → no flicker
                }
            }



            VStack(spacing: 14) {
                HStack { Spacer() }

                VStack(spacing: 0) {
                    Text("FrameTool").font(.system(size: 34, weight: .bold)).foregroundColor(primaryTextColor)
                    Text("by Hardware Lab / wheissmd").font(.caption2).foregroundColor(.gray)
                }

                VStack(alignment: .leading) {
                    Text("Export Path:").font(.subheadline).foregroundColor(primaryTextColor)
                    HStack {
                        Text(config.exportPath).font(.caption).lineLimit(1)
                            .foregroundColor(config.app.useCustomTheme && (config.app.theme == .miku || config.app.theme == .luka) ? .black : .primary)
                        Spacer()
                        Button(action: {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url { config.exportPath = url.path }
                        }) {
                            Text("Choose Folder")
                                .foregroundColor(config.app.useCustomTheme && (config.app.theme == .miku || config.app.theme == .luka) ? .black : .primary)
                        }
                    }
                    .padding(8).background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray))
                }
                .padding(.horizontal)

                ZStack {
                    let locked = !queueItems.isEmpty

                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            locked ? Color.gray.opacity(0.5) : Color.blue,
                            style: StrokeStyle(lineWidth: 2, dash: [5])
                        )
                        .frame(height: 120)
                        .overlay(
                            Text(
                                locked
                                ? "Render Queue is in use. To do fast analysis empty the Render Queue first."
                                : (droppedFilePath ?? "Drop your video file here")
                            )
                            .foregroundColor(.gray)   // <- always gray, regardless of theme
                        )
                        .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
                            guard !locked else { return false }
                            if let provider = providers.first {
                                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                                    DispatchQueue.main.async { self.droppedFilePath = url?.path }
                                }
                                return true
                            }
                            return false
                        }
                        .allowsHitTesting(!locked)
                        .animation(.easeInOut(duration: 0.2), value: locked)
                }
                .padding(.horizontal)


                Button(action: { runAnalysis() }) {
                    Text("Run Analysis").foregroundColor(config.app.useCustomTheme && (config.app.theme == .miku || config.app.theme == .luka) ? .black : .primary)
                }
                .disabled(isAnalyzing || droppedFilePath == nil)
                .padding(.bottom, 5)

                if !isAnalyzing {
                    ScrollView {
                        Text(outputText)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(config.app.useCustomTheme && (config.app.theme == .miku || config.app.theme == .luka) ? .black : .primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }
                    .frame(height: 200)
                }

                Spacer()
            }
            .frame(width: 600, height: 700)
            .disabled(isAnalyzing)
            .padding()
            .onAppear {
                loadConfig()
                _ = QueueStore.purgeIfFirstLaunch()  // clear cache once per app run
                queueItems = QueueStore.load()       // load any cached queue (will be empty after purge)
            }
            .onChange(of: queueItems) { QueueStore.save($0) }
            .onReceive(timer) { _ in if isAnalyzing { processingDuration += 1 } }
            .onChange(of: config.app.theme) { _ in if isPlayingMusic { audioPlayer?.stop(); isPlayingMusic = false } }

            if isAnalyzing {
                VStack(spacing: 8) {
                    CustomSpinner(color: config.app.useCustomTheme && (config.app.theme == .miku || config.app.theme == .luka) ? .black : .primary, size: 32)
                    Text("Analyzing...").foregroundColor(config.app.useCustomTheme && (config.app.theme == .miku || config.app.theme == .luka) ? .black : .primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }

            if !musicAttribution.isEmpty {
                Text(musicAttribution)
                    .font(.caption)
                    .foregroundColor(config.app.useCustomTheme && (config.app.theme == .miku || config.app.theme == .luka) ? .black : .gray)
                    .padding(.leading, 16).padding(.bottom, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }

            Text(themeArtAttribution)
                .font(.caption)
                .foregroundColor(config.app.useCustomTheme && (config.app.theme == .miku || config.app.theme == .luka) ? .black : .gray)
                .padding(.leading, 16).padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            if config.app.measureProcessingTime && (isAnalyzing || processingDuration > 0) {
                Text("Processing Time: \(formatDuration(processingDuration))")
                    .font(.caption)
                    .foregroundColor(config.app.useCustomTheme && (config.app.theme == .miku || config.app.theme == .luka) ? .black : .gray)
                    .padding(.trailing, 16).padding(.bottom, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }

            if config.app.useCustomTheme && config.app.theme == .miku {
                Button(action: { toggleMusic() }) {
                    Rectangle().fill(Color.clear).frame(width: 250, height: 450).contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle()).position(x: 580, y: 590)
            }
            if config.app.useCustomTheme && config.app.theme == .luka {
                Button(action: { toggleMusic() }) {
                    Rectangle().fill(Color.clear).frame(width: 250, height: 450).contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle()).position(x: 199, y: 590)
            }

            ZStack {
                if showSettings {
                    SettingsPopup(config: $config, isRunning: isRunning)
                        .frame(width: 600).padding()
                        .background(
                            RoundedRectangle(cornerRadius: 12).fill(
                                config.app.useCustomTheme
                                ? (config.app.theme == .miku
                                   ? Color(red: 104/255, green: 160/255, blue: 204/255)
                                   : (config.app.theme == .luka
                                      ? Color(red: 191/255, green: 116/255, blue: 141/255)
                                      : Color(NSColor.windowBackgroundColor)))
                                : Color(NSColor.windowBackgroundColor)
                            )
                        )
                        .shadow(radius: 10).padding(.top, 60).offset(x: 0, y: 33)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
                if showQueue {
                    QueuePopup(items: $queueItems, isRunning: isRunning, customThemeEnabled: config.app.useCustomTheme,
                               themeType: config.app.theme.rawValue, globalOutput: $config.output)
                            .frame(width: 600)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        config.app.useCustomTheme
                                        ? (config.app.theme == .miku
                                           ? Color(red: 104/255, green: 160/255, blue: 204/255)
                                           : (config.app.theme == .luka
                                              ? Color(red: 191/255, green: 116/255, blue: 141/255)
                                              : Color(NSColor.windowBackgroundColor)))
                                        : Color(NSColor.windowBackgroundColor)
                                    )
                            )
                            .shadow(radius: 10)
                            .padding(.top, 60)
                            .offset(x: 0, y: 33)
                            .transition(.move(edge: .top).combined(with: .opacity))
                    }
                
            }
            .animation(.easeInOut(duration: 0.25), value: showSettings)
            .animation(.easeInOut(duration: 0.25), value: showQueue)
        }
        .frame(width: 600)
        .background {
            if config.app.useCustomTheme {
                Group {
                    if config.app.theme == .miku {
                        if let imagePath = Bundle.main.path(forResource: "Hatsune_Miku_Background", ofType: "png"),
                           let nsImage = NSImage(contentsOfFile: imagePath) {
                            Image(nsImage: nsImage).resizable().scaledToFill().ignoresSafeArea()
                        }
                    } else if config.app.theme == .luka {
                        if let imagePath = Bundle.main.path(forResource: "Megurine_Luka_Background", ofType: "png"),
                           let nsImage = NSImage(contentsOfFile: imagePath) {
                            Image(nsImage: nsImage).resizable().scaledToFill().ignoresSafeArea()
                        }
                    }
                }
            }
        }
    }

    func runAnalysis() {
        guard !isRunning, let videoPath = droppedFilePath else { return }
        isRunning = true; isAnalyzing = true; processingDuration = 0; outputText = ""
        saveConfig()

        // Temporary mapping until backend supports multiple exports
        let exportGraph: Bool
        let graphType: String
        if config.output.exportAnimated { exportGraph = true; graphType = "Animated Overlay" }
        else if config.output.exportInteractive { exportGraph = true; graphType = "Interactive" }
        else if config.output.exportImage { exportGraph = true; graphType = "Image" }
        else { exportGraph = false; graphType = "Image" }

        DispatchQueue.global(qos: .userInitiated).async {
            _ = FrameAnalyzer.runAnalysis(
                videoPath: videoPath,
                outputPath: config.exportPath,
                isMultithreading: config.performance.multithreadingEnabled,
                reportStats: config.output.exportCsvSummary,
                statsMode: config.output.csvSummaryMode.rawValue,
                exportImage: config.output.exportImage,
                exportInteractive: config.output.exportInteractive,
                exportAnimated: config.output.exportAnimated,
                detectTearing: config.output.tearingDetection,
                userGraphScale: config.output.overlayScale,
                renderOneSideOnly: config.output.renderOneSideOnly,
                overlayPosition: config.output.overlayPosition.rawValue,
                response250msEnabled: config.output.enable250ms,
                graphColorHex: config.output.graphColorHex,
                mtChunkSize: config.performance.multithreadingChunkSize,
                codec: (config.performance.animatedOverlayCodec == .prores422) ? "ProRes" : "H264",
                onComplete: { result in
                    DispatchQueue.main.async {
                        self.outputText = result
                        self.isAnalyzing = false
                        self.isRunning = false
                    }
                }
            )
        }

    }

    func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60; let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    func saveConfig() {
        if let data = try? JSONEncoder().encode(config) {
            let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("frametool_config.json")
            try? data.write(to: url)
        }
    }

    func loadConfig() {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("frametool_config.json")
        if let data = try? Data(contentsOf: url), let loaded = try? JSONDecoder().decode(AppConfig.self, from: data) {
            config = loaded
        }
    }
}

// MARK: - Per-item editor

struct PerItemOutputEditor: View {
    let itemIndex: Int
    @Binding var items: [QueueItem]
    @Binding var globalOutput: OutputSettings
    var useCustomTheme: Bool
    var themeType: String

    @State private var draft: OutputSettings = .init()
    @State private var fileNameEdited = false
    @State private var isPriming = true
    @State private var itemID: UUID?
    @State private var timer = Timer.publish(every: 0.25, on: .main, in: .common).autoconnect()
    @State private var lastIndex: Int?


    private var liveIndex: Int? {
        guard let id = itemID else { return nil }
        return items.firstIndex(where: { $0.id == id })
    }

    var body: some View {
        let idx = liveIndex ?? itemIndex
        return VStack(spacing: 16) {
            if items.indices.contains(idx) {
                Text(items[idx].url.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Divider()

            OutputTabForm(
                settings: $draft,
                customThemeEnabled: useCustomTheme,
                themeType: themeType,
                colorScheme: (useCustomTheme && themeType.lowercased().contains("dark")) ? .dark :
                             (useCustomTheme && themeType.lowercased().contains("light")) ? .light :
                             (NSApp.effectiveAppearance.name == .darkAqua ? .dark : .light),
                onFileNameEdited: {
                    let idx = liveIndex ?? itemIndex
                    if items.indices.contains(idx) {
                        let expected = "\(globalOutput.fileName)-\(idx + 1)"
                        let editedNow = draft.fileName != expected
                        fileNameEdited = editedNow
                        items[idx].fileNameEdited = editedNow
                        markOverridden()
                    }
                }
            )
            .frame(width: 600)


            Spacer(minLength: 0)

            HStack {
                Button("Reset to defaults") {
                    let idx = liveIndex ?? itemIndex
                    if items.indices.contains(idx) {
                        items[idx].perItemOutput = nil
                        items[idx].fileNameEdited = false
                        draft = globalOutput
                        draft.fileName = "\(globalOutput.fileName)-\(idx + 1)"
                        items[idx].hasOverrides = false
                        QueueStore.save(items)
                    }
                }
                Spacer()
                Button("Close") { NSApp.keyWindow?.close() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .onAppear {
            if itemID == nil, items.indices.contains(itemIndex) {
                itemID = items[itemIndex].id
            }
            let idx = liveIndex ?? itemIndex
            if items.indices.contains(idx) {
                draft = items[idx].perItemOutput ?? globalOutput
                fileNameEdited = items[idx].fileNameEdited
                if !fileNameEdited {
                    draft.fileName = "\(globalOutput.fileName)-\(idx + 1)"
                }
                lastIndex = idx
            }
            isPriming = false
        }


        .onChange(of: draft) { _ in
            if !isPriming { markOverridden() }
        }
        .onChange(of: draft.fileName) { _ in
            let idx = liveIndex ?? itemIndex
            if items.indices.contains(idx) {
                let expected = "\(globalOutput.fileName)-\(idx + 1)"
                let editedNow = draft.fileName != expected
                fileNameEdited = editedNow
                items[idx].fileNameEdited = editedNow
                markOverridden()
            }
        }
        .onChange(of: globalOutput) { _ in
            markOverridden()
        }
        .onChange(of: items.map { $0.id }) { _ in
            let newIdx = liveIndex ?? itemIndex
            guard items.indices.contains(newIdx) else { return }
            let oldIdx = lastIndex ?? newIdx
            let oldExpected = "\(globalOutput.fileName)-\(oldIdx + 1)"
            let newExpected = "\(globalOutput.fileName)-\(newIdx + 1)"

            if draft.fileName == oldExpected {
                draft.fileName = newExpected
            }
            if var per = items[newIdx].perItemOutput, per.fileName == oldExpected {
                per.fileName = newExpected
                items[newIdx].perItemOutput = per
            }
            lastIndex = newIdx
            markOverridden()
        }

        .onReceive(timer) { _ in
            if !isPriming { markOverridden() }
        }

    }

    private func markOverridden() {
        let idx = liveIndex ?? itemIndex
        guard items.indices.contains(idx) else { return }
        let expected = "\(globalOutput.fileName)-\(idx + 1)"
        var a = draft
        var b = globalOutput
        b.fileName = expected
        if a.fileName == expected { a.fileName = expected }
        let matches = (a == b)
        items[idx].hasOverrides = !matches
        items[idx].perItemOutput = matches ? nil : draft
        QueueStore.save(items)
    }

}


// MARK: - Reusable Output Tab for queue

struct OutputTabForm: View {
    @Binding var settings: OutputSettings
    var customThemeEnabled: Bool
    var themeType: String
    var colorScheme: ColorScheme
    var onFileNameEdited: (() -> Void)? = nil

    @State private var isOptionKeyPressed = false

    @State private var isHoveringResponseRateToggle = false
    @State private var responseRateToggleFrame: CGRect = .zero

    @State private var isHoveringReportCSVToggle = false
    @State private var reportCSVToggleFrame: CGRect = .zero
    @State private var isHoveringStatisticsGeneral = false
    @State private var isHoveringStatisticsDetailed = false
    @State private var statisticsGeneralFrame: CGRect = .zero
    @State private var statisticsDetailedFrame: CGRect = .zero

    @State private var isHoveringExportImage = false
    @State private var isHoveringExportInteractive = false
    @State private var isHoveringExportAnimated = false
    @State private var exportImageFrame: CGRect = .zero
    @State private var exportInteractiveFrame: CGRect = .zero
    @State private var exportAnimatedFrame: CGRect = .zero

    @State private var isHoveringGraphColor = false
    @State private var graphColorFrame: CGRect = .zero

    @State private var isHoveringGraphScaleSlider = false
    @State private var graphScaleSliderFrame: CGRect = .zero

    @State private var isHoveringRenderOneSideOnly = false
    @State private var renderOneSideOnlyFrame: CGRect = .zero

    @State private var isHoveringTearingDetectionToggle = false
    @State private var tearingDetectionToggleFrame: CGRect = .zero

    @State private var isHoveringFileName = false
    @State private var fileNameFrame: CGRect = .zero
    
    @State private var isHoveringCsvFrametimes = false
    @State private var csvFrametimesFrame: CGRect = .zero

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 22) {
                GeometryReader { geo in
                    HStack {
                        Text("File Name").font(.system(size: 13))
                        TextField("Output", text: $settings.fileName)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 150)
                            .onChange(of: settings.fileName) { _ in onFileNameEdited?() }
                            .onSubmit {
                                if settings.fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    settings.fileName = "Output"
                                }
                            }
                    }
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isHoveringFileName = hovering
                            if hovering { fileNameFrame = geo.frame(in: .global) }
                        }
                    }
                }
                .frame(height: 24)

                GeometryReader { geo in
                    Toggle("Enable 250 ms Response Rate", isOn: $settings.enable250ms)
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isHoveringResponseRateToggle = hovering
                                if hovering { responseRateToggleFrame = geo.frame(in: .global); blurFirstResponder()}
                            }
                        }
                }
                .frame(height: 20)

                if settings.enable250ms {
                    Text("⚠️ WARNING: 250 ms response rate may produce inaccurate FPS reports when analyzing locked-framerate footage.")
                        .font(.caption)
                        .foregroundColor(customThemeEnabled && themeType.lowercased().contains("miku") ? Color(red: 1.0, green: 0.9, blue: 0.4) : .orange)
                }

                GeometryReader { geo in
                    Toggle("Export CSV Frametimes", isOn: $settings.exportCsvFrametimes)
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isHoveringCsvFrametimes = hovering
                                if hovering { csvFrametimesFrame = geo.frame(in: .global); blurFirstResponder() }
                            }
                        }
                }
                .frame(height: 20)

                GeometryReader { geo in
                    Toggle("Export CSV Summary", isOn: $settings.exportCsvSummary)
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isHoveringReportCSVToggle = hovering
                                if hovering { reportCSVToggleFrame = geo.frame(in: .global); blurFirstResponder() }
                            }
                        }
                }
                .frame(height: 20)

                if settings.exportCsvSummary {
                    SegmentedTwoOptions(
                        leftTitle: "General",
                        rightTitle: "Detailed",
                        selectedLeft: settings.csvSummaryMode == .general,
                        onLeft: { settings.csvSummaryMode = .general },
                        onRight: { settings.csvSummaryMode = .detailed },
                        customThemeEnabled: customThemeEnabled,
                        themeType: themeType,
                        colorScheme: colorScheme,
                        onLeftHover: { isHoveringStatisticsGeneral = $0 },
                        onRightHover: { isHoveringStatisticsDetailed = $0 },
                        leftFrame: $statisticsGeneralFrame,
                        rightFrame: $statisticsDetailedFrame
                    )
                }

                GeometryReader { geo in
                    Toggle("Export Graph (Image)", isOn: $settings.exportImage)
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isHoveringExportImage = hovering
                                if hovering { exportImageFrame = geo.frame(in: .global); blurFirstResponder() }
                            }
                        }
                }
                .frame(height: 20)

                GeometryReader { geo in
                    Toggle("Export Graph (Interactive)", isOn: $settings.exportInteractive)
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isHoveringExportInteractive = hovering
                                if hovering { isHoveringExportAnimated = false; }
                                if hovering { exportInteractiveFrame = geo.frame(in: .global); blurFirstResponder() }
                            }
                        }
                }
                .frame(height: 20)

                GeometryReader { geo in
                    Toggle("Export Animated Overlay", isOn: $settings.exportAnimated)
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isHoveringExportAnimated = hovering
                                if hovering { isHoveringExportInteractive = false }
                                if hovering { exportAnimatedFrame = geo.frame(in: .global); blurFirstResponder() }
                            }
                        }
                }
                .frame(height: 20)

                if settings.exportImage || settings.exportInteractive || settings.exportAnimated {
                    GeometryReader { geo in
                        HStack(spacing: 8) {
                            Text("Exported Graph Colour   ").font(.system(size: 13))
                                .onHover { hovering in
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        isHoveringGraphColor = hovering
                                        if hovering { graphColorFrame = geo.frame(in: .global); blurFirstResponder() }
                                    }
                                }
                            ColorPicker("", selection: Binding<Color>(
                                get: { ColorSelect.fromHex(settings.graphColorHex) ?? .green },
                                set: { newColor in settings.graphColorHex = ColorSelect.toHex(newColor) ?? "#33B170FF" }
                            ), supportsOpacity: true)
                            .labelsHidden().frame(width: 24, height: 24)
                            .background(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.4)))
                        }
                    }
                    .frame(height: 24)
                }

                if settings.exportAnimated {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Animated Overlay Size").font(.system(size: 13))
                        HStack {
                            GeometryReader { geo in
                                Slider(value: $settings.overlayScale, in: 50...150)
                                    .onHover { hovering in
                                        withAnimation(.easeInOut(duration: 0.25)) {
                                            isHoveringGraphScaleSlider = hovering
                                            if hovering { graphScaleSliderFrame = geo.frame(in: .global); blurFirstResponder() }
                                        }
                                    }
                            }
                            .frame(height: 20)
                            Text("\(Int(settings.overlayScale))").frame(width: 35, alignment: .trailing).font(.system(size: 13))
                        }
                    }
                    GeometryReader { geo in
                        HStack(spacing: 8) {
                            Toggle(isOn: $settings.renderOneSideOnly) {
                                Text("Render overlay on half of the frame").font(.system(size: 13))
                            }
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isHoveringRenderOneSideOnly = hovering
                                    if hovering { renderOneSideOnlyFrame = geo.frame(in: .global); blurFirstResponder() }
                                }
                            }
                            Picker("", selection: $settings.overlayPosition) {
                                Text("Left").tag(OutputSettings.OverlaySide.left)
                                Text("Middle").tag(OutputSettings.OverlaySide.middle)
                                Text("Right").tag(OutputSettings.OverlaySide.right)
                            }
                            .frame(width: 90).pickerStyle(MenuPickerStyle())
                            .disabled(!settings.renderOneSideOnly)
                        }
                    }
                    .frame(height: 24)
                }

                if settings.tearingDetection || isOptionKeyPressed {
                    GeometryReader { geo in
                        Toggle("Tearing Detection (Experimental)", isOn: $settings.tearingDetection)
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isHoveringTearingDetectionToggle = hovering
                                    if hovering { tearingDetectionToggleFrame = geo.frame(in: .global); blurFirstResponder() }
                                }
                            }
                    }
                    .frame(height: 20)
                }
            }
            .padding()
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                    isOptionKeyPressed = event.modifierFlags.contains(.option)
                    return event
                }
            }

            tooltipsOverlay
        }
    }

    private var tooltipsOverlay: some View {
        ZStack {
            if isHoveringFileName {
                    TooltipText(
                        "Determines the prefix of all output files names",
                        frame: fileNameFrame,
                        customThemeEnabled: customThemeEnabled,
                        themeType: themeType,
                        xOffset: 256, yOffset: 60
                    )
            }
            if isHoveringResponseRateToggle {
                TooltipText(
                    "Default response rate is 1000 ms. Enabling 250 ms increases precision but reduces accuracy, and is not recommended when analyzing locked-framerate footage.",
                    frame: responseRateToggleFrame,
                    customThemeEnabled: customThemeEnabled,
                    themeType: themeType,
                    xOffset: 236, yOffset: 60
                )
            }
            if isHoveringReportCSVToggle {
                TooltipText(
                    "Exports a CSV file with test summary data (i. e. min FPS, avg FPS, max FPS).",
                    frame: reportCSVToggleFrame,
                    customThemeEnabled: customThemeEnabled,
                    themeType: themeType,
                    xOffset: 196, yOffset: 60
                )
            }
            if isHoveringCsvFrametimes {
                TooltipText(
                    "Exports CSV file with frametimes of every frame",
                    frame: csvFrametimesFrame,
                    customThemeEnabled: customThemeEnabled,
                    themeType: themeType,
                    xOffset: 196, yOffset: 60
                )
            }
            if isHoveringStatisticsGeneral {
                TooltipText(
                    "Reports min FPS, avg FPS, and max FPS.",
                    frame: statisticsGeneralFrame,
                    customThemeEnabled: customThemeEnabled,
                    themeType: themeType,
                    xOffset: 25, yOffset: 30
                )
            }
            if isHoveringStatisticsDetailed {
                TooltipText(
                    "Reports min FPS, avg FPS, max FPS, longest frame duration, % of frames matching it, 1% slowest frames, and their corresponding FPS.",
                    frame: statisticsDetailedFrame,
                    customThemeEnabled: customThemeEnabled,
                    themeType: themeType,
                    xOffset: 30, yOffset: 30
                )
            }
            if isHoveringExportImage {
                TooltipImagePreview(
                    title: "Exports a high resolution image with FPS and Frametime graphs.",
                    imageName: "Image",
                    frame: exportImageFrame,
                    width: 320, height: 269,
                    offsetX: 20, offsetY: 120,
                    customThemeEnabled: customThemeEnabled,
                    themeType: themeType
                )
            }
            if isHoveringExportInteractive && !isHoveringExportAnimated {
                TooltipGIFPreview(
                    title: "Exports an interactive HTML graph of FPS and Frametime.",
                    gifName: "Interactive",
                    frame: exportInteractiveFrame,
                    height: 320, offsetX: 35, offsetY: 110,
                    customThemeEnabled: customThemeEnabled,
                    themeType: themeType
                )
            }
            if isHoveringExportAnimated {
                TooltipGIFPreview(
                    title: "Exports an original video with Frametime and FPS graphs as overlays.",
                    gifName: "Animated_Overlay",
                    frame: exportAnimatedFrame,
                    height: 220, offsetX: 30, offsetY: 70,
                    customThemeEnabled: customThemeEnabled,
                    themeType: themeType
                )
            }
            if isHoveringGraphColor {
                TooltipText(
                    "Choose colour of the graph",
                    frame: graphColorFrame,
                    customThemeEnabled: customThemeEnabled,
                    themeType: themeType,
                    xOffset: 236, yOffset: 60
                )
            }
            if isHoveringGraphScaleSlider {
                TooltipScalePreview(
                    text: "Controls the size of the Animated Overlay",
                    imageForScale: getScalingImage(for: Int(settings.overlayScale)),
                    frame: graphScaleSliderFrame,
                    customThemeEnabled: customThemeEnabled,
                    themeType: themeType,
                    offsetX: 110, offsetY: 30
                )
            }
            if isHoveringRenderOneSideOnly {
                TooltipOverlaySide(
                    overlayPosition: settings.overlayPosition.rawValue,
                    frame: renderOneSideOnlyFrame,
                    customThemeEnabled: customThemeEnabled,
                    themeType: themeType,
                    offsetX: 110, offsetY: 35
                )
            }
            if isHoveringTearingDetectionToggle {
                TooltipText(
                    "Tearing detection predicts the original framerate in recordings with screen tearing. This feature is EXPERIMENTAL and known to cause false positives or negatives. Use it mainly for testing or entertainment purposes.",
                    frame: tearingDetectionToggleFrame,
                    customThemeEnabled: customThemeEnabled,
                    themeType: themeType,
                    xOffset: 245, yOffset: 60
                )
            }
        }
    }
}


// MARK: - Drag & Drop Reorder

private struct QueueDropDelegate: DropDelegate {
    let item: QueueItem
        @Binding var items: [QueueItem]
        @Binding var draggingItem: QueueItem?

    func validateDrop(info: DropInfo) -> Bool { true }

    func dropEntered(info: DropInfo) {
        guard let dragging = draggingItem, dragging != item,
              let from = items.firstIndex(of: dragging),
              let to   = items.firstIndex(of: item) else { return }

        if items[to].id != dragging.id {
            items.move(fromOffsets: IndexSet(integer: from),
                       toOffset: (to > from) ? to + 1 : to)
        }
    }



        func performDrop(info: DropInfo) -> Bool {
            draggingItem = nil
            // Update default names after reordering
            for (idx, _) in items.enumerated() {
                if items[idx].fileNameEdited == false, var o = items[idx].perItemOutput {
                    items[idx].perItemOutput = o
                }
            }
            QueueStore.save(items)
            return true

    }
}

// MARK: - QueuePopup
struct QueuePopup: View {
    
    @Binding var items: [QueueItem]
    let isRunning: Bool
    
    
    var customThemeEnabled: Bool
    var themeType: String
    
    @Binding var globalOutput: OutputSettings

    private var footerColor: Color {
            (customThemeEnabled && (themeType == "Hatsune Miku" || themeType == "Megurine Luka")) ? .black : .white
        }
    
    @State private var editingItem: QueueItem? = nil

    @State private var draggingItem: QueueItem?
    
    @State private var isDropTarget = false
    
    private func recomputeOverrides() {
        for idx in items.indices {
            let edited = items[idx].fileNameEdited
            let dynamicName = "\(globalOutput.fileName)-\(idx + 1)"
            var draft = items[idx].perItemOutput ?? globalOutput
            var a = draft
            var b = globalOutput
            if !edited {
                a.fileName = dynamicName
                b.fileName = dynamicName
            }
            let match = (a == b)
            let isOverridden = !match || edited
            items[idx].hasOverrides = isOverridden
            items[idx].perItemOutput = isOverridden ? draft : nil
        }
        QueueStore.save(items)
    }


    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header and button
            HStack(spacing: 8) {
                Image(systemName: "list.bullet.rectangle")
                    .font(.system(size: 16, weight: .semibold))
                Text("Render Queue")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button {
                    addVideos()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "plus.circle")
                        Text("Add video files")
                    }
                }
                .buttonStyle(.bordered)
                .disabled(isRunning)
                .opacity(isRunning ? 0.6 : 1.0)
            }

            // List
            if items.isEmpty {
                // Non-interactive placeholder
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        Text("Add video files before configuring the set up")
                            .foregroundColor(.secondary)
                            .padding(12)
                    )
                    .frame(height: 260)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .disabled(isRunning)
                    .onDrop(of: [UTType.fileURL, .movie, .audiovisualContent, .url],
                            isTargeted: $isDropTarget) { providers in

                        let allowedExt: Set<String> = ["mov","mp4","m4v","avi","mkv","webm"]

                        func appendURL(_ url: URL) {
                            guard url.isFileURL, allowedExt.contains(url.pathExtension.lowercased()) else { return }
                            DispatchQueue.main.async {
                                items.append(QueueItem(url: url))
                                QueueStore.save(items)
                            }
                        }

                        var accepted = false

                        for p in providers {
                            // 1) Direct file URL
                            if p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                                accepted = true
                                p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                                    if let url = item as? URL { appendURL(url) }
                                }
                                continue
                            }

                            // 2) Movie file (e.g. QuickTime .mov)
                            if p.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                                accepted = true
                                p.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                                    if let url = url { appendURL(url) }
                                }
                                continue
                            }

                            // 3) Generic audiovisual content
                            if p.hasItemConformingToTypeIdentifier(UTType.audiovisualContent.identifier) {
                                accepted = true
                                p.loadFileRepresentation(forTypeIdentifier: UTType.audiovisualContent.identifier) { url, _ in
                                    if let url = url { appendURL(url) }
                                }
                                continue
                            }

                            // 4) Fallback: plain URL (sometimes Finder provides public.url)
                            if p.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                                accepted = true
                                p.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                                    if let url = item as? URL, url.isFileURL { appendURL(url) }
                                }
                            }
                        }

                        return accepted
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(isDropTarget ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 2)
                    )
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(items) { item in
                            rowView(item)
                                .onDrag {
                                    draggingItem = item
                                    return NSItemProvider(object: item.id.uuidString as NSString)
                                }
                                .onDrop(of: [.text], delegate: QueueDropDelegate(
                                    item: item,
                                    items: $items,
                                    draggingItem: $draggingItem
                                ))
                        }
                    }
                    .animation(.easeInOut(duration: 0.12), value: items)
                    .padding(.vertical, 4)
                }
                .onDrop(of: [UTType.fileURL, .movie, .audiovisualContent, .url],
                        isTargeted: $isDropTarget) { providers in

                    let allowedExt: Set<String> = ["mov","mp4","m4v","avi","mkv","webm"]

                    func appendURL(_ url: URL) {
                        guard url.isFileURL, allowedExt.contains(url.pathExtension.lowercased()) else { return }
                        DispatchQueue.main.async {
                            items.append(QueueItem(url: url))   // your model
                            QueueStore.save(items)             // if you persist
                        }
                    }

                    var accepted = false

                    for p in providers {
                        // 1) Direct file URL
                        if p.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                            accepted = true
                            p.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                                if let url = item as? URL { appendURL(url) }
                            }
                            continue
                        }

                        // 2) Movie file (e.g. QuickTime .mov)
                        if p.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                            accepted = true
                            p.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                                if let url = url { appendURL(url) }
                            }
                            continue
                        }

                        // 3) Generic audiovisual content
                        if p.hasItemConformingToTypeIdentifier(UTType.audiovisualContent.identifier) {
                            accepted = true
                            p.loadFileRepresentation(forTypeIdentifier: UTType.audiovisualContent.identifier) { url, _ in
                                if let url = url { appendURL(url) }
                            }
                            continue
                        }

                        // 4) Fallback: plain URL (sometimes Finder provides public.url)
                        if p.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                            accepted = true
                            p.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { item, _ in
                                if let url = item as? URL, url.isFileURL { appendURL(url) }
                            }
                        }
                    }

                    return accepted
                }
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(isDropTarget ? Color.accentColor.opacity(0.6) : .clear, lineWidth: 2)
                )
                .transaction { tx in
                    if draggingItem != nil { tx.disablesAnimations = true }
                }

                .disabled(isRunning)
                .frame(minHeight: 160, maxHeight: 260)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(NSColor.controlBackgroundColor))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                
                
            }
            Text("v0.4.0-Alpha")
              .font(.caption2)
              .foregroundStyle(.secondary)
        }
        .onChange(of: items.map { $0.id }) { _ in
                    recomputeOverrides()
                }
    }

    // Row

    private func rowView(_ item: QueueItem) -> some View {
        HStack(spacing: 10) {
            // Left: icon + name
            HStack(spacing: 8) {
                Image(systemName: "film")
                    .font(.system(size: 14, weight: .semibold))
                Text(item.url.lastPathComponent)
                    .font(.system(size: 13))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            Spacer(minLength: 12)

            // Right: settings + delete
            HStack(spacing: 8) {
                Button {
                    openItemSettings(item)
                } label: {
                    Image(systemName: "gearshape")
                        .foregroundColor(item.hasOverrides ? .red : .primary)
                }
                .buttonStyle(.borderless)

                Button {
                    remove(item)
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
            }
            .disabled(isRunning)
            .opacity(isRunning ? 0.6 : 1.0)
            
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(NSColor.textBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal, 8)
        
    }

    // Actions

    private func addVideos() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowedFileTypes = ["mov", "mp4", "m4v", "avi", "mkv", "webm"]

        if panel.runModal() == .OK {
            let newItems = panel.urls
                .filter { url in !items.contains(where: { $0.url == url }) }
                .map { QueueItem(url: $0) }
            if !newItems.isEmpty {
                items.append(contentsOf: newItems)
                recomputeOverrides()
            }
        }
    }

    

    private func remove(_ item: QueueItem) {
        if let idx = items.firstIndex(of: item) {
            items.remove(at: idx)
            recomputeOverrides()
        }
    }


    private func openItemSettings(_ item: QueueItem) {
        guard let idx = items.firstIndex(of: item) else { return }
        let controller = PerItemSettingsWindowController(
            itemIndex: idx,
            itemsBinding: $items,
            globalOutputBinding: $globalOutput,
            useCustomTheme: customThemeEnabled,
            themeType: themeType
        )
        controller.showWindow(nil)
    }

    
    
}


// MARK: - Queue model
struct QueueItem: Identifiable, Codable, Equatable {
    let id: UUID
    var url: URL
    var perItemOutput: OutputSettings?   // nil = follow main Output settings
    var fileNameEdited: Bool             // User manual override file name
    var hasOverrides: Bool               // any per-item overrides
    var position: Int = 0

    init(url: URL) {
        self.id = UUID()
        self.url = url
        self.perItemOutput = nil
        self.fileNameEdited = false
        self.hasOverrides = false
    }
}

// MARK: - Per-item Output Settings Window (match app theme)

fileprivate let SettingsContentWidth: CGFloat = 600
struct PerItemEditorByID: View {
    let itemID: UUID
    @Binding var items: [QueueItem]
    @Binding var globalOutput: OutputSettings
    var useCustomTheme: Bool
    var themeType: String

    var body: some View {
        let idx = items.firstIndex(where: { $0.id == itemID }) ?? 0
        return PerItemOutputEditor(
            itemIndex: idx,
            items: $items,
            globalOutput: $globalOutput,
            useCustomTheme: useCustomTheme,
            themeType: themeType
        )
    }
}

final class PerItemSettingsWindowController: NSWindowController {
    private var hosting: NSHostingController<AnyView>!

    init(itemIndex: Int,
         itemsBinding: Binding<[QueueItem]>,
         globalOutputBinding: Binding<OutputSettings>,
         useCustomTheme: Bool,
         themeType: String) {

        let initialItems = itemsBinding.wrappedValue
        let itemID = initialItems.indices.contains(itemIndex) ? initialItems[itemIndex].id : UUID()

        let editorByID = PerItemEditorByID(
            itemID: itemID,
            items: itemsBinding,
            globalOutput: globalOutputBinding,
            useCustomTheme: useCustomTheme,
            themeType: themeType
        )

        let rootView: AnyView = useCustomTheme
        ? AnyView(editorByID.preferredColorScheme(.dark))
        : AnyView(editorByID)

        hosting = NSHostingController(rootView: rootView)

        let initialHeight: CGFloat = 700
        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0,
                                width: Int(SettingsContentWidth),
                                height: Int(initialHeight)),
            styleMask: [.titled, .closable, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        w.title = "Item Output Settings"
        w.isReleasedWhenClosed = false
        w.contentViewController = hosting
        w.setContentSize(NSSize(width: SettingsContentWidth, height: initialHeight))
        w.minSize = NSSize(width: SettingsContentWidth, height: 560)

        let themeBG: NSColor = {
            guard useCustomTheme else { return .windowBackgroundColor }
            switch themeType {
            case AppSettings.Theme.miku.rawValue:
                return NSColor(srgbRed: 94/255, green: 150/255, blue: 194/255, alpha: 1)
            case AppSettings.Theme.luka.rawValue:
                return NSColor(srgbRed: 181/255, green: 106/255, blue: 131/255, alpha: 1)
            default:
                return .windowBackgroundColor
            }
        }()
        w.isOpaque = true
        w.backgroundColor = themeBG
        if let cv = w.contentView {
            cv.wantsLayer = true
            cv.layer?.backgroundColor = themeBG.cgColor
        }
        w.appearance = useCustomTheme ? NSAppearance(named: .darkAqua) : nil
        w.center()
        super.init(window: w)
    }

    required init?(coder: NSCoder) { fatalError() }
}




// MARK: - Cache in /Library/Caches
enum QueueStore {
    private static let fileURL: URL = {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("render-queue.json")
    }()

    private static var didPurgeThisRun = false
    /// Removes the cache once per app run so the app always launches empty.
    static func purgeIfFirstLaunch() -> Bool {
        guard !didPurgeThisRun else { return false }
        didPurgeThisRun = true
        try? FileManager.default.removeItem(at: fileURL)
        return true
    }

    static func load() -> [QueueItem] {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([QueueItem].self, from: data)
        else { return [] }
        return normalize(decoded)
    }

    static func save(_ items: [QueueItem]) {
        let items = normalize(items)
        if items.isEmpty {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        if let data = try? JSONEncoder().encode(items) {
            try? data.write(to: fileURL, options: .atomic)
        }
    }

    @discardableResult
    private static func normalize(_ items: [QueueItem]) -> [QueueItem] {
        var out = items
        for i in out.indices { out[i].position = i }
        return out
    }
}



// MARK: - SettingsPopup with Tabs

struct SettingsPopup: View {
    @Binding var config: AppConfig

    @Environment(\.colorScheme) var colorScheme
    @State private var isOptionKeyPressed = false

    enum Tab { case output, performance, app }
    @State private var tab: Tab = .output

    // Tooltip states / frames
    @State private var isHoveringResponseRateToggle = false
    @State private var responseRateToggleFrame: CGRect = .zero

    @State private var isHoveringReportCSVToggle = false
    @State private var reportCSVToggleFrame: CGRect = .zero
    @State private var isHoveringStatisticsGeneral = false
    @State private var isHoveringStatisticsDetailed = false
    @State private var statisticsGeneralFrame: CGRect = .zero
    @State private var statisticsDetailedFrame: CGRect = .zero

    @State private var isHoveringExportImage = false
    @State private var isHoveringExportInteractive = false
    @State private var isHoveringExportAnimated = false
    @State private var exportImageFrame: CGRect = .zero
    @State private var exportInteractiveFrame: CGRect = .zero
    @State private var exportAnimatedFrame: CGRect = .zero

    @State private var isHoveringGraphColor = false
    @State private var graphColorFrame: CGRect = .zero

    @State private var isHoveringGraphScaleSlider = false
    @State private var graphScaleSliderFrame: CGRect = .zero

    @State private var isHoveringRenderOneSideOnly = false
    @State private var renderOneSideOnlyFrame: CGRect = .zero

    @State private var isHoveringTearingDetectionToggle = false
    @State private var tearingDetectionToggleFrame: CGRect = .zero

    @State private var isHoveringMultithreadingToggle = false
    @State private var multithreadingToggleFrame: CGRect = .zero
    @State private var isHoveringChunkSlider = false
    @State private var chunkSliderFrame: CGRect = .zero
    @State private var isHoveringCodec = false
    @State private var codecFrame: CGRect = .zero

    @State private var isHoveringCustomThemeToggle = false
    @State private var customThemeToggleFrame = CGRect.zero
    @State private var isHoveringThemeMiku = false
    @State private var isHoveringThemeLuka = false
    @State private var themeMikuFrame: CGRect = .zero
    @State private var themeLukaFrame: CGRect = .zero

    @State private var isHoveringMeasureTimeToggle = false
    @State private var measureTimeToggleFrame: CGRect = .zero
    
    @State private var isHoveringFileName = false
    @State private var fileNameFrame: CGRect = .zero

    @State private var isHoveringCsvFrametimes = false
    @State private var csvFrametimesFrame: CGRect = .zero
    
    let isRunning: Bool
    
    
    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16, weight: .semibold))
                    Text("Settings")
                        .font(.system(size: 16, weight: .semibold))
                }
                TabsPicker(tab: $tab,
                           customThemeEnabled: config.app.useCustomTheme,
                           themeType: config.app.theme.rawValue,
                           colorScheme: colorScheme)

                Group {
                    switch tab {
                    case .output: outputTab
                    case .performance: performanceTab
                    case .app: appTab
                    }
                }

                Text("v0.4.0-Alpha")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            
            .padding()
            .overlay(alignment: .topLeading) { tooltipsOverlay }
            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                    isOptionKeyPressed = event.modifierFlags.contains(.option)
                    return event
                }
            }
        }
    }

    // Output Tab
    private var outputTab: some View {
        
        VStack(alignment: .leading, spacing: 22) {
            
            GeometryReader { geo in
                HStack {
                    Text("File Name").font(.system(size: 13))
                    TextField("Output", text: $config.output.fileName)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 150)
                        .onSubmit {
                            if config.output.fileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                config.output.fileName = "Output"
                            }
                        }
                }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.25)) {
                        isHoveringFileName = hovering
                        if hovering { fileNameFrame = geo.frame(in: .global) }
                    }
                }
            }
            .frame(height: 24)
            
            GeometryReader { geo in
                Toggle("Enable 250 ms Response Rate", isOn: $config.output.enable250ms)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isHoveringResponseRateToggle = hovering
                            if hovering { responseRateToggleFrame = geo.frame(in: .global); blurFirstResponder() }
                        }
                    }
            }
            .frame(height: 20)

            if config.output.enable250ms {
                Text("⚠️ WARNING: 250 ms response rate may produce inaccurate FPS reports when analyzing locked-framerate footage.")
                    .font(.caption)
                    .foregroundColor(config.app.useCustomTheme && config.app.theme == .miku ? Color(red: 1.0, green: 0.9, blue: 0.4) : .orange)
            }

            GeometryReader { geo in
                Toggle("Export CSV Frametimes", isOn: $config.output.exportCsvFrametimes)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isHoveringCsvFrametimes = hovering
                            if hovering { csvFrametimesFrame = geo.frame(in: .global); blurFirstResponder() }
                        }
                    }
            }
            .frame(height: 20)
            
            GeometryReader { geo in
                Toggle("Export CSV Summary", isOn: $config.output.exportCsvSummary)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isHoveringReportCSVToggle = hovering
                            if hovering { reportCSVToggleFrame = geo.frame(in: .global); blurFirstResponder() }
                        }
                    }
            }
            .frame(height: 20)

            if config.output.exportCsvSummary {
                SegmentedTwoOptions(
                    leftTitle: "General",
                    rightTitle: "Detailed",
                    selectedLeft: config.output.csvSummaryMode == .general,
                    onLeft: { config.output.csvSummaryMode = .general },
                    onRight: { config.output.csvSummaryMode = .detailed },
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue,
                    colorScheme: colorScheme,
                    onLeftHover: { isHoveringStatisticsGeneral = $0 },
                    onRightHover: { isHoveringStatisticsDetailed = $0 },
                    leftFrame: $statisticsGeneralFrame,
                    rightFrame: $statisticsDetailedFrame
                )
            }

            // Graph export toggles
            GeometryReader { geo in
                Toggle("Export Graph (Image)", isOn: $config.output.exportImage)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isHoveringExportImage = hovering
                            if hovering { exportImageFrame = geo.frame(in: .global); blurFirstResponder() }
                        }
                    }
            }.frame(height: 20)

            // Export Graph (Interactive)
            GeometryReader { geo in
                Toggle("Export Graph (Interactive)", isOn: $config.output.exportInteractive)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isHoveringExportInteractive = hovering
                            if hovering { isHoveringExportAnimated = false }
                            if hovering { exportInteractiveFrame = geo.frame(in: .global); blurFirstResponder() }
                        }
                    }
            }
            .frame(height: 20)

            // Export Animated Overlay
            GeometryReader { geo in
                Toggle("Export Animated Overlay", isOn: $config.output.exportAnimated)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isHoveringExportAnimated = hovering
                            if hovering { isHoveringExportInteractive = false }
                            if hovering { exportAnimatedFrame = geo.frame(in: .global); blurFirstResponder() }
                        }
                    }
            }
            .frame(height: 20)

            if config.output.exportImage || config.output.exportInteractive || config.output.exportAnimated {
                GeometryReader { geo in
                    HStack(spacing: 8) {
                        Text("Exported Graph Colour   ").font(.system(size: 13))
                            .onHover { hovering in
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    isHoveringGraphColor = hovering
                                    if hovering { graphColorFrame = geo.frame(in: .global); blurFirstResponder() }
                                }
                            }
                        ColorPicker("", selection: Binding<Color>(
                            get: { ColorSelect.fromHex(config.output.graphColorHex) ?? .green },
                            set: { newColor in config.output.graphColorHex = ColorSelect.toHex(newColor) ?? "#33B170FF" }
                        ), supportsOpacity: true)
                        .labelsHidden().frame(width: 24, height: 24)
                        .background(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.4)))
                    }
                }.frame(height: 24)
            }

            if config.output.exportAnimated {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Animated Overlay Size").font(.system(size: 13))
                    HStack {
                        GeometryReader { geo in
                            Slider(value: $config.output.overlayScale, in: 50...150)
                                .onHover { hovering in
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        isHoveringGraphScaleSlider = hovering
                                        if hovering { graphScaleSliderFrame = geo.frame(in: .global); blurFirstResponder() }
                                    }
                                }
                        }.frame(height: 20)
                        Text("\(Int(config.output.overlayScale))").frame(width: 35, alignment: .trailing).font(.system(size: 13))
                    }
                }
                GeometryReader { geo in
                    HStack(spacing: 8) {
                        Toggle(isOn: $config.output.renderOneSideOnly) {
                            Text("Render overlay on half of the frame").font(.system(size: 13))
                        }
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isHoveringRenderOneSideOnly = hovering
                                if hovering { renderOneSideOnlyFrame = geo.frame(in: .global); blurFirstResponder() }
                            }
                        }
                        Picker("", selection: $config.output.overlayPosition) {
                            Text("Left").tag(OutputSettings.OverlaySide.left)
                            Text("Middle").tag(OutputSettings.OverlaySide.middle)
                            Text("Right").tag(OutputSettings.OverlaySide.right)
                        }
                        .frame(width: 90).pickerStyle(MenuPickerStyle())
                        .disabled(!config.output.renderOneSideOnly)
                    }
                }.frame(height: 24)
            }

            if config.output.tearingDetection || isOptionKeyPressed {
                GeometryReader { geo in
                    Toggle("Tearing Detection (Experimental)", isOn: $config.output.tearingDetection)
                        .onHover { hovering in
                            withAnimation(.easeInOut(duration: 0.25)) {
                                isHoveringTearingDetectionToggle = hovering
                                if hovering { tearingDetectionToggleFrame = geo.frame(in: .global); blurFirstResponder() }
                            }
                        }
                }.frame(height: 20)
            }
        }
        .disabled(isRunning)
        .opacity(isRunning ? 0.6 : 1.0)
    }

    // Performance Tab
    private var performanceTab: some View {
        VStack(alignment: .leading, spacing: 22) {
            GeometryReader { geo in
                Toggle("Enable Multithreading", isOn: $config.performance.multithreadingEnabled)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isHoveringMultithreadingToggle = hovering
                            if hovering { multithreadingToggleFrame = geo.frame(in: .global); blurFirstResponder() }
                        }
                    }
            }.frame(height: 20)

            if config.performance.multithreadingEnabled {
                Text("⚠️ WARNING: Multithreading might slow down performance on machines with less than 16GB of RAM.")
                    .font(.caption)
                    .foregroundColor(config.app.useCustomTheme && config.app.theme == .miku ? Color(red: 1.0, green: 0.9, blue: 0.4) : .orange)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Multithreading Chunk Size").font(.system(size: 13))
                    HStack {
                        GeometryReader { geo in
                            Slider(value: Binding(get: { Double(config.performance.multithreadingChunkSize) },
                                                  set: { config.performance.multithreadingChunkSize = Int($0) }),
                                   in: 500...2000, step: 100)
                                .onHover { hovering in
                                    withAnimation(.easeInOut(duration: 0.25)) {
                                        isHoveringChunkSlider = hovering
                                        if hovering { chunkSliderFrame = geo.frame(in: .global); blurFirstResponder() }
                                    }
                                }
                        }.frame(height: 20)
                        Text("\(config.performance.multithreadingChunkSize)").frame(width: 50, alignment: .trailing).font(.system(size: 13))
                    }
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                Text("Codec for Animated Overlay").font(.system(size: 13))
                GeometryReader { geo in
                    CodecSelector(
                        selected: $config.performance.animatedOverlayCodec,
                        customThemeEnabled: config.app.useCustomTheme,
                        themeType: config.app.theme.rawValue,
                        colorScheme: colorScheme
                    )
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isHoveringCodec = hovering
                            if hovering { codecFrame = geo.frame(in: .global); blurFirstResponder() }
                        }
                    }
                }.frame(height: 28)
            }
        }
        .disabled(isRunning)
        .opacity(isRunning ? 0.6 : 1.0)
    }

    // App Tab
    private var appTab: some View {
        VStack(alignment: .leading, spacing: 22) {
            GeometryReader { geo in
                Toggle("Measure Processing Time", isOn: $config.app.measureProcessingTime)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isHoveringMeasureTimeToggle = hovering
                            if hovering { measureTimeToggleFrame = geo.frame(in: .global); blurFirstResponder() }
                        }
                    }
            }.frame(height: 20)

            GeometryReader { geo in
                Toggle("Use Custom Theme", isOn: $config.app.useCustomTheme)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isHoveringCustomThemeToggle = hovering
                            if hovering { customThemeToggleFrame = geo.frame(in: .global); blurFirstResponder() }
                        }
                    }
            }.frame(height: 20)

            if config.app.useCustomTheme {
                ThemeSelector(
                    selectedTheme: $config.app.theme,
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue,
                    colorScheme: colorScheme,
                    onMikuHover: { isHoveringThemeMiku = $0 },
                    onLukaHover: { isHoveringThemeLuka = $0 },
                    mikuFrame: $themeMikuFrame,
                    lukaFrame: $themeLukaFrame
                )
            }
        }
        .disabled(isRunning)
        .opacity(isRunning ? 0.6 : 1.0)
    }

    // Tooltips overlay
    private var tooltipsOverlay: some View {
        ZStack {
            ForEach(Array(composeTooltips().enumerated()), id: \.offset) { _, view in
                view
            }
        }
    }

    // Build the currently active tooltips as an array of AnyView
    private func composeTooltips() -> [AnyView] {
        var out: [AnyView] = []
        
        if isHoveringFileName {
            out.append(AnyView(
                TooltipText(
                    "Determines the prefix of all output files names",
                    frame: fileNameFrame,
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue
                )
            ))
        }

        if isHoveringCsvFrametimes {
            out.append(AnyView(
                TooltipText(
                    "Exports CSV file with frametimes of every frame",
                    frame: csvFrametimesFrame,
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue
                )
            ))
        }


        if isHoveringResponseRateToggle {
            out.append(AnyView(
                TooltipText(
                    "Default response rate is 1000 ms. Enabling 250 ms increases precision but reduces accuracy, and is not recommended when analyzing locked-framerate footage.",
                    frame: responseRateToggleFrame,
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue
                )
            ))
        }
        
        if isHoveringReportCSVToggle {
            out.append(AnyView(
                TooltipText(
                    "Exports a CSV file with test summary data (i. e. min FPS, avg FPS, max FPS).",
                    frame: reportCSVToggleFrame,
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue
                )
            ))
        }
        if isHoveringStatisticsGeneral {
            out.append(AnyView(
                TooltipText(
                    "Reports min FPS, avg FPS, and max FPS.",
                    frame: statisticsGeneralFrame,
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue,
                    xOffset: 0, yOffset: -108
                )
            ))
        }
        if isHoveringStatisticsDetailed {
            out.append(AnyView(
                TooltipText(
                    "Reports min FPS, avg FPS, max FPS, longest frame duration, % of frames matching it, 1% slowest frames, and their corresponding FPS.",
                    frame: statisticsDetailedFrame,
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue,
                    xOffset: 0, yOffset: -108
                )
            ))
        }
        if isHoveringExportImage {
            out.append(AnyView(
                TooltipImagePreview(
                    title: "Exports a high resolution image with FPS and Frametime graphs.",
                    imageName: "Image",
                    frame: exportImageFrame,
                    width: 380, height: 320, offsetX: -120,
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue
                )
            ))
        } else if isHoveringExportInteractive {
            out.append(AnyView(
                TooltipGIFPreview(
                    title: "Exports an interactive HTML graph of FPS and Frametime.",
                    gifName: "Interactive",
                    frame: exportInteractiveFrame,
                    height: 320, offsetX: -105, offsetY: 0,
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue
                )
            ))
        } else if isHoveringExportAnimated {
            out.append(AnyView(
                TooltipGIFPreview(
                    title: "Exports an original video with Frametime and FPS graphs as overlays.",
                    gifName: "Animated_Overlay",
                    frame: exportAnimatedFrame,
                    height: 220, offsetX: -120, offsetY: 0,
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue
                )
            ))
        }
        if isHoveringGraphColor {
            out.append(AnyView(
                TooltipText(
                    "Choose colour of the graph",
                    frame: graphColorFrame,
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue
                )
            ))
        }
        if isHoveringGraphScaleSlider {
            out.append(AnyView(
                TooltipScalePreview(
                    text: "Controls the size of the Animated Overlay",
                    imageForScale: getScalingImage(for: Int(config.output.overlayScale)),
                    frame: graphScaleSliderFrame,
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue,
                    offsetX: 0, offsetY: 0
                )
            ))
        }
        if isHoveringRenderOneSideOnly {
            out.append(AnyView(
                TooltipOverlaySide(
                    overlayPosition: config.output.overlayPosition.rawValue,
                    frame: renderOneSideOnlyFrame,
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue,
                    offsetX: 0, offsetY: 0
                )
            ))
        }
        if isHoveringTearingDetectionToggle {
            out.append(AnyView(
                TooltipText(
                    "Tearing detection predicts the original framerate in recordings with screen tearing. This feature is EXPERIMENTAL and known to cause false positives or negatives. Use it mainly for testing or entertainment purposes.",
                    frame: tearingDetectionToggleFrame,
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue
                )
            ))
        }
        if isHoveringMultithreadingToggle {
            out.append(AnyView(
                TooltipText(
                    "Multithreading uses multiple CPU cores to improve performance.\nThis significantly speeds up processing but increases RAM usage.",
                    frame: multithreadingToggleFrame,
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue
                )
            ))
        }
        if isHoveringChunkSlider {
            out.append(AnyView(
                TooltipText(
                    "Defines chunk size (in frames) of individually loaded buffers for multithreading. This setting DOES NOT affect RAM consumption, the RAM management scales automatically by default. Greater chunk values are recommended for high-end machines, where they might improve performance, lower values are recommended for low-end machines. The optimal value for M4 Pro CPU is 1500, but you can fine tune it on your machine to achieve better results.",
                    frame: chunkSliderFrame,
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue,
                    maxWidth: 360
                )
            ))
        }
        if isHoveringCodec {
            out.append(AnyView(
                TooltipText(
                    "Defines codec used for animated overlay. ProRes 422 is faster than H264 and provides better image quality at a cost of way larger file size.",
                    frame: codecFrame,
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue,
                    maxWidth: 300
                )
            ))
        }
        if isHoveringMeasureTimeToggle {
            out.append(AnyView(
                TooltipText(
                    "Displays a timer during the analysis. The timer measures how long the analysis takes and stops when it finishes. Useful for performance testing.",
                    frame: measureTimeToggleFrame,
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue
                )
            ))
        }
        if isHoveringCustomThemeToggle {
            out.append(AnyView(
                TooltipText(
                    "Use a pre-made visual theme to customize the app's appearance. Just for fun!",
                    frame: customThemeToggleFrame,
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue,
                    xOffset: -35
                )
            ))
        }
        if isHoveringThemeMiku {
            out.append(AnyView(
                ThemePreview(
                    imageName: "Hatsune_Miku",
                    frame: themeMikuFrame, width: 300, height: 180, defaultYOffset: -100,
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue
                )
            ))
        }
        if isHoveringThemeLuka {
            out.append(AnyView(
                ThemePreview(
                    imageName: "Megurine_Luka",
                    frame: themeLukaFrame, width: 300, height: 200, defaultYOffset: -100,
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue
                )
            ))
        }
        return out
    }

}



    // Helper used in tooltips
    func getScalingImage(for scale: Int) -> NSImage? {
        let value: Int
        switch scale {
        case 50..<55: value = 50
        case 55..<65: value = 60
        case 65..<75: value = 70
        case 75..<85: value = 80
        case 85..<95: value = 90
        case 95..<105: value = 100
        case 105..<115: value = 110
        case 115..<125: value = 120
        case 125..<135: value = 130
        case 135..<145: value = 140
        case 145..<151: value = 150
        default: value = 150
        }
        return NSImage(named: "\(value)")
    }

// MARK: - Subviews (Tabs, Segments, Pickers, Tooltips)

struct TabsPicker: View {
    @Binding var tab: SettingsPopup.Tab
    var customThemeEnabled: Bool
    var themeType: String
    var colorScheme: ColorScheme

    @Namespace private var indicatorNS
    private let items: [SettingsPopup.Tab] = [.output, .performance, .app]

    var body: some View {
        HStack(spacing: 8) {
            ForEach(items, id: \.self) { item in
                let isSelected = (item == tab)

                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) { tab = item }
                } label: {
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(selectionColor)
                                .matchedGeometryEffect(id: "tabIndicator", in: indicatorNS)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: iconName(for: item))
                                .font(.system(size: 12, weight: .semibold))
                            Text(title(for: item))
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .padding(.vertical, 6)
                        .frame(maxWidth: .infinity)
                        .foregroundColor(isSelected ? selectedTextColor : unselectedTextColor)
                        .contentShape(Rectangle())
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .background(trayBackground)   // << much lighter
        .frame(height: 44)
    }

    // MARK: - Background
    private var trayBackground: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)                                        // airy base
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white).opacity(colorScheme == .dark ? 0.04 : 0.16)   // white lift
            if customThemeEnabled {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(themeAccent).opacity(colorScheme == .dark ? 0.05 : 0.02) // gentle tint
            }
        }
    }

    // MARK: - Theming helpers
    private var themeAccent: Color {
        if customThemeEnabled && themeType == "Hatsune Miku" {
            return Color(red: 101/255, green: 137/255, blue: 173/255)
        } else if customThemeEnabled && themeType == "Megurine Luka" {
            return Color(red: 182/255, green: 115/255, blue: 143/255)
        } else {
            return .clear
        }
    }

    private var selectionColor: Color {
        if customThemeEnabled && themeType == "Hatsune Miku" {
            return Color(red: 226/255, green: 244/255, blue: 254/255)
        } else if customThemeEnabled && themeType == "Megurine Luka" {
            return Color(red: 245/255, green: 191/255, blue: 218/255)
        } else {
            return Color.white.opacity(colorScheme == .dark ? 0.20 : 0.92)        // lighter default chip
        }
    }

    private var selectedTextColor: Color {
        if customThemeEnabled && (themeType == "Hatsune Miku" || themeType == "Megurine Luka") {
            return .black
        } else {
            return colorScheme == .dark ? .white : .black
        }
    }


    private var unselectedTextColor: Color {
        colorScheme == .dark ? .white.opacity(0.9) : .black.opacity(0.8)
    }

    private func title(for t: SettingsPopup.Tab) -> String {
        switch t {
        case .output:      return "Output"
        case .performance: return "Performance"
        case .app:         return "App"
        }
    }

    private func iconName(for t: SettingsPopup.Tab) -> String {
        switch t {
        case .output:      return "square.and.arrow.up"
        case .performance: return "bolt.fill"
        case .app:         return "gearshape"
        }
    }
}


struct SegmentedTwoOptions: View {
    var leftTitle: String
    var rightTitle: String
    var selectedLeft: Bool
    var onLeft: () -> Void
    var onRight: () -> Void

    var customThemeEnabled: Bool
    var themeType: String
    var colorScheme: ColorScheme

    var onLeftHover: (Bool) -> Void
    var onRightHover: (Bool) -> Void

    @Binding var leftFrame: CGRect
    @Binding var rightFrame: CGRect

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Text(leftTitle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.selectorBackground(selected: selectedLeft, customThemeEnabled: customThemeEnabled, themeType: themeType, colorScheme: colorScheme))
                    .foregroundColor(Color.selectorText(selected: selectedLeft, customThemeEnabled: customThemeEnabled, themeType: themeType, colorScheme: colorScheme))
                    .cornerRadius(6, corners: [.topLeft, .bottomLeft])
                    .contentShape(Rectangle())
                    .onTapGesture { onLeft() }
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            onLeftHover(hovering)
                        }
                    }
                GeometryReader { geo in
                    Color.clear.onAppear { leftFrame = geo.frame(in: .global) }.onChange(of: geo.frame(in: .global)) { leftFrame = $0 }
                }
            }
            ZStack {
                Text(rightTitle)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.selectorBackground(selected: !selectedLeft, customThemeEnabled: customThemeEnabled, themeType: themeType, colorScheme: colorScheme))
                    .foregroundColor(Color.selectorText(selected: !selectedLeft, customThemeEnabled: customThemeEnabled, themeType: themeType, colorScheme: colorScheme))
                    .cornerRadius(6, corners: [.topRight, .bottomRight])
                    .contentShape(Rectangle())
                    .onTapGesture { onRight() }
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            onRightHover(hovering)
                        }
                    }
                GeometryReader { geo in
                    Color.clear.onAppear { rightFrame = geo.frame(in: .global) }.onChange(of: geo.frame(in: .global)) { rightFrame = $0 }
                }
            }
        }
        .frame(height: 28)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.ultraThinMaterial)                                         // airy base
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white).opacity(colorScheme == .dark ? 0.04 : 0.16)    // white lift
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.gray.opacity(colorScheme == .dark ? 0.25 : 0.18), lineWidth: 1)
        )

    }
}

struct ThemeSelector: View {
    @Binding var selectedTheme: AppSettings.Theme
    var customThemeEnabled: Bool
    var themeType: String
    var colorScheme: ColorScheme

    var onMikuHover: (Bool) -> Void
    var onLukaHover: (Bool) -> Void

    @Binding var mikuFrame: CGRect
    @Binding var lukaFrame: CGRect

    var body: some View {
        HStack(spacing: 0) {
            ZStack {
                Text("Hatsune Miku")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.selectorBackground(selected: selectedTheme == .miku, customThemeEnabled: customThemeEnabled, themeType: themeType, colorScheme: colorScheme))
                    .foregroundColor(Color.selectorText(selected: selectedTheme == .miku, customThemeEnabled: customThemeEnabled, themeType: themeType, colorScheme: colorScheme))
                    .cornerRadius(6, corners: [.topLeft])
                    .contentShape(Rectangle())
                    .onTapGesture { selectedTheme = .miku }
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            onMikuHover(hovering)
                        }
                    }
                GeometryReader { geo in Color.clear.onAppear { mikuFrame = geo.frame(in: .global) }.onChange(of: geo.frame(in: .global)) { mikuFrame = $0 } }
            }
            ZStack {
                Text("Megurine Luka")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.selectorBackground(selected: selectedTheme == .luka, customThemeEnabled: customThemeEnabled, themeType: themeType, colorScheme: colorScheme))
                    .foregroundColor(Color.selectorText(selected: selectedTheme == .luka, customThemeEnabled: customThemeEnabled, themeType: themeType, colorScheme: colorScheme))
                    .contentShape(Rectangle())
                    .onTapGesture { selectedTheme = .luka }
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            onLukaHover(hovering)
                        }
                    }
                GeometryReader { geo in Color.clear.onAppear { lukaFrame = geo.frame(in: .global) }.onChange(of: geo.frame(in: .global)) { lukaFrame = $0 } }
            }
            ZStack {
                Text("Coming Soon")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(Color.selectorBackground(selected: selectedTheme == .soon, customThemeEnabled: customThemeEnabled, themeType: themeType, colorScheme: colorScheme))
                    .foregroundColor(selectedTheme == .soon ? .white : .primary)
                    .cornerRadius(6, corners: [.topRight])
                    .contentShape(Rectangle())
                    .allowsHitTesting(false) // unclickable
                    .opacity(0.6)            // disabled look
            }
        }
        .frame(height: 28)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.ultraThinMaterial)                                         // airy base
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white).opacity(colorScheme == .dark ? 0.04 : 0.16)    // white lift
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.gray.opacity(colorScheme == .dark ? 0.25 : 0.18), lineWidth: 1)
        )

    }
}

struct CodecSelector: View {
    @Binding var selected: PerformanceSettings.OverlayCodec
    var customThemeEnabled: Bool
    var themeType: String
    var colorScheme: ColorScheme

    var body: some View {
        HStack(spacing: 0) {
            segment(title: "H.264 (CPU)", isSelected: selected == .h264) { selected = .h264 }
                .cornerRadius(6, corners: [.topLeft, .bottomLeft])
            segment(title: "ProRes 422 (CPU)", isSelected: selected == .prores422) { selected = .prores422 }
            // GPU Coming Soon (unclickable)
            Text("GPU Coming Soon")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(Color.selectorBackground(selected: false, customThemeEnabled: customThemeEnabled, themeType: themeType, colorScheme: colorScheme))
                .foregroundColor(Color.selectorText(selected: false, customThemeEnabled: customThemeEnabled, themeType: themeType, colorScheme: colorScheme))
                .cornerRadius(6, corners: [.topRight, .bottomRight])
                .contentShape(Rectangle())
                .allowsHitTesting(false)
                .opacity(0.6)
        }
        .frame(height: 28)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(.ultraThinMaterial)                                         // airy base
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(Color.white).opacity(colorScheme == .dark ? 0.04 : 0.16)    // white lift
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(Color.gray.opacity(colorScheme == .dark ? 0.25 : 0.18), lineWidth: 1)
        )

    }

    @ViewBuilder
    func segment(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Text(title)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(Color.selectorBackground(selected: isSelected, customThemeEnabled: customThemeEnabled, themeType: themeType, colorScheme: colorScheme))
            .foregroundColor(Color.selectorText(selected: isSelected, customThemeEnabled: customThemeEnabled, themeType: themeType, colorScheme: colorScheme))
            .contentShape(Rectangle())
            .onTapGesture { action() }
    }
}

// MARK: - Tooltip building blocks

struct TooltipText: View {
    var text: String
    var frame: CGRect
    var customThemeEnabled: Bool
    var themeType: String
    var maxWidth: CGFloat
    var xOffset: CGFloat
    var yOffset: CGFloat

    @State private var measuredSize: CGSize = .zero

    init(_ text: String, frame: CGRect, customThemeEnabled: Bool, themeType: String, maxWidth: CGFloat = 260, xOffset: CGFloat = 8, yOffset: CGFloat = -8) {
        self.text = text
        self.frame = frame
        self.customThemeEnabled = customThemeEnabled
        self.themeType = themeType
        self.maxWidth = maxWidth
        self.xOffset = xOffset
        self.yOffset = yOffset
    }
    init(text: String, frame: CGRect, customThemeEnabled: Bool, themeType: String, maxWidth: CGFloat = 260, xOffset: CGFloat = 8, yOffset: CGFloat = -8) {
        self.init(text, frame: frame, customThemeEnabled: customThemeEnabled, themeType: themeType, maxWidth: maxWidth, xOffset: xOffset, yOffset: yOffset)
    }

    var body: some View {
        let win = tooltipHostWindow()
        let contentScreen = win?.convertToScreen(win?.contentView?.bounds ?? .zero) ?? .zero

        let localX = frame.minX - contentScreen.minX
        let localY = frame.minY - contentScreen.minY

        let desiredLeft = localX + xOffset
        let desiredTop  = localY - measuredSize.height - 36 + yOffset

        let left = max(8, min(desiredLeft, contentScreen.width - measuredSize.width - 8))
        let top  = desiredTop

        return Text(text)
            .font(.caption)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .frame(maxWidth: maxWidth, alignment: .topLeading)
            .background(
                Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType)
                    .overlay(
                        GeometryReader { geo in
                            Color.clear
                                .onAppear { measuredSize = geo.size }
                                .onChange(of: geo.size) { measuredSize = $0 }
                        }
                    )
            )
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.35), lineWidth: 1))
            .shadow(radius: 4)
            .zIndex(10)
            .offset(x: left, y: top)
            .allowsHitTesting(false)
    }
}

struct TooltipImagePreview: View {
    var title: String
    var imageName: String
    var frame: CGRect
    var width: CGFloat
    var height: CGFloat
    var offsetX: CGFloat
    var offsetY: CGFloat = 0
    var customThemeEnabled: Bool
    var themeType: String

    var body: some View {
        let win = tooltipHostWindow()
        let contentScreen = win?.convertToScreen(win?.contentView?.bounds ?? .zero) ?? .zero

        let popupW = width + 20
        let popupH = height + 40

        let localX = frame.minX - contentScreen.minX
        let localY = frame.minY - contentScreen.minY

        let desiredLeft = localX + 180 + offsetX
        let desiredTop  = localY - popupH - 46 + offsetY

        let left = max(8, min(desiredLeft, contentScreen.width - popupW - 8))
        let top  = desiredTop

        return VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption)
            if let path = Bundle.main.path(forResource: imageName, ofType: "png"),
               let nsImage = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImage)
                    .resizable()
                    .interpolation(.high)
                    .scaledToFit()
                    .frame(width: width, height: height)
            }
        }
        .padding(8)
        .frame(width: popupW, height: popupH, alignment: .topLeading)
        .background(Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.35), lineWidth: 1))
        .shadow(radius: 4)
        .zIndex(10)
        .offset(x: left, y: top)
        .allowsHitTesting(false)
    }
}

struct TooltipGIFPreview: View {
    var title: String
    var gifName: String
    var frame: CGRect
    var height: CGFloat
    var offsetX: CGFloat
    var offsetY: CGFloat
    var customThemeEnabled: Bool
    var themeType: String

    var body: some View {
        let win = tooltipHostWindow()
        let contentScreen = win?.convertToScreen(win?.contentView?.bounds ?? .zero) ?? .zero

        let isInteractive = gifName.lowercased().contains("interactive")
        let contentW: CGFloat = isInteractive ? 300 : 360
        let contentH: CGFloat = isInteractive ? 300 : 220

        let popupW = contentW
        let popupH = contentH + 40

        let localX = frame.minX - contentScreen.minX
        let localY = frame.minY - contentScreen.minY

        let desiredLeft = localX + 180 + offsetX
        let desiredTop  = localY - popupH - 46 + offsetY

        let left = max(8, min(desiredLeft, contentScreen.width - popupW - 8))
        let top  = desiredTop

        return VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption)
                .bold()
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)
                .lineLimit(nil)
            GIFImage(gifName: gifName)
                .resizable()
                .id(gifName)
                .frame(width: contentW - 20, height: contentH)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(8)
        .frame(width: popupW, height: popupH, alignment: .topLeading)
        .background(Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.35), lineWidth: 1))
        .shadow(radius: 4)
        .zIndex(10)
        .offset(x: left, y: top)
        .allowsHitTesting(false)
    }
}

struct TooltipScalePreview: View {
    var text: String
    var imageForScale: NSImage?
    var frame: CGRect
    var customThemeEnabled: Bool
    var themeType: String
    var offsetX: CGFloat
    var offsetY: CGFloat

    var body: some View {
        let win = tooltipHostWindow()
        let contentScreen = win?.convertToScreen(win?.contentView?.bounds ?? .zero) ?? .zero

        let contentW: CGFloat = 360
        let contentH: CGFloat = 220

        let popupW = contentW
        let popupH = contentH + 40

        let localX = frame.minX - contentScreen.minX
        let localY = frame.minY - contentScreen.minY

        let desiredLeft = localX + 8 + offsetX
        let desiredTop  = localY - popupH - 46 + offsetY

        let left = max(8, min(desiredLeft, contentScreen.width - popupW - 8))
        let top  = desiredTop

        return VStack(alignment: .leading, spacing: 8) {
            Text(text).font(.caption).bold()
            if let nsImage = imageForScale {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: contentW - 20, height: contentH)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(8)
        .frame(width: popupW, height: popupH, alignment: .topLeading)
        .background(Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.35), lineWidth: 1))
        .shadow(radius: 4)
        .zIndex(10)
        .offset(x: left, y: top)
        .allowsHitTesting(false)
    }
}

struct TooltipOverlaySide: View {
    var overlayPosition: String
    var frame: CGRect
    var customThemeEnabled: Bool
    var themeType: String
    var offsetX: CGFloat
    var offsetY: CGFloat

    var body: some View {
        let win = tooltipHostWindow()
        let contentScreen = win?.convertToScreen(win?.contentView?.bounds ?? .zero) ?? .zero

        let contentW: CGFloat = 360
        let contentH: CGFloat = 220

        let popupW = contentW
        let popupH = contentH + 50

        let localX = frame.minX - contentScreen.minX
        let localY = frame.minY - contentScreen.minY

        let desiredLeft = localX + 8 + offsetX
        let desiredTop  = localY - popupH - 46 + offsetY

        let left = max(8, min(desiredLeft, contentScreen.width - popupW - 8))
        let top  = desiredTop

        return VStack(alignment: .leading, spacing: 8) {
            Text("Renders overlay on one side of the frame. Useful for side-by-side comparisons.")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
            if let url = Bundle.main.url(forResource: overlayPosition, withExtension: "png"),
               let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: contentW - 20, height: contentH)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(8)
        .frame(width: popupW, height: popupH, alignment: .topLeading)
        .background(Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.35), lineWidth: 1))
        .shadow(radius: 4)
        .zIndex(10)
        .offset(x: left, y: top)
        .allowsHitTesting(false)
    }
}

struct ThemePreview: View {
    var imageName: String
    var frame: CGRect
    var width: CGFloat
    var height: CGFloat
    var defaultYOffset: CGFloat
    var customThemeEnabled: Bool
    var themeType: String

    var body: some View {
        let win = tooltipHostWindow()
        let contentScreen = win?.convertToScreen(win?.contentView?.bounds ?? .zero) ?? .zero

        let popupW = width + 20
        let popupH = height + 20

        let localX = frame.minX - contentScreen.minX
        let localY = frame.minY - contentScreen.minY

        let desiredLeft = localX + 8
        let desiredTop  = localY - popupH - 46

        let left = max(8, min(desiredLeft, contentScreen.width - popupW - 8))
        let top  = desiredTop

        return VStack(alignment: .leading, spacing: 8) {
            if let path = Bundle.main.path(forResource: imageName, ofType: imageName == "Megurine_Luka" ? "jpg" : "png"),
               let nsImage = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(8)
        .frame(width: popupW, height: popupH, alignment: .topLeading)
        .background(Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.35), lineWidth: 1))
        .shadow(radius: 4)
        .zIndex(10)
        .offset(x: left, y: top)
        .allowsHitTesting(false)
    }
}

//  ContentView.swift
//  FrameTool
//
//  Created by wheissmd on 17/04/2025.

import AVFoundation
import SwiftUI
import AppKit

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

    enum CsvMode: String, Codable, CaseIterable { case general = "General", detailed = "Detailed" }
    var exportCsvSummary: Bool = false
    var csvSummaryMode: CsvMode = .general

    var exportImage: Bool = false
    var exportInteractive: Bool = false
    var exportAnimated: Bool = false

    var graphColorHex: String = "#33B170FF"

    var overlayScale: CGFloat = 100        // 50…150
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
            Button(action: { showSettings.toggle() }) {
                Image(systemName: "gearshape").imageScale(.large).padding(6).foregroundColor(settingsIconColor)
            }
            .offset(x: -120, y: 12)

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
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .frame(height: 120)
                        .foregroundColor(.blue)
                        .overlay(Text(droppedFilePath ?? "Drop your video file here").foregroundColor(.gray))
                        .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
                            if let provider = providers.first {
                                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                                    DispatchQueue.main.async { self.droppedFilePath = url?.path }
                                }
                                return true
                            }
                            return false
                        }
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
            .onAppear(perform: loadConfig)
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
                    SettingsPopup(config: $config)
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
            }
            .animation(.easeInOut(duration: 0.25), value: showSettings)
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
    
    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 22) {
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

                Text("v0.3.0.1-Alpha")
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
                Toggle("Enable 250 ms Response Rate", isOn: $config.output.enable250ms)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isHoveringResponseRateToggle = hovering
                            if hovering { responseRateToggleFrame = geo.frame(in: .global) }
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
                Toggle("Export CSV Summary", isOn: $config.output.exportCsvSummary)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isHoveringReportCSVToggle = hovering
                            if hovering { reportCSVToggleFrame = geo.frame(in: .global) }
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
                            if hovering { exportImageFrame = geo.frame(in: .global) }
                        }
                    }
            }.frame(height: 20)

            // Export Graph (Interactive)
            GeometryReader { geo in
                Toggle("Export Graph (Interactive)", isOn: $config.output.exportInteractive)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isHoveringExportInteractive = hovering
                            if hovering { isHoveringExportAnimated = false }   // <-- make exclusive
                            if hovering { exportInteractiveFrame = geo.frame(in: .global) }
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
                            if hovering { isHoveringExportInteractive = false } // <-- make exclusive
                            if hovering { exportAnimatedFrame = geo.frame(in: .global) }
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
                                    if hovering { graphColorFrame = geo.frame(in: .global) }
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
                                        if hovering { graphScaleSliderFrame = geo.frame(in: .global) }
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
                                if hovering { renderOneSideOnlyFrame = geo.frame(in: .global) }
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
                                if hovering { tearingDetectionToggleFrame = geo.frame(in: .global) }
                            }
                        }
                }.frame(height: 20)
            }
        }
    }

    // Performance Tab
    private var performanceTab: some View {
        VStack(alignment: .leading, spacing: 22) {
            GeometryReader { geo in
                Toggle("Enable Multithreading", isOn: $config.performance.multithreadingEnabled)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isHoveringMultithreadingToggle = hovering
                            if hovering { multithreadingToggleFrame = geo.frame(in: .global) }
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
                                        if hovering { chunkSliderFrame = geo.frame(in: .global) }
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
                            if hovering { codecFrame = geo.frame(in: .global) }
                        }
                    }
                }.frame(height: 28)
            }
        }
    }

    // App Tab
    private var appTab: some View {
        VStack(alignment: .leading, spacing: 22) {
            GeometryReader { geo in
                Toggle("Measure Processing Time", isOn: $config.app.measureProcessingTime)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isHoveringMeasureTimeToggle = hovering
                            if hovering { measureTimeToggleFrame = geo.frame(in: .global) }
                        }
                    }
            }.frame(height: 20)

            GeometryReader { geo in
                Toggle("Use Custom Theme", isOn: $config.app.useCustomTheme)
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.25)) {
                            isHoveringCustomThemeToggle = hovering
                            if hovering { customThemeToggleFrame = geo.frame(in: .global) }
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
    }

    // Tooltips overlay (type-erased to avoid ViewBuilder arity/complexity limits)
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
                    height: 320, offsetX: -105,
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
                    height: 220, offsetX: -120,
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
                    themeType: config.app.theme.rawValue
                )
            ))
        }
        if isHoveringRenderOneSideOnly {
            out.append(AnyView(
                TooltipOverlaySide(
                    overlayPosition: config.output.overlayPosition.rawValue,
                    frame: renderOneSideOnlyFrame,
                    customThemeEnabled: config.app.useCustomTheme,
                    themeType: config.app.theme.rawValue
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
    var maxWidth: CGFloat = 260
    var xOffset: CGFloat = -8
    var yOffset: CGFloat = -113

    init(_ text: String, frame: CGRect, customThemeEnabled: Bool, themeType: String, maxWidth: CGFloat = 260, xOffset: CGFloat = -8, yOffset: CGFloat = -113) {
        self.text = text; self.frame = frame; self.customThemeEnabled = customThemeEnabled; self.themeType = themeType
        self.maxWidth = maxWidth; self.xOffset = xOffset; self.yOffset = yOffset
    }

    var body: some View {
        Text(text)
            .font(.caption)
            .padding(8)
            .frame(maxWidth: maxWidth, alignment: .leading)
            .background(Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType))
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
            .shadow(radius: 4)
            .transition(.opacity)
            .zIndex(10)
            .offset(x: frame.minX + xOffset, y: frame.minY + yOffset)
    }
}

struct TooltipImagePreview: View {
    var title: String
    var imageName: String
    var frame: CGRect
    var width: CGFloat
    var height: CGFloat
    var offsetX: CGFloat
    var customThemeEnabled: Bool
    var themeType: String

    var body: some View {
        let popupHeight: CGFloat = height + 40
        let windowContentFrame = NSApp.mainWindow?.contentView?.frame ?? .zero
        let popupBottomY = frame.maxY
        let offsetY: CGFloat = (popupBottomY + popupHeight > windowContentFrame.maxY) ? frame.minY - popupHeight - 145 : frame.minY - 93

        return VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption)
            if let imagePath = Bundle.main.path(forResource: imageName, ofType: "png"),
               let nsImage = NSImage(contentsOfFile: imagePath) {
                Image(nsImage: nsImage).resizable().scaledToFit().frame(width: width, height: height)
            }
        }
        .padding(8)
        .frame(maxWidth: width + 20, alignment: .leading)
        .background(Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
        .shadow(radius: 4)
        .transition(.opacity)
        .zIndex(10)
        .offset(x: frame.minX + offsetX, y: offsetY)
    }
}

struct TooltipGIFPreview: View {
    var title: String
    var gifName: String
    var frame: CGRect
    var height: CGFloat
    var offsetX: CGFloat
    var customThemeEnabled: Bool
    var themeType: String

    var body: some View {
        let popupHeight: CGFloat = height + 40
        let windowContentFrame = NSApp.mainWindow?.contentView?.frame ?? .zero
        let popupBottomY = frame.maxY
        let offsetY: CGFloat = (popupBottomY + popupHeight > windowContentFrame.maxY) ? frame.minY - popupHeight - 145 : frame.minY - 93

        return VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.caption)
            GIFImage(gifName: gifName).resizable().id(gifName).frame(height: height).clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .padding(8)
        .frame(maxWidth: 400, alignment: .leading)
        .background(Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
        .shadow(radius: 4)
        .transition(.opacity)
        .zIndex(10)
        .offset(x: frame.minX + offsetX, y: offsetY)
    }
}

struct TooltipScalePreview: View {
    var text: String
    var imageForScale: NSImage?
    var frame: CGRect
    var customThemeEnabled: Bool
    var themeType: String

    var body: some View {
        let height: CGFloat = 220
        let popupHeight: CGFloat = height + 40
        let windowContentFrame = NSApp.mainWindow?.contentView?.frame ?? .zero
        let popupBottomY = frame.maxY
        let offsetY: CGFloat = (popupBottomY + popupHeight > windowContentFrame.maxY) ? frame.minY - popupHeight - 145 : frame.minY - 93

        return VStack(alignment: .leading, spacing: 8) {
            Text(text).font(.caption)
            if let nsImage = imageForScale {
                Image(nsImage: nsImage).resizable().scaledToFit().frame(height: height).clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(8)
        .frame(maxWidth: 400, alignment: .leading)
        .background(Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
        .shadow(radius: 4)
        .transition(.opacity)
        .zIndex(10)
        .offset(x: frame.minX - 65, y: offsetY)
    }
}

struct TooltipOverlaySide: View {
    var overlayPosition: String
    var frame: CGRect
    var customThemeEnabled: Bool
    var themeType: String

    var body: some View {
        let height: CGFloat = 220
        let popupHeight: CGFloat = height + 30
        let windowContentFrame = NSApp.mainWindow?.contentView?.frame ?? .zero
        let popupBottomY = frame.maxY
        let offsetY: CGFloat = (popupBottomY + popupHeight > windowContentFrame.maxY) ? frame.minY - popupHeight - 158 : frame.minY - 113

        return VStack(alignment: .leading, spacing: 8) {
            Text("Renders overlay on only one side of a frame. Useful for locating the videos with overlays side by side.")
                .font(.caption).fixedSize(horizontal: false, vertical: true)
            if let url = Bundle.main.url(forResource: overlayPosition, withExtension: "png"),
               let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage).resizable().scaledToFit().frame(height: height).clipShape(RoundedRectangle(cornerRadius: 6))
            }
        }
        .padding(8)
        .frame(maxWidth: 400, alignment: .leading)
        .background(Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
        .shadow(radius: 4)
        .transition(.opacity)
        .zIndex(10)
        .offset(x: frame.minX - 35, y: offsetY)
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
        let popupHeight: CGFloat = height + 20
        let windowContentFrame = NSApp.mainWindow?.contentView?.frame ?? .zero
        let popupBottomY = frame.maxY
        let offsetY: CGFloat = (popupBottomY + popupHeight > windowContentFrame.maxY) ? frame.minY - popupHeight - 145 : frame.minY + defaultYOffset

        return VStack(alignment: .leading, spacing: 8) {
            if let imagePath = Bundle.main.path(forResource: imageName, ofType: imageName == "Megurine_Luka" ? "jpg" : "png"),
               let nsImage = NSImage(contentsOfFile: imagePath) {
                Image(nsImage: nsImage).resizable().scaledToFit().frame(width: width, height: height).clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(8)
        .frame(maxWidth: width + 20, alignment: .leading)
        .background(Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType))
        .cornerRadius(8)
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
        .shadow(radius: 4)
        .transition(.opacity)
        .zIndex(10)
        .offset(x: frame.minX - 60, y: offsetY)
    }
}

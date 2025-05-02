//  ContentView.swift
//  FrameTool
//
//  Created by wheissmd on 17/04/2025.

import AVFoundation
import SwiftUI
import AppKit

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
            .onAppear {
                isAnimating = true
            }
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





// Custom enum to replace UIRectCorner
enum RectCorner {
    case topLeft
    case topRight
    case bottomLeft
    case bottomRight
}

extension View {
    /// Applies corner radius to specific corners
    func cornerRadius(_ radius: CGFloat, corners: [RectCorner]) -> some View {
        clipShape(RoundedCorner(radius: radius, corners: corners))
    }
}

extension Color {
    static let selectorUnselected = Color(red: 60 / 255, green: 60 / 255, blue: 60 / 255)

    static func selectorBackground(selected: Bool, customThemeEnabled: Bool, themeType: String, colorScheme: ColorScheme) -> Color {
        if customThemeEnabled {
            if themeType == "Hatsune Miku" {
                if selected {
                    return Color(red: 226/255, green: 244/255, blue: 254/255) // Miku Light blue
                } else {
                    return Color(red: 101/255, green: 137/255, blue: 173/255) // Miku Blue-gray
                }
            } else if themeType == "Megurine Luka" {
                if selected {
                    return Color(red: 245/255, green: 191/255, blue: 218/255) // Luka Light pink
                } else {
                    return Color(red: 182/255, green: 115/255, blue: 143/255) // Luka Darker pink
                }
            }
        }

        // Default fallback
        if selected {
            return Color(NSColor.gray)
        } else {
            return colorScheme == .dark ? .selectorUnselected : Color(NSColor.lightGray)
        }
    }

    static func selectorText(selected: Bool, customThemeEnabled: Bool, themeType: String, colorScheme: ColorScheme) -> Color {
        if selected {
            if customThemeEnabled && (themeType == "Hatsune Miku" || themeType == "Megurine Luka") {
                return .black // Black text if Miku OR Luka and selected
            } else {
                return colorScheme == .dark ? .white : .black // System default selected
            }
        } else {
            return colorScheme == .dark ? .white : .black // System default unselected
        }
    }
    
    static func tooltipBackground(customThemeEnabled: Bool, themeType: String) -> Color {
            if customThemeEnabled && themeType == "Hatsune Miku" {
                return Color(red: 110/255, green: 170/255, blue: 200/255)
            } else if customThemeEnabled && themeType == "Megurine Luka" {
                return Color(red: 191/255, green: 116/255, blue: 141/255)
            } else {
                return Color(NSColor.textBackgroundColor) // Default system tooltip color
            }
        }
    }






/// Shape for selectively rounded corners
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

        // Top edge
        path.addLine(to: CGPoint(x: rect.maxX - topRight, y: rect.minY))
        if topRight > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - topRight, y: rect.minY + topRight),
                        radius: topRight,
                        startAngle: .degrees(-90),
                        endAngle: .degrees(0),
                        clockwise: false)
        }

        // Right edge
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - bottomRight))
        if bottomRight > 0 {
            path.addArc(center: CGPoint(x: rect.maxX - bottomRight, y: rect.maxY - bottomRight),
                        radius: bottomRight,
                        startAngle: .degrees(0),
                        endAngle: .degrees(90),
                        clockwise: false)
        }

        // Bottom edge
        path.addLine(to: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY))
        if bottomLeft > 0 {
            path.addArc(center: CGPoint(x: rect.minX + bottomLeft, y: rect.maxY - bottomLeft),
                        radius: bottomLeft,
                        startAngle: .degrees(90),
                        endAngle: .degrees(180),
                        clockwise: false)
        }

        // Left edge
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + topLeft))
        if topLeft > 0 {
            path.addArc(center: CGPoint(x: rect.minX + topLeft, y: rect.minY + topLeft),
                        radius: topLeft,
                        startAngle: .degrees(180),
                        endAngle: .degrees(270),
                        clockwise: false)
        }

        path.closeSubpath()

        return path
    }
}





struct AppConfig: Codable {
    var multithreadingEnabled: Bool
    var measureProcessingTime: Bool
    var reportStatistics: Bool
    var statisticsType: String
    var csvExportPath: String
    var exportGraph: Bool
    var graphType: String
    var tearingDetection: Bool
    var customThemeEnabled: Bool
    var themeType: String
}

struct ContentView: View {
    
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingMusic = false
    @State private var isAnalyzing = false
    @State private var isRunning = false
    @State private var progressStage: String = ""
    @State private var multithreadingEnabled = false
    @State private var measureProcessingTime = false
    @State private var csvExportPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.path
    @State private var droppedFilePath: String? = nil
    @State private var outputText: String = ""

    @State private var reportStatistics = false
    @State private var statisticsType = "General"
    private let statisticsOptions: [String] = ["General", "Detailed"]

    @State private var exportGraph = false
    @State private var graphType = "Image"
    private let graphOptions: [String] = ["Image", "Interactive", "Animated Overlay"]

    @State private var processingDuration = 0
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    @State private var tearingDetection = false
    @State private var showSettings = false
    
    @State private var customThemeEnabled = false
    @State private var themeType = "Hatsune Miku"
    private let themeOptions = ["Hatsune Miku", "Megurine Luka", "Coming Soon"]
    
    var themeArtAttribution: String {
        if customThemeEnabled && themeType == "Hatsune Miku" {
            return #"Art: "Snow Miku 2023" by nibeさん (piapro)"#
        } else if customThemeEnabled && themeType == "Megurine Luka" {
            return #"Art: "Megurine Luka 14th Anniversary" by なっつみかんさん (piapro)"#
        } else {
            return ""
        }
    }
    
    var musicAttribution: String {
        if isPlayingMusic && customThemeEnabled {
            if themeType == "Hatsune Miku" {
                return #"Music: "MICHRONICLE" by 厚寝巻 (piapro)"#
            } else if themeType == "Megurine Luka" {
                return #"Music: "Ghost Rule" by Tsubaki_Kun (piapro)"#
            }
        }
        return ""
    }

    
    var primaryTextColor: Color {
        if customThemeEnabled && (themeType == "Hatsune Miku" || themeType == "Megurine Luka") {
            return .black
        } else {
            return Color.primary
        }
    }

    var settingsIconColor: Color {
        if customThemeEnabled && (themeType == "Hatsune Miku" || themeType == "Megurine Luka") {
            return .black
        } else {
            return Color.primary
        }
    }

    func toggleMusic() {
        if isPlayingMusic {
            audioPlayer?.stop()
            isPlayingMusic = false
        } else {
            var musicFileName: String?

            if customThemeEnabled && themeType == "Hatsune Miku" {
                musicFileName = "Thick_nightgown_Miku-MICHRONICLE"
            } else if customThemeEnabled && themeType == "Megurine Luka" {
                musicFileName = "Tsubaki_Kun-Luka-Ghost_Rule"
            }

            if let fileName = musicFileName, let path = Bundle.main.path(forResource: fileName, ofType: "mp3") {
                let url = URL(fileURLWithPath: path)
                do {
                    audioPlayer = try AVAudioPlayer(contentsOf: url)
                    audioPlayer?.play()
                    isPlayingMusic = true
                } catch {
                    print("Failed to play music: \(error.localizedDescription)")
                }
            } else {
                print("Music file not found")
            }
        }
    }


    
    var body: some View {
        
        ZStack(alignment: .topLeading) {
            Button(action: {
                showSettings.toggle()
            }) {
                Image(systemName: "gearshape")
                    .imageScale(.large)
                    .padding(6)
                    .foregroundColor(settingsIconColor)
            }
            .offset(x: -120, y: 12)
            VStack(spacing: 14) {
                HStack {
                    Spacer()
                }

                VStack(spacing: 0) {
                    Text("FrameTool")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(primaryTextColor)
                    Text("by Hardware Lab / wheissmd")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }

                VStack(alignment: .leading) {
                    Text("Export Path:")
                        .font(.subheadline)
                        .foregroundColor(primaryTextColor)

                    HStack {
                        Text(csvExportPath)
                            .font(.caption)
                            .lineLimit(1)
                            .foregroundColor(customThemeEnabled && (themeType == "Hatsune Miku" || themeType == "Megurine Luka") ? .black : .primary)


                        Spacer()
                        Button(action: {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.allowsMultipleSelection = false
                            if panel.runModal() == .OK, let url = panel.url {
                                csvExportPath = url.path
                            }
                        }) {
                            Text("Choose Folder")
                                .foregroundColor(customThemeEnabled && (themeType == "Hatsune Miku" || themeType == "Megurine Luka") ? .black : .primary)

                        }
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).stroke(Color.gray))
                }
                .padding(.horizontal)

                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                        .frame(height: 120)
                        .foregroundColor(.blue)
                        .overlay(
                            Text(droppedFilePath ?? "Drop your video file here")
                                .foregroundColor(.gray)
                        )
                        .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
                            if let provider = providers.first {
                                _ = provider.loadObject(ofClass: URL.self) { url, _ in
                                    DispatchQueue.main.async {
                                        self.droppedFilePath = url?.path
                                    }
                                }
                                return true
                            }
                            return false
                        }
                }
                .padding(.horizontal)

                Button(action: {
                    runAnalysis()
                }) {
                    Text("Run Analysis")
                        .foregroundColor(customThemeEnabled && (themeType == "Hatsune Miku" || themeType == "Megurine Luka") ? .black : .primary)

                }

                .disabled(isAnalyzing || droppedFilePath == nil)
                .padding(.bottom, 5)

                if !isAnalyzing {
                    ScrollView {
                        Text(outputText)
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(customThemeEnabled && (themeType == "Hatsune Miku" || themeType == "Megurine Luka") ? .black : .primary)

                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }
                    .frame(height: 200)

                }

                Spacer()
            }
            .frame(width: 600, height: 760)
            .disabled(isAnalyzing)
            .padding()
            .onAppear(perform: loadConfig)
            .onReceive(timer) { _ in if isAnalyzing { processingDuration += 1 } }
            .onChange(of: themeType) { newTheme in
                if isPlayingMusic {
                    audioPlayer?.stop()
                    isPlayingMusic = false
                }
            }

            
            if isAnalyzing {
                VStack(spacing: 8) {
                    CustomSpinner(
                        color: customThemeEnabled && (themeType == "Hatsune Miku" || themeType == "Megurine Luka") ? .black : .primary,
                        size: 32
                    )
                    Text("Analyzing...")
                        .foregroundColor(customThemeEnabled && (themeType == "Hatsune Miku" || themeType == "Megurine Luka") ? .black : .primary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }


            if !musicAttribution.isEmpty {
                Text(musicAttribution)
                    .font(.caption)
                    .foregroundColor(customThemeEnabled && (themeType == "Hatsune Miku" || themeType == "Megurine Luka") ? .black : .gray)
                    .padding(.leading, 16)
                    .padding(.bottom, 32)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            }

            
            Text(themeArtAttribution)
                .font(.caption)
                .foregroundColor(customThemeEnabled && (themeType == "Hatsune Miku" || themeType == "Megurine Luka") ? .black : .gray)
                .padding(.leading, 16)
                .padding(.bottom, 16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)

            if measureProcessingTime && (isAnalyzing || processingDuration > 0) {
                Text("Processing Time: \(formatDuration(processingDuration))")
                    .font(.caption)
                    .foregroundColor(customThemeEnabled && (themeType == "Hatsune Miku" || themeType == "Megurine Luka") ? .black : .gray)
                    .padding(.trailing, 16)
                    .padding(.bottom, 16)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            
            if customThemeEnabled && themeType == "Hatsune Miku" {
                Button(action: {
                    toggleMusic()
                }) {
                    Rectangle()
                        .fill(Color.clear) // invisible, but still clickable
                        .frame(width: 250, height: 450)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .position(x: 580, y: 590)
            }
            
            if customThemeEnabled && themeType == "Megurine Luka" {
                Button(action: {
                    toggleMusic()
                }) {
                    Rectangle()
                        .fill(Color.clear) // invisible, but still clickable
                        .frame(width: 250, height: 450)
                        .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
                .position(x: 199, y: 590)
            }




            if showSettings {
                SettingsPopup(
                    multithreadingEnabled: $multithreadingEnabled,
                    measureProcessingTime: $measureProcessingTime,
                    reportStatistics: $reportStatistics,
                    statisticsType: $statisticsType,
                    statisticsOptions: statisticsOptions,
                    exportGraph: $exportGraph,
                    graphType: $graphType,
                    graphOptions: graphOptions,
                    tearingDetection: $tearingDetection,
                    customThemeEnabled: $customThemeEnabled,
                    themeType: $themeType
                )
                .frame(width: 600)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                customThemeEnabled
                                ? (themeType == "Hatsune Miku"
                                    ? Color(red: 104/255, green: 160/255, blue: 204/255) // Miku
                                    : (themeType == "Megurine Luka"
                                        ? Color(red: 191/255, green: 116/255, blue: 141/255) // Luka
                                        : Color(NSColor.windowBackgroundColor))) // Other custom themes
                                : Color(NSColor.windowBackgroundColor)
                            )
                    )

                    .shadow(radius: 10)
                    .padding(.top, 60)
                    .offset(x: 0, y: 33)
            }
            
        }
        .frame(width: 600)
        .background {
            if customThemeEnabled {
                Group {
                    if themeType == "Hatsune Miku" {
                        if let imagePath = Bundle.main.path(forResource: "Hatsune_Miku_Background", ofType: "png"),
                           let nsImage = NSImage(contentsOfFile: imagePath) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFill()
                                .ignoresSafeArea()
                        }
                    } else if themeType == "Megurine Luka" {
                        if let imagePath = Bundle.main.path(forResource: "Megurine_Luka_Background", ofType: "png"),
                           let nsImage = NSImage(contentsOfFile: imagePath) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFill()
                                .ignoresSafeArea()
                        }
                    }
                }
            }
        }



    }

    func runAnalysis() {
        guard !isRunning, let videoPath = droppedFilePath else { return }

        isRunning = true
        isAnalyzing = true
        processingDuration = 0
        outputText = ""

        saveConfig()

        DispatchQueue.global(qos: .userInitiated).async {
            FrameAnalyzer.runAnalysis(
                videoPath: videoPath,
                outputPath: csvExportPath,
                isMultithreading: multithreadingEnabled,
                reportStats: reportStatistics,
                statsMode: statisticsType,
                exportGraph: exportGraph,
                graphType: graphType,
                detectTearing: tearingDetection
            ) { result in
                DispatchQueue.main.async {
                    self.outputText = result
                    self.isAnalyzing = false
                    self.isRunning = false
                }
            }
        }
    }

    func formatDuration(_ seconds: Int) -> String {
        let minutes = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", minutes, secs)
    }

    func saveConfig() {
        let config = AppConfig(
            multithreadingEnabled: multithreadingEnabled,
            measureProcessingTime: measureProcessingTime,
            reportStatistics: reportStatistics,
            statisticsType: statisticsType,
            csvExportPath: csvExportPath,
            exportGraph: exportGraph,
            graphType: graphType,
            tearingDetection: tearingDetection,
            customThemeEnabled: customThemeEnabled,
            themeType: themeType
        )
        if let data = try? JSONEncoder().encode(config) {
            let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("frametool_config.json")
            try? data.write(to: url)
        }
    }

    func loadConfig() {
        let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("frametool_config.json")
        if let data = try? Data(contentsOf: url), let config = try? JSONDecoder().decode(AppConfig.self, from: data) {
            multithreadingEnabled = config.multithreadingEnabled
            measureProcessingTime = config.measureProcessingTime
            reportStatistics = config.reportStatistics
            statisticsType = config.statisticsType
            exportGraph = config.exportGraph
            graphType = config.graphType
            csvExportPath = config.csvExportPath
            tearingDetection = config.tearingDetection
            customThemeEnabled = config.customThemeEnabled
            themeType = config.themeType
        }
        
    }
    
}

struct SettingsPopup: View {
    
    @State private var hoverLocation: CGPoint = .zero
    
    @Binding var multithreadingEnabled: Bool
    @State private var isHoveringMultithreadingToggle = false
    @State private var multithreadingToggleFrame: CGRect = .zero

    @Binding var measureProcessingTime: Bool
    @State private var isHoveringMeasureTimeToggle = false
    @State private var measureTimeToggleFrame: CGRect = .zero
    
    @Binding var reportStatistics: Bool
    @State private var isHoveringReportCSVToggle = false
    @State private var reportCSVToggleFrame: CGRect = .zero
    
    @Binding var statisticsType: String
    let statisticsOptions: [String]
    @State private var isHoveringStatisticsGeneral = false
    @State private var isHoveringStatisticsDetailed = false
    @State private var statisticsGeneralFrame: CGRect = .zero
    @State private var statisticsDetailedFrame: CGRect = .zero

    
    @Binding var exportGraph: Bool
    @State private var isHoveringExportGraphToggle = false
    @State private var exportGraphToggleFrame: CGRect = .zero
    
    @Binding var graphType: String
    let graphOptions: [String]
    @State private var isHoveringGraphImage = false
    @State private var isHoveringGraphInteractive = false
    @State private var isHoveringGraphAnimated = false
    @State private var graphImageFrame: CGRect = .zero
    @State private var graphInteractiveFrame: CGRect = .zero
    @State private var graphAnimatedFrame: CGRect = .zero
    
    @Binding var tearingDetection: Bool
    @State private var isHoveringTearingDetectionToggle = false
    @State private var tearingDetectionToggleFrame: CGRect = .zero
    @State private var isOptionKeyPressed = false
    @Environment(\.colorScheme) var colorScheme
    
    @Binding var customThemeEnabled: Bool
    @Binding var themeType: String
    @State private var isHoveringCustomThemeToggle = false
    @State private var customThemeToggleFrame = CGRect.zero
    @State private var isHoveringThemeMiku = false
    @State private var isHoveringThemeLuka = false
    @State private var themeMikuFrame: CGRect = .zero
    @State private var themeLukaFrame: CGRect = .zero

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 22) {
                GeometryReader { geo in
                    Toggle("Enable Multithreading", isOn: $multithreadingEnabled)
                        .onHover { hovering in
                            isHoveringMultithreadingToggle = hovering
                            if hovering {
                                multithreadingToggleFrame = geo.frame(in: .global)
                            }
                        }
                }
                .frame(height: 20)

                
                if multithreadingEnabled {
                    Text("⚠️ WARNING: Multithreading requires at least 16GB of RAM, otherwise it slows down the processing.")
                        .font(.caption)
                        .foregroundColor(
                            customThemeEnabled && themeType == "Hatsune Miku"
                            ? Color(red: 1.0, green: 0.9, blue: 0.4) // Yellow, more readable
                            : .orange
                        )

                }
                
                if tearingDetection || isOptionKeyPressed {
                    GeometryReader { geo in
                        Toggle("Tearing Detection (Experimental)", isOn: $tearingDetection)
                            .onHover { hovering in
                                isHoveringTearingDetectionToggle = hovering
                                if hovering {
                                    tearingDetectionToggleFrame = geo.frame(in: .global)
                                }
                            }
                    }
                    .frame(height: 20)
                }
                
                GeometryReader { geo in
                    Toggle("Measure Processing Time", isOn: $measureProcessingTime)
                        .onHover { hovering in
                            isHoveringMeasureTimeToggle = hovering
                            if hovering {
                                measureTimeToggleFrame = geo.frame(in: .global)
                            }
                        }
                }
                .frame(height: 20)
                
                GeometryReader { geo in
                    Toggle("Report Statistics to CSV", isOn: $reportStatistics)
                        .onHover { hovering in
                            isHoveringReportCSVToggle = hovering
                            if hovering {
                                reportCSVToggleFrame = geo.frame(in: .global)
                            }
                        }
                }
                .frame(height: 20)

                
                if reportStatistics {

                    HStack(spacing: 0) {
                        ZStack {
                            Text("General")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    Color.selectorBackground(
                                        selected: statisticsType == "General",
                                        customThemeEnabled: customThemeEnabled,
                                        themeType: themeType,
                                        colorScheme: colorScheme
                                    )
                                )
                                .foregroundColor(
                                    Color.selectorText(
                                        selected: statisticsType == "General",
                                        customThemeEnabled: customThemeEnabled,
                                        themeType: themeType,
                                        colorScheme: colorScheme
                                    )
                                )
                                .cornerRadius(6, corners: [.topLeft, .bottomLeft])
                                .contentShape(Rectangle())
                                .onTapGesture { statisticsType = "General" }
                                .onHover { hovering in
                                    isHoveringStatisticsGeneral = hovering
                                }

                            GeometryReader { geo in
                                Color.clear
                                    .onAppear {
                                        statisticsGeneralFrame = geo.frame(in: .global)
                                    }
                                    .onChange(of: geo.frame(in: .global)) { newFrame in
                                        statisticsGeneralFrame = newFrame
                                    }
                            }
                        }

                        ZStack {
                            Text("Detailed")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    Color.selectorBackground(
                                        selected: statisticsType == "Detailed",
                                        customThemeEnabled: customThemeEnabled,
                                        themeType: themeType,
                                        colorScheme: colorScheme
                                    )
                                )

                                .foregroundColor(
                                    Color.selectorText(
                                        selected: statisticsType == "Detailed",
                                        customThemeEnabled: customThemeEnabled,
                                        themeType: themeType,
                                        colorScheme: colorScheme
                                    )
                                )
                                .cornerRadius(6, corners: [.topRight, .bottomRight])
                                .contentShape(Rectangle())
                                .onTapGesture { statisticsType = "Detailed" }
                                .onHover { hovering in
                                    isHoveringStatisticsDetailed = hovering
                                }

                            GeometryReader { geo in
                                Color.clear
                                    .onAppear {
                                        statisticsDetailedFrame = geo.frame(in: .global)
                                    }
                                    .onChange(of: geo.frame(in: .global)) { newFrame in
                                        statisticsDetailedFrame = newFrame
                                    }
                            }
                        }
                    }
                    .frame(height: 28)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))

                }
                
                ZStack {
                    
                    GeometryReader { geo in
                        Toggle("Export Graph", isOn: $exportGraph)
                            .onHover { hovering in
                                isHoveringExportGraphToggle = hovering
                                if hovering {
                                    exportGraphToggleFrame = geo.frame(in: .global)
                                }
                            }
                    }
                    .frame(height: 20)

                }

                if exportGraph {
                    HStack(spacing: 0) {
                        ZStack {
                            Text("Image")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    Color.selectorBackground(
                                        selected: graphType == "Image",
                                        customThemeEnabled: customThemeEnabled,
                                        themeType: themeType,
                                        colorScheme: colorScheme
                                    )
                                )

                                .foregroundColor(
                                    Color.selectorText(
                                        selected: graphType == "Image",
                                        customThemeEnabled: customThemeEnabled,
                                        themeType: themeType,
                                        colorScheme: colorScheme
                                    )
                                )
                                .cornerRadius(6, corners: [.topLeft])
                                .contentShape(Rectangle())
                                .onTapGesture { graphType = "Image" }
                                .onHover { hovering in isHoveringGraphImage = hovering }
                            
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear { graphImageFrame = geo.frame(in: .global) }
                                    .onChange(of: geo.frame(in: .global)) { graphImageFrame = $0 }
                            }
                        }

                        ZStack {
                            Text("Interactive")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    Color.selectorBackground(
                                        selected: graphType == "Interactive",
                                        customThemeEnabled: customThemeEnabled,
                                        themeType: themeType,
                                        colorScheme: colorScheme
                                    )
                                )

                                .foregroundColor(
                                    Color.selectorText(
                                        selected: graphType == "Interactive",
                                        customThemeEnabled: customThemeEnabled,
                                        themeType: themeType,
                                        colorScheme: colorScheme
                                    )
                                )
                                .contentShape(Rectangle())
                                .onTapGesture { graphType = "Interactive" }
                                .onHover { hovering in isHoveringGraphInteractive = hovering }
                            
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear { graphInteractiveFrame = geo.frame(in: .global) }
                                    .onChange(of: geo.frame(in: .global)) { graphInteractiveFrame = $0 }
                            }
                        }

                        ZStack {
                            Text("Animated Overlay")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    Color.selectorBackground(
                                        selected: graphType == "Animated Overlay",
                                        customThemeEnabled: customThemeEnabled,
                                        themeType: themeType,
                                        colorScheme: colorScheme
                                    )
                                )

                                .foregroundColor(
                                    Color.selectorText(
                                        selected: graphType == "Animated Overlay",
                                        customThemeEnabled: customThemeEnabled,
                                        themeType: themeType,
                                        colorScheme: colorScheme
                                    )
                                )
                                .cornerRadius(6, corners: [.topRight])
                                .contentShape(Rectangle())
                                .onTapGesture { graphType = "Animated Overlay" }
                                .onHover { hovering in isHoveringGraphAnimated = hovering }
                            
                            GeometryReader { geo in
                                Color.clear
                                    .onAppear { graphAnimatedFrame = geo.frame(in: .global) }
                                    .onChange(of: geo.frame(in: .global)) { graphAnimatedFrame = $0 }
                            }
                        }
                        
                    }
                    .frame(height: 28)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))

                }
                
                ZStack {
                    GeometryReader { geo in
                        Toggle("Use Custom Theme", isOn: $customThemeEnabled)
                            .onHover { hovering in
                                isHoveringCustomThemeToggle = hovering
                                if hovering {
                                    customThemeToggleFrame = geo.frame(in: .global)
                                }
                            }
                    }
                    .frame(height: 20)
                }
                
                if customThemeEnabled {
                    HStack(spacing: 0) {
                        ZStack {
                            Text("Hatsune Miku")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    Color.selectorBackground(
                                        selected: themeType == "Hatsune Miku",
                                        customThemeEnabled: customThemeEnabled,
                                        themeType: themeType,
                                        colorScheme: colorScheme
                                    )
                                )
                                .foregroundColor(
                                    Color.selectorText(
                                        selected: themeType == "Hatsune Miku",
                                        customThemeEnabled: customThemeEnabled,
                                        themeType: themeType,
                                        colorScheme: colorScheme
                                    )
                                )
                                .cornerRadius(6, corners: [.topLeft])
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    themeType = "Hatsune Miku"
                                }
                                .onHover { hovering in
                                    isHoveringThemeMiku = hovering
                                }

                            GeometryReader { geo in
                                Color.clear
                                    .onAppear {
                                        themeMikuFrame = geo.frame(in: .global)
                                    }
                                    .onChange(of: geo.frame(in: .global)) { newFrame in
                                        themeMikuFrame = newFrame
                                    }
                            }
                        }

                        ZStack {
                            Text("Megurine Luka")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    Color.selectorBackground(
                                        selected: themeType == "Megurine Luka",
                                        customThemeEnabled: customThemeEnabled,
                                        themeType: themeType,
                                        colorScheme: colorScheme
                                    )
                                )
                                .foregroundColor(
                                    Color.selectorText(
                                        selected: themeType == "Megurine Luka",
                                        customThemeEnabled: customThemeEnabled,
                                        themeType: themeType,
                                        colorScheme: colorScheme
                                    )
                                )
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    themeType = "Megurine Luka"
                                }
                                .onHover { hovering in
                                    isHoveringThemeLuka = hovering
                                }

                            GeometryReader { geo in
                                Color.clear
                                    .onAppear {
                                        themeLukaFrame = geo.frame(in: .global)
                                    }
                                    .onChange(of: geo.frame(in: .global)) { newFrame in
                                        themeLukaFrame = newFrame
                                    }
                            }
                        }


                        ZStack {
                            Text("Coming Soon")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 6)
                                .background(
                                    Color.selectorBackground(
                                        selected: themeType == "Coming Soon",
                                        customThemeEnabled: customThemeEnabled,
                                        themeType: themeType,
                                        colorScheme: colorScheme
                                    )
                                )
                                .foregroundColor(themeType == "Coming Soon" ? .white : .primary)
                                .cornerRadius(6, corners: [.topRight])
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    themeType = "Coming Soon"
                                }
                        }
                    }
                    .frame(height: 28)
                    .background(Color(NSColor.controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.3)))
                }


                
            }
            .padding()
            .overlay(alignment: .topLeading) {
                if isHoveringMultithreadingToggle {
                    Text("Multithreading uses multiple CPU cores to improve performance.\nThis significantly speeds up processing but increases RAM usage.")
                        .font(.caption)
                        .padding(8)
                        .frame(maxWidth: 260, alignment: .leading)
                        .background(
                            Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType)
                        )
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
                        .shadow(radius: 4)
                        .transition(.opacity)
                        .zIndex(10)
                        .offset(x: multithreadingToggleFrame.minX - 8, y: multithreadingToggleFrame.minY - 113)
                }
                if isHoveringTearingDetectionToggle {
                    Text("Tearing detection predicts the original framerate in recordings with screen tearing. This feature is EXPERIMENTAL and known to cause false positives or negatives. Use it mainly for testing or entertainment purposes.")
                        .font(.caption)
                        .padding(8)
                        .frame(maxWidth: 260, alignment: .leading)
                        .background(
                            Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType)
                        )
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
                        .shadow(radius: 4)
                        .transition(.opacity)
                        .zIndex(10)
                        .offset(x: tearingDetectionToggleFrame.minX - 8, y: tearingDetectionToggleFrame.minY - 113)
                }
                if isHoveringMeasureTimeToggle {
                    Text("Displays a timer during the analysis. The timer measures how long the analysis takes and stops when it finishes. Useful for performance testing.")
                        .font(.caption)
                        .padding(8)
                        .frame(maxWidth: 260, alignment: .leading)
                        .background(
                            Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType)
                        )
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
                        .shadow(radius: 4)
                        .transition(.opacity)
                        .zIndex(10)
                        .offset(x: measureTimeToggleFrame.minX - 8, y: measureTimeToggleFrame.minY - 113)
                }
                if isHoveringReportCSVToggle {
                    Text("Exports a CSV file with test summary data (i. e. min FPS, avg FPS, max FPS).")
                        .font(.caption)
                        .padding(8)
                        .frame(maxWidth: 260, alignment: .leading)
                        .background(
                            Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType)
                        )
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
                        .shadow(radius: 4)
                        .transition(.opacity)
                        .zIndex(10)
                        .offset(x: reportCSVToggleFrame.minX - 8, y: reportCSVToggleFrame.minY - 113)
                }
                if isHoveringStatisticsGeneral {
                    Text("Reports min FPS, avg FPS, and max FPS.")
                        .font(.caption)
                        .padding(8)
                        .frame(maxWidth: 260, alignment: .leading)
                        .background(
                            Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType)
                        )
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
                        .shadow(radius: 4)
                        .transition(.opacity)
                        .zIndex(10)
                        .offset(x: statisticsGeneralFrame.minX, y: statisticsGeneralFrame.minY - 108)
                }
                if isHoveringStatisticsDetailed {
                    Text("Reports min FPS, avg FPS, max FPS, longest frame duration, % of frames matching it, 1% slowest frames, and their corresponding FPS.")
                        .font(.caption)
                        .padding(8)
                        .frame(maxWidth: 260, alignment: .leading)
                        .background(
                            Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType)
                        )
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
                        .shadow(radius: 4)
                        .transition(.opacity)
                        .zIndex(10)
                        .offset(x: statisticsDetailedFrame.minX, y: statisticsDetailedFrame.minY - 108)
                }
                if isHoveringExportGraphToggle {
                    Text("Export graph of the frame times and FPS throughout the analyzed video.")
                        .font(.caption)
                        .padding(8)
                        .frame(maxWidth: 260, alignment: .leading)
                        .background(
                            Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType)
                        )
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
                        .shadow(radius: 4)
                        .transition(.opacity)
                        .zIndex(10)
                        .offset(x: exportGraphToggleFrame.minX - 80, y: exportGraphToggleFrame.minY - 113)
                }
                if isHoveringGraphImage {
                    VStack(alignment: .leading, spacing: 8) {
                            Text("Exports a high resolution image with FPS and Frametime graphs.")
                                .font(.caption)
                        if let imagePath = Bundle.main.path(forResource: "Image", ofType: "png"),
                           let nsImage = NSImage(contentsOfFile: imagePath) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 380, height: 320)
                        }

                        }
                        .padding(8)
                        .frame(maxWidth: 400, alignment: .leading)
                        .background(
                            Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType)
                        )
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
                        .shadow(radius: 4)
                        .transition(.opacity)
                        .zIndex(10)
                        .offset(x: graphImageFrame.minX - 120, y: graphImageFrame.minY - 93)
                    
                    
                }
                if isHoveringGraphInteractive {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Exports an interactive HTML graph of FPS and Frametime.")
                            .font(.caption)

                        GIFImage(gifName: "Interactive")
                            .resizable()
                            .frame(height: 320)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(8)
                    .frame(maxWidth: 400, alignment: .leading)
                    .background(
                        Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType)
                    )
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
                    .shadow(radius: 4)
                    .transition(.opacity)
                    .zIndex(10)
                    .offset(x: graphInteractiveFrame.minX - 45, y: graphInteractiveFrame.minY - 93)
                }


                if isHoveringGraphAnimated {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Exports an original video with Frametime and FPS graphs as overlays.")
                            .font(.caption)

                        GIFImage(gifName: "Animated_Overlay")
                            .resizable()
                            .frame(height: 220)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(8)
                    .frame(maxWidth: 400, alignment: .leading)
                    .background(
                        Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType)
                    )
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
                    .shadow(radius: 4)
                    .transition(.opacity)
                    .zIndex(10)
                    .offset(x: graphInteractiveFrame.minX - 120, y: graphInteractiveFrame.minY - 93)
                }
                if isHoveringCustomThemeToggle {
                    Text("Use a pre-made visual theme to customize the app's appearance. Just for fun!")
                        .font(.caption)
                        .padding(8)
                        .frame(maxWidth: 260, alignment: .leading)
                        .background(
                            Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType)
                        )
                        .cornerRadius(8)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
                        .shadow(radius: 4)
                        .transition(.opacity)
                        .zIndex(10)
                        .offset(x: customThemeToggleFrame.minX - 35, y: customThemeToggleFrame.minY - 113)
                }
                if isHoveringThemeMiku {
                    VStack(alignment: .leading, spacing: 8) {
                        if let imagePath = Bundle.main.path(forResource: "Hatsune_Miku", ofType: "png"),
                           let nsImage = NSImage(contentsOfFile: imagePath) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 300, height: 180)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: 320, alignment: .leading)
                    .background(
                        Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType)
                    )
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
                    .shadow(radius: 4)
                    .transition(.opacity)
                    .zIndex(10)
                    .offset(x: themeMikuFrame.minX - 60, y: themeMikuFrame.minY - 100)
                }
                if isHoveringThemeLuka {
                    VStack(alignment: .leading, spacing: 8) {
                        if let imagePath = Bundle.main.path(forResource: "Megurine_Luka", ofType: "jpg"),
                           let nsImage = NSImage(contentsOfFile: imagePath) {
                            Image(nsImage: nsImage)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 300, height: 200)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: 320, alignment: .leading)
                    .background(
                        Color.tooltipBackground(customThemeEnabled: customThemeEnabled, themeType: themeType)
                    )
                    .cornerRadius(8)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
                    .shadow(radius: 4)
                    .transition(.opacity)
                    .zIndex(10)
                    .offset(x: themeLukaFrame.minX - 60, y: themeLukaFrame.minY - 100)
                }


                




                
            }
            

            .onAppear {
                NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { event in
                    isOptionKeyPressed = event.modifierFlags.contains(.option)
                    return event
                }
            }

        }
    }
}

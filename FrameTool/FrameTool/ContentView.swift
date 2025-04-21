//  ContentView.swift
//  FrameTool
//
//  Created by wheissmd on 17/04/2025.


import SwiftUI

struct AppConfig: Codable {
    var multithreadingEnabled: Bool
    var measureProcessingTime: Bool
    var reportStatistics: Bool
    var statisticsType: String
    var csvExportPath: String
    var exportGraph: Bool
    var graphType: String
}

struct ContentView: View {
    @State private var isAnalyzing = false
    @State private var isRunning = false
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

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 14) {
                VStack(spacing: 0) {
                    Text("FrameTool")
                        .font(.title)
                        .padding(.top, 16)

                    Text("by Hardware Lab / wheissmd")
                        .font(.caption2)
                        .foregroundColor(.gray)
                }


                Toggle("Enable Multithreading", isOn: $multithreadingEnabled)
                    .padding(.horizontal, 40)

                if multithreadingEnabled {
                    Text("⚠️ WARNING: Multithreading requires at least 16GB of RAM, otherwise it slows down the processing.")
                        .foregroundColor(.orange)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Toggle("Measure Processing Time", isOn: $measureProcessingTime)
                    .padding(.horizontal, 40)

                Toggle("Report Statistics to CSV", isOn: $reportStatistics)
                    .padding(.horizontal, 40)

                if reportStatistics {
                    Picker("Statistics Type", selection: $statisticsType) {
                        ForEach(statisticsOptions, id: \.self) { option in
                            Text(option)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 40)
                }

                Toggle("Export Graph", isOn: $exportGraph)
                    .padding(.horizontal, 40)

                if exportGraph {
                    Picker("Graph Type", selection: $graphType) {
                        ForEach(graphOptions, id: \.self) { type in
                            Text(type)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal, 40)
                }

                VStack(alignment: .leading) {
                    Text("Export Path:")
                        .font(.subheadline)

                    HStack {
                        Text(csvExportPath)
                            .font(.caption)
                            .lineLimit(1)
                        Spacer()
                        Button("Choose Folder") {
                            let panel = NSOpenPanel()
                            panel.canChooseDirectories = true
                            panel.canChooseFiles = false
                            panel.allowsMultipleSelection = false

                            if panel.runModal() == .OK, let url = panel.url {
                                csvExportPath = url.path
                            }
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

                Button("Run Analysis") {
                    runAnalysis()
                }
                .disabled(isAnalyzing || droppedFilePath == nil)
                .padding(.bottom, 5)

                if isAnalyzing {
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Analyzing...")
                            .foregroundColor(.gray)
                    }
                    .padding()
                } else {
                    ScrollView {
                        Text(outputText)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal)
                    }
                    .frame(height: 200)
                }

                Spacer()
            }
            .frame(width: 600, height: 760)
            .padding()
            .onAppear {
                loadConfig()
            }
            .onReceive(timer) { _ in
                if isAnalyzing {
                    processingDuration += 1
                }
            }

            if measureProcessingTime && (isAnalyzing || processingDuration > 0) {
                Text("Processing Time: \(formatDuration(processingDuration))")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .padding(.trailing, 12)
                    .padding(.bottom, 10)
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
                graphType: graphType
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
            graphType: graphType
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
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

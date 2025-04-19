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

    @State private var showFullDiskAccessAlert = false
    @State private var showGraphPermissionsPopup = false
    @State private var showInteractiveWarning = false

    @State private var permissionCheckResults = [
        "Numbers Installed": false,
        "Numbers Full Disk Access": false,
        "Terminal Full Disk Access": false,
        "AppleScript Automation Enabled": false
    ]
    
    @State private var showPermissionsPopup = false
    @State private var canProceedWithInteractive = false

    private func checkAllPermissions() {
        let appleScriptPerm = checkAppleScriptPermission()
        let numbersInstalled = checkIfNumbersInstalled()
        let terminalAccess = checkFullDiskAccess(bundleId: "com.apple.Terminal")
        let numbersAccess = checkFullDiskAccess(bundleId: "com.apple.iWork.Numbers")

        canProceedWithInteractive = appleScriptPerm && numbersInstalled && terminalAccess && numbersAccess
    }


    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 16) {
                Text("FrameTool")
                    .font(.title)
                    .padding(.top)

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
                    .onChange(of: graphType) { newValue in
                        print("GraphType changed to: \(newValue)")
                        if newValue == "Interactive" {
                            updateGraphPermissions()

                            // Delay to wait for async permission check to complete
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                let granted = permissionCheckResults.values.allSatisfy { $0 }
                                if !granted {
                                    graphType = "Image"
                                    showInteractiveWarning = true
                                }
                            }
                        }
                    }



                }

                VStack(alignment: .leading) {
                    Text("CSV Export Path:")
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
            .alert(isPresented: $showFullDiskAccessAlert) {
                Alert(
                    title: Text("Full Disk Access Required"),
                    message: Text("To export the graph, please enable Full Disk Access for Terminal, Xcode, and Numbers in System Settings → Privacy & Security."),
                    primaryButton: .default(Text("Open Settings"), action: {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                            NSWorkspace.shared.open(url)
                        }
                    }),
                    secondaryButton: .cancel()
                )
            }
            .sheet(isPresented: $showInteractiveWarning) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("⚠️ Interactive Export Requirements")
                        .font(.title2).bold()

                    ForEach(permissionCheckResults.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack {
                            Image(systemName: value ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(value ? .green : .red)
                            Text(key)
                        }
                    }

                    Divider()

                    Button("Open Privacy & Security Settings") {
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                    .buttonStyle(.bordered)

                    Button("Close") {
                        showInteractiveWarning = false
                    }
                }
                .padding()
                .frame(width: 400)
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

    func allPermissionsGranted() -> Bool {
        return permissionCheckResults.values.allSatisfy { $0 }
    }

    func updateGraphPermissions() {
        permissionCheckResults["Numbers Installed"] = FileManager.default.fileExists(atPath: "/Applications/Numbers.app") || FileManager.default.fileExists(atPath: "/System/Applications/Numbers.app")

        permissionCheckResults["AppleScript Automation Enabled"] = {
            let script = """
            tell application \"System Events\"
                get name of application processes
            end tell
            """
            let task = Process()
            task.launchPath = "/usr/bin/osascript"
            task.arguments = ["-e", script]

            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            task.launch()
            task.waitUntilExit()

            let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            return !output.contains("Not authorized") && task.terminationStatus == 0
        }()

        permissionCheckResults["Terminal Full Disk Access"] = testDiskAccess(forApp: "Terminal")
        permissionCheckResults["Numbers Full Disk Access"] = testDiskAccess(forApp: "Numbers")

        print("Permission Check Results:")
        for (key, value) in permissionCheckResults {
            print("- \(key): \(value)")
        }
    }

    func testDiskAccess(forApp appName: String) -> Bool {
        let testDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/FrameTool")
        let testFile = testDir.appendingPathComponent("fd_access_test.txt")

        do {
            try FileManager.default.createDirectory(at: testDir, withIntermediateDirectories: true, attributes: nil)
            try "test".write(to: testFile, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: testFile)
            return true
        } catch {
            print("❌ [\(appName)] Full Disk Access test failed: \(error.localizedDescription)")
            return false
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
            let result = FrameAnalyzer.runAnalysis(
                videoPath: videoPath,
                outputPath: csvExportPath,
                isMultithreading: multithreadingEnabled,
                reportStats: reportStatistics,
                statsMode: statisticsType,
                exportGraph: exportGraph,
                graphType: graphType
            )

            DispatchQueue.main.async {
                self.outputText = result
                self.isAnalyzing = false
                self.isRunning = false
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
    
    func checkIfNumbersInstalled() -> Bool {
        let fm = FileManager.default
        return fm.fileExists(atPath: "/Applications/Numbers.app")
    }

    func checkFullDiskAccess(bundleId: String) -> Bool {
        let url = URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        let testPath = url.path
        return FileManager.default.isReadableFile(atPath: testPath)
    }

    func checkAppleScriptPermission() -> Bool {
        let appleScript = """
        tell application "System Events"
            return true
        end tell
        """
        var error: NSDictionary?
        if let scriptObject = NSAppleScript(source: appleScript) {
            scriptObject.executeAndReturnError(&error)
            return error == nil
        }
        return false
    }

}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

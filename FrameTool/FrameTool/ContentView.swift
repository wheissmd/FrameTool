//
//  ContentView.swift
//  FrameTool
//
//  Created by wheissmd on 17/04/2025.
//

import SwiftUI

struct ContentView: View {
    @State private var isAnalyzing = false
    @State private var isRunning = false
    @State private var multithreadingEnabled = false
    @State private var csvExportPath = "/Users/denisvays/Documents"
    @State private var droppedFilePath: String? = nil
    @State private var outputText: String = ""

    var body: some View {
        VStack(spacing: 16) {
            Text("FrameTool")
                .font(.title)
                .padding(.top)

            Toggle("Enable Multithreading", isOn: $multithreadingEnabled)
                .padding(.horizontal, 40)

            if multithreadingEnabled {
                Text("⚠️ WARNING: Multithreading requires at least 16GB of RAM, otherwise it slows down the processing and might result in an error.")
                    .foregroundColor(.orange)
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(alignment: .leading) {
                Text("CSV Export Path:")
                    .font(.subheadline)
                TextField("/Users/denisvays/Documents", text: $csvExportPath)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
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
        .frame(width: 600, height: 600)
        .padding()
    }

    func runAnalysis() {
        guard !isRunning, let videoPath = droppedFilePath else { return }
        
        isRunning = true
        isAnalyzing = true
        outputText = ""

        DispatchQueue.global(qos: .userInitiated).async {
            print("DEBUG: called runAnalysis")
            let result = FrameAnalyzer.runAnalysis(
                videoPath: videoPath,
                outputPath: csvExportPath,
                isMultithreading: multithreadingEnabled
            )

            DispatchQueue.main.async {
                self.outputText = result
                self.isAnalyzing = false
                self.isRunning = false
            }
        }
    }
}


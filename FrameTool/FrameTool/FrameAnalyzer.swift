//  FrameAnalyzer.swift
//  FrameTool
//
//  Created by wheissmd on 17/04/2025.

import AVFoundation
import CoreImage
import Accelerate

public struct FrameAnalyzer {
    /// Main method to analyze frame timings in a video.
        /// - Parameters:
        ///   - videoPath: path to the input video file
        ///   - outputPath: folder to write the CSV output
        ///   - isMultithreading: whether to analyze using multiple CPU threads
    public static func runAnalysis(videoPath: String, outputPath: String, isMultithreading: Bool, reportStats: Bool, statsMode: String, exportGraph: Bool = false, graphType: String = "") -> String {


            var outputLog = ""
            func log(_ msg: String) {
                outputLog += msg + "\n"
                print(msg)  // Also output to Xcode console
            }

            let finalOutputPath: String = outputPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.path : outputPath
        
            // Load video file from given path
            let videoURL = URL(fileURLWithPath: videoPath)
            let asset = AVAsset(url: videoURL)

            // Attempt to find a video track in the asset
            guard let track = asset.tracks(withMediaType: .video).first else {
                log("⚠️ ERROR: No video track found")
                return outputLog
            }

            // Create AVAssetReader to read raw video frames
            let reader: AVAssetReader
            do {
                reader = try AVAssetReader(asset: asset)
            } catch {
                log("⚠️ ERROR: Could not create AVAssetReader")
                return outputLog
            }

            // Configure output: raw 32-bit BGRA pixel buffers
            let readerOutput = AVAssetReaderTrackOutput(track: track, outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ])
            reader.add(readerOutput)
            reader.startReading()

            // List to store (frameIndex, timestamp, isChangeDetected, timeSinceLastChange)
            var frameTimes: [(Int, Double, Bool, Double)] = []

            if isMultithreading {
                log("📦 Loading frames into memory...")
                var frames: [vImage_Buffer] = []     // Holds grayscale frame data
                var timestamps: [Double] = []        // Timestamps for each frame

                // Read and convert all frames
                while let sampleBuffer = readerOutput.copyNextSampleBuffer(),
                      let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {

                    CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
                    let width = CVPixelBufferGetWidth(imageBuffer)
                    let height = CVPixelBufferGetHeight(imageBuffer)
                    let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
                    let rowBytes = CVPixelBufferGetBytesPerRow(imageBuffer)

                    var buffer = vImage_Buffer(data: baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)

                    // Allocate grayscale buffer
                    var grayBuffer = vImage_Buffer()
                    vImageBuffer_Init(&grayBuffer, buffer.height, buffer.width, 8, vImage_Flags(kvImageNoFlags))

                    // Apply grayscale conversion matrix (ARGB to grayscale)
                    let matrix: [Int16] = [54, 183, 19, 0]  // Based on luminance weights
                    let divisor: Int32 = 256
                    vImageMatrixMultiply_ARGB8888ToPlanar8(&buffer, &grayBuffer, matrix, divisor, nil, 0, vImage_Flags(kvImageNoFlags))

                    frames.append(grayBuffer)

                    // Store timestamp of current frame
                    let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    timestamps.append(CMTimeGetSeconds(pts))
                    CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
                }

                //log("✅ Loaded \(frames.count) frames")
                log("🧠 Analyzing frame deltas in parallel...")

                // Compute differences between frames in parallel
                let queue = DispatchQueue(label: "compareQueue", attributes: .concurrent)
                let group = DispatchGroup()
                var diffs = Array(repeating: 0.0, count: frames.count)

                for i in 1..<frames.count {
                    queue.async(group: group) {
                        diffs[i] = mseVImage(frames[i], frames[i - 1])
                    }
                }
                group.wait()  // Wait until all diffs are computed

                // Identify changes using diff threshold and calculate delta timing
                var lastChange = 0
                for i in 0..<diffs.count {
                    let time = timestamps[i]
                    let diff = diffs[i]
                    if diff > 1.0 {
                        let delta = time - timestamps[lastChange]
                        frameTimes.append((i, time, true, delta))
                        lastChange = i
                    } else {
                        frameTimes.append((i, time, false, 0))
                    }
                }
                frames.forEach { free($0.data) }  // Free memory

            } else {
                log("🧠 Analyzing frame deltas sequentially...")
                var prevBuffer: vImage_Buffer? = nil
                var index = 0
                var lastChange = 0

                // Process frames one at a time, single threading mode
                while let sampleBuffer = readerOutput.copyNextSampleBuffer(),
                      let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {

                    CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
                    let width = CVPixelBufferGetWidth(imageBuffer)
                    let height = CVPixelBufferGetHeight(imageBuffer)
                    let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
                    let rowBytes = CVPixelBufferGetBytesPerRow(imageBuffer)

                    var buffer = vImage_Buffer(data: baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)

                    var grayBuffer = vImage_Buffer()
                    vImageBuffer_Init(&grayBuffer, buffer.height, buffer.width, 8, vImage_Flags(kvImageNoFlags))
                    let matrix: [Int16] = [54, 183, 19, 0]
                    let divisor: Int32 = 256
                    vImageMatrixMultiply_ARGB8888ToPlanar8(&buffer, &grayBuffer, matrix, divisor, nil, 0, vImage_Flags(kvImageNoFlags))

                    let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                    let time = CMTimeGetSeconds(pts)

                    if let prev = prevBuffer {
                        let diff = mseVImage(grayBuffer, prev)
                        if diff > 1.0 {
                            let delta = time - frameTimes[lastChange].1
                            frameTimes.append((index, time, true, delta))
                            lastChange = index
                        } else {
                            frameTimes.append((index, time, false, 0))
                        }
                        free(prev.data)
                    } else {
                        frameTimes.append((index, time, true, 0))
                        lastChange = index
                    }

                    prevBuffer = grayBuffer
                    index += 1
                    CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
                }

                if let last = prevBuffer {
                    free(last.data)
                }
            }

            log("✅ Processed \(frameTimes.count) frames")

            // Extract timestamps of all scene changes
            let changedTimestamps = frameTimes.filter { $0.2 }.map { $0.1 }

            // Calculate average FPS based on changed frames
            let avgFPS: Double
            if let first = changedTimestamps.first,
               let last = changedTimestamps.last,
               changedTimestamps.count > 1 {
                let duration = last - first
                let count = changedTimestamps.count - 1
                avgFPS = Double(count) / duration
            } else {
                avgFPS = 0
            }

            // Calculate min and max FPS from delta values
            let validTimes = frameTimes.compactMap { $0.3 > 0 ? $0.3 : nil }
            let fpsList = validTimes.map { 1.0 / $0 }
            let minFPS = fpsList.min() ?? 0
            let maxFPS = fpsList.max() ?? 0

            log("📊 Average FPS: \(String(format: "%.2f", avgFPS))")
            log("📊 Min FPS: \(String(format: "%.2f", minFPS))")
            log("📊 Max FPS: \(String(format: "%.2f", maxFPS))")

            // Write results to CSV file
        // Write results to CSV file
                var csvLines: [String] = []
                var statBlock: [String] = []

                if reportStats {
                    let avgStr = String(format: "%.4f", avgFPS)
                    let minStr = String(format: "%.0f", minFPS)
                    let maxStr = String(format: "%.0f", maxFPS)

                    if statsMode == "General" {
                        statBlock.append("Avg FPS: \(avgStr), Min FPS: \(minStr), Max FPS: \(maxStr)")
                    } else if statsMode == "Detailed" {
                        let longest = validTimes.max() ?? 0
                        let longestMs = longest * 1000.0
                        let longestCount = validTimes.filter { abs($0 - longest) < 0.0001 }.count
                        let longestPercent = Double(longestCount) / Double(validTimes.count) * 100
                        let sorted = validTimes.sorted(by: >)
                        let onePercentIndex = max(Int(Double(validTimes.count) * 0.01) - 1, 0)
                        let longestOnePercent = sorted[onePercentIndex]
                        let longestOnePercentMs = longestOnePercent * 1000.0
                        let minFpsOnePercent = 1.0 / longestOnePercent

                        statBlock.append("Avg FPS, \(avgStr)")
                        statBlock.append("Min FPS, \(minStr)")
                        statBlock.append("Max FPS, \(maxStr)")
                        statBlock.append("The longest frame, \(String(format: "%.4f", longestMs))ms")
                        statBlock.append("The % of \(Int(longestMs))ms frames, \(String(format: "%.1f", longestPercent))")
                        statBlock.append("The frame time that 1% of the frames are equal to or longer, \(String(format: "%.4f", longestOnePercentMs))ms, Corresponding to 1% Min FPS, \(String(format: "%.2f", minFpsOnePercent))")

                    }
                }
                
                //Export Table and Inject data via Apple Script
                if exportGraph && graphType == "Interactive" {
                    let graphTemplatePath = Bundle.main.path(forResource: "GraphTemplate", ofType: "numbers")!
                    let destinationPath = URL(fileURLWithPath: finalOutputPath).appendingPathComponent("frametime_graph.numbers").path
                    let scriptPath = Bundle.main.path(forResource: "InjectValuesForGraph", ofType: "scpt")!

                    // Prepare raw injection data for script
                    let frameDataRows = frameTimes
                        .filter { $0.3 > 0 }
                        .map {
                            let timestamp = String(format: "%.4f", $0.1)
                            let frametime = String(format: "%.4f", $0.3 * 1000.0)
                            return "\(timestamp),\(frametime)"
                        }.joined(separator: "\n")

                    do {
                        // Copy the .numbers template to output location
                        try FileManager.default.copyItem(atPath: graphTemplatePath, toPath: destinationPath)
                        log("📄 Graph template copied to \(destinationPath)")

                        // Call AppleScript with data
                        let task = Process()
                        task.launchPath = "/usr/bin/osascript"
                        task.arguments = [scriptPath, destinationPath, destinationPath, frameDataRows]

                        let pipe = Pipe()
                        task.standardOutput = pipe
                        task.standardError = pipe

                        task.launch()
                        task.waitUntilExit()

                        let data = pipe.fileHandleForReading.readDataToEndOfFile()
                        let output = String(data: data, encoding: .utf8) ?? ""
                        log("📈 AppleScript executed: \(output)")

                    } catch {
                        log("⚠️ Error during graph generation: \(error.localizedDescription)")
                    }
                }




                let csvRows = frameTimes.map {
                    let timestampMs = $0.1 * 1000.0
                    let deltaMs = $0.3 * 1000.0
                    return "\(String(format: "%d", $0.0)),\(String(format: "%.4f", timestampMs)),\($0.2 ? 1 : 0),\(String(format: "%.4f", deltaMs))"
                }

                // Save statistics to a separate file if needed
                if reportStats {
                    let statsFileURL = URL(fileURLWithPath: finalOutputPath).appendingPathComponent("frametime_stats.csv")

                    let statsContent = statBlock.joined(separator: "\n")
                    print("DEBUG: Saving stats to \(statsFileURL.path)")

                    do {
                        try statsContent.write(to: statsFileURL, atomically: true, encoding: .utf8)
                    } catch {
                        print("⚠️ Error saving stats CSV: \(error.localizedDescription)")
                    }
                }


                // Save main frametime table
                csvLines.append("frame_index,timestamp (ms),is_change,delta (ms)")
                csvLines.append(contentsOf: csvRows)


                let csvContent = csvLines.joined(separator: "\n")
                let outputURL = URL(fileURLWithPath: finalOutputPath).appendingPathComponent("frametime_output.csv")
                try? csvContent.write(to: outputURL, atomically: true, encoding: .utf8)

                log("✅ Saved output to \(outputURL.path)")
                log("📁 Using video file: \(videoPath)")
                log("⚠️ WARNING: This is the early prototype version, it’s full of bugs and provides false positives if fed with video full of screen tearing!")

                return outputLog
            }

            /// Calculates mean squared error (MSE) between two grayscale images
            static func mseVImage(_ img1: vImage_Buffer, _ img2: vImage_Buffer) -> Double {
                guard img1.width == img2.width && img1.height == img2.height else {
                    return Double.infinity
                }

                let pixelCount = Int(img1.width * img1.height)
                var float1 = [Float](repeating: 0, count: pixelCount)
                var float2 = [Float](repeating: 0, count: pixelCount)
                var diffSquared = [Float](repeating: 0, count: pixelCount)

                vDSP_vfltu8(img1.data.assumingMemoryBound(to: UInt8.self), 1, &float1, 1, vDSP_Length(pixelCount))
                vDSP_vfltu8(img2.data.assumingMemoryBound(to: UInt8.self), 1, &float2, 1, vDSP_Length(pixelCount))
                vDSP_vsub(float2, 1, float1, 1, &diffSquared, 1, vDSP_Length(pixelCount))
                vDSP_vsq(diffSquared, 1, &diffSquared, 1, vDSP_Length(pixelCount))

                var mse: Float = 0
                vDSP_meanv(diffSquared, 1, &mse, vDSP_Length(pixelCount))

                return Double(mse)
            }
        }

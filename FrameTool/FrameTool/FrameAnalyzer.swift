//  FrameAnalyzer.swift
//  FrameTool
//
//  Created by wheissmd on 17/04/2025.

import AVFoundation
import CoreImage
import Accelerate
import ZIPFoundation
import AppKit

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
        
        // Export interactive HTML graph using Plotly
        if exportGraph {
            // Collect frametime graph data
            let timeValues = frameTimes
                .filter { $0.3 > 0 }
                .map { String(format: "%.4f", $0.1) }
            
            let deltaValues = frameTimes
                .filter { $0.3 > 0 }
                .map { String(format: "%.4f", $0.3 * 1000.0) }
            
            // Collect FPS data per 1/4 second
            var fpsDict = [Double: Int]()
            for (_, timestamp, isChange, delta) in frameTimes where isChange && delta > 0.0 {
                let bucket = Double(Int(timestamp / 0.25)) * 0.25
                fpsDict[bucket, default: 0] += 1
            }
            
            var fpsTimeValues = fpsDict.keys.sorted()
            var fpsValues = fpsTimeValues.map { Double(fpsDict[$0] ?? 0) * 4.0 }
            
            if fpsTimeValues.count > 2 {
                fpsTimeValues = Array(fpsTimeValues.dropLast(2))
                fpsValues = Array(fpsValues.dropLast(2))
            }
            
            let trimmedFpsTime = fpsTimeValues.map { String(format: "%.2f", $0) }
            let trimmedFpsValues = fpsValues.map { String(format: "%.2f", $0) }
            
            let outputHTMLPath = URL(fileURLWithPath: outputPath).appendingPathComponent("frametime_graph.html")
            let imageOutputPath = URL(fileURLWithPath: outputPath).appendingPathComponent("frametime_graph.png")
            
            if graphType == "Interactive" {
                var htmlContent = """
                <!DOCTYPE html>
                <html>
                <head>
                    <meta charset="utf-8">
                    <script src="https://cdn.plot.ly/plotly-latest.min.js"></script>
                    <style>body { margin: 0; background: transparent; }</style>
                </head>
                <body>
                    <div id="frametime" style="width:1200px;height:600px;"></div>
                    <script>
                        var trace1 = {
                            x: \(timeValues),
                            y: \(deltaValues),
                            mode: 'lines',
                            type: 'scatter',
                            name: 'Frametime (ms)',
                            line: { color: 'green' }
                        };
                        var layout1 = {
                            title: 'Frametime',
                            xaxis: { title: 'Time (s)' },
                            yaxis: { title: 'Frametime (ms)' },
                            paper_bgcolor: 'rgba(0,0,0,0)',
                            plot_bgcolor: 'rgba(0,0,0,0)'
                        };
                        Plotly.newPlot('frametime', [trace1], layout1);
                    </script>
                
                    <div id="fps" style="width:1200px;height:600px;"></div>
                    <script>
                        var trace2 = {
                            x: \(trimmedFpsTime),
                            y: \(trimmedFpsValues),
                            mode: 'lines+markers',
                            type: 'scatter',
                            name: 'FPS',
                            line: { color: 'darkgreen' }
                        };
                        var layout2 = {
                            title: 'Frames Per Second',
                            xaxis: { title: 'Time (s)' },
                            yaxis: { title: 'FPS' },
                            paper_bgcolor: 'rgba(0,0,0,0)',
                            plot_bgcolor: 'rgba(0,0,0,0)'
                        };
                        Plotly.newPlot('fps', [trace2], layout2);
                    </script>
                </body>
                </html>
                """
                
                do {
                    try htmlContent.write(to: outputHTMLPath, atomically: true, encoding: .utf8)
                } catch {
                    log("⚠️ Error generating interactive graph: \(error.localizedDescription)")
                }
            }
            
            else if graphType == "Image" {
                // Image size: tall and high-res
                let width = 6000
                let height = 2000
                let margin: CGFloat = 100
                let graphHeight = (height - Int(margin) * 3) / 2
                
                let colorBg = NSColor.black
                let colorLine1 = NSColor.green
                let colorLine2 = NSColor.systemGreen
                let colorText = NSColor.white
                
                let image = NSImage(size: NSSize(width: width, height: height))
                image.lockFocus()
                
                guard let context = NSGraphicsContext.current?.cgContext else {
                    log("⚠️ Could not get graphics context for image rendering.")
                    return "Error"
                }
                
                // Background
                context.clear(CGRect(x: 0, y: 0, width: width, height: height))
                
                // Frametime Graph
                let deltaYStart = height - Int(margin)
                let deltaYEnd = deltaYStart - Int(graphHeight)
                
                if let minDelta = deltaValues.map({ Double($0)! }).min(),
                   let maxDelta = deltaValues.map({ Double($0)! }).max() {
                    let xScale = CGFloat(width - 2 * Int(margin)) / CGFloat(timeValues.count)
                    let yScale = CGFloat(graphHeight) / CGFloat(maxDelta - minDelta)
                    
                    context.setStrokeColor(colorLine1.cgColor)
                    context.setLineWidth(1.0)
                    context.beginPath()
                    
                    for (index, value) in deltaValues.enumerated() {
                        let x = margin + CGFloat(index) * xScale
                        let yVal = CGFloat(Double(value)! - minDelta) * yScale
                        let y = CGFloat(deltaYEnd) + yVal
                        
                        if index == 0 {
                            context.move(to: CGPoint(x: x, y: y))
                        } else {
                            context.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    context.strokePath()
                    
                    // Frametime Axis Lines & Ticks
                    context.setStrokeColor(NSColor.gray.cgColor)
                    context.setLineWidth(1.0)

                    // Y-axis line
                    context.move(to: CGPoint(x: margin, y: CGFloat(deltaYEnd)))
                    context.addLine(to: CGPoint(x: margin, y: CGFloat(deltaYStart)))
                    context.strokePath()

                    // X-axis line
                    context.move(to: CGPoint(x: margin, y: CGFloat(deltaYEnd)))
                    context.addLine(to: CGPoint(x: CGFloat(width) - margin, y: CGFloat(deltaYEnd)))
                    context.strokePath()

                    // Y-axis ticks and labels
                    let yStep: Double = 5
                    for yVal in stride(from: minDelta, through: maxDelta, by: yStep) {
                        let yOffset = CGFloat(yVal - minDelta) * yScale
                        let y = CGFloat(deltaYEnd) + yOffset
                        let label = String(format: "%.0f", yVal)
                        let attributes: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 24), .foregroundColor: colorText]
                        label.draw(at: CGPoint(x: 10, y: y - 12), withAttributes: attributes)
                    }
                    
                    // Shared X-Axis Time Labels
                    context.setStrokeColor(NSColor.gray.cgColor)
                    context.setLineWidth(1.0)

                    let totalTime = timeValues.last.flatMap { Double($0) } ?? 0.0
                    let timeStep: Double = 1.0
                    let pixelsPerSecond = CGFloat(width - Int(2 * margin)) / CGFloat(totalTime)

                    for t in stride(from: 0.0, through: totalTime, by: timeStep) {
                        let x = CGFloat(margin) + CGFloat(t) * pixelsPerSecond
                        context.move(to: CGPoint(x: Int(x), y: height - Int(margin)))
                        context.addLine(to: CGPoint(x: Int(x), y: height - Int(margin) + 10))
                        
                        let label = String(format: "%.0f", t)
                        let attributes: [NSAttributedString.Key: Any] = [
                            .font: NSFont.systemFont(ofSize: 24),
                            .foregroundColor: colorText
                        ]
                        label.draw(at: CGPoint(x: x - 10, y: CGFloat(height) - margin + 14), withAttributes: attributes)
                    }
                    context.strokePath()


                    
                    // Add frametime title
                    let title = "Frametime (ms)"
                    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 48), .foregroundColor: colorText]
                    title.draw(at: CGPoint(x: margin, y: CGFloat(deltaYStart + 20)), withAttributes: attrs)
                    
                    // Y-axis label
                    let yLabel = "Frametime (ms)"
                    let yLabelAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 36), .foregroundColor: colorText]
                    yLabel.draw(at: CGPoint(x: margin, y: CGFloat(deltaYEnd + 20)), withAttributes: yLabelAttrs)
                }
                
                // FPS Graph
                let fpsYStart = deltaYEnd - Int(margin)
                let fpsYEnd = fpsYStart - Int(graphHeight)

                if let minFps = fpsValues.min(), let maxFps = fpsValues.max() {
                    let xScale = CGFloat(width - 2 * Int(margin)) / CGFloat(fpsValues.count)
                    let yScale = CGFloat(graphHeight) / CGFloat(maxFps - minFps)

                    context.setStrokeColor(colorLine2.cgColor)
                    context.setLineWidth(2.0)
                    context.beginPath()

                    for (index, value) in fpsValues.enumerated() {
                        let x = margin + CGFloat(index) * xScale
                        let yVal = CGFloat(value - minFps) * yScale
                        let y = CGFloat(fpsYEnd) + yVal

                        if index == 0 {
                            context.move(to: CGPoint(x: x, y: y))
                        } else {
                            context.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    context.strokePath()

                    // FPS Axis Lines
                    context.setStrokeColor(NSColor.gray.cgColor)
                    context.setLineWidth(1.0)

                    // Y-axis line
                    context.move(to: CGPoint(x: margin, y: CGFloat(fpsYEnd)))
                    context.addLine(to: CGPoint(x: margin, y: CGFloat(fpsYStart)))
                    context.strokePath()

                    // X-axis line
                    context.move(to: CGPoint(x: margin, y: CGFloat(fpsYEnd)))
                    context.addLine(to: CGPoint(x: CGFloat(width) - margin, y: CGFloat(fpsYEnd)))
                    context.strokePath()

                    // Y-Axis ticks and labels
                    let fpsStep: Double = 5.0
                    for fps in stride(from: minFps, through: maxFps, by: fpsStep) {
                        let offset = CGFloat(fps - minFps) * yScale
                        let y = CGFloat(fpsYEnd) + offset

                        let label = String(format: "%.0f", fps)
                        let attributes: [NSAttributedString.Key: Any] = [
                            .font: NSFont.systemFont(ofSize: 24),
                            .foregroundColor: colorText
                        ]
                        label.draw(at: CGPoint(x: 10, y: y - 10), withAttributes: attributes)
                    }

                    // Add FPS title
                    let fpsTitle = "Frames Per Second"
                    let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.boldSystemFont(ofSize: 48), .foregroundColor: colorText]
                    fpsTitle.draw(at: CGPoint(x: margin, y: CGFloat(fpsYStart + 20)), withAttributes: attrs)

                    // Y-axis label
                    let yLabel = "FPS"
                    let yLabelAttrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 36), .foregroundColor: colorText]
                    yLabel.draw(at: CGPoint(x: margin, y: CGFloat(fpsYEnd + 20)), withAttributes: yLabelAttrs)
                }

                image.unlockFocus()
                
                let imageOutputPath = URL(fileURLWithPath: outputPath).appendingPathComponent("frametime_graph.png")
                if let data = image.tiffRepresentation,
                   let rep = NSBitmapImageRep(data: data),
                   let pngData = rep.representation(using: .png, properties: [:]) {
                    do {
                        try pngData.write(to: imageOutputPath)
                        //log("📸 Saved image graph to \(imageOutputPath.path)")
                    } catch {
                        log("⚠️ Failed to write image: \(error.localizedDescription)")
                    }
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
        func mseVImage(_ img1: vImage_Buffer, _ img2: vImage_Buffer) -> Double {
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
        }; return outputLog;
        
    }
    
    
    
    
}

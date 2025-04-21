//  FrameAnalyzer.swift
//  FrameTool
//
//  Created by wheissmd on 17/04/2025.

import AVFoundation
import CoreImage
import Accelerate
import AppKit
import CoreText
extension vImage_Buffer {
    func deepCopy() -> vImage_Buffer {
        var newBuffer = vImage_Buffer()
        vImageBuffer_Init(&newBuffer, self.height, self.width, 8, vImage_Flags(kvImageNoFlags))
        memcpy(newBuffer.data, self.data, Int(self.height) * self.rowBytes)
        return newBuffer
    }
}

public struct FrameAnalyzer {
    /// Main method to analyze frame timings in a video.
    /// - Parameters:
    ///   - videoPath: path to the input video file
    ///   - outputPath: folder to write the CSV output
    ///   - isMultithreading: whether to analyze using multiple CPU threads
    public static func runAnalysis(
        videoPath: String,
        outputPath: String,
        isMultithreading: Bool,
        reportStats: Bool,
        statsMode: String,
        exportGraph: Bool = false,
        graphType: String,
        onComplete: @escaping (String) -> Void = { _ in }
    )
    -> String {
        
        
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
        let videoAsset = AVAsset(url: URL(fileURLWithPath: videoPath))
        guard let readerTrack = videoAsset.tracks(withMediaType: .video).first else {
            log("❌ Could not get video track.")
            return outputLog
        }

        let reader = try! AVAssetReader(asset: videoAsset)
        let readerOutput = AVAssetReaderTrackOutput(track: readerTrack, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
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

            var frames: [vImage_Buffer] = []
            var timestamps: [Double] = []

            // === Create fresh reader + output for single-threaded analysis ===
            let analysisAsset = AVAsset(url: URL(fileURLWithPath: videoPath))
            guard let analysisTrack = analysisAsset.tracks(withMediaType: .video).first else {
                log("❌ Could not get video track for sequential analysis.")
                return outputLog
            }
            guard let analysisReader = try? AVAssetReader(asset: analysisAsset) else {
                log("❌ Could not create AVAssetReader for sequential analysis.")
                return outputLog
            }
            let analysisOutput = AVAssetReaderTrackOutput(track: analysisTrack, outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ])
            guard analysisReader.canAdd(analysisOutput) else {
                fatalError("❌ Cannot add analysisOutput to reader")
            }
            analysisReader.add(analysisOutput)
            analysisReader.startReading()

            // === Analyze frames one by one ===
            while let sampleBuffer = analysisOutput.copyNextSampleBuffer(),
                  let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {

                CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
                let width = CVPixelBufferGetWidth(imageBuffer)
                let height = CVPixelBufferGetHeight(imageBuffer)
                let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)!
                let rowBytes = CVPixelBufferGetBytesPerRow(imageBuffer)

                var buffer = vImage_Buffer(data: baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)

                // Allocate grayscale buffer
                var grayBuffer = vImage_Buffer()
                let grayRowBytes = width
                grayBuffer.data = malloc(height * grayRowBytes)
                grayBuffer.height = vImagePixelCount(height)
                grayBuffer.width = vImagePixelCount(width)
                grayBuffer.rowBytes = grayRowBytes

                // Convert to grayscale
                let matrix: [Int16] = [54, 183, 19, 0]
                let divisor: Int32 = 256
                let error = vImageMatrixMultiply_ARGB8888ToPlanar8(&buffer, &grayBuffer, matrix, divisor, nil, 0, vImage_Flags(kvImageNoFlags))

                CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)

                if error == kvImageNoError {
                    let bufferCopy = grayBuffer.deepCopy()
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

                    prevBuffer = bufferCopy
                    index += 1
                } else {
                    print("⚠️ Grayscale conversion error: \(error)")
                }

                free(grayBuffer.data)
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
            var fpsDict = [Double: [Double]]()

            for (_, timestamp, isChange, delta) in frameTimes where isChange && delta > 0.0 {
                let bucket = Double(Int(timestamp / 0.25)) * 0.25
                fpsDict[bucket, default: []].append(timestamp)
            }

            var fpsTimeValues: [Double] = []
            var fpsValues: [Double] = []

            for (bucketStart, timestamps) in fpsDict.sorted(by: { $0.key < $1.key }) {
                guard timestamps.count >= 2 else {
                    fpsTimeValues.append(bucketStart)
                    fpsValues.append(Double(timestamps.count))  // fallback to count if only 1 frame
                    continue
                }

                let duration = timestamps.last! - timestamps.first!
                let fps = Double(timestamps.count - 1) / duration
                fpsTimeValues.append(bucketStart)
                fpsValues.append(fps)
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
                // Video with overlay render
            else if graphType == "Animated Overlay" {
                
                let outputVideoURL = URL(fileURLWithPath: outputPath).appendingPathComponent("frametime_overlay.mov")
                if FileManager.default.fileExists(atPath: outputVideoURL.path) {
                    try? FileManager.default.removeItem(at: outputVideoURL)
                }

                let asset = AVAsset(url: URL(fileURLWithPath: videoPath))
                guard let readerTrack = asset.tracks(withMediaType: .video).first else {
                    log("❌ Could not get video track.")
                    return outputLog
                }

                let renderSize = readerTrack.naturalSize
                let nominalFrameRate = readerTrack.nominalFrameRate
                let durationSeconds = asset.duration.seconds
                let totalFramesToWrite = Int(durationSeconds * Double(nominalFrameRate))
                let frameDuration = CMTime(value: 1, timescale: CMTimeScale(nominalFrameRate))
                let imageSize = CGSize(width: Int(renderSize.width), height: Int(renderSize.height))
                let windowDuration: Double = 5.0

                guard let writer = try? AVAssetWriter(outputURL: outputVideoURL, fileType: .mov) else {
                    log("❌ Failed to create AVAssetWriter for output.")
                    return outputLog
                }

                let videoSettings: [String: Any] = [
                    AVVideoCodecKey: AVVideoCodecType.h264,
                    AVVideoWidthKey: Int(imageSize.width),
                    AVVideoHeightKey: Int(imageSize.height)
                ]

                let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput, sourcePixelBufferAttributes: [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32ARGB),
                    kCVPixelBufferWidthKey as String: Int(imageSize.width),
                    kCVPixelBufferHeightKey as String: Int(imageSize.height)
                ])

                writer.add(writerInput)

                // Use a separate reader for overlay rendering
                let overlayAsset = AVAsset(url: URL(fileURLWithPath: videoPath))
                guard let overlayTrack = overlayAsset.tracks(withMediaType: .video).first else {
                    log("❌ Could not get overlay video track.")
                    return outputLog
                }

                let overlayReader = try! AVAssetReader(asset: overlayAsset)
                let overlayOutput = AVAssetReaderTrackOutput(track: overlayTrack, outputSettings: [
                    kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
                ])

                overlayReader.add(overlayOutput)
                overlayReader.startReading()


                let frameDeltaValues: [(Double, Double)] = frameTimes
                    .filter { $0.2 && $0.3 > 0 }
                    .map { ($0.1, $0.3) }

                writer.startWriting()
                writer.startSession(atSourceTime: .zero)

                var frameCount = 0
                let queue = DispatchQueue(label: "overlay.queue")

                writerInput.requestMediaDataWhenReady(on: queue) {
                    while writerInput.isReadyForMoreMediaData && frameCount < totalFramesToWrite {
                        autoreleasepool {
                            let currentTime = Double(frameCount) / Double(nominalFrameRate)
                            let windowStart = max(0, currentTime - windowDuration)
                            let windowEnd = currentTime

                            let visiblePoints = frameDeltaValues.filter { $0.0 >= windowStart && $0.0 <= windowEnd }
                            if visiblePoints.isEmpty {
                                frameCount += 1
                                return
                            }

                            var pixelBuffer: CVPixelBuffer?
                            CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pixelBuffer)

                            if let buffer = pixelBuffer {
                                CVPixelBufferLockBaseAddress(buffer, [])
                                let baseAddress = CVPixelBufferGetBaseAddress(buffer)
                                let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
                                let colorSpace = CGColorSpaceCreateDeviceRGB()

                                let context = CGContext(
                                    data: baseAddress,
                                    width: Int(imageSize.width),
                                    height: Int(imageSize.height),
                                    bitsPerComponent: 8,
                                    bytesPerRow: bytesPerRow,
                                    space: colorSpace,
                                    bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
                                )

                                if let ctx = context {
                                    // Draw original frame
                                    guard overlayReader.status == .reading,
                                          let sampleBuffer = overlayOutput.copyNextSampleBuffer(),
                                          let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {

                                        if overlayReader.status == .completed || overlayReader.status == .reading {
                                            writerInput.markAsFinished()
                                            writer.finishWriting {
                                                onComplete(outputLog)
                                            }
                                        } else {
                                            log("❌ OverlayReader error: \(overlayReader.error?.localizedDescription ?? "Unknown error")")
                                            onComplete(outputLog)
                                        }
                                        return
                                    }


                                    let bgImage = CIImage(cvPixelBuffer: imageBuffer)

                                    let ciContext = CIContext()
                                    if let cgImage = ciContext.createCGImage(bgImage, from: bgImage.extent) {
                                        ctx.draw(cgImage, in: CGRect(origin: .zero, size: imageSize))
                                    }

                                    // --- Layout ---
                                    let graphPadding: CGFloat = 60
                                    let graphWidth = imageSize.width - 2 * graphPadding
                                    let graphHeight = (imageSize.height / 6) * 0.65
                                    let offsetX = graphPadding
                                    let offsetY: CGFloat = 80  // spacing from bottom

                                    let ftGraphY = offsetY + graphHeight + 80
                                    let fpsGraphY = offsetY

                                    let xScale = graphWidth / CGFloat(windowDuration)

                                    // === Frametime Graph ===
                                    let visiblePoints = frameDeltaValues.filter {
                                        $0.0 >= currentTime - windowDuration && $0.0 <= currentTime
                                    }

                                    let maxDelta = visiblePoints.map { $0.1 }.max() ?? 1
                                    let minDelta: Double = 0  // always start at 0 now
                                    let yScaleFT = graphHeight / CGFloat(maxDelta - minDelta)

                                    ctx.setStrokeColor(NSColor.green.cgColor)
                                    ctx.setLineWidth(2.5)
                                    ctx.beginPath()

                                    for (i, (timestamp, delta)) in visiblePoints.enumerated() {
                                        let x = offsetX + CGFloat(timestamp - (currentTime - windowDuration)) * xScale
                                        let y = ftGraphY + CGFloat(delta - minDelta) * yScaleFT
                                        if i == 0 {
                                            ctx.move(to: CGPoint(x: x, y: y))
                                        } else {
                                            ctx.addLine(to: CGPoint(x: x, y: y))
                                        }
                                    }
                                    ctx.strokePath()

                                    // === FPS Graph ===
                                    var fpsBuckets: [(time: Double, fps: Double)] = []
                                    let step: Double = 0.25
                                    var bucketTime: Double = 0.0

                                    while bucketTime < currentTime {
                                        let next = bucketTime + step
                                        let timestamps = frameDeltaValues
                                            .filter { $0.0 >= bucketTime && $0.0 < next }
                                            .map { $0.0 }

                                        let fps: Double
                                        if timestamps.count >= 2 {
                                            let duration = timestamps.last! - timestamps.first!
                                            fps = Double(timestamps.count - 1) / duration
                                        } else {
                                            fps = Double(timestamps.count)
                                        }

                                        fpsBuckets.append((time: bucketTime, fps: fps))
                                        bucketTime = next
                                    }


                                    let visibleFpsPoints = fpsBuckets.filter {
                                        $0.time >= currentTime - windowDuration && $0.time <= currentTime
                                    }

                                    let minFps = visibleFpsPoints.map { $0.fps }.min() ?? 0
                                    let maxFps = visibleFpsPoints.map { $0.fps }.max() ?? 60
                                    let fpsRange = maxFps - minFps != 0 ? maxFps - minFps : 1
                                    let fpsYScale = graphHeight / CGFloat(fpsRange)

                                    ctx.setStrokeColor(NSColor.green.cgColor)
                                    ctx.setLineWidth(2.5)
                                    ctx.beginPath()

                                    for (i, point) in visibleFpsPoints.enumerated() {
                                        let x = offsetX + CGFloat(point.time - (currentTime - windowDuration)) * xScale
                                        let y = fpsGraphY + CGFloat(point.fps - minFps) * fpsYScale
                                        if i == 0 {
                                            ctx.move(to: CGPoint(x: x, y: y))
                                        } else {
                                            ctx.addLine(to: CGPoint(x: x, y: y))
                                        }
                                    }
                                    ctx.strokePath()

                                    // === Axes ===
                                    ctx.setStrokeColor(NSColor.white.cgColor)
                                    ctx.setLineWidth(1.0)

                                    // Y axes
                                    ctx.stroke(CGRect(x: offsetX, y: ftGraphY, width: 0, height: graphHeight))
                                    ctx.stroke(CGRect(x: offsetX, y: fpsGraphY, width: 0, height: graphHeight))

                                    // X axes
                                    ctx.stroke(CGRect(x: offsetX, y: ftGraphY, width: graphWidth, height: 0))
                                    ctx.stroke(CGRect(x: offsetX, y: fpsGraphY, width: graphWidth, height: 0))
                                    
                                    // === FPS Text Box ===
                                    let currentBucket = Double(Int(currentTime / 0.25)) * 0.25
                                    let liveFPS = Int((fpsBuckets.first(where: { abs($0.time - currentBucket) < 0.001 })?.fps ?? 0))
                                    let fpsText = "Output FPS: \(liveFPS)"

                                    // Set up font
                                    let fontSize: CGFloat = 58
                                    let fontName = "Menlo-Bold"
                                    let font = CTFontCreateWithName(fontName as CFString, fontSize, nil)

                                    let attributes: [NSAttributedString.Key: Any] = [
                                        .font: font,
                                        .foregroundColor: CGColor(gray: 1.0, alpha: 1.0)
                                    ]

                                    let attrString = NSAttributedString(string: fpsText, attributes: attributes)
                                    let line = CTLineCreateWithAttributedString(attrString)

                                    // Adjust position further away from top-right corner
                                    ctx.textPosition = CGPoint(x: imageSize.width - 680, y: imageSize.height - 120)
                                    CTLineDraw(line, ctx)
                                    
                                    // === Add Frametime label ===
                                    let frametimeLabel = "Frametime"
                                    let frametimeAttr = [
                                        NSAttributedString.Key.font: CTFontCreateWithName("Menlo-Bold" as CFString, 60, nil),
                                        NSAttributedString.Key.foregroundColor: NSColor.white
                                    ]
                                    let frametimeText = NSAttributedString(string: frametimeLabel, attributes: frametimeAttr)
                                    let frametimePos = CGPoint(x: offsetX + 20, y: ftGraphY + graphHeight + 10)
                                    ctx.textPosition = frametimePos
                                    CTLineDraw(CTLineCreateWithAttributedString(frametimeText), ctx)


                                    // === Add FPS label ===
                                    let fpsGraphLabel = "FPS"
                                    let fpsGraphAttr = [
                                        NSAttributedString.Key.font: CTFontCreateWithName("Menlo-Bold" as CFString, 60, nil),
                                        NSAttributedString.Key.foregroundColor: NSColor.white
                                    ]
                                    let fpsGraphText = NSAttributedString(string: fpsGraphLabel, attributes: fpsGraphAttr)
                                    let fpsGraphPos = CGPoint(x: offsetX + 20, y: fpsGraphY + graphHeight + 10)
                                    ctx.textPosition = fpsGraphPos
                                    CTLineDraw(CTLineCreateWithAttributedString(fpsGraphText), ctx)
                                    
                                    // === Frametime Y-axis scale marks ===
                                    let uniqueFTValues = Set(visiblePoints.map { round($0.1 * 10000) / 10 })  // round to 0.1ms

                                    let ftRange = maxDelta - minDelta
                                    let frametimeGraphHeight: CGFloat = graphHeight
                                    let frametimeYScale: CGFloat = ftRange != 0 ? frametimeGraphHeight / CGFloat(ftRange) : 1.0


                                    var lastFtLabelY: CGFloat = -CGFloat.infinity
                                    let minFtSpacing: CGFloat = 28.0

                                    for value in uniqueFTValues.sorted() {
                                        let y = ftGraphY + CGFloat((value / 1000.0) - minDelta) * frametimeYScale
                                        if abs(y - lastFtLabelY) < minFtSpacing { continue }
                                        lastFtLabelY = y

                                        let tickStart = CGPoint(x: offsetX - 5, y: y)
                                        let tickEnd = CGPoint(x: offsetX, y: y)
                                        ctx.setStrokeColor(NSColor.white.cgColor)
                                        ctx.setLineWidth(1.0)
                                        ctx.beginPath()
                                        ctx.move(to: tickStart)
                                        ctx.addLine(to: tickEnd)
                                        ctx.strokePath()

                                        let label = String(format: "%.1f", value)
                                        let attributes: [NSAttributedString.Key: Any] = [
                                            .font: CTFontCreateWithName("Menlo" as CFString, 22, nil),
                                            .foregroundColor: NSColor.white
                                        ]
                                        let attrText = NSAttributedString(string: label, attributes: attributes)
                                        ctx.textPosition = CGPoint(x: offsetX - 40, y: y - 8)
                                        CTLineDraw(CTLineCreateWithAttributedString(attrText), ctx)
                                    }





                                    // === FPS Y-axis scale marks ===
                                    let uniqueFPSValues = Set(visibleFpsPoints.map { round($0.fps) })

                                    var lastFpsLabelY: CGFloat = -CGFloat.infinity
                                    let minFpsSpacing: CGFloat = 28.0

                                    for value in uniqueFPSValues.sorted() {
                                        let y = fpsGraphY + (CGFloat(value - minFps) * fpsYScale)
                                        if abs(y - lastFpsLabelY) < minFpsSpacing { continue }
                                        lastFpsLabelY = y

                                        let tickStart = CGPoint(x: offsetX - 5, y: y)
                                        let tickEnd = CGPoint(x: offsetX, y: y)

                                        ctx.setStrokeColor(NSColor.white.cgColor)
                                        ctx.setLineWidth(1.0)
                                        ctx.beginPath()
                                        ctx.move(to: tickStart)
                                        ctx.addLine(to: tickEnd)
                                        ctx.strokePath()

                                        let label = String(format: "%.0f", value)
                                        let attributes: [NSAttributedString.Key: Any] = [
                                            .font: CTFontCreateWithName("Menlo" as CFString, 25, nil),
                                            .foregroundColor: NSColor.white
                                        ]
                                        let attrText = NSAttributedString(string: label, attributes: attributes)
                                        ctx.textPosition = CGPoint(x: offsetX - 40, y: y - 8)
                                        CTLineDraw(CTLineCreateWithAttributedString(attrText), ctx)
                                    }







                                    
                                }




                                CVPixelBufferUnlockBaseAddress(buffer, [])

                                let presentationTime = CMTime(value: CMTimeValue(frameCount), timescale: CMTimeScale(nominalFrameRate))
                                adaptor.append(buffer, withPresentationTime: presentationTime)
                            }

                            frameCount += 1
                        }
                    }

                    if frameCount >= totalFramesToWrite {
                        writerInput.markAsFinished()
                        writer.finishWriting {
                            //let retries = 10
                            var attempts = 0
                            //while attempts < retries {
                                if FileManager.default.isReadableFile(atPath: outputVideoURL.path),
                                   AVAsset(url: outputVideoURL).isPlayable {
                                    onComplete(outputLog)
                                    return
                                } else {
                                    Thread.sleep(forTimeInterval: 1.0)
                                    attempts += 1
                                }
                            //}

                            onComplete(outputLog)
                        }
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
            
            if !exportGraph || (graphType != "Animated Overlay") {
                onComplete(outputLog)
                    return outputLog
                }
            
        }
        
        func pixelBufferFromCGImage(cgImage: CGImage, size: CGSize) -> CVPixelBuffer? {
            var pixelBuffer: CVPixelBuffer?
            let options: [String: Any] = [
                kCVPixelBufferCGImageCompatibilityKey as String: true,
                kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
            ]
            let status = CVPixelBufferCreate(
                kCFAllocatorDefault,
                Int(size.width),
                Int(size.height),
                kCVPixelFormatType_32ARGB,
                options as CFDictionary,
                &pixelBuffer
            )

            guard status == kCVReturnSuccess, let buffer = pixelBuffer else {
                return nil
            }

            CVPixelBufferLockBaseAddress(buffer, [])
            let context = CGContext(
                data: CVPixelBufferGetBaseAddress(buffer),
                width: Int(size.width),
                height: Int(size.height),
                bitsPerComponent: 8,
                bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
            )

            if let ctx = context {
                ctx.draw(cgImage, in: CGRect(origin: .zero, size: size))
            }

            CVPixelBufferUnlockBaseAddress(buffer, [])
            return buffer
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
        }; return outputLog
        if !exportGraph || !(graphType == "Interactive" || graphType == "Image" || graphType == "Animated Overlay") {
            onComplete(outputLog)
        }

        
    }
    
    
    
    
}


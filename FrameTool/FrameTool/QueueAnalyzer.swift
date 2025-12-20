//
//  QueueAnalyzer.swift
//  FrameTool
//
//  Created by Denis Vays on 06/09/2025.
//

import AVFoundation
import CoreImage
import Accelerate
import AppKit
import CoreText
import Foundation
import MachO

public struct QueueAnalyzer {
    /// Main method to analyze frame timings in a video.
    /// - Parameters:
    ///   - videoPath: path to the input video file
    ///   - outputPath: folder to write the CSV output
    ///   - isMultithreading: whether to analyze using multiple CPU threads
    ///   - reportStats: output a separate csv with overall statistics
    ///   - statsMode: detailed or general statistics
    ///   - exportGraph: export data as a graph
    ///   - graphType: type of the graph
    ///   - detectTearing: try to catch tearing frames and get rid of false positives
    ///   - userGraphScale: scale graph size for animated overlay
    ///   - renderOneSideOnly: render graph in a half of the screen
    ///   - overlayPosition: graph position
    
    
    
    static func runAnalysis(
        videoPath: String,
        indexInQueue: Int,
        outputSettings: OutputSettings,
        commonOutputPath: String,
        multithreadingEnabled: Bool,
        mtChunkSize: Int,
        codec: String,
        onComplete: @escaping (String) -> Void = { _ in }
    ) -> String {


        
        let outputPath = commonOutputPath
        let baseFileName = outputSettings.fileName
        let exportCsvFrametimes = outputSettings.exportCsvFrametimes
        let isMultithreading = multithreadingEnabled
        let reportStats = outputSettings.exportCsvSummary
        let statsMode = outputSettings.csvSummaryMode.rawValue
        let exportImage = outputSettings.exportImage
        let exportInteractive = outputSettings.exportInteractive
        let exportAnimated = outputSettings.exportAnimated
        let detectTearing = outputSettings.tearingDetection
        let userGraphScale = outputSettings.overlayScale
        let renderOneSideOnly = outputSettings.renderOneSideOnly
        let overlayPosition = outputSettings.overlayPosition.rawValue
        let response250msEnabled = outputSettings.enable250ms
        let graphColorHex = outputSettings.graphColorHex
        _ = indexInQueue


        
            let bucketSize = response250msEnabled ? 0.25 : 1.0
            let chosenNSColor: NSColor = {
                let hex = graphColorHex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
                guard let v = UInt32(hex.count == 6 ? hex + "FF" : hex, radix: 16) else { return .green }
                let r = CGFloat((v >> 24) & 0xFF) / 255
                let g = CGFloat((v >> 16) & 0xFF) / 255
                let b = CGFloat((v >>  8) & 0xFF) / 255
                let a = CGFloat((v >>  0) & 0xFF) / 255
                return NSColor(srgbRed: r, green: g, blue: b, alpha: a)
            }()
            let chosenCGColor = chosenNSColor.cgColor
            let cssHexNoAlpha: String = {
                guard let rgb = chosenNSColor.usingColorSpace(.sRGB) else { return "#00AA00" }
                let r = Int(round(rgb.redComponent   * 255))
                let g = Int(round(rgb.greenComponent * 255))
                let b = Int(round(rgb.blueComponent  * 255))
                return String(format: "#%02X%02X%02X", r, g, b)
            }()
            var outputLog = ""
            func log(_ msg: String) {
                outputLog += msg + "\n"
                print(msg)  // Also output to Xcode console
            }

            let finalOutputPath: String = outputPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!.path : outputPath
        
            let baseName = baseFileName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Output" : baseFileName
            let outDirURL = URL(fileURLWithPath: finalOutputPath)

            let frametimeCSVURL = outDirURL.appendingPathComponent("\(baseName)_frametime.csv")
            let summaryCSVURL   = outDirURL.appendingPathComponent("\(baseName)_summary.csv")
            let imageOutputURL  = outDirURL.appendingPathComponent("\(baseName)_graph.png")
            let htmlOutputURL   = outDirURL.appendingPathComponent("\(baseName)_interactive.html")
            let overlayOutputURL = outDirURL.appendingPathComponent("\(baseName)_overlay.mov")

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

            func getFreeMemoryBytes() -> UInt64 {
                var stats = vm_statistics64()
                var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: stats) / MemoryLayout<integer_t>.size)
                let result = withUnsafeMutablePointer(to: &stats) { statsPtr in
                    statsPtr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                        host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
                    }
                }
                if result != KERN_SUCCESS { return 0 }
                let free = UInt64(stats.free_count) * UInt64(vm_kernel_page_size)
                let inactive = UInt64(stats.inactive_count) * UInt64(vm_kernel_page_size)
                return free + inactive
            }
            
            if isMultithreading {
                let chunkSize = mtChunkSize
                let minFreeMemory: UInt64 = 5 * 1024 * 1024 * 1024 // 5 GB
                log("🧠 Analyzing frame deltas in parallel...")

                var frameIndex = 0
                var prevFrame: vImage_Buffer? = nil
                var prevTimestamp: Double? = nil
                var doneLoading = false

                // Thread-safe chunk buffer
                let chunkQueue = DispatchQueue(label: "chunk.queue", attributes: .concurrent)
                var chunkBuffer: [([vImage_Buffer], [Double])] = []

                func enqueueChunk(_ frames: [vImage_Buffer], _ timestamps: [Double]) {
                    chunkQueue.async(flags: .barrier) {
                        chunkBuffer.append((frames, timestamps))
                    }
                }

                func dequeueChunk() -> ([vImage_Buffer], [Double])? {
                    var chunk: ([vImage_Buffer], [Double])?
                    chunkQueue.sync {
                        if !chunkBuffer.isEmpty {
                            chunk = chunkBuffer.removeFirst()
                        }
                    }
                    return chunk
                }

                // Producer: read and convert frames in background
                let loaderQueue = DispatchQueue.global(qos: .userInitiated)
                loaderQueue.async {
                    
                    while true {
                        // Check available RAM before preparing next chunk
                        while getFreeMemoryBytes() < minFreeMemory {
                            var queueHasItems = false
                            chunkQueue.sync { queueHasItems = !chunkBuffer.isEmpty }
                            if !queueHasItems { break }            // nothing queued → proceed despite low RAM
                            Thread.sleep(forTimeInterval: 0.05)
                        }

                        var frames: [vImage_Buffer] = []
                        var timestamps: [Double] = []

                        // Keep last frame for continuity
                        if let prev = prevFrame, let prevTs = prevTimestamp {
                            frames.append(prev)
                            timestamps.append(prevTs)
                            prevFrame = nil
                            prevTimestamp = nil
                        }

                        var framesLoaded = 0
                        while framesLoaded < chunkSize,
                              let sampleBuffer = readerOutput.copyNextSampleBuffer(),
                              let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {

                            CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
                            let width = CVPixelBufferGetWidth(imageBuffer)
                            let height = CVPixelBufferGetHeight(imageBuffer)
                            let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)
                            let rowBytes = CVPixelBufferGetBytesPerRow(imageBuffer)

                            var buffer = vImage_Buffer(data: baseAddress,
                                                       height: vImagePixelCount(height),
                                                       width: vImagePixelCount(width),
                                                       rowBytes: rowBytes)

                            var grayBuffer = vImage_Buffer()
                            vImageBuffer_Init(&grayBuffer, buffer.height, buffer.width, 8, vImage_Flags(kvImageNoFlags))

                            let matrix: [Int16] = [19, 183, 54, 0]
                            let divisor: Int32 = 256
                            vImageMatrixMultiply_ARGB8888ToPlanar8(&buffer, &grayBuffer, matrix, divisor, nil, 0, vImage_Flags(kvImageNoFlags))

                            frames.append(grayBuffer)
                            let pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                            timestamps.append(CMTimeGetSeconds(pts))
                            CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)

                            framesLoaded += 1
                        }

                        if frames.isEmpty {
                            doneLoading = true
                            break
                        }

                        // Save last frame for continuity into the next chunk
                        if let lastFrame = frames.last, let lastTs = timestamps.last {
                            prevFrame = lastFrame
                            prevTimestamp = lastTs
                        }

                        enqueueChunk(frames, timestamps)

                        if frames.count < chunkSize {
                            doneLoading = true
                            break
                        }
                    }
                }

                // Consumer: process chunks until loader finishes and buffer is empty
                while true {
                    if let (frames, timestamps) = dequeueChunk() {
                        if frames.count < 2 { continue }

                        let queue = DispatchQueue.global(qos: .userInitiated)
                        let group = DispatchGroup()
                        var diffs = Array(repeating: 0.0, count: frames.count)

                        for i in 1..<frames.count {
                            group.enter()
                            queue.async {
                                diffs[i] = mseVImage(frames[i], frames[i - 1])
                                group.leave()
                            }
                        }
                        group.wait()

                        // Detection logic
                        var consecutiveTearing = 0
                        let windowSize = 10
                        var recentDeltas: [Double] = []
                        var recentSpikes: [Bool] = []
                        var lastChange = 0

                        for i in 0..<diffs.count {
                            let time = timestamps[i]
                            let diff = diffs[i]

                            let rawChange = diff > 1 && hasClusterDifference(frames[i], frames[i - 1])
                            var isSceneChange = rawChange

                            let delta = time - timestamps[lastChange]

                            var lock: Double? = nil
                            if recentDeltas.count == windowSize {
                                for v in recentDeltas {
                                    let nearCount = recentDeltas.filter { abs($0 - v) <= 0.001 }.count
                                    if nearCount >= 7 {
                                        lock = v
                                        break
                                    }
                                }
                            }

                            let sawSpikeBefore = recentSpikes.contains(true)
                            let epsilon = 0.001
                            if rawChange, let L = lock, delta < L - epsilon, !sawSpikeBefore {
                                isSceneChange = false
                            }

                            if !rawChange {
                                frameTimes.append((frameIndex + i, time, false, 0))
                                continue
                            }

                            if isSceneChange {
                                recentDeltas.append(delta)
                                if recentDeltas.count > windowSize { recentDeltas.removeFirst() }

                                let didSpike = (lock != nil && delta > lock! + epsilon)
                                recentSpikes.append(didSpike)
                                if recentSpikes.count > windowSize { recentSpikes.removeFirst() }
                            }

                            if detectTearing && i > 0 {
                                let height = Int(frames[i].height)
                                let width = Int(frames[i].width)
                                let rowBytes = frames[i].rowBytes
                                let sliceCount = 8
                                let sliceHeight = height / sliceCount

                                var matchPrev = 0
                                for s in 0..<sliceCount {
                                    let y = s * sliceHeight
                                    let offset = y * rowBytes

                                    let curr = vImage_Buffer(data: frames[i].data + offset,
                                                             height: vImagePixelCount(sliceHeight),
                                                             width: vImagePixelCount(width),
                                                             rowBytes: rowBytes)

                                    let prev = vImage_Buffer(data: frames[i - 1].data + offset,
                                                             height: vImagePixelCount(sliceHeight),
                                                             width: vImagePixelCount(width),
                                                             rowBytes: rowBytes)

                                    let msePrev = mseVImage(curr, prev)
                                    if msePrev < 5.0 && !isRegionBlack(curr) {
                                        matchPrev += 1
                                    }
                                }
                                if matchPrev > 0 && matchPrev < sliceCount {
                                    consecutiveTearing += 1
                                    isSceneChange = (consecutiveTearing % 2 == 0)
                                } else {
                                    consecutiveTearing = 0
                                }
                            }

                            if isSceneChange {
                                let delta = time - timestamps[lastChange]
                                frameTimes.append((frameIndex + i, time, true, delta))
                                lastChange = i
                            } else {
                                frameTimes.append((frameIndex + i, time, false, 0))
                            }
                        }

                        // Free everything except last frame in chunk
                        for i in 0..<(frames.count - 1) {
                            free(frames[i].data)
                        }

                        frameIndex += frames.count - 1
                    } else if doneLoading {
                        break
                    } else {
                        Thread.sleep(forTimeInterval: 0.001)
                    }
                }

                // Final cleanup
                if let oldPrev = prevFrame {
                    free(oldPrev.data)
                }
                prevFrame = nil
                prevTimestamp = nil
            } else {
                log("🧠 Analyzing frame deltas sequentially...")
                var prevBuffer: vImage_Buffer? = nil
                var index = 0
                var lastChange = 0
                var consecutiveTearing = 0

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
                analysisReader.add(analysisOutput)
                analysisReader.startReading()

                let windowSize    = 10
                let epsilon       = 0.001
                var recentDeltas: [Double] = []
                var recentSpikes: [Bool]   = []
                
                while let sampleBuffer = analysisOutput.copyNextSampleBuffer(),
                      let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
                    
                    CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
                    let width = CVPixelBufferGetWidth(imageBuffer)
                    let height = CVPixelBufferGetHeight(imageBuffer)
                    let baseAddress = CVPixelBufferGetBaseAddress(imageBuffer)!
                    let rowBytes = CVPixelBufferGetBytesPerRow(imageBuffer)
                    
                    var buffer = vImage_Buffer(data: baseAddress, height: vImagePixelCount(height), width: vImagePixelCount(width), rowBytes: rowBytes)
                    
                    var grayBuffer = vImage_Buffer()
                    let grayRowBytes = width
                    grayBuffer.data = malloc(height * grayRowBytes)
                    grayBuffer.height = vImagePixelCount(height)
                    grayBuffer.width = vImagePixelCount(width)
                    grayBuffer.rowBytes = grayRowBytes
                    
                    let matrix: [Int16] = [19, 183, 54, 0]
                    let divisor: Int32 = 256
                    let error = vImageMatrixMultiply_ARGB8888ToPlanar8(&buffer, &grayBuffer, matrix, divisor, nil, 0, vImage_Flags(kvImageNoFlags))
                    
                    CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
                    
                    if error == kvImageNoError {
                        // make a copy of a gray frame
                        let bufferCopy = grayBuffer.deepCopy()
                        let time       = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
                        
                        if prevBuffer == nil {
                            // treat first frame as a "change" with delta=0
                            print("FIRST FRAME: idx=\(index), time=\(time)")
                            frameTimes.append((index, time, true, 0))
                            lastChange   = index
                            // seed history windows
                            recentDeltas.append(0)
                            recentSpikes.append(false)
                            prevBuffer = bufferCopy
                            index += 1
                            free(grayBuffer.data)
                            continue
                        }
                        
                        // 1 compute diff
                        let diff = mseVImage(grayBuffer, prevBuffer!)
                        let rawChange = diff > 1 && hasClusterDifference(grayBuffer, prevBuffer!)
                        var isSceneChange = rawChange
                        print("DBG1: idx=\(index) rawChange=\(rawChange)")
                        
                        // 2 delta since last accepted change
                        let delta: Double = (lastChange < frameTimes.count)
                        ? time - frameTimes[lastChange].1
                        : 0
                        print("DBG2: idx=\(index) delta=\(delta) lastChange=\(lastChange)")
                        
                        // 3 detect lock
                        let epsilon = 0.001
                        var lock: Double? = nil
                        if recentDeltas.count == windowSize {
                            for v in recentDeltas {
                                if recentDeltas.filter({ abs($0 - v) <= epsilon }).count >= 7 {
                                    lock = v; break
                                }
                            }
                        }
                        print("DBG3: idx=\(index) recentDeltas=\(recentDeltas)")
                        print("DBG3: idx=\(index) lock=\(lock ?? -1)")
                        
                        // 4 check a real spike
                        let sawSpikeBefore = recentSpikes.contains(true)
                        print("DBG4: idx=\(index) recentSpikes=\(recentSpikes) sawSpikeBefore=\(sawSpikeBefore)")
                        
                        // 5 veto sub-lock dip if no spike
                        if rawChange, let L = lock, delta < (L - epsilon), !sawSpikeBefore {
                            isSceneChange = false
                            print("VETO: idx=\(index) delta=\(delta) < lock-ε=\(L - epsilon)")
                        }
                        
                        // 6 if on-rawChange append no-change and continue
                        if !rawChange {
                            print("DBG6: idx=\(index) skip non-rawChange")
                            frameTimes.append((index, time, false, 0))
                            // advance buffer and index
                            prevBuffer?.data.deallocate()
                            prevBuffer = bufferCopy
                            index += 1
                            free(grayBuffer.data)
                            continue
                        }
                        
                        // 7 log
                        print("DBG7: idx=\(index) isSceneChange=\(isSceneChange)")
                        
                        // 8 if accepted, update history
                        if isSceneChange {
                            recentDeltas.append(delta)
                            if recentDeltas.count > windowSize { recentDeltas.removeFirst() }
                            let didSpike = (lock != nil && delta > lock! + epsilon)
                            recentSpikes.append(didSpike)
                            if recentSpikes.count > windowSize { recentSpikes.removeFirst() }
                            if let L = lock {
                                print("SPIKE?: idx=\(index) delta \(delta) > lock+ε \(L + epsilon)? \(didSpike)")
                            } else {
                                print("SPIKE?: idx=\(index) no lock → didSpike=\(didSpike)")
                            }
                        }
                        
                        // 9 final append
                        if isSceneChange {
                            frameTimes.append((index, time, true, delta))
                            lastChange = index
                        } else {
                            frameTimes.append((index, time, false, 0))
                        }
                        
                        // advance buffer and index
                        prevBuffer?.data.deallocate()
                        prevBuffer = bufferCopy
                        index += 1
                        free(grayBuffer.data)
                    }
                    
                }

                if let last = prevBuffer {
                    free(last.data)
                }
            }


            log("✅ Processed \(frameTimes.count) frames")

            let changedTimestamps = frameTimes.filter { $0.2 }.map { $0.1 }

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
        
            
            func generateFPSBuckets(from frameDeltaValues: [(Double, Double)], step: Double) -> [(time: Double, fps: Double)] {
                var fpsBuckets: [(Double, Double)] = []
                guard let maxTime = frameDeltaValues.map(\.0).max() else { return fpsBuckets }
                
                var bucketTime: Double = 0.0
                while bucketTime < maxTime {
                    let next = bucketTime + step
                    let timestamps = frameDeltaValues
                        .filter { $0.0 >= bucketTime && $0.0 < next }
                        .map { $0.0 }
                    
                    let fps: Double
                    if timestamps.count >= 2 {
                        let duration = timestamps.last! - timestamps.first!
                        fps = duration > 0 ? Double(timestamps.count - 1) / duration : 0
                    } else {
                        fps = Double(timestamps.count)
                    }
                    
                    fpsBuckets.append((time: bucketTime, fps: fps))
                    bucketTime = next
                }
                
                return fpsBuckets
            }

            
        // Calculate min and max FPS from fps bucket
        let validTimes = frameTimes.compactMap { $0.3 > 0 ? $0.3 : nil }
        let fpsList = validTimes.map { 1.0 / $0 }
            var fpsBuckets = generateFPSBuckets(
                from: frameTimes.filter { $0.2 && $0.3 > 0 }.map { ($0.1, $0.3) },
                step: bucketSize
            )
        if fpsBuckets.count > 1 {
                fpsBuckets.removeLast()
        }
        let minFPS = fpsBuckets.map(\.fps).min() ?? 0
        let maxFPS = fpsBuckets.map(\.fps).max() ?? 0

        
            
            
        let compactLine = "\(indexInQueue): ✅  Processed \(frameTimes.count) frames 📊 FPS Avg: \(String(format: "%.2f", avgFPS)), Min: \(String(format: "%.2f", minFPS)), Max: \(String(format: "%.2f", maxFPS))"

        
        // Write results to CSV file
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
        
        // Export graph
        if (exportImage || exportAnimated || exportInteractive)  {
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
                    let bucket: Double
                    if response250msEnabled {
                        bucket = Double(Int(timestamp / 0.25)) * 0.25
                    } else {
                        bucket = floor(timestamp) // 1-second buckets
                    }

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
                
                // Drop the last, partial bucket
                if fpsTimeValues.count > 1 {
                    fpsTimeValues.removeLast()
                    fpsValues.removeLast()
                }
                
                let trimmedFpsTime = fpsTimeValues.map { String(format: "%.2f", $0) }
                let trimmedFpsValues = fpsValues.map { String(format: "%.2f", $0) }
                
            let outputHTMLPath = htmlOutputURL
            let imageOutputPath = imageOutputURL
                
                if exportInteractive {
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
                            line: { color: '\(cssHexNoAlpha)' }
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
                            line: { color: '\(cssHexNoAlpha)' }
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
                
                if exportImage {
                    // Image size: tall and high-res
                    let width = 6000
                    let height = 2000
                    let margin: CGFloat = 100
                    let graphHeight = (height - Int(margin) * 3) / 2
                    
                    let colorBg = NSColor.black
                    let colorLine1 = chosenNSColor
                    let colorLine2 = chosenNSColor
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
                            
                            
                            
                        } catch {
                            log("⚠️ Failed to write image: \(error.localizedDescription)")
                            
                            
                        }
                        
                    }
                }
                // Video with overlay render
            if exportAnimated {
                let outputVideoURL = overlayOutputURL
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
                    // trim off the last 0.25 s so that the last bucket (potentially wrong) is not displayed
                    let trimmedDuration = max(0, durationSeconds - bucketSize)
                    let totalFramesToWrite = Int(trimmedDuration * Double(nominalFrameRate))
                    let imageSize = CGSize(width: Int(renderSize.width), height: Int(renderSize.height))
                    let scaleBase: CGFloat = 1260.0
                    let graphScaleValue = min(max(userGraphScale, 50), 150)
                    let adjustedBase = scaleBase * (100.0 / graphScaleValue)
                    let scaleFactor = imageSize.height / adjustedBase
                    let windowDuration: Double = 5.0
                    
                    guard let writer = try? AVAssetWriter(outputURL: outputVideoURL, fileType: .mov) else {
                        log("❌ Failed to create AVAssetWriter for output.")
                        return outputLog
                    }
                    

                // Encoding tweaks for stability/perf (used only for H.264)
                let compressionProps: [String: Any] = [
                    AVVideoAverageBitRateKey: 12_000_000,
                    AVVideoExpectedSourceFrameRateKey: Int(nominalFrameRate),
                    AVVideoAllowFrameReorderingKey: false,
                    AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
                    AVVideoH264EntropyModeKey: AVVideoH264EntropyModeCABAC
                ]

                // Codec selection by string
                let selectedCodec: AVVideoCodecType = (codec == "ProRes")
                    ? AVVideoCodecType(rawValue: "apco")
                    : .h264

                var videoSettings: [String: Any] = [
                    AVVideoCodecKey: selectedCodec,
                    AVVideoWidthKey: Int(imageSize.width),
                    AVVideoHeightKey: Int(imageSize.height)
                ]

                // Only H.264 uses the compression properties dictionary
                if selectedCodec == .h264 {
                    videoSettings[AVVideoCompressionPropertiesKey] = compressionProps
                }
                    
                    let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
                    writerInput.expectsMediaDataInRealTime = false
                    writerInput.performsMultiPassEncodingIfSupported = false
                    
                    let sourceAttrs: [String: Any] = [
                        kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA),
                        kCVPixelBufferWidthKey as String: Int(imageSize.width),
                        kCVPixelBufferHeightKey as String: Int(imageSize.height),
                        kCVPixelBufferIOSurfacePropertiesKey as String: [:]
                    ]
                    
                    let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: writerInput,
                                                                       sourcePixelBufferAttributes: sourceAttrs)
                    writer.add(writerInput)
                    
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
                    
                    // ======= Precompute arrays and buckets to avoid per-frame rescans =======
                    let timestamps: [Double] = frameDeltaValues.map { $0.0 }
                    let deltas: [Double]     = frameDeltaValues.map { $0.1 }
                    
                    let bucketCount = max(1, Int(ceil(trimmedDuration / bucketSize)) + 1)
                    struct Bucket { var count: Int = 0; var first: Double = .infinity; var last: Double = -.infinity }
                    var buckets = Array(repeating: Bucket(), count: bucketCount)
                    for t in timestamps {
                        let b = min(bucketCount - 1, max(0, Int(t / bucketSize)))
                        buckets[b].count += 1
                        if t < buckets[b].first { buckets[b].first = t }
                        if t > buckets[b].last  { buckets[b].last  = t }
                    }
                    @inline(__always)
                    func fpsForBucket(_ b: Int) -> Double {
                        let bk = buckets[b]
                        if bk.count >= 2 {
                            let duration = bk.last - bk.first
                            return duration > 0 ? Double(bk.count - 1) / duration : Double(bk.count)
                        } else {
                            return Double(bk.count)
                        }
                    }
                    
                    // Sliding window indices for visible frametime points
                    var leftFT = 0
                    var rightFT = 0
                    
                    // ======= Cache drawing resources that don't change each frame =======
                    let colorSpace = CGColorSpaceCreateDeviceRGB()
                    let lineColor = chosenCGColor
                    let whiteCG = NSColor.white.cgColor
                    let blackNS = NSColor.black
                    
                    // Set up fonts and prebuilt CTLines for static labels
                    let fontFPSBoxSize: CGFloat = 58 * scaleFactor
                    let fontAxisLabelSize: CGFloat = 60 * scaleFactor
                    let fontFTTickSize: CGFloat = 22 * scaleFactor
                    let fontFPSTickSize: CGFloat = 25 * scaleFactor
                    
                    let fontMenloBoldFPSBox = CTFontCreateWithName("Menlo-Bold" as CFString, fontFPSBoxSize, nil)
                    let fontMenloBoldLabels = CTFontCreateWithName("Menlo-Bold" as CFString, fontAxisLabelSize, nil)
                    let fontMenloFTTicks    = CTFontCreateWithName("Menlo" as CFString, fontFTTickSize, nil)
                    let fontMenloFPSTicks   = CTFontCreateWithName("Menlo" as CFString, fontFPSTickSize, nil)
                    
                    let frametimeAttrStatic: [NSAttributedString.Key: Any] = [
                        .font: fontMenloBoldLabels,
                        .foregroundColor: NSColor.white,
                        .strokeColor: blackNS,
                        .strokeWidth: -2.0
                    ]
                    let fpsGraphAttrStatic: [NSAttributedString.Key: Any] = [
                        .font: fontMenloBoldLabels,
                        .foregroundColor: NSColor.white,
                        .strokeColor: blackNS,
                        .strokeWidth: -2.0
                    ]
                    let frametimeLabelLine = CTLineCreateWithAttributedString(NSAttributedString(string: "Frametime", attributes: frametimeAttrStatic))
                    let fpsGraphLabelLine  = CTLineCreateWithAttributedString(NSAttributedString(string: "FPS", attributes: fpsGraphAttrStatic))
                    
                    // Precompute static layout pieces
                    let fullGraphWidth = imageSize.width
                    let halfGraphWidth = imageSize.width / 2
                    
                    // Determine visible overlay region based on setting
                    let (graphAreaX, graphAreaWidth): (CGFloat, CGFloat) = {
                        if renderOneSideOnly {
                            switch overlayPosition {
                            case "Left":
                                return (0, halfGraphWidth)
                            case "Middle":
                                return (fullGraphWidth / 4, halfGraphWidth)
                            case "Right":
                                return (fullGraphWidth / 2, halfGraphWidth)
                            default:
                                return (0, halfGraphWidth)
                            }
                        } else {
                            return (0, fullGraphWidth)
                        }
                    }()
                    
                    let graphPadding: CGFloat = 60 * scaleFactor
                    let graphWidth = graphAreaWidth - 2 * graphPadding
                    let graphHeight = (imageSize.height / 6) * 0.65
                    let offsetX = graphAreaX + graphPadding  // shift graph drawing into the restricted region
                    let offsetY: CGFloat = 80 * scaleFactor  // spacing from bottom
                    
                    let ftGraphY = offsetY + graphHeight + 80 * scaleFactor
                    let fpsGraphY = offsetY
                    
                    let xScale = graphWidth / CGFloat(windowDuration)
                    
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
                                
                                // Advance sliding window indices without scanning the whole array
                                while leftFT < timestamps.count && timestamps[leftFT] < windowStart { leftFT += 1 }
                                while rightFT < timestamps.count && timestamps[rightFT] <= currentTime { rightFT += 1 }
                                
                                // Visible range is [leftFT ..< rightFT)
                                let visCount = max(0, rightFT - leftFT)
                                
                                if visCount == 0 {
                                    // No visible data for this frame; still advance to keep encoder pacing
                                    frameCount += 1
                                    return
                                }
                                
                                guard overlayReader.status == .reading,
                                      let sampleBuffer = overlayOutput.copyNextSampleBuffer(),
                                      let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                                    if overlayReader.status == .completed {
                                        writerInput.markAsFinished()
                                        writer.finishWriting {
                                            onComplete(compactLine)
                                        }
                                    } else if overlayReader.status == .failed {
                                        log("❌ OverlayReader error: \(overlayReader.error?.localizedDescription ?? "Unknown error")")
                                        onComplete(compactLine)
                                    } else {
                                        writerInput.markAsFinished()
                                        writer.finishWriting {
                                            onComplete(compactLine)
                                        }
                                    }
                                    return
                                }
                                
                                var pixelBuffer: CVPixelBuffer?
                                CVPixelBufferPoolCreatePixelBuffer(nil, adaptor.pixelBufferPool!, &pixelBuffer)
                                
                                guard let buffer = pixelBuffer else {
                                    frameCount += 1
                                    return
                                }
                                
                                // Directly copy the base frame into our destination buffer (avoid CI/CGImage creation)
                                CVPixelBufferLockBaseAddress(imageBuffer, .readOnly)
                                CVPixelBufferLockBaseAddress(buffer, [])
                                
                                let srcBase = CVPixelBufferGetBaseAddress(imageBuffer)!
                                let dstBase = CVPixelBufferGetBaseAddress(buffer)!
                                let srcBPR  = CVPixelBufferGetBytesPerRow(imageBuffer)
                                let dstBPR  = CVPixelBufferGetBytesPerRow(buffer)
                                let h       = CVPixelBufferGetHeight(buffer)
                                let rowBytes = min(srcBPR, dstBPR)
                                
                                for y in 0..<h {
                                    let src = srcBase.advanced(by: y * srcBPR)
                                    let dst = dstBase.advanced(by: y * dstBPR)
                                    memcpy(dst, src, rowBytes)
                                }
                                
                                // Create CGContext ON the destination buffer to draw overlays
                                guard let ctx = CGContext(
                                    data: dstBase,
                                    width: Int(imageSize.width),
                                    height: Int(imageSize.height),
                                    bitsPerComponent: 8,
                                    bytesPerRow: dstBPR,
                                    space: colorSpace,
                                    bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue
                                ) else {
                                    CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
                                    CVPixelBufferUnlockBaseAddress(buffer, [])
                                    frameCount += 1
                                    return
                                }
                                
                                
                                // === Frametime Graph ===
                                // Build from visible slice only (no global filter)
                                let visTs = timestamps[leftFT..<rightFT]
                                let visDt = deltas[leftFT..<rightFT]
                                
                                let maxDelta = visDt.max() ?? 1
                                let minDelta: Double = 0
                                let yScaleFT = graphHeight / CGFloat(maxDelta - minDelta)
                                
                                ctx.setStrokeColor(lineColor)
                                ctx.setLineWidth(2.5 * scaleFactor)
                                ctx.beginPath()
                                
                                // Enumerate only visible slice
                                var i = 0
                                var idx = leftFT
                                while idx < rightFT {
                                    let timestamp = timestamps[idx]
                                    let delta = deltas[idx]
                                    let x = offsetX + CGFloat(timestamp - (currentTime - windowDuration)) * xScale
                                    let y = ftGraphY + CGFloat(delta - minDelta) * yScaleFT
                                    if i == 0 {
                                        ctx.move(to: CGPoint(x: x, y: y))
                                    } else {
                                        ctx.addLine(to: CGPoint(x: x, y: y))
                                    }
                                    i += 1
                                    idx += 1
                                }
                                ctx.strokePath()
                                
                                // === FPS Graph ===
                                var fpsBuckets: [(time: Double, fps: Double)] = []
                                let startB = max(0, Int((currentTime - windowDuration) / bucketSize))
                                let endB   = min(bucketCount - 1, Int(currentTime / bucketSize))
                                fpsBuckets.reserveCapacity(max(0, endB - startB + 1))
                                if startB <= endB {
                                    for b in startB...endB {
                                        fpsBuckets.append((time: Double(b) * bucketSize, fps: fpsForBucket(b)))
                                    }
                                }

                                // keep only points inside the window and draw clamped to the windowStart
                                let visibleFpsPoints = fpsBuckets.filter {
                                    $0.time >= windowStart && $0.time <= currentTime
                                }

                                // Right-aligning the graph from the very first frame
                                let xWindowStart = currentTime - windowDuration   // may be negative early on

                                // clamp to zero whenever the FPS span is under 1
                                let windowFps = visibleFpsPoints.map { $0.fps }

                                var minFps = windowFps.min() ?? 0
                                let maxFps = windowFps.max() ?? 0

                                // only clamp when the *current* window’s span is under 1 FPS
                                if maxFps - minFps < 1 {
                                    minFps = 0
                                }

                                // compute the range (never zero)
                                var fpsRange = maxFps - minFps
                                if fpsRange == 0 { fpsRange = 1 }

                                // scale factor
                                let fpsYScale = graphHeight / CGFloat(fpsRange)

                                ctx.setStrokeColor(lineColor)
                                ctx.setLineWidth(2.5 * scaleFactor)
                                ctx.beginPath()

                                for (i, point) in visibleFpsPoints.enumerated() {
                                    // clamp time to real visible window
                                    let clampedTime = min(max(point.time, windowStart), currentTime)
                                    let x = offsetX + CGFloat(clampedTime - xWindowStart) * xScale
                                    let y = fpsGraphY + CGFloat(point.fps - minFps) * fpsYScale
                                    if i == 0 {
                                        ctx.move(to: CGPoint(x: x, y: y))
                                    } else {
                                        ctx.addLine(to: CGPoint(x: x, y: y))
                                    }
                                }
                                ctx.strokePath()


                                
                                // === Axes ===
                                ctx.setStrokeColor(whiteCG)
                                ctx.setLineWidth(1.0 * scaleFactor)
                                
                                // Y axes
                                ctx.stroke(CGRect(x: offsetX, y: ftGraphY, width: 0, height: graphHeight))
                                ctx.stroke(CGRect(x: offsetX, y: fpsGraphY, width: 0, height: graphHeight))
                                
                                // X axes
                                ctx.stroke(CGRect(x: offsetX, y: ftGraphY, width: graphWidth, height: 0))
                                ctx.stroke(CGRect(x: offsetX, y: fpsGraphY, width: graphWidth, height: 0))
                                
                                // === FPS Text Box ===
                                let currentBucket = floor(currentTime / bucketSize) * bucketSize
                                let fallbackFPS = visibleFpsPoints.last?.fps ?? 0
                                let rawFPS = visibleFpsPoints.first(where: { abs($0.time - currentBucket) < 0.001 })?.fps ?? fallbackFPS
                                
                                // round to nearest whole number, then display
                                let liveFPS = Int(round(rawFPS))
                                let fpsText = "Output FPS: \(liveFPS)"
                                
                                // Set up font and draw dynamic string
                                let fpsAttr: [NSAttributedString.Key: Any] = [
                                    .font: fontMenloBoldFPSBox,
                                    .strokeColor: blackNS,
                                    .foregroundColor: NSColor.white,
                                    .strokeWidth: -2.0
                                ]
                                let fpsAttrString = NSAttributedString(string: fpsText, attributes: fpsAttr)
                                ctx.textPosition = CGPoint(
                                    x: renderOneSideOnly ?
                                        (overlayPosition == "Left" ? 60 * scaleFactor :
                                         overlayPosition == "Middle" ? imageSize.width / 2 - 240 * scaleFactor :
                                         imageSize.width - 680 * scaleFactor) :
                                        imageSize.width - 680 * scaleFactor,
                                    y: imageSize.height - 120 * scaleFactor
                                )
                                CTLineDraw(CTLineCreateWithAttributedString(fpsAttrString), ctx)
                                
                                // === Add Frametime label ===
                                ctx.textPosition = CGPoint(x: offsetX + 20 * scaleFactor, y: ftGraphY + graphHeight + 10 * scaleFactor)
                                CTLineDraw(frametimeLabelLine, ctx)
                                
                                // === Add FPS label ===
                                ctx.textPosition = CGPoint(x: offsetX + 20 * scaleFactor, y: fpsGraphY + graphHeight + 10 * scaleFactor)
                                CTLineDraw(fpsGraphLabelLine, ctx)
                                
                                // === Frametime Y-axis scale marks ===
                                var uniqueFTValues = Set<Double>()
                                uniqueFTValues.reserveCapacity(visCount)
                                idx = leftFT
                                while idx < rightFT {
                                    let v = round(deltas[idx] * 10000) / 10 // matches your rounding
                                    uniqueFTValues.insert(v)
                                    idx += 1
                                }
                                
                                let ftRange = maxDelta - minDelta
                                let frametimeGraphHeight: CGFloat = graphHeight
                                let frametimeYScale: CGFloat = ftRange != 0 ? frametimeGraphHeight / CGFloat(ftRange) : 1.0
                                var lastFtLabelY: CGFloat = -CGFloat.infinity
                                let minFtSpacing: CGFloat = 28.0 * scaleFactor
                                
                                for value in uniqueFTValues.sorted() {
                                    let y = ftGraphY + CGFloat((value / 1000.0) - minDelta) * frametimeYScale
                                    if abs(y - lastFtLabelY) < minFtSpacing { continue }
                                    lastFtLabelY = y
                                    
                                    let tickStart = CGPoint(x: offsetX - 5 * scaleFactor, y: y)
                                    let tickEnd = CGPoint(x: offsetX, y: y)
                                    ctx.setStrokeColor(whiteCG)
                                    ctx.setLineWidth(1.0 * scaleFactor)
                                    ctx.beginPath()
                                    ctx.move(to: tickStart)
                                    ctx.addLine(to: tickEnd)
                                    ctx.strokePath()
                                    
                                    let label = String(format: "%.1f", value)
                                    let attributes: [NSAttributedString.Key: Any] = [
                                        .font: fontMenloFTTicks,
                                        .foregroundColor: NSColor.white,
                                        .strokeColor: blackNS,
                                        .strokeWidth: -2.0
                                    ]
                                    let attrText = NSAttributedString(string: label, attributes: attributes)
                                    ctx.textPosition = CGPoint(x: offsetX - 57 * scaleFactor, y: y - 8 * scaleFactor)
                                    CTLineDraw(CTLineCreateWithAttributedString(attrText), ctx)
                                }
                                
                                // === FPS Y-axis scale marks ===
                                var uniqueFPSValues = Set<Double>()
                                uniqueFPSValues.reserveCapacity(visibleFpsPoints.count)
                                for p in visibleFpsPoints {
                                    uniqueFPSValues.insert(round(p.fps))
                                }
                                var lastFpsLabelY: CGFloat = -CGFloat.infinity
                                let minFpsSpacing: CGFloat = 28.0 * scaleFactor
                                
                                for value in uniqueFPSValues.sorted() {
                                    let y = fpsGraphY + (CGFloat(value - minFps) * fpsYScale)
                                    if abs(y - lastFpsLabelY) < minFpsSpacing { continue }
                                    lastFpsLabelY = y
                                    
                                    let tickStart = CGPoint(x: offsetX - 5 * scaleFactor, y: y)
                                    let tickEnd = CGPoint(x: offsetX, y: y)
                                    ctx.setStrokeColor(whiteCG)
                                    ctx.setLineWidth(1.0)
                                    ctx.beginPath()
                                    ctx.move(to: tickStart)
                                    ctx.addLine(to: tickEnd)
                                    ctx.strokePath()
                                    
                                    let label = String(format: "%.0f", value)
                                    let attributes: [NSAttributedString.Key: Any] = [
                                        .font: fontMenloFPSTicks,
                                        .foregroundColor: NSColor.white,
                                        .strokeColor: blackNS,
                                        .strokeWidth: -2.0
                                    ]
                                    let attrText = NSAttributedString(string: label, attributes: attributes)
                                    ctx.textPosition = CGPoint(x: offsetX - 40 * scaleFactor, y: y - 8 * scaleFactor)
                                    CTLineDraw(CTLineCreateWithAttributedString(attrText), ctx)
                                }
                                
                                // Unlock buffers now that drawing is done
                                CVPixelBufferUnlockBaseAddress(imageBuffer, .readOnly)
                                CVPixelBufferUnlockBaseAddress(buffer, [])
                                
                                // Extra safety: check isReadyForMoreMediaData again before appending
                                if writerInput.isReadyForMoreMediaData {
                                    let presentationTime = CMTime(value: CMTimeValue(frameCount), timescale: CMTimeScale(nominalFrameRate))
                                    adaptor.append(buffer, withPresentationTime: presentationTime)
                                }
                                
                                frameCount += 1
                            }
                        }
                        
                        if frameCount >= totalFramesToWrite {
                            writerInput.markAsFinished()
                            writer.finishWriting {
                                onComplete(compactLine)
                            }
                        }
                    }
                }


            }





            
            
            
            
            
        if exportCsvFrametimes {
            var lines: [String] = ["time_s,frametime_ms"]
            for (_, ts, isChange, delta) in frameTimes where isChange && delta > 0 {
                lines.append(String(format: "%.4f,%.4f", ts, delta * 1000.0))
            }
            do {
                try lines.joined(separator: "\n").write(to: frametimeCSVURL, atomically: true, encoding: .utf8)
            } catch {
                log("⚠️ Error writing frametime CSV: \(error.localizedDescription)")
            }
        }

        if reportStats {
            do {
                try statBlock.joined(separator: "\n").write(to: summaryCSVURL, atomically: true, encoding: .utf8)
            } catch {
                log("⚠️ Error writing summary CSV: \(error.localizedDescription)")
            }
        }
            
        if !exportAnimated {
            onComplete(compactLine)
            return compactLine
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
                bitmapInfo: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue

            )

            if let ctx = context {
                ctx.draw(cgImage, in: CGRect(origin: .zero, size: size))
            }

            CVPixelBufferUnlockBaseAddress(buffer, [])
            return buffer
        }

            func safeFinishWriting(_ writer: AVAssetWriter, _ writerInput: AVAssetWriterInput, _ outputURL: URL, _ outputLog: String, _ onComplete: @escaping (String) -> Void) {
                if writer.status == .writing {
                    writerInput.markAsFinished()
                    writer.finishWriting {
                        onComplete(compactLine)
                    }
                } else {
                    print("⚠️ Tried to finish writing but writer was not in .writing state (status: \(writer.status.rawValue))")
                    onComplete(compactLine)
                }
            }

          
            // Detects whether identified tearing is incorrect
            func isRegionBlack(_ buffer: vImage_Buffer) -> Bool {
                let pixels = buffer.data.assumingMemoryBound(to: UInt8.self)
                let height = Int(buffer.height)
                let width = Int(buffer.width)
                let rowBytes = buffer.rowBytes

                var sum: UInt64 = 0
                var sumSq: UInt64 = 0
                var count = 0

                var rowLuminanceStart: UInt64 = 0
                var rowLuminanceEnd: UInt64 = 0
                var horizontalEdge: Int = 0
                var verticalEdge: Int = 0
                var rowMeans: [Float] = Array(repeating: 0.0, count: height)

                for y in 0..<height {
                    var rowSum: UInt64 = 0
                    for x in 0..<width {
                        let offset = y * rowBytes + x
                        let value = UInt64(pixels[offset])
                        sum += value
                        sumSq += value * value
                        rowSum += value
                        count += 1

                        if x > 0 {
                            let left = y * rowBytes + (x - 1)
                            horizontalEdge += abs(Int(pixels[offset]) - Int(pixels[left]))
                        }

                        if y > 0 {
                            let above = (y - 1) * rowBytes + x
                            verticalEdge += abs(Int(pixels[offset]) - Int(pixels[above]))
                        }
                    }

                    rowMeans[y] = Float(rowSum) / Float(width)

                    if y == 0 { rowLuminanceStart = rowSum }
                    if y == height - 1 { rowLuminanceEnd = rowSum }
                }

                let mean = Float(sum) / Float(count)
                let variance = Float(sumSq) / Float(count) - mean * mean
                let stddev = sqrt(variance)
                let luminanceGradient = abs(Float(rowLuminanceStart) - Float(rowLuminanceEnd)) / Float(width)
                let avgEdgeStrength = Float(horizontalEdge + verticalEdge) / Float(2 * width * (height - 1))

                let directionRatio = abs(Float(horizontalEdge - verticalEdge)) / max(1.0, Float(horizontalEdge + verticalEdge))

                // Tearing cues
                var maxRowJump: Float = 0
                var midFrameJump: Float = 0
                for i in 1..<height {
                    let jump = abs(rowMeans[i] - rowMeans[i - 1])
                    if jump > maxRowJump { maxRowJump = jump }
                    if abs(i - height / 2) < height / 6 {
                        if jump > midFrameJump { midFrameJump = jump }
                    }
                }

                // Adaptive lowTexture
                let contrastBoostedEdge = avgEdgeStrength / (stddev + 1.0)
                let lowTexture = contrastBoostedEdge < 0.04

                let isDark = mean < 16.0
                let isFlat = stddev < 6.0
                let baseBlack = isDark && isFlat && lowTexture

                let baseThreshold: Float = 1.5
                let adaptiveBoost = min(stddev / 8.0, 1.5)
                let pixelDiffThreshold = baseThreshold + adaptiveBoost

                let strongTearLine = maxRowJump > pixelDiffThreshold || midFrameJump > (pixelDiffThreshold * 0.75)


                // Fallback cue for strong visual signal
                let strongVisualCue = stddev > 20.0 || avgEdgeStrength > 1.0 || luminanceGradient > 10.0

                let shouldBlock = !strongTearLine && !strongVisualCue

                print("""
                [Filter Debug]
                mean: \(mean), stddev: \(stddev), luminanceGradient: \(luminanceGradient)
                avgEdgeStrength: \(avgEdgeStrength), contrastBoostedEdge: \(contrastBoostedEdge), directionRatio: \(directionRatio)
                maxRowJump: \(maxRowJump), midFrameJump: \(midFrameJump)
                isDark: \(isDark), isFlat: \(isFlat), lowTexture: \(lowTexture)
                baseBlack: \(baseBlack), strongTearLine: \(strongTearLine), strongVisualCue: \(strongVisualCue)
                -> shouldBlock: \(shouldBlock)
                """)

                return shouldBlock
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
        

        
    }
    
    public static func hasClusterDifference(_ a: vImage_Buffer, _ b: vImage_Buffer) -> Bool {
        let w = Int(a.width), h = Int(a.height)
        let ptrA = a.data!.assumingMemoryBound(to: UInt8.self)
        let ptrB = b.data!.assumingMemoryBound(to: UInt8.self)
        let blockSize = 4
        let numX = w / blockSize, numY = h / blockSize
        let pixelsNeeded = blockSize * blockSize / 2 + 1

        // build changed‐block map
        var changed = [[Bool]](
          repeating: [Bool](repeating: false, count: numX),
          count: numY
        )
        var totalChanged = 0
        for by in 0..<numY {
          for bx in 0..<numX {
            var cnt = 0
            let baseY = by * blockSize, baseX = bx * blockSize
            for y in 0..<blockSize where cnt < pixelsNeeded {
              let row = (baseY + y) * w
              for x in 0..<blockSize {
                let idx = row + baseX + x
                if abs(Int(ptrA[idx]) - Int(ptrB[idx])) >= 4 {
                  cnt += 1
                  if cnt >= pixelsNeeded { break }
                }
              }
            }
            if cnt >= pixelsNeeded {
              changed[by][bx] = true
              totalChanged += 1
            }
          }
        }
        if totalChanged == 0 { return false }

        // count how many changed blocks have ≥1 changed neighbor
        var clustered = 0
        for by in 0..<numY {
          for bx in 0..<numX where changed[by][bx] {
            outer: for dy in -1...1 {
              for dx in -1...1 where (dy != 0 || dx != 0) {
                let ny = by + dy, nx = bx + dx
                if ny >= 0, ny < numY, nx >= 0, nx < numX, changed[ny][nx] {
                  clustered += 1
                  break outer
                }
              }
            }
          }
        }

        // require ≥75% of changed blocks to be clustered
        return Double(clustered) / Double(totalChanged) >= 0.50
    }













    
    
    
    
}


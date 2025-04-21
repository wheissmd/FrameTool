# Changelog

## Alpha [0.1.0] - 2025-04-21
### Added
- Moved back end to swift, dramatic increase of performance and RAM utilization efficiency
- Added options
  - 'Report statistics to csv' - Statistic report, general or detailed
  - 'Export graph' - Visual representation of the analyzed performance, options to export include
      - 'Image' - Renders an image with graphs representing the frame times in the video
      - 'Interactive' - Outputs an interactive HTML graph with all the data
      - 'Animated Overlay' - Renders an overlay of the graphs on top of provided video
  - 'Measure Processing Time' - Measures total time of processing
- Increased Accuracy of readings and statistics
- Improved UI

## early-prototype [0.0.2] - 2025-04-17
### Added
- Toggle for enabling/disabling multithreading
- Option to choose custom csv export path
- Settings interface with RAM usage warning
- Switched to SwiftUI front-end

## early-prototype [0.0.1] - 2025-04-15
### Initial Release
- Core video analysis
- CSV export
- DMG packaging with background and test file

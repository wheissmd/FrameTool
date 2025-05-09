# Changelog

## Alpha [0.2.2] - 2025-05-10
### Added
- Custom graph scaling option for Animated Overlay
- Option to render the graph on only half of the frame in Animated Overlay
### Improved
- Frametime labels location was wrong, fixed
- Text had no outline and was barely readable on light backgrounds, fixed
- Slightly reduced window size for better display on smaller macbooks (like M1 Air)

## Alpha [0.2.1] - 2025-05-03
### Improved
- Animated Overlay reporting 0 FPS in some frames bug fixed
- Animated Overlay now scales properly to any 16:9 resolution, text no longer huge in 720p or small in 4K

## Alpha [0.2.0] - 2025-05-02
### Added
- Early Prototype of a screen tearing detection system
- Animated Overlay GPU render (Significantly increases performance)
- Proper settings menu, config support
- Themes with vocaloids
### Improved
- UI was reworked to support different themes, logically organize options, include settings descriptions
- Fixed multiple bugs
- Improved min and max FPS statistics to work with FPS quarter second bucket rather than rely on longest or shortest frame

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

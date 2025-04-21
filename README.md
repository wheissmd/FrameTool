# FrameTool

**FrameTool** is a macOS application for analyzing whether a video contains dropped (duplicated) frames. It’s primarily intended for evaluating game performance via recorded output but can be applied to other scenarios as well (i. e. Dropped frames in recordings from camera).

---

## App Purpose

FrameTool is designed to identify **dropped or duplicated frames** in a video file. This is often used to analyze gaming performance based on captured footage.

The app calculates:

- **Average FPS**
- **Minimum FPS**
- **Maximum FPS**
- **Exports csv Table with every frame's display time**

These calculations are based solely on the **frame time that was captured**, and do **not reflect internal game engine behavior**. As such, FrameTool's readings do **not directly compare to** tools like MSI Afterburner or Fraps.

### Installation and Usage
Installation of the app:
1. Open DMG
2. Drag the app to the application folder

Using FrameTool is simple:
1. Launch the app
2. Set up the output location (defaults to user/Documents)
3. Set up additional exports you would like (CSV statistics or Graph Output)
4. Drop a video file to a drag and drop section
5. Press "Run Analysis"
6. Wait for the analysis to complete
7. Once done, you can drag and drop another video to analyze

A test sample video is provided within the `.dmg` installer to demonstrate how the tool works.

> ⚠️ **Note:** Analysis can take a significant amount of time, especially for videos longer than 2 minutes or on lower-end machines. Outputing "Animated Overlay" significantly increases the analysis time even further.

> ⚠️ **Important:** The analyzed video must be free of screen tearing. Any tearing will cause the app to falsely detect new frames. Poor bitrate of the video might also result in falsely detecting new frames, it is not recommended to process the videos recorded on Intel Arc by its own codec (AMD and Nvidia is fine as long as its reasonable bitrate). Additionally, the app does **not** report FPS values higher than the framerate the video was recorded at.

---

## System Requirements

- Tested on **Apple Silicon Macs only**, however the v0.1.0 **may** run on **Intel-based Macs**
- **8GB RAM recommended** for Single threading processing
- **16GB RAM recommended** for Multithreading accelleration for videos under 1 minute long
- **24GB RAM recommended** for Multithreading accelleration for videos over 1 minute long
- macOS Sequoia 15.1 or newer for v0.1.0 (on earlier macOS versions you can still run a basic version v0.0.1)

---

## Features

- Video frametime analysis with with min, max and avg FPS output
- Generation of csv files with times of every frame
- Detailed statistics csv output
- Graphical visualization of frame time and fps, that can either be rendered as image, interactive HTML graph or Animated overlay on top of the provided video source
- Processing time tracker
  
---

## Future Development

- Multiple bugfixes
- Addition of customizable graph output designs
- Animated Overlay render optimization
- Better statististics output options
- Ability to run multiple graph outputs for a single analysis
- Windows port with different UI framework
  
---

## Included in the DMG

The `.dmg` installer includes:
- `FrameTool.app`
- A test video (`SampleForTesting.mp4`)
- An alias to the Applications folder for easy installation

---

## License

This project is licensed under a **custom license**:

- You may **use**, **modify**, and **redistribute** the software (with attribution)
- You may **not sell** this software or any modified version
- Commercial use as part of a larger product is permitted (as long as FrameTool itself is not sold directly)

See `LICENSE.md` for full details.

---

## Credits

- Built with assistance from **ChatGPT (OpenAI)**  
- Packaged using xCode, UI is designed using SwiftUI 
- Developed in **Swift**, using:
  - `AVFoundation`
  - `CoreImage`
  - `Accelerate`
  - `AppKit`
  - `CoreText`
- Developed and tested in **xCode** on macOS

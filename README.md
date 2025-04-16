# FrameTool

**FrameTool** is a macOS application for analyzing whether a video contains dropped (duplicated) frames. It’s primarily intended for evaluating game performance via recorded output but can be applied to other scenarios as well.

---

## App Purpose

FrameTool is designed to identify **dropped or duplicated frames** in a video file. This is often used to analyze gaming performance based on captured footage.

The app calculates:

- **Average FPS**
- **Minimum FPS**
- **Maximum FPS**
- **Exports csv Table with every frame's display time**

These calculations are based solely on the **shortest and longest time a frame was displayed**, and do **not reflect internal engine behavior**. As such, FrameTool's readings do **not directly compare to** tools like MSI Afterburner or Fraps.

### Usage
Using FrameTool is simple:
1. Launch the app
2. Select a video file from the popup window
3. Wait for the analysis to complete
4. Once done, you can drag and drop another video to analyze

> ⚠️ **Note:** Analysis can take a significant amount of time, especially for videos longer than 2 minutes or on lower-end machines.

A test sample video is provided within the `.dmg` installer to demonstrate how the tool works.

> ⚠️ **Important:** The analyzed video must be free of screen tearing. Any tearing will cause the app to falsely detect new frames. Additionally, the app does **not** report FPS values higher than the framerate the video was recorded at.

---

## System Requirements

- Currently supports **Apple Silicon Macs only**
- **16GB RAM recommended**, especially for longer videos (due to frame preloading and multithreaded processing)

The FrameTool is built in **pure Python**, so it may be possible to run it on **Intel-based Macs** by:
- Installing an Intel-compatible standalone Python build within the app's directory
- Modifying the script to use your system's Python environment

---

## Future Development

FrameTool is currently a prototype built in Python, which was chosen for rapid development and experimentation.

In the future, the app will likely be **rewritten in Swift**, which will:
- Greatly improve performance
- Reduce memory usage
- Improve responsiveness on lower-end machines

If you're considering integrating FrameTool into a production workflow, especially on less powerful systems, you may prefer to wait for the Swift-based release.

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
- Packaged using **Platypus**: https://sveinbjorn.org/platypus  
- Developed in **Python**, using:
  - `opencv-python`
  - `numpy`
- Developed and tested in **Nova** on macOS

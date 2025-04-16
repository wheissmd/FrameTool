
import cv2
import numpy as np
import csv
import sys
import os
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

# === CONFIG ===
threshold = 5.0  # MSE threshold

#print("Args:", sys.argv)

video_path = sys.argv[1]
export_dir = sys.argv[2].strip()
output_csv = os.path.join(export_dir, "frametime_output.csv")
MULTITHREADING_ENABLED = sys.argv[3].strip() == "1"
export_path = os.path.join(export_dir, "frametime_output.csv")

if not export_path:
    export_path = os.path.expanduser("~/Documents")

output_file_path = os.path.join(export_path, "frametimes_parallel.csv")

if "--no-multithread" in sys.argv:
    MULTITHREADING_ENABLED = False

# === VIDEO LOAD ===
if len(sys.argv[1]) <= 1:
    print("❌ Error: No video file provided.")
    sys.exit(1)

video_path = sys.argv[1]
if not os.path.isfile(video_path):
    print(f"❌ Error: File '{video_path}' does not exist.")
    sys.exit(1)

cap = cv2.VideoCapture(video_path)
fps_from_video = cap.get(cv2.CAP_PROP_FPS)
frame_count = int(cap.get(cv2.CAP_PROP_FRAME_COUNT))

# === FUNCTIONS ===
def mse(img1, img2):
    return np.mean((img1.astype("float") - img2.astype("float")) ** 2)

def compare_frames(pair):
    i, prev, curr = pair
    diff = mse(prev, curr)
    return (i, diff)

# === MAIN LOGIC ===
frametimes = []
prev_frame = None
frame_number = 0
frame_timestamps = []

print("📦 Loading frames into memory..." if MULTITHREADING_ENABLED else "🔁 Processing frames sequentially...")
frames = []

while True:
    ret, frame = cap.read()
    if not ret:
        break
    gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
    frames.append(gray)
    frame_number += 1
cap.release()

print(f"✅ Loaded {len(frames)} frames")

if MULTITHREADING_ENABLED:
    print("🧠 Analyzing frame deltas in parallel...")

    pairs = [(i, frames[i - 1], frames[i]) for i in range(1, len(frames))]
    with ThreadPoolExecutor() as executor:
        results = list(executor.map(compare_frames, pairs))

    frametimes = [[0, 0, True, 0]]  # First frame
    last_change_idx = 0

    for i, diff in results:
        if diff > threshold:
            delta_ms = ((i - last_change_idx) / fps_from_video) * 1000
            frametimes.append([i, i * (1000 / fps_from_video), True, delta_ms])
            last_change_idx = i
        else:
            frametimes.append([i, i * (1000 / fps_from_video), False, 0])

else:
    print("🧠 Analyzing frame deltas sequentially...")

    frametimes = []
    last_change_idx = 0

    for i in range(len(frames)):
        current = frames[i]
        if i == 0:
            frametimes.append([i, 0, True, 0])
            prev_frame = current
            continue

        diff = mse(prev_frame, current)
        if diff > threshold:
            delta_ms = ((i - last_change_idx) / fps_from_video) * 1000
            frametimes.append([i, i * (1000 / fps_from_video), True, delta_ms])
            last_change_idx = i
        else:
            frametimes.append([i, i * (1000 / fps_from_video), False, 0])
        prev_frame = current

# === STATS & CSV ===
valid_deltas = [row[3] for row in frametimes if row[2]]
non_zero_deltas = [d for d in valid_deltas if d > 0]

if non_zero_deltas:
    avg_fps = 1000 / (sum(non_zero_deltas) / len(non_zero_deltas))
    min_fps = 1000 / max(non_zero_deltas)
    max_fps = 1000 / min(non_zero_deltas)
else:
    avg_fps = min_fps = max_fps = 0


with open(output_csv, "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["Frame", "Time (ms)", "Changed", "DeltaMS"])
    for row in frametimes:
        writer.writerow(row)

print(f"📊 Total Frames: {len(frametimes)}")
print(f"📊 Average FPS: {avg_fps:.2f}")
print(f"📊 Min FPS: {min_fps:.2f}")
print(f"📊 Max FPS: {max_fps:.2f}")
print(f"✅ Done! Results saved to: {output_csv}")
print(f"📁 Using video file: {video_path}")
print(f"⚠️ WARNING! This is the early prototype version, it's full of bugs and provide false positive result if feeded with video full of screen tearing!")
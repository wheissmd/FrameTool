import cv2
import numpy as np
import csv
import sys
import os
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor

# === ENTRY VALIDATION ===
if len(sys.argv) <= 1:
	print("❌ Error: No input video file provided.")
	sys.exit(1)

video_path = sys.argv[1]
if not os.path.isfile(video_path):
	print(f"❌ Error: File '{video_path}' does not exist.")
	sys.exit(1)

# === CONFIG ===
output_csv = str(Path.home() / "Documents" / "frametimes_parallel.csv")
threshold = 5.0  # MSE threshold

def mse(img1, img2):
	err = np.sum((img1.astype("float") - img2.astype("float")) ** 2)
	err /= float(img1.shape[0] * img1.shape[1])
	return err

# === LOAD VIDEO ===
cap = cv2.VideoCapture(video_path)
if not cap.isOpened():
	print(f"❌ Failed to open video file '{video_path}'")
	sys.exit(1)

fps_from_video = cap.get(cv2.CAP_PROP_FPS)
if fps_from_video == 0:
	print("❌ Could not retrieve FPS from video.")
	sys.exit(1)

frames = []
timestamps = []
grays = []

print("📦 Loading frames into memory...")
while True:
	success, frame = cap.read()
	if not success:
		break
	timestamp = cap.get(cv2.CAP_PROP_POS_MSEC)
	gray = cv2.cvtColor(frame, cv2.COLOR_BGR2GRAY)
	frames.append(frame)
	timestamps.append(timestamp)
	grays.append(gray)

cap.release()
print(f"✅ Loaded {len(frames)} frames")

# === FRAME ANALYSIS ===
frametimes = []
last_change_time = timestamps[0]
frametimes.append([0, timestamps[0], True, 0.0])

for i in range(1, len(frames)):
	mse_val = mse(grays[i], grays[i - 1])
	is_new = mse_val > threshold
	if is_new:
		delta = timestamps[i] - last_change_time
		last_change_time = timestamps[i]
	else:
		delta = 0.0
	frametimes.append([i, timestamps[i], is_new, delta])

# === SAVE CSV ===
with open(output_csv, mode="w", newline="") as f:
	writer = csv.writer(f)
	writer.writerow(["Frame", "Time (ms)", "Changed", "DeltaMS"])
	for row in frametimes:
		writer.writerow(row)

# === SUMMARY ===
delta_values = [row[3] for row in frametimes if row[3] > 0]
if delta_values:
	total_time_sec = len(frames) / fps_from_video
	avg_fps = len(delta_values) / (total_time_sec)
	min_fps = 1000.0 / max(delta_values)
	max_fps = 1000.0 / min(delta_values)

	print(f"📊 Total Frames: {len(frames)}")
	print(f"🕒 Duration: {total_time_sec:.2f} seconds")
	print(f"📊 Average FPS: {avg_fps:.2f}")
	print(f"📊 Min FPS (longest frame): {min_fps:.2f}")
	print(f"📊 Max FPS (shortest frame): {max_fps:.2f}")
else:
	print("⚠️ Not enough valid frame changes for FPS calculation.")

print(f"✅ Done! Results saved to: {output_csv}")
print(f"📁 Using video file: {os.path.abspath(video_path)}")
print(f"⚠️ WARNING! This is the early prototype version, it's full of bugs and provide false positive result if feeded with video full of screen tearing!")
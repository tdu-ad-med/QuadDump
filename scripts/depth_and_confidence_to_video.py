import numpy as np
import cv2
import ctypes
import zlib
import os

date = "2021-06-05_23-40-22"

def load_frames(path, w, h, t):
    files = os.listdir(path)
    files = list(sorted(files, key=lambda x: int(x)))
    files = list(map(lambda x: os.path.join(path, x), files))
    frames = []
    for file in files:
        with open(file, 'rb') as f:
            data = f.read()
            data = zlib.decompress(data, -15)
            frame = np.frombuffer(data, t).reshape(h, w).copy()
            frames.append(frame)
    frames = np.array(frames)
    frames = np.nan_to_num(frames, 0)
    return frames

depth_frames = load_frames("./Documents/" + date + "/depth", 256, 192, np.float32)
frame_count, h, w = depth_frames.shape
minim = np.min(depth_frames[np.nonzero(depth_frames)])
maxim = depth_frames.max()
diff = maxim - minim
depth_frames = 255.0 * (depth_frames - minim) / (maxim - minim)
depth_frames[depth_frames < 0.0] = 0.0
depth_frames = depth_frames.astype('uint8')

confidence_frames = load_frames("./Documents/" + date + "/confidence", 256, 192, np.uint8)
confidence_frames = (255 * confidence_frames / 3).astype('uint8')

FPS = 60
fourcc = cv2.VideoWriter_fourcc(*'mp4v')
depth = cv2.VideoWriter('depth.mp4',fourcc, FPS, (w, h))
confidence = cv2.VideoWriter('confidence.mp4',fourcc, FPS, (w, h))

for i in range(frame_count):
    depth.write(cv2.cvtColor(depth_frames[i,:,:], cv2.COLOR_GRAY2BGR))
    confidence.write(cv2.cvtColor(confidence_frames[i,:,:], cv2.COLOR_GRAY2BGR))

depth.release()
confidence.release()

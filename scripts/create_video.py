import numpy as np
import cv2
import ctypes
import zlib
import os
import math
from numba import jit
import json

@jit
def to_colorful(num):
    num = math.log(num)
    fill = 0.0 if ((num * 10.0) - math.floor(num * 10.0) < 0.6) else 1.0
    num = (num - math.floor(num)) * 6.0
    color = [0.0, 0.0, 0.0]
    if num < 1.0:
        color = [1.0, num, 0.0]
    elif 1.0 <= num < 2.0:
        color = [2.0 - num, 1.0, 0.0]
    elif 2.0 <= num < 3.0:
        color = [0.0, 1.0, num - 2.0]
    elif 3.0 <= num < 4.0:
        color = [0.0, 4.0 - num, 1.0]
    elif 4.0 <= num < 5.0:
        color = [num - 4.0, 0.0, 1.0]
    else:
        color = [1.0, 0.0, 6.0 - num]

    return (np.array(color, dtype=np.float32) * 255 * fill).astype(np.uint8)

@jit
def to_colorful_frame(frame, scale):
    result = np.zeros((frame.shape[0], frame.shape[1], 3), dtype=np.uint8)
    for y, py in enumerate(result):
        for x, p in enumerate(py):
            result[y][x] = np.flip(to_colorful(frame[y][x] * scale))
    return result

@jit
def only_confidence(depth, confidence):
    for y, py in enumerate(depth):
        for x, p in enumerate(py):
            if confidence[y][x] != 2:
                depth[y][x] = 0.0

def make_video_frame(color, depth, confidence):
    only_confidence(depth, confidence)
    depth = to_colorful_frame(depth, 2.0)
    depth = cv2.resize(depth, (color.shape[1], color.shape[0]))
    result = cv2.addWeighted(src1=color, alpha=0.5, src2=depth, beta=0.5, gamma=0)
    return result

video_infomation = {}
with open("../info.json", "rb") as f:
    video_infomation = json.loads(f.read())
color_width = video_infomation["camera.mp4"]["width"]
color_height = video_infomation["camera.mp4"]["height"]
depth_width = video_infomation["depth"]["width"]
depth_height = video_infomation["depth"]["height"]
confidence_width = video_infomation["confidence"]["width"]
confidence_height = video_infomation["confidence"]["height"]

positions = []
with open("../cameraFrameInfo", "rb") as f:
    while f.read(1):
        f.seek(-1, 1)
        positions.append({
            "frameNumber"      : np.frombuffer(f.read(8*1), dtype=np.uint64, count=1)[0],
            "timestamp"        : np.frombuffer(f.read(8*1), dtype=np.float64, count=1)[0],
            "exists"           : np.frombuffer(f.read(1*3), dtype=np.uint8, count=3),
            "intrinsics"       : np.frombuffer(f.read(4*3*3), dtype=np.float32, count=3*3).reshape(3, 3).copy(),
            "projectionMatrix" : np.frombuffer(f.read(4*4*4), dtype=np.float32, count=4*4).reshape(4, 4).copy(),
            "viewMatrix"       : np.frombuffer(f.read(4*4*4), dtype=np.float32, count=4*4).reshape(4, 4).copy()
        })

video = cv2.VideoCapture("../camera.mp4")
depth_data = open("../depth", "rb")
confidence_data = open("../confidence", "rb")

offset = positions[0]["timestamp"]

FPS = 60
fourcc = cv2.VideoWriter_fourcc(*"mp4v")
writer = cv2.VideoWriter("result.mp4", fourcc, FPS, (color_width, color_height))

actual_timestamp = video.get(cv2.CAP_PROP_POS_MSEC) * 0.001 + offset
for frame in positions:
    number = frame["frameNumber"]
    timestamp = frame["timestamp"]
    try:
        print("frame {} / {}".format(int(number), positions[-1]["frameNumber"]))

        if frame["exists"][0] == 1:
            ret, color = video.read()

        if frame["exists"][1] == 1:
            zlib_size = np.frombuffer(depth_data.read(8*1), dtype=np.uint64, count=1)[0]
            depth = depth_data.read(zlib_size)
            depth = zlib.decompress(depth, -15)
            depth = np.frombuffer(depth, np.float32).reshape(depth_height, depth_width).copy()

        if frame["exists"][2] == 1:
            zlib_size = np.frombuffer(confidence_data.read(8*1), dtype=np.uint64, count=1)[0]
            confidence = confidence_data.read(zlib_size)
            confidence = zlib.decompress(confidence, -15)
            confidence = np.frombuffer(confidence, np.uint8).reshape(confidence_height, confidence_width).copy()

        if frame["exists"][0] == 1 and frame["exists"][1] == 1 and frame["exists"][2]:
            result = make_video_frame(color, depth, confidence)
            writer.write(result)

        else:
            print("skip frame {}".format(int(number + 1)))

    except FileNotFoundError:
        print("skip depth frame {}".format(number))

writer.release()
depth_data.close()
video.release()

import numpy as np
import cv2
import ctypes
import zlib
import os

date = "2021-06-06_09-21-57"

def load_positions(path):
    result = []
    with open(path, 'rb') as f:
        while f.read(1):
            f.seek(-1, 1)
            result.append({
                "frameNumber"      : len(result),
                "timestamp"        : np.frombuffer(f.read(8*1), dtype=np.float64, count=1)[0],
                "intrinsics"       : np.frombuffer(f.read(4*3*3), dtype=np.float32, count=3*3).reshape(3, 3).copy(),
                "projectionMatrix" : np.frombuffer(f.read(4*4*4), dtype=np.float32, count=4*4).reshape(4, 4).copy(),
                "viewMatrix"       : np.frombuffer(f.read(4*4*4), dtype=np.float32, count=4*4).reshape(4, 4).copy()
            })
    return result

def print_mat(mat):
    for y in mat:
        text = ""
        for x in y:
            text += "\t{:.2g}".format(x)
        print(text)

positions = load_positions("./Documents/" + date + "/cameraPosition")

for p in positions:
    print("frameNumber: {}".format(p["frameNumber"]))
    print("timestamp: {}".format(p["timestamp"]))
    print("intrinsics:")
    print_mat(p["intrinsics"])
    print("projection:")
    print_mat(p["projectionMatrix"])
    print("view:")
    print_mat(p["viewMatrix"])
    print("============================================")

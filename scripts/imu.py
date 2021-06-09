import numpy as np

with open("../imu", "rb") as f:
    while f.read(1):
        f.seek(-1, 1)
        text = ""
        text += "time : {}\n".format(np.frombuffer(f.read(8*1), dtype=np.float64, count=1)[0])
        text += "  accleration : {}\n".format(np.frombuffer(f.read(8*3), dtype=np.float64, count=3)[0:3])
        text += "  attitude    : {}".format(np.frombuffer(f.read(8*3), dtype=np.float64, count=3)[0:3])
        print(text)

import numpy as np

with open("../gps", "rb") as f:
    while f.read(1):
        f.seek(-1, 1)
        text = ""
        text += "time : {}\n".format(np.frombuffer(f.read(8*1), dtype=np.float64, count=1)[0])
        text += "  latitude  : {}\n".format(np.frombuffer(f.read(8*1), dtype=np.float64, count=1)[0])
        text += "  longitude : {}\n".format(np.frombuffer(f.read(8*1), dtype=np.float64, count=1)[0])
        text += "  altitude  : {}\n".format(np.frombuffer(f.read(8*1), dtype=np.float64, count=1)[0])
        text += "  horizontalAccuracy : {}\n".format(np.frombuffer(f.read(8*1), dtype=np.float64, count=1)[0])
        text += "  verticalAccuracy   : {}".format(np.frombuffer(f.read(8*1), dtype=np.float64, count=1)[0])
        print(text)

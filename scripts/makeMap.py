# 録画したdb.sqlite3から地図上に軌跡を表示する
# htmlファイルを生成するためのプログラム
#
# 使い方: python3 makeMap.py <db.sqlite3へのパス>
#
# 実行するとhtmlのテキストが表示されるので、これをファイルとして保存する。
#

import sys
import os
import sqlite3
import folium

if len(sys.argv) < 2:
    print("Usage:\n\n  python3 makeMap.py <path to db.sqlite3>\n")
    print(sys.argv)
    exit()

path = sys.argv[1]

if not os.path.isfile(path):
    print("Can't open file '{}'".format(path))
    exit()

con = sqlite3.connect(path)
cur = con.cursor()
trajectory = [(row[0], row[1]) for row in cur.execute("SELECT latitude, longitude from gps ORDER BY id ASC")]

con.close()

tiles = [
    "cartodbdark_matter",
    "cartodbpositron",
    "cartodbpositronnolabels",
    "cartodbpositrononlylabels",
    "openstreetmap",
    "stamenterrain",
    "stamentoner",
    "stamentonerbackground",
    "stamentonerlabels",
    "stamenwatercolor",
]

m = folium.Map(tiles=tiles[1], control_scale=True)
m_trajectory = folium.PolyLine(trajectory, weight=10)
m_trajectory.add_to(m)
folium.FitBounds(m_trajectory.get_bounds()).add_to(m)
print(m.get_root().render())
#m.save("map.html")

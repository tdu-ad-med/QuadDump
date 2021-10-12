# Google MapでGPSの軌跡を表示できるようにするため、
# 録画したdb.sqlite3からGPXファイルを生成するためのプログラム
#
# 使い方: python3 makeGPX.py <db.sqlite3へのパス>
#
# 実行するとGPXのテキストが表示されるので、これをファイルとして保存する。
#

import sys
import os
import sqlite3
import datetime

if len(sys.argv) < 2:
    print("Usage:\n\n  python3 makeGPX.py <path to db.sqlite3>\n")
    print(sys.argv)
    exit()

path = sys.argv[1]

if not os.path.isfile(path):
    print("Can't open file '{}'".format(path))
    exit()

gpx = '''<?xml version="1.0"?>
<gpx xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns="http://www.topografix.com/GPX/1/0" version="1.0" creator="GPSBabel - http://www.gpsbabel.org" xsi:schemaLocation="http://www.topografix.com/GPX/1/0 http://www.topografix.com/GPX/1/0/gpx.xsd">
  <trk>
    <name>Trajectory</name>
    <number>1</number>
    <trkseg>
'''

con = sqlite3.connect(path)
cur = con.cursor()
date = [row for row in cur.execute("SELECT date from description")][0][0] + "Z"
date = datetime.datetime.strptime(date, '%Y-%m-%d %H:%M:%S.%f%z')
cur.execute("SELECT latitude, longitude, timestamp from gps ORDER BY id ASC")
for i in cur:
    timestamp = (date + datetime.timedelta(seconds=i[2])).isoformat()
    gpx += '''      <trkpt lat="{}" lon="{}"><ele>0</ele><time>{}</time></trkpt>
'''.format(i[0], i[1], timestamp)
con.close()

gpx += '''    </trkseg>
  </trk>
</gpx>'''

print(gpx)

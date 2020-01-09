import glob,os
import pprint
import json


THIS_FOLDER = os.path.dirname(os.path.abspath(__file__))

def findnth(haystack, needle, n):
    parts= haystack.split(needle, n+1)
    if len(parts)<=n+1:
        return -1
    return len(haystack)-len(parts[-1])-len(needle)

def scale(k):
    out = ((int(k) + 10000) / 20000) * 255
    if(out < 0):
        return 0
    if(out > 255): 
        return 255
    return int(out)

kind = "empty"

data = []

os.chdir("raw-data/" + kind)
for path in glob.glob("*.txt"):
    file = open(path,"r") 

    values = []

    array = file.read().split("SensorEvent")
    del(array[0])
    del(array[-1])

    for line in array:
        accl = line[findnth(line, "accl: [", 0)+7:findnth(line, "]", 0)]
        acclA = list(map(scale, accl.split(',')))
        gyro = line[findnth(line, "gyro: [", 0)+7:findnth(line, "]", 1)]
        gyroA = list(map(scale, gyro.split(',')))

        sensorValues = acclA + gyroA
        values.append(sensorValues)

    data.append(values)

print(os.path.join(THIS_FOLDER, 'data/' + kind +'.json'))

with open(os.path.join(THIS_FOLDER, 'data/' + kind + '.json'), 'w', encoding='utf-8') as f:
    json.dump(data, f, ensure_ascii=False, indent=4)
# eSense gesture recognition

Using acceleration and gyroscope data from the headphones, a "Nodding"-Yes or "Headshake"-No is reconized.
Classification is done on the raw data. Data is sampled at a rate of 50Hz.
The data is fed to the Neural Network in a 6x50 Matrix.

The Matrix holds the following data:
```
[[accel.x, accel.y, accel.z, gyro.x, gyro.y, gyro.z],  <- 1st sampling
 ...
 [accel.x, accel.y, accel.z, gyro.x, gyro.y, gyro.z]]  <- 50th sampling
 
```

The neural network recognizes the following classes:
 - Yes   (A nod is recognized)
 - No    (A headshake is recognized)
 - Empty (No gesture is recognized)

Classification is done serverside. 
The webserver is a flask server found in server.py.




Developed as part of the lecture "Mobile Computing" at Karlsruhe Institute of Technology.

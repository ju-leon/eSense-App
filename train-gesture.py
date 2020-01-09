from __future__ import absolute_import, division, print_function, unicode_literals

import tensorflow as tf
import json
import pprint
import numpy as np
from keras.datasets import mnist

pp = pprint.PrettyPrinter(indent=4)

with open('data/no.json') as json_file:
    jsonNo = json.load(json_file)

with open('data/yes.json') as json_file:
    jsonYes = json.load(json_file)

with open('data/empty.json') as json_file:
    jsonEmpty = json.load(json_file)

data = []
data.extend(jsonNo)
data.extend(jsonYes)
data.extend(jsonEmpty)

labels = []
for line in jsonNo:
    labels.append(0)
for line in jsonYes:
    labels.append(1)
for line in jsonEmpty:
    labels.append(2)

testData = data[0::10]
del(data[0::10])

testLabels = labels[0::10]
del(labels[0::10])


data = np.asarray(data)
testData = np.asarray(testData)

labels = np.asarray(labels)
testLabels = np.asarray(testLabels)

print(data)

model = tf.keras.models.Sequential([
    tf.keras.layers.Dense(50, input_shape=(50, 6), activation='relu'),
    tf.keras.layers.Conv1D(32, 6, padding="same", activation="softmax"),
    tf.keras.layers.Flatten(data_format=None),
    tf.keras.layers.Dense(32, activation='softmax'),
    tf.keras.layers.Dense(3, activation='softmax'),
])

model.compile(optimizer='adam',
              loss='sparse_categorical_crossentropy',
              metrics=['accuracy'])


model.fit(data, labels, batch_size=20, epochs=10)
model.evaluate(testData, testLabels, verbose=2)


with open('data/classify.json') as json_file:
    jsonClassify = json.load(json_file)
classify = np.asarray(jsonClassify)

print(classify)
print(model.predict(classify))

#model.save('models/my_model_discrete.h5')


#converter = tf.lite.TFLiteConverter.from_keras_model_file('models/my_model_discrete.h5')
#tflite_model = converter.convert()
#open("converted_model.tflite", "wb").write(tflite_model)


from flask import Flask, request
import tensorflow as tf
import numpy as np
import flask

import numpy as np

# initialize our Flask application and the Keras model
app = flask.Flask(__name__)
model = None


def load_model():
    # load the pre-trained Keras model (here we are using a model
    # pre-trained on ImageNet and provided by Keras, but you can
    # substitute in your own networks just as easily)
    global model
    model = tf.keras.models.load_model('models/my_model.h5')


@app.route('/predict', methods=['POST'])
def hello():
    name = (np.asarray(request.json)).reshape(50, 6)
    name = np.expand_dims(name, axis=0)

    prediction = model.predict(name)
    winner = np.argmax(prediction)

    if winner == 0:
        print("NO")
        return '{"winner": "no"}'
    if winner == 1:
        print("YES")
        return '{"winner": "yes"}'

    print("EMPTY")
    return '{"winner": "empty"}'

if __name__ == "__main__":
    print(("* Loading Keras model and Flask starting server..."
           "please wait until server has fully started"))
    load_model()
    # Add threaded=False if you want to use keras instead of tensorflow.keras
    app.run(host='0.0.0.0', port='5000', threaded=False)

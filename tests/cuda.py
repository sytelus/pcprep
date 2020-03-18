# find tensorflow packages
import pkg_resources
l = [d for d in pkg_resources.working_set  if 'tensorflow' in str(d)]
print(l)

# what devices tensorflow see?
import tensorflow.compat.v1 as tensorflow
print('TF version', tensorflow.__version__)

from tensorflow.python.client import device_lib
print('Tensorflow devices:')
print(device_lib.list_local_devices())

import tensorflow.compat.v1 as tf
tf.compat.v1.disable_eager_execution()
a = tf.constant(5.0)
b = tf.constant(6.0)
c = a * b
sess=tf.Session()
sess.run(c)

# find PyTorch packages
import pkg_resources
l = [d for d in pkg_resources.working_set  if 'pytorch' in str(d)]
print(l)

# confirm PyTorch sees the GPU
from torch import cuda
import torch
print('PyTorch version', torch.__version__)
print('PyTorch cuda available', cuda.is_available())
print('PyTorch device count', cuda.device_count())
print('PyTorch device', cuda.get_device_name(cuda.current_device()))

# confirm Keras sees the GPU
# from tensorflow.keras import backend
# print('keras GPUs:', backend.tensorflow_backend._get_available_gpus())

import os
os.system('nvidia-smi')
os.system('nvcc --version')

import ray
ray.init(num_gpus=1)
print('ray GPU IDs', ray.get_gpu_ids())

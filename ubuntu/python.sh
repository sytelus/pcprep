#!/bin/bash
#fail if any errors
set -e
set -o xtrace

pip install -q mpi4py
#conda install -y x264=='1!152.20180717' ffmpeg=4.0.2 -c conda-forge
#pip install -q pyqt5==5.12.0 pyqtwebengine==5.12.0
pip install -q setuptools wheel twine
pip install -q gputil setproctitle
conda install -y opencv graphviz python-graphviz
pip install -q  opencv-python

pip install -q  pydot plotly pyzmq dominate pygame pymunk
pip install -q  gunicorn dash dash-core-components dash-html-components dash-renderer dash-auth
pip install -q  nltk gensim annoy ujson tables sharedmem sacred pprofile mlxtend fitter mpld3
pip install -q  jupyter_nbextensions_configurator fasttext pandas-profiling scikit-image tqdm patool skorch fastcluster
pip install -q  sphinx recommonmark sphinx-autobuild sphinx_rtd_theme click-man
pip install -q jupyterthemes
pip install -q gpustat azureml-sdk overrides timebudget py-spy autopep8
conda install -y -c conda-forge jupyter_contrib_nbextensions
pip -q install qgrid
jupyter nbextension enable --py --sys-prefix widgetsnbextension
pip -q install pyyaml pybullet optuna pytablewriter scikit-optimize py-spy filelock tabulate aiohttp psutil

#pip install -q glances[gpu]
#conda install -y h5py==2.8.0
#pip install -q  mkdocs-alabaster mkdocs-cinder mkdocs-cluster mkdocs-cinder mkdocs-material mkdocs-rtd-dropdown mkdocs-windmill mkdocs-bootstrap mkdocs-bootswatch mkdocs-psinder
#pip install -q  pep8
#pip install -q  --upgrade autopep8

# conda install -y -c conda-forge jupyterlab nodejs
# conda install -y ipywidgets
# conda install -y -c plotly plotly-orca psutil

# set NODE_OPTIONS=--max-old-space-size=4096
# jupyter labextension install @jupyter-widgets/jupyterlab-manager --no-build
# jupyter labextension install plotlywidget --no-build
# jupyter labextension install @jupyterlab/plotly-extension --no-build
# jupyter labextension install jupyterlab-chart-editor --no-build
# jupyter lab build
# set NODE_OPTIONS=

# pip install -q  jupyter_contrib_nbextensions
# jupyter contrib nbextension install
# conda install -y jupyter_dashboards -c conda-forge
#pip install -q  ipyaggrid pydbgen
# jupyter labextension install @jupyter-widgets/jupyterlab-manager


#pip install 'pyqt5<5.13'
#pip install 'pyqtwebengine<5.13'




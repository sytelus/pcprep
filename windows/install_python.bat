pip install -q mpi4py
call conda install -y x264=='1!152.20180717' ffmpeg=4.0.2 -c conda-forge
pip install -q pyqt5==5.12.0 pyqtwebengine==5.12.0
pip install -q setuptools wheel twine
pip install -q gputil setproctitle
call conda install -y opencv graphviz python-graphviz
pip install -q  opencv-python 

pip install -q  pydot plotly pyzmq dominate pygame pymunk
pip install -q  gunicorn dash dash-core-components dash-html-components dash-renderer dash-auth
pip install -q  nltk gensim annoy ujson tables sharedmem sacred pprofile mlxtend fitter mpld3 
pip install -q  jupyter_nbextensions_configurator fasttext pandas-profiling scikit-image tqdm patool skorch fastcluster 
pip install -q  sphinx recommonmark sphinx-autobuild sphinx_rtd_theme click-man
pip install -q jupyterthemes
pip install -q gpustat azureml-sdk
call conda install -y -c conda-forge jupyter_contrib_nbextensions
pip -q install qgrid
jupyter nbextension enable --py --sys-prefix widgetsnbextension
pip -q install pyyaml pybullet optuna pytablewriter scikit-optimize

REM msgpack msgpack-rpc-python
REM conda install -y h5py==2.8.0
REM imgaug
REM mkdocs glances[gpu] 
REM pip install -q  mkdocs-alabaster mkdocs-cinder mkdocs-cluster mkdocs-cinder mkdocs-material mkdocs-rtd-dropdown mkdocs-windmill mkdocs-bootstrap mkdocs-bootswatch mkdocs-psinder
REM pip install -q  pep8   
REM pip install -q  --upgrade autopep8

REM  conda install -y -c conda-forge jupyterlab nodejs
REM  conda install -y ipywidgets
REM  conda install -y -c plotly plotly-orca psutil

REM  set NODE_OPTIONS=--max-old-space-size=4096
REM  jupyter labextension install @jupyter-widgets/jupyterlab-manager --no-build
REM  jupyter labextension install plotlywidget --no-build
REM  jupyter labextension install @jupyterlab/plotly-extension --no-build
REM  jupyter labextension install jupyterlab-chart-editor --no-build
REM  jupyter lab build
REM  set NODE_OPTIONS=

REM  pip install -q  jupyter_contrib_nbextensions
REM  jupyter contrib nbextension install
REM  conda install -y jupyter_dashboards -c conda-forge
REM pip install -q  ipyaggrid pydbgen
REM  jupyter labextension install @jupyter-widgets/jupyterlab-manager


REM pip install 'pyqt5<5.13'
REM pip install 'pyqtwebengine<5.13'

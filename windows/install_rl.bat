REM installing GYM
pip install -q gym
call conda install -y pystan swig

REM install fixed version of pybox2d
D:
cd D:\GitHubSrc
git clone https://github.com/sytelus/pybox2d.git
cd pybox2d
pip install -e .

cd D:\GitHubSrc
git clone https://github.com/sytelus/box2d-py.git
cd box2d-py
pip install -e .

pip install pyglet==1.2.4
REM below is for xming
REM setx DISPLAY 0 # don't do this as it interferes with ssh

pip install -q gym[box2d]
pip install -q gym[classic_control]
pip install -q gym[atari]
D:
mkdir \GitHubSrc
pushd \GitHubSrc

REM installing GYM
pip install -q gym
call conda install -y pystan swig

REM install fixed version of pybox2d
CALL :install_from_git sytelus pybox2d 1
CALL :install_from_git sytelus box2d-py 1

pip install pyglet==1.2.4
REM below is for xming
REM setx DISPLAY 0 # don't do this as it interferes with ssh

pip install -q gym[box2d]
pip install -q gym[classic_control]
pip install -q gym[atari]

popd
EXIT /B %ERRORLEVEL% 

:install_from_git
if not exist "\GitHubSrc\%~2" (
    git clone https://github.com/%~1/%~2.git
)
if "%~3" EQ "1" (
    pushd "%~2"
    pip install -e .
    popd
)
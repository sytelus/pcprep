D:
mkdir \GitHubSrc
pushd \GitHubSrc

CALL :install_from_git microsoft tensorwatch 1
CALL :install_from_git sytelus podworld 1
CALL :install_from_git sytelus regim 1
CALL :install_from_git hill-a stable-baselines 1
CALL :install_from_git openai spinningup 1

CALL :install_from_git microsoft AirSim
CALL :install_from_git sytelus shitalshah.com-v5
CALL :install_from_git sytelus gymexp
CALL :install_from_git sytelus pcprep
CALL :install_from_git sytelus rl-experiments
CALL :install_from_git sytelus rl-baselines-zoo

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

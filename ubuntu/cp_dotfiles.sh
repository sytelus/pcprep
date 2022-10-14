if ! grep -Fxq "# >>> conda initialize >>>" ~/.bashrc; then
    cp -f .bashrc ~/.bashrc
else
    echo *********** .bashrc is not replaced.
fi
cp -f .bash_aliases ~/.bash_aliases
cp -f .inputrc ~/.inputrc
cp -f .tmux.conf ~/.tmux.conf
cp -f rundocker.sh ~/rundocker.sh
sudo chmod +x ~/rundocker.sh
cp -rf .config/ ~/
cp -rf .local/ ~/


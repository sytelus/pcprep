if ! grep -Fxq "# >>> conda initialize >>>" ~/.bashrc; then
    cp -f .bashrc ~/.bashrc
else
    echo *********** .bashrc is not replaced.
fi
cp -f .bash_aliases ~/.bash_aliases
cp -f .inputrc ~/.inputrc
cp -f .tmux.conf ~/.tmux.conf
cp -f rundocker.sh ~/rundocker.sh
cp -f azmount.yaml ~/azmount.yaml
cp -f azmount.sh ~/azmount.sh
sudo chmod +x ~/rundocker.sh
cp -rf .config/ ~/
cp -rf .ssh/ ~/
cp -rf .local/ ~/


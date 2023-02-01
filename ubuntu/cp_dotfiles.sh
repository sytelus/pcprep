if ! grep -Fxq "# >>> conda initialize >>>" ~/.bashrc; then
    cp -f .bashrc ~/.bashrc
else
    echo *********** .bashrc is not replaced.
fi
cp -f .bash_aliases ~/.bash_aliases
cp -f .inputrc ~/.inputrc
cp -f .tmux.conf ~/.tmux.conf
cp -f rundocker.sh ~/rundocker.sh
cp -f azure-mount-config.yaml /azure-mount-config.yaml
cp -f azure_mount_blob.sh ~/azure_mount_blob.sh
sudo chmod +x ~/rundocker.sh
cp -rf .config/ ~/
cp -rf .local/ ~/


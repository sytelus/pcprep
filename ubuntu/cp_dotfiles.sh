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

cp -f mount_cifs.sh ~/mount_cifs.sh
cp -f start_tmux.sh ~/start_tmux.sh
cp -f sysinfo.sh ~/sysinfo.sh
cp -f treesize.sh ~/treesize.sh

cp -f measure_flops.py ~/measure_flops.py
cp -rf .config/ ~/
cp -rf .ssh/ ~/
cp -rf .local/ ~/

sudo chmod +x ~/*.sh

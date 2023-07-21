if ! grep -Fxq "# >>> conda initialize >>>" ~/.bashrc; then
    cp -f .bashrc ~/.bashrc
else
    echo *********** .bashrc is not replaced.
fi
cp -f .bash_aliases ~/.bash_aliases
cp -f .inputrc ~/.inputrc
cp -f .tmux.conf ~/.tmux.conf

sudo chmod +x *.sh

sudo cp -f rundocker.sh /usr/local/bin/rundocker.sh

sudo cp -f azmount.yaml /usr/local/bin/azmount.yaml
sudo cp -f azmount.sh /usr/local/bin/azmount.sh

sudo cp -f mount_cifs.sh /usr/local/bin/mount_cifs.sh
sudo cp -f start_tmux.sh /usr/local/bin/start_tmux.sh
sudo cp -f sysinfo.sh /usr/local/bin/sysinfo.sh
sudo cp -f treesize.sh /usr/local/bin/treesize.sh

sudo cp -f measure_flops.py /usr/local/bin/measure_flops.py

cp -rf .config/ ~/
cp -rf .ssh/ ~/
cp -rf .local/ ~/

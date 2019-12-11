curl https://storage.googleapis.com/tensorflow-serving-apt/tensorflow-serving.release.pub.gpg | sudo apt-key add -
sudo apt-get update
sudo apt-get upgrade -y
sudo apt-get dist-upgrade -y
sudo apt-get install -y cuda-drivers
#sudo apt-get install -y cuda

#sudo apt-get install -y cuda-10-0
#conda install -y pytorch torchvision cudatoolkit=10.0 -c pytorch
pip install -q --upgrade torch
echo --------------------------
echo !!Please reboot!!
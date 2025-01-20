# Move home folder after installing WSL
bash move_home.sh /mnt/e/wsl_home

# WSL is stored as VM in this location
C:\Users\%USERNAME%\AppData\Local\Packages\

# WSL files in its virtual disk can be accessed from Windows Explorer
\\wsl$\

# check WSL version (it should be 2 or higher)
wsl -l -v

# Update if needed
wsl --update

# verify CUDA in WSL
nvidia-smi

# map GitHubSrc
ln -s /mnt/d/GitHubSrc ~/GitHubSrc

# map .ssh
ln -s /mnt/c/Users/shitals/.ssh ~/.ssh
#chmod 600 ~/.ssh/*

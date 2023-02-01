#!/bin/bash

# let current user use sudo
adduser --disabled-password --gecos '' $USER
adduser $USER sudo
echo '%sudo ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers
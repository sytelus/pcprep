#!/usr/bin/env bash

echo "=========== Docker plugin =========== "
docker --version

echo "=========== Docker dir =========== "
docker info | sed -n 's/ *Docker Root Dir: //p'

echo "=========== Docker Disk Usage =========== "
docker system df

echo "=========== BuildX plugin =========== "
docker buildx version

echo "=========== Available Builders =========== "
docker buildx ls

echo "=========== BuildX Info =========== "
docker info | grep -i buildx

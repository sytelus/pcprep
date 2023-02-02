#!/bin/bash

exec su -l docker_admin -c "bash sudo adduser $USER sudo"

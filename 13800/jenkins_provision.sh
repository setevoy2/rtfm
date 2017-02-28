#!/usr/bin/env bash

sudo curl https://get.docker.com/ | bash
sudo usermod -aG docker jageradmin
docker run -tid -p 80:8080 -v /jenkins:/jenkins -v /var/run/docker.sock:/var/run/docker.sock -e JENKINS_HOME='/jenkins' --name jenkins jenkins
mkdir /jenkins
mount /dev/sdc1 /jenkins/

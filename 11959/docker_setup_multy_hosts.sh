#!/usr/bin/env bash

#IPS="10.0.2.33 10.0.1.245 10.0.2.185 10.0.2.186"
IPS="10.0.2.141"
USER="ubuntu"
RSA_KEY="my-cluster.pem"

docker_update () {
    echo -e "\nInstalling Docker to $1\n"
    ssh -t -t -oStrictHostKeyChecking=no -i "$RSA_KEY" "$USER@$1" "bash -c '
    	sudo apt-get update && curl -sSL https://get.docker.com/ | sh
    '"
}

copy_opts () {

    echo -e "\nCopy /etc/profile.d/docker_host.sh to $1\n"
    # subsctitute Master's IP to Node's IP
    sed -e 's/10.0.1.103/'"$1"'/g' /etc/profile.d/docker_host.sh > docker_host.sh
    scp -i "$RSA_KEY" docker_host.sh "$USER@$1":/home/$USER
    rm docker_host.sh

    echo -e "\nCopy /etc/default/docker to $1\n"
    # subsctitute Master's IP to Node's IP
    sed -e 's/10.0.1.103/'"$1"'/g' /etc/default/docker > docker
    scp -i "$RSA_KEY" docker "$USER@$1":/home/$USER
    rm docker
}

move_opts () {
    ssh -t -t -oStrictHostKeyChecking=no -i "$RSA_KEY" "$USER@$1" "bash -c '
        sudo mv /home/$USER/docker /etc/default/docker
        sudo mv /home/$USER/docker_host.sh /etc/profile.d/docker_host.sh
    '"
}

docker_restart () {
    echo -e "\nRestarting Docker daemon.\n"
    ssh -t -t -oStrictHostKeyChecking=no -i "$RSA_KEY" "$USER@$1" "bash -c '
        sudo service docker restart
    '"
}

for host in $IPS; do
    docker_update $host
    copy_opts $host
    move_opts $host
    docker_restart $host
done

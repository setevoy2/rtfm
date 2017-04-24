#!/usr/bin/env bash
set -x

masterIPs=$1
env=$2

user=jmadmin
rsa="/home/$user/.ssh/jm-website-sw-$env"

gituser=""
gitpass=""

dockerUser=""
dockerPass=""

tokenslist="/home/$user/tokens.txt"

[[ -z $env ]] && { echo "ERROR: ENV variable is empty. Exit."; exit 1; }

# data disk mount
sgdisk -n 1 /dev/sdc
time mkfs.ext4 /dev/sdc1
mkdir /docker
mount /dev/sdc1 /docker/

# docker install
docker_install () {

    if [ ! $(which docker) ]; then
        curl https://get.docker.com/ | bash
        usermod -aG docker jageradmin
        echo -e "{\n  \"graph\": \"/docker/\"\n}" > /etc/docker/daemon.json
        service docker restart
        curl -L https://github.com/docker/compose/releases/download/1.11.2/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
#        docker login -u $dockerUser -p $dockerPass
    else
        echo "Docker already installed."
    fi
}

docker_login () {
    sudo runuser -l $user -c "docker login -u $dockerUser -p $dockerPass"
    chown -R $user:$user /home/$user/.docker
}

get_keys () {

    [[ -d azure-infrastructure ]] && rm -rf azure-infrastructure
    git clone https://$gituser:$gitpass@github.com/jm/azure-infrastructure.git
    mv azure-infrastructure/jm-website/.ssh/jm-website-sw-$env /home/$user/.ssh/
    chmod 400 $rsa
    chown $user:$user $rsa
}

test_ssh () {
        local ip=$1
        ssh -q -t -t -o StrictHostKeyChecking=no $user@$ip -i $rsa exit
}

check_master () {

        local timeout=10
        local attempt=0
        
        while [ $attempt -lt 3 ]; do
                for ip in $masterIPs; do
                        if $(test_ssh $ip); then
                                MASTER=$ip
                                break
                        fi
                done

                if [ -z $MASTER ]; then
                        echo "Sleeping..."
                        sleep $timeout
                        ((attempt++))
                else
                        echo $MASTER
                        break
                fi
        done

#        [[ ! -z $master ]] && { echo "IP found: $ip"; } || { echo "IP not found, exit."; exit 1; }
}

docker_test () {

        local masterip=$1
        nc -zv $masterip 2377
}

get_worker_token () {

        local masterip=$1
        local tknstart="SWMTKN.*"

        until $(docker_test $masterip); do
           echo "First Master not initialized yet..."
           sleep 30
        done

#        master_token=$(ssh -t -t -o StrictHostKeyChecking=no $user@$masterip -i $rsa "bash -c '
#                docker swarm join-token worker | grep token 
#        '" | awk '{print $2}')

        token=$(ssh -t -t -o StrictHostKeyChecking=no $user@$masterip -i $rsa "bash -c '
               cat $tokenslist | grep -A 3 worker | tail -n 1 '
        '")

        master_token=$(echo $token | cut -d" " -f 2)

        if [[ $master_token =~ $tknstart ]]; then
            echo $master_token
        else
            echo -e "ERROR: wrong token: $master_token"
            exit 1
        fi

}

master_joint () {
    
        local masterip=$1
        echo "Executing: docker swarm join --token $(get_worker_token $masterip) $masterip:2377"
        docker swarm join --token $(get_worker_token $masterip) $masterip:2377
}

if docker_install; then
    echo -e "Docker installed"
else
    echo -e "ERROR: can't install Docker. Exit."
    exit 1
fi

if docker_login; then
    echo -e "Docker authenticated"
else
    echo -e "ERROR: can't login to DockerGub."
fi

if get_keys; then
    echo -e "Git repository cloned, OK."
else
    echo -e "Can't clone repo. Exit."
    exit 1
fi

if check_master; then
        echo "Master found: $MASTER"
else
    echo -e "Swarm init error. Exit."
    exit 1
fi

if get_worker_token $MASTER; then
        echo -e "Master token obtained: $master_token"
else
        echo -e "ERROR during get master token."
fi

if master_joint $MASTER; then
        echo -e "Worker added"
else
        echo -e "ERROR during master attach."
fi

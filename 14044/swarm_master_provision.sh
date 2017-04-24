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

# docker install
docker_install () {

    if [ ! $(which docker) ]; then
        curl https://get.docker.com/ | bash
        usermod -aG docker jageradmin
        curl -L https://github.com/docker/compose/releases/download/1.11.2/docker-compose-`uname -s`-`uname -m` > /usr/local/bin/docker-compose
        chmod +x /usr/local/bin/docker-compose
        # docker login -u $dockerUser -p $dockerPass
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
#        echo $?
}

check_master () {

        local timeout=10
        local attempt=0
        
		echo -e "\nMASTER CHECK: $masterIPs\n"

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
                else
                        echo "$MASTER"
                        break
                fi

				((attempt++))
				[[ $attempt == 3 ]] && exit 1

        done

}

swarm_init () {
    
        local masterip=$1

        ssh -t -t -o StrictHostKeyChecking=no $user@$masterip -i $rsa "bash -c '
                docker swarm init
        '"
        ssh -t -t -o StrictHostKeyChecking=no $user@$masterip -i $rsa "bash -c '
                docker swarm join-token manager > $tokenslist
        '"

        ssh -t -t -o StrictHostKeyChecking=no $user@$masterip -i $rsa "bash -c '
                docker swarm join-token worker >> $tokenslist
        '"

}

docker_test () {

        local masterip=$1
        nc -zv $masterip 2377
}


get_master_token () {

        local masterip=$1
        local tknstart="SWMTKN.*"

        local timeout=30
        local attempt=0

#        while [ $attempt -lt 20 ]; do
#
#                if [ $(docker_test $masterip) ]; then
#                        echo "First Master not initialized yet..."
#                        sleep $timeout
#                        ((attempt++))
#                else
#                        echo "\nMaster Up and Running. Master IP used: $masterip"
#                        break
#                fi
#        done

        until $(docker_test $masterip); do
           echo "First Master not initialized yet..."
           sleep 30
        done

#        master_token=$(ssh -t -t -o StrictHostKeyChecking=no $user@$masterip -i $rsa "bash -c '
#                docker swarm join-token manager | grep token 
#        '" | awk '{print $2}')

        token=$(ssh -t -t -o StrictHostKeyChecking=no $user@$masterip -i $rsa "bash -c '
               cat $tokenslist | grep -A 3 manager | tail -n 1 
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
        echo "Executing: docker swarm join --token $(get_master_token $masterip) $masterip:2377"
        docker swarm join --token $(get_master_token $masterip) $masterip:2377
}

master_drain () {

    nodes=$(docker node ls | grep -v ID | cut -d" " -f 1)
    echo "Master nodes found: $nodes"

    for node in $nodes; do
        docker node update --availability drain $node
    done
}
        
copy_docker_clean () {
    [[ -e docker_cleanup.sh ]] && cp docker_cleanup.sh /home/$user/
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

if swarm_init $MASTER; then
        echo -e "\nSwarm initialization complete."
else
        echo -e "\nSwarm already initialized."
fi

if get_master_token $MASTER; then
        echo -e "Master token obtained: $master_token"
else
        echo -e "ERROR during get master token."
fi

if master_joint $MASTER; then
        echo -e "Master added"
else
        echo -e "ERROR during master attach."
fi

if copy_docker_clean; then
    echo -e "docker_cleanup.sh copied to the /home/$user/"
else
    echo -e "ERROR: can't copy docker_cleanup.sh to /home/$user/."
    ls -l
fi

if master_drain; then
    echo "Master drain done"
    echo -e "\Result: $?\n"
    exit 0
else
    echo "ERROR: can set drain for master"
    echo -e "\nResult: $?\n"
fi


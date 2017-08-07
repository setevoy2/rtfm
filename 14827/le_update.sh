#!/usr/bin/env bash

GIT_USER=username
GIT_PASS=password

le_renew () {

        /opt/letsencrypt/letsencrypt-auto renew -vvv --post-hook "systemctl reload nginx"
}

le_rsync_to_secondary () {

        local secondary_host=$1
        local secondary_user=$2

        rsync -avh --rsync-path="sudo rsync" /etc/letsencrypt/{live,archive} $secondary_user@$secondary_host:/etc/letsencrypt/
}

le_rsync_to_repo () {

        local git_user=$1
        local git_pass=$2

        cd /root
        git clone https://$git_user:$git_pass@github.com/jm/jm-gw-proxy-data.git

        rsync -avh /etc/letsencrypt/{live,archive} /root/jm-gw-proxy-data/tests/letsencrypt

        cd /root/jm-gw-proxy-data 
        git add -A && git commit -m "Lets Encrypt SSL synchronization on  $(date +"%m_%d_%Y_%H_%M")" && git push
}

repo_cleanup_local () {

        rm -rf /root/jm-gw-proxy-data
}

# 1. make `renew`
# 2. rsync from /etc/letsencrypt/{live,archive} on master to /etc/letsencrypt/ on secondary
# 3. clone jm-gw-proxy-data repo to /root
# 4. rsync /etc/letsencrypt/{live,archive} to repo jm-gw-proxy-data/tests/letsencrypt
# 5. commit && push

le_renew || exit 1
le_rsync_to_secondary 10.0.0.5 jmadmin || exit 1
le_rsync_to_repo $GIT_USER $GIT_PASS || exit 1
repo_cleanup_local

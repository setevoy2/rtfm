#!/usr/bin/env python

"""Backup and deploy script"""

import os
import sys
import datetime
import glob
import shutil

from fabric.api import run, env, put, sudo

import azure.common
from azure.storage.file import FileService
from azure.storage.blob import BlockBlobService


def get_backup(gw_account_name, gw_account_key, gw_account_share, backup_local_path):

    """Upload directories and files from $account_name to local $backup_local_path using Azure FileService"""

    print('\nRunning get_backup from the {} and file share {} to local path {}.\n'.format(gw_account_name, gw_account_share, backup_local_path))

    file_service = FileService(account_name=gw_account_name, account_key=gw_account_key)
    share_dirs_list = file_service.list_directories_and_files(gw_account_share)

    for share_dir_name in share_dirs_list:

        backup_local_dir = os.path.join(backup_local_path, share_dir_name.name)

        if not os.path.isdir(backup_local_dir):
            print('Local backup directory {} not found, creating...'.format(backup_local_dir))
            os.makedirs(backup_local_dir)

        share_files_list = file_service.list_directories_and_files(gw_account_share, share_dir_name.name)
        for share_file in share_files_list:
            try:
                print('Getting file: {}'.format(os.path.join('/', share_dir_name.name, share_file.name)))
                # example:
                # file_service.get_file_to_path('gwdevproxydata', 'datanginx-conf.d', 'jm-gw-proxy-dev.domain.tld.conf', '/tmp/jm-gw-proxy-dev.domain.tld.conf-out')
                file_service.get_file_to_path(gw_account_share, share_dir_name.name, share_file.name, os.path.join(backup_local_dir, share_file.name))
            # to pass /data/datahtml/.well-known dir on master host
            except azure.common.AzureMissingResourceHttpError as e:
                print('\nWARNING: {}\n'.format(e))


def push_backup(bac_account_name, bac_account_key, bac_container_name, backup_local_path):

    """Upload directories and files from $backup_local_path to account_name using Azure BlockBlobService"""

    print('\nRunning push_backup from local path {} to the {} and container {}\n'.format(backup_local_path, bac_account_name, bac_container_name))

    now = datetime.datetime.today().strftime('%Y_%m_%d_%H_%M')

    for root, dirs, files in os.walk(backup_local_path, topdown=True):
        for name in dirs:
            path = os.path.join(root, name)
            for filename in os.listdir(path):
                fullpath = os.path.join(path, filename)

                block_blob_service = BlockBlobService(account_name=bac_account_name, account_key=bac_account_key)
                # example
                # block_blob_service.create_blob_from_path(container_name, 'datanginx-conf.d/jm-gw-proxy-production.domain.tld.conf',  '/tmp/datanginx-conf.d/jm-gw-proxy-production.domain.tld.conf')
                print('Uploading {} as {}'.format(fullpath, os.path.join(now, name, filename)))
                block_blob_service.create_blob_from_path(bac_container_name, os.path.join(now, name, filename), fullpath)


def update_datanginxconfd(gw_account_name, gw_account_key, gw_account_share):

    """Upload data from cloned repo to the GW Storage account into the datanginx-conf.d directory with overwriting"""

    print('\nRunning update_confd to the {} and file share {} to the path datanginx-conf.d.\n'.format(gw_account_name, gw_account_share))

    file_service = FileService(account_name=gw_account_name, account_key=gw_account_key)

    configs = glob.glob('*.conf')
    for config in configs:
        print('Uploading config: {}'.format(config))
        file_service.create_file_from_path(gw_account_share, 'datanginx-conf.d', config, config)


def cleanup_backup_local_path(backup_local_path):

    print('Cleaning up local {} directory....'.format(backup_local_path))
    shutil.rmtree(backup_local_path)


def nginx_reload(gw_proxy_host, gw_proxy_user, gw_proxy_key, gw_proxy_ports):

    """Will connect to the Master and Secondary host to execute "nginx -t" before reload"""

    for port in gw_proxy_ports:
        env.host_string = gw_proxy_host + ':' + str(port)
        env.key_filename = [os.path.join('.ssh', gw_proxy_key)]
        env.user = gw_proxy_user

        validate_status = sudo('nginx -t')

        if validate_status.return_code == 0:
            print('OK: NGINX configs validated\n')
        else:
            print('ERROR: can\'t validate NGINX\n')
            exit(1)

        reload_status = sudo('systemctl reload nginx.service')

        if reload_status.return_code == 0:
            print('\nOK: NGINX reload complete\n')
        else:
            print('\nERROR: can\'t reload NGINX\n')
            exit(1)

        nginx_status = run('curl -s localhost > /dev/null')

        if nginx_status.return_code == 0:
            print('\nOK: NGINX reloaded status code: {}\n'.format(nginx_status.return_code))
        else:
            print('\nERROR: NGINX reloaded status code: {}\n'.format(nginx_status.return_code))
            exit(1)

if __name__ == "__main__":

    try:
        gw_account_name = os.environ['GW_ACCOUNT_NAME']
        gw_account_key = os.environ['GW_ACCOUNT_KEY']
        gw_account_share = os.environ['GW_ACCOUNT_SHARE']

        bac_account_name = os.environ['BAC_ACCOUNT_NAME']
        bac_account_key = os.environ['BAC_ACCOUNT_KEY']
        bac_account_container = os.environ['BAC_ACCOUNT_CONTAINER']

        backup_local_path = os.environ['BAC_LOCAL_PATH']

        gw_proxy_host = os.environ['GW_PROXY_HOST']
        gw_proxy_user = os.environ['GW_PROXY_USER']
        gw_proxy_key = os.environ['GW_PROXY_KEY']
        gw_proxy_ports = [2200, 2201]

    except KeyError as e:
        print('ERROR: no such environment variable - {}'.format(e))
        sys.exit(1)

    # download all files and directories from:
    # $gw_account_name (jmgatewayproxydata) $gw_account_share (gwproxydata)
    # to $backup_local_path (/tmp/GW_TEMP_BACKUP)
    get_backup(gw_account_name, gw_account_key, gw_account_share, backup_local_path)

    # upload all data from:
    # $backup_local_path (/tmp/GW_TEMP_BACKUP)
    # to:
    # $bac_account_name (jmbackup) $bac_account_container (jm-gw-proxy-backup)
    push_backup(bac_account_name, bac_account_key, bac_account_container, backup_local_path)

    # upload all *.conf files from local directory (i.e. cloned repository)
    # to the  $gw_account_name (jmgatewayproxydata) $gw_account_share (gwproxydata)
    update_datanginxconfd(gw_account_name, gw_account_key, gw_account_share)

    # SSH to the $gw_proxy_host (jm-gw-proxy-production.domain.tld)
    # and execute:
    # 1. nginx -t
    # 2. systemctl reload nginx.service
    # 3. curl -s localhost > /dev/null
    nginx_reload(gw_proxy_host, gw_proxy_user, gw_proxy_key, gw_proxy_ports)

    # remove local $backup_local_path (/tmp/GW_TEMP_BACKUP)
    # just in case, as anyway builds are in Travis Docker containers
    cleanup_backup_local_path(backup_local_path)

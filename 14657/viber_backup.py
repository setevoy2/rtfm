#!/usr/bin/env python

import os
import sys
import sqlite3
import datetime

# phone number to find path
# i.e. /home/setevoy/.ViberPC/380968889900
if len(sys.argv) < 3:
    print('ERROR: specify your cell num as first argument.')
    exit(1)

# some globals
db_name = 'viber.db'
dbpath = '/home/setevoy/.ViberPC/'
back_path = '/home/setevoy/Backups/ViberChats'


def get_mid():

    """Get contact's MID"""

    cur = conn.cursor()
    mid = cur.execute("""select name, mid from contact where name='{}';""".format(contact_name))

    for i in mid:
        return(i[1])


def get_todays_history(mid):

    """Select all messages for today from Contact's MID"""

    cur = conn.cursor()
    history_today = cur.execute("""select datetime(timestamp, 'unixepoch'), chattoken, body \
                                   from eventinfo where chattoken like '{mid}%' and datetime(timestamp, 'unixepoch') like "{day}%" \
                                   order by timestamp""".format(mid=mid, day=today));

    return history_today


def save_history():

    """Save all todays messages to /home/setevoy/Backups/ViberChats/Name_datetime"""

    mid = get_mid()
    back_file = contact_name + "_" +  today

    if not os.path.isdir(back_path):
        print('WARNING: o {} directory found, creating.').format(back_path)
        os.mkdir(back_path)
    else:
        print("OK: {} found.".format(back_path))

    os.chdir(back_path)
    with open(back_file, 'w') as bf:
        for mes in get_todays_history(mid):
            data = "{}\n".format(mes)
            bf.write(data)


if __name__ == "__main__":

    # cell number - first argument
    my_num = sys.argv[1]
    # contact's name to be saved in second one
    contact_name = sys.argv[2]

    # Create database connection, 
    conn = sqlite3.connect(os.path.join(dbpath, my_num, db_name))

    # 2017_07_10
    today = datetime.datetime.now().strftime('%Y_%m_%d')

    save_history()

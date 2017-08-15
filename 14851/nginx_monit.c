#include <stdio.h>
#include <sys/socket.h>
#include <arpa/inet.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

#define HOST_ADDR "127.0.0.1"
#define HOST_PORT 80

int socket_get(int i_addr, int i_port) {
    
    int socket_desc;
    struct sockaddr_in server;
    
    socket_desc = socket(AF_INET , SOCK_STREAM , 0);
    
    if (socket_desc == -1) {
        return 1;
    }
    
    server.sin_addr.s_addr = inet_addr(HOST_ADDR);
    server.sin_family = AF_INET;
    server.sin_port = htons(HOST_PORT);
    
    if (connect(socket_desc , (struct sockaddr *)&server , sizeof(server)) < 0) {
        return -1;
    }
    
    return 0;
}

void send_alarm() {

    char cmd[100];
    char to[20] = "1th@setevoy.kiev.ua";

    char hostname[1024], from_host[24];
    gethostname(hostname, 1024);   

    if (strcmp(hostname, "lj3hwzghi6ibg000000") ==0) { 
         strncpy(from_host, "Master", 24);
    } else if (strcmp(hostname, "lj3hwzghi6ibg000001") ==0) { 
        strncpy(from_host, "Secondary", 24);
    } else {
        exit(1);
    }

    sprintf(cmd, "echo NGINX is in DOWN state on the host %s! | /usr/bin/mailx -s \"ALARM from %s\" %s", from_host, from_host, to);
    system(cmd);

}

int main(int argc , char *argv[]) {

    if (socket_get(atoi(HOST_ADDR), HOST_PORT) != 0) {
        printf("Can't connect to local NGINX service!\n");
        send_alarm();
    }
}

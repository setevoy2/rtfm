#define _GNU_SOURCE
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

#define STACK_SIZE (1024 * 1024)

static char child_stack[STACK_SIZE];

// sync primitive
int checkpoint[2];

static int child_function() {

    char c;

    // init sync primitive
    close(checkpoint[1]);

    // wait for network setup in parent
    read(checkpoint[0], &c, 1);

    // setup network
    system("ip link set lo up");
    system("ip link set veth1 up");
    system("ip addr add 169.254.1.2/30 dev veth1");

    printf("New NET namespace:\n\n");
    system("ip link list");
    printf("\n");

    sleep(500);

    return 0;
}

int main() {

    // init sync primitive
    pipe(checkpoint);

    pid_t child_pid = clone(child_function, child_stack + STACK_SIZE, CLONE_NEWPID | CLONE_NEWNET | SIGCHLD, NULL);

    // further init: create a veth pair
    char* cmd;

    asprintf(&cmd, "ip link set veth1 netns %d", child_pid);
    system("ip link add veth0 type veth peer name veth1");
    system(cmd);
    system("ip link set veth0 up");
    system("ip addr add 169.254.1.1/30 dev veth0");
    free(cmd);

    // signal "done"
    close(checkpoint[1]);
   
    printf("\nOriginal NET namespace:\n\n");
    system("ip link list");
    printf("\n");

    waitpid(child_pid, NULL, 0);
    return 0;
}

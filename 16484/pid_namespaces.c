#define _GNU_SOURCE
#include <sched.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/wait.h>
#include <unistd.h>

#define STACK_SIZE (1024 * 1024)

static char child_stack[STACK_SIZE];

static int child_function() {

    printf("Child's PID from child_function() from own namespace: %d\n", getpid());
    printf("Parent's PID from child_function() from own namespace: %d\n", getppid());
    return 0;
}

int main(int argc, char** argv) {

    pid_t pid = getpid();
    pid_t child_pid = clone(child_function, child_stack + STACK_SIZE, SIGCHLD, NULL);

    printf("PID for %s process = %d\n", argv[0], pid);
    printf("Child process created by clone() from %s have PID = %d\n", argv[0], child_pid);

    waitpid(child_pid, NULL, 0);
    return 0;
}

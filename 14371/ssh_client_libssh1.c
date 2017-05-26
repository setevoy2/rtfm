#include <stdio.h>
#include <libssh/libssh.h> 
#include <stdlib.h>
#include <string.h>
#include <errno.h>

int verify_knownhost(ssh_session session) {

  int state, hlen;
  unsigned char *hash = NULL;
  char *hexa;
  char buf[10];

  state = ssh_is_server_known(session);
  hlen = ssh_get_pubkey_hash(session, &hash);

  if (hlen < 0)
    return -1;
  switch (state)

  {
    case SSH_SERVER_KNOWN_OK:
      break; /* ok */
    case SSH_SERVER_KNOWN_CHANGED:
      fprintf(stderr, "Host key for server changed: it is now:\n");
      ssh_print_hexa("Public key hash", hash, hlen);
      fprintf(stderr, "For security reasons, connection will be stopped\n");
      free(hash);
      return -1;
    case SSH_SERVER_FOUND_OTHER:
      fprintf(stderr, "The host key for this server was not found but an other"
        "type of key exists.\n");
      fprintf(stderr, "An attacker might change the default server key to"
        "confuse your client into thinking the key does not exist\n");
      free(hash);
      return -1;
    case SSH_SERVER_FILE_NOT_FOUND:
      fprintf(stderr, "Could not find known host file.\n");
      fprintf(stderr, "If you accept the host key here, the file will be"
       "automatically created.\n");
      /* fallback to SSH_SERVER_NOT_KNOWN behavior */
    case SSH_SERVER_NOT_KNOWN:
      hexa = ssh_get_hexa(hash, hlen);
      fprintf(stderr,"The server is unknown. Do you trust the host key [yes/no]?\n");
      fprintf(stderr, "Public key hash: %s\n", hexa);
      free(hexa);
      if (fgets(buf, sizeof(buf), stdin) == NULL)
      {
        free(hash);
        return -1;
      }
      if (strncasecmp(buf, "yes", 3) != 0)
      {
        free(hash);
        return -1;
      }
      if (ssh_write_knownhost(session) < 0)
      {
        fprintf(stderr, "Error %s\n", strerror(errno));
        free(hash);
        return -1;
      }
      break;
    case SSH_SERVER_ERROR:
      fprintf(stderr, "Error %s", ssh_get_error(session));
      free(hash);
      return -1;
  }

  free(hash);
  return 0;
}

int show_remote_processes(ssh_session session) {

  ssh_channel channel;
  int rc;
  char buffer[256];
  int nbytes;

  channel = ssh_channel_new(session);
  if (channel == NULL)
    return SSH_ERROR;

  rc = ssh_channel_open_session(channel);
  if (rc != SSH_OK)
  {
    ssh_channel_free(channel);
    return rc;
  }

  rc = ssh_channel_request_exec(channel, "ps aux | grep ssh");
  if (rc != SSH_OK)
  {
    ssh_channel_close(channel);
    ssh_channel_free(channel);
    return rc;
  }

  nbytes = ssh_channel_read(channel, buffer, sizeof(buffer), 0);
  while (nbytes > 0)
  {
    if (write(1, buffer, nbytes) != (unsigned int) nbytes)
    {
      ssh_channel_close(channel);
      ssh_channel_free(channel);
      return SSH_ERROR;
    }
    nbytes = ssh_channel_read(channel, buffer, sizeof(buffer), 0);
  }
    
  if (nbytes < 0)
  {
    ssh_channel_close(channel);
    ssh_channel_free(channel);
    return SSH_ERROR;
  }

  ssh_channel_send_eof(channel);
  ssh_channel_close(channel);
  ssh_channel_free(channel);

  return SSH_OK;
}

int main(int argc, char **argv) {

    // check for args num
    if (argc < 3) exit(-1);

    // assign first arg to host var
    char host[20];
    strcpy(host, argv[1]);

    // assign second arg to port var
    int port = atoi(argv[2]);

// set verbosity if need
//    int verbosity = SSH_LOG_FUNCTIONS;
//    int verbosity = SSH_LOG_PROTOCOL;
    int connection;
    
    ssh_session session;
    session = ssh_new();

    if (session == NULL) exit(-1);

    ssh_options_set(session, SSH_OPTIONS_HOST, host);
//    ssh_options_set(session, SSH_OPTIONS_LOG_VERBOSITY, &verbosity);
    ssh_options_set(session, SSH_OPTIONS_PORT, &port);
    ssh_options_set(session, SSH_OPTIONS_USER, "setevoy");

    printf("Connecting to host %s and port %d\n", host, port);
    connection = ssh_connect(session);

    if (connection != SSH_OK) {
        printf("Error connecting to %s: %s\n", host, ssh_get_error(session));
        exit -1;
    } else {
        printf("Connected.\n");
    }    

    if (verify_knownhost(session) < 0) {
        ssh_disconnect(session);
        ssh_free(session);
        exit(-1);   
    }

    int rc;
    char *password;

    password = getpass("Password: ");
    rc = ssh_userauth_password(session, NULL, password);

    if (rc != SSH_AUTH_SUCCESS) {
        fprintf(stderr, "Error authenticating with password: %s\n",
            ssh_get_error(session));
        ssh_disconnect(session);
        ssh_free(session);
        exit(-1);
    }

    if (show_remote_processes(session) != SSH_OK) {
        printf("Error executing request\n");
        ssh_get_error(session);
        ssh_disconnect(session);
        ssh_free(session);
        exit(-1);
    } else { 
        printf("\nRequest completed successfully!\n");
    }

    ssh_disconnect(session);
    ssh_free(session);
}

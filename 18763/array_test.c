#include <stdio.h>

#include <my_global.h>
#include <mysql.h>

#define DB_HOST "cdb-example.setevoy.org.ua"
#define DB_USER "setevoy"
#define DP_PASS "Heig3Ca7eiCi"
#define DB_NAME "testdb"
#define DB_TABLE "ExampleTable"
#define TEST "TEST"

void finish_with_error(MYSQL *con) {
  fprintf(stderr, "%s\n", mysql_error(con));
  mysql_close(con);
  exit(1);
}

char mysqlexec(char *query) {

    printf("Running query: %s\n", query);

    MYSQL *con = mysql_init(NULL);

    if (con == NULL) {
        fprintf(stderr, "mysql_init() failed\n");
        exit(1);
    }

    if (mysql_real_connect(con, DB_HOST, DB_USER, DP_PASS,
          DB_NAME, 0, NULL, 0) == NULL) {
      finish_with_error(con);
    }

    if (mysql_query(con, "DROP TABLE IF EXISTS " DB_TABLE)) {
      finish_with_error(con);
    }

    if (mysql_query(con, query)) {    
      finish_with_error(con);    
    }

    mysql_close(con);
    exit(0);

 }

int main() {
    
    char *textArray[] = {"a", "b", "c"};
    int intArray[] = {1, 2, 3};

    int n; 
    // count intArray[] lengh
    // example taken from the https://www.sanfoundry.com/c-program-number-elements-array/
    n = sizeof(intArray)/sizeof(int);

    int i;
    for (i=0; i<n; i++) {
        // best to check needed size for maloc() using sizeof()
        char *buffer = malloc(1024); 
        sprintf(buffer, "INSERT INTO %s (Name) VALUES('%s' '%d')" , DB_TABLE, textArray[i], intArray[i]);
        mysqlexec(buffer);
    }

    return 0;
}

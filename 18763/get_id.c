#include <my_global.h>
#include <mysql.h>

#define DB_HOST "cdb-example.setevoy.org.ua"
#define DB_USER "setevoy"
#define DP_PASS "p@ssw0rd"
#define DB_NAME "testdb"
#define DB_TABLE "ExampleTable"

void finish_with_error(MYSQL *con) {

    fprintf(stderr, "%s\n", mysql_error(con));
    mysql_close(con);
    exit(1);        
}

void mysqlexec(MYSQL *con, char *query) {

    printf("Running query: %s\n", query);

    if (mysql_query(con, query)) {
      finish_with_error(con);
    }

}

int main() {
  
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

    char *buffer = malloc(1024);
    sprintf(buffer, "CREATE TABLE %s(Id INT PRIMARY KEY AUTO_INCREMENT, TextCol TEXT, IntCol INT)", DB_TABLE);

    if (mysql_query(con, buffer)) {      
        finish_with_error(con);
    }

    char *textArray[] = {"a", "b", "c"};
    int intArray[] = {1, 2, 3};

    int n;
    // count intArray[] lengh
    // example taken from the https://www.sanfoundry.com/c-program-number-elements-array/
    n = sizeof(intArray)/sizeof(int);

    int i;
    for (i=0; i<n; i++) {
        // best to check needed size for maloc() using sizeof()
        //sprintf(buffer, "INSERT INTO %s (TextCol, IntCol) VALUES(NULL, '%s' '%d')" , DB_TABLE, textArray[i], intArray[i]);
        sprintf(buffer, "INSERT INTO %s VALUES(NULL, '%s', '%d')" , DB_TABLE, textArray[i], intArray[i]);
        mysqlexec(con, buffer);
    }

    int id = mysql_insert_id(con);

    printf("The last inserted row id is: %d\n", id);

    mysql_close(con);
    exit(0);
}

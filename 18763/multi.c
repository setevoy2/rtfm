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

int main() {

    MYSQL *con = mysql_init(NULL);

    if (con == NULL) {
      fprintf(stderr, "mysql_init() failed\n");
      exit(1);
    }

    if (mysql_real_connect(con, DB_HOST, DB_USER, DP_PASS,
          DB_NAME, 0, NULL, CLIENT_MULTI_STATEMENTS) == NULL) {
      finish_with_error(con);
    }

    char *buffer = malloc(1024);
    sprintf(buffer, "SELECT TextCol FROM %1$s WHERE Id=1; SELECT TextCol FROM %1$s WHERE Id=2; SELECT TextCol FROM %1$s WHERE Id=3", DB_TABLE);

    if (mysql_query(con, buffer)) {
        finish_with_error(con);
    }

    int status = 0;  

    do {  

        MYSQL_RES *result = mysql_store_result(con);
        
        if (result == NULL) {
            finish_with_error(con);
        }
            
        MYSQL_ROW row = mysql_fetch_row(result);
      
        printf("%s\n", row[0]);
      
        mysql_free_result(result);
                 
        status = mysql_next_result(con); 
     
        if (status > 0) {
            finish_with_error(con);
        }
      
      } while (status == 0);

    mysql_close(con);  
    exit(0);
}

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
          DB_NAME, 0, NULL, 0) == NULL) {
      finish_with_error(con);
    }

    char *buffer = malloc(1024);
    sprintf(buffer, "SELECT * FROM %s LIMIT 3", DB_TABLE);

    if (mysql_query(con, buffer)) {
      finish_with_error(con);
    }

    MYSQL_RES *result = mysql_store_result(con);

    if (result == NULL) {
      finish_with_error(con);
    }  

    int num_fields = mysql_num_fields(result);

    MYSQL_ROW row;
    MYSQL_FIELD *field;

    while ((row = mysql_fetch_row(result))) { 
      for(int i = 0; i < num_fields; i++) { 
          if (i == 0) {              
             while(field = mysql_fetch_field(result)) {
                printf("%s ", field->name);
             }
             printf("\n");           
          }
          printf("%s\t", row[i] ? row[i] : "NULL"); 
      }
    }

    printf("\n");

    mysql_free_result(result);
    mysql_close(con);

    exit(0);
}

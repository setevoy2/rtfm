#include <my_global.h>
#include <mysql.h>

#define DB_HOST "cdb-example.setevoy.org.ua"
#define DB_USER "setevoy"
#define DP_PASS "Heig3Ca7eiCi"
#define DB_NAME "testdb"
#define DB_TABLE "ExampleTable"

void finish_with_error(MYSQL *con) {

  fprintf(stderr, "%s\n", mysql_error(con));
  mysql_close(con);
  exit(1);        
}

int main(int argc, char **argv) {      

  MYSQL *con = mysql_init(NULL);
  
  if (con == NULL) {
      fprintf(stderr, "mysql_init() failed\n");
      exit(1);
  }  
  
  if (mysql_real_connect(con, DB_HOST, DB_USER, DP_PASS, 
          DB_NAME, 0, NULL, 0) == NULL) {
      finish_with_error(con);
  }    
  
  if (mysql_query(con, "SELECT * FROM " DB_TABLE)) {
      finish_with_error(con);
  }
  
  MYSQL_RES *result = mysql_store_result(con);
  
  if (result == NULL) {
      finish_with_error(con);
  }

  int num_fields = mysql_num_fields(result);

  MYSQL_ROW row;
  
  while ((row = mysql_fetch_row(result))) { 

      for(int i = 0; i < num_fields; i++) { 
          printf("%s ", row[i] ? row[i] : "NULL"); 
      } 
          printf("\n"); 
  }
  
  mysql_free_result(result);
  mysql_close(con);
  
  exit(0);
}

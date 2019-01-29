#include <my_global.h>
#include <mysql.h>

void finish_with_error(MYSQL *con) {
  fprintf(stderr, "%s\n", mysql_error(con));
  mysql_close(con);
  exit(1);        
}

int main(int argc, char **argv) {

  MYSQL *con = mysql_init(NULL);
  
  if (con == NULL) {
      fprintf(stderr, "%s\n", mysql_error(con));
      exit(1);
  }  

  if (mysql_real_connect(con, "cdb-example.setevoy.org.ua", "setevoy", "Heig3Ca7eiCi", 
          "testdb", 0, NULL, 0) == NULL) {
      finish_with_error(con);
  }    
  
  if (mysql_query(con, "DROP TABLE IF EXISTS ExampleTable")) {
      finish_with_error(con);
  }

  if (mysql_query(con, "CREATE TABLE ExampleTable(Id INT, TextCol TEXT, IntCol INT)")) {      
      finish_with_error(con);
  }

  if (mysql_query(con, "INSERT INTO ExampleTable VALUES(1, 'TextValue', 12345)")) {
      finish_with_error(con);
  }

  mysql_close(con);
  exit(0);

}

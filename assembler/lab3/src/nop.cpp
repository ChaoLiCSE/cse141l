#include <iostream>
#include <fstream>
using namespace std;

int main(int argc, char *argv[]){
   ifstream file_i(argv[1]);
   ofstream file_o(argv[2]);

   string s;
   while(1) {
     if(file_i.eof()) {
         break;
      }
      file_i >> s;
      file_o << s << '\n' << "A000" << endl;
   }
   
   file_i.close();
   file_o.close();
   
   return 0;
}

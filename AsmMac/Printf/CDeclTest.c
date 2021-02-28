extern void myprintf(char* format, ...);


int main(){
    unsigned x = 912690;
    
    myprintf("%s %d is %h in hex?\n"
             "Even more. It's also %b and %o\n"
             "in binary and octal notations respectively.\n\n"
             "%s %d * 2 = %d\n%s",
             
             "You know that",
             x,
             x,
             x,
             x,
             "These params are passed by stack\n"
             "as System V works this way:",
             x,
             x * 2,
             "\nCat.\n");
}



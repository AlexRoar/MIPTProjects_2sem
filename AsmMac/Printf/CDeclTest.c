extern void myprintf(char* format, ...);

extern unsigned sumWrapper(unsigned a, unsigned b);


int main(){
    unsigned x = 912690;
    
    myprintf("%s %d is %x in hex?\n"
             "Even more. It's also %b and %o\n"
             "in binary and octal notations respectively.\n\n"
             "%s %d + %d * 2 = %d (%x)"
             "\n%s%c%c%c\n"
             "And I %s %x %d%%%c %b\n",
             
             "You know that",
             x,
             x,
             x,
             x,
             // STACK
             "These params are passed by stack\n"
             "as System V works this way:",
             x,
             x,
             sumWrapper(x, x * 2),
             sumWrapper(x, x * 2),
             "\nCa",
             't',
             '.',
             '\n',
             "love",
             3802,
             100,
             33,
             255);
}


unsigned sum(unsigned a, unsigned b) {
    return a + b;
}

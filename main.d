
//import pey;
import pey.codereader;
import pey.common;
import sm;

import std.outbuffer;

int main() {
    auto reader = new FileCodeReader("test.sm");

    /+
    while(!reader.empty) {
        io.write(reader.c);
        reader.next();
    }
    +/

    auto lexer = new Lexer(reader);
    /+
    Token token;
    while(!lexer.empty) {
        if(lexer.parseToken(token))
            io.writeln(token);
    }
    +/

    Parser parser = new Parser(lexer);
    Instruction inst;
    int mem = 0;
    while(!parser.empty) {
        if(parser.parseInstruction(inst))
            io.write(toCode(inst, mem));
        mem++;
    }



    return 0;
}


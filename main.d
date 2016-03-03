
//import pey;
import pey.codereader;
import pey.common;
import sm;

int main() {
    auto reader = new FileCodeReader("test.sm");

    /+
    while(!reader.empty) {
        io.write(reader.c);
        reader.next();
    }
    +/

    auto lexer = new Lexer(reader);
    Token token;
    /+
    while(!lexer.empty) {
        if(lexer.parseToken(token))
            io.writeln(token);
    }
    +/

    Parser parser = new Parser(lexer);
    Instruction inst;
    while(!parser.empty) {
        if(parser.parseInstruction(inst))
            io.writeln(inst);
    }



    return 0;
}


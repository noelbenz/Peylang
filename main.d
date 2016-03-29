
//import pey;
import pey.codereader;
import pey.common;
import sm;

import std.stdio;
import std.exception;
import std.outbuffer;

int main(string[] args) {

    if(args.length != 2) {
        printHelp();
        return 1;
    }

    CodeReader reader;
    try {
        reader = new FileCodeReader(args[1]);
    } catch(ErrnoException ex) {
        io.writefln("File %s could not be opened. (errno = %d)", args[1], ex.errno);
        return 1;
    }

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

    auto parser = new Parser(lexer);
    /+
    Instruction inst;
    int mem = 0;
    while(!parser.empty) {
        if(parser.parseInstruction(inst))
            io.write(toCode(inst, mem));
        mem++;
    }
    +/

    auto trans = new CTranslator(parser);
    trans.run();

    io.writeln(cast(char[])trans.labels.toBytes());
    io.writeln(cast(char[])trans.code.toBytes());


    return 0;
}

string help = `
SYPNOSIS:
sm [options] FILE
`;

void printHelp() {
    io.writeln(help);
}


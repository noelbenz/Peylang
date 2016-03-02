
import pey;
import pey.common;

int main() {
    auto reader = new FileCodeReader("test.pey");

    /+
    while(!reader.empty) {
        io.write(reader.c);
        reader.next();
    }
    +/

    auto lexer = new Lexer(reader);
    Token token;
    while(!lexer.empty) {
        if(lexer.parseToken(token))
            io.writeln(token);
    }

    return 0;
}


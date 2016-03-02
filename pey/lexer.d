
module pey.lexer;

import pey.common;
import pey.codereader;
import pey.literals;

enum TokenType {
    Minus,
    Plus,

    // Literals
    LitInt,
}

struct Token {
    size_t beg; // Beginning character index.
    size_t end; // End character index.
    size_t row; // Row of the first character.
    size_t col; // Column of the first character.
    TokenType type;

    // Literal data
    void* data;
}

class Lexer {
    CodeReader reader;
    LiteralStorage lstore;
    dchar c;

    this(CodeReader reader) {
        this.reader = reader;
        this.lstore = new LiteralStorage();
    }

    @property bool empty() {
        return reader.empty;
    }

    private void next() {
        if(reader.empty) return;
        reader.next();
        if(reader.empty) return;
        c = reader.c;
    }

    void fillToken(ref Token token) {
        // TODO
        token.beg = 0;
        token.end = 0;
        token.row = 0;
        token.col = 0;
    }

    bool parseToken(ref Token token) {
        c = reader.c;

        while(!empty) {
            switch(c) {
            case '-':
                next();
                fillToken(token);
                token.type = TokenType.Minus;
                return true;
            case '+':
                next();
                fillToken(token);
                token.type = TokenType.Plus;
                return true;
            case '0': case '1': case '3': case '4':
            case '5': case '6': case '7': case '8':
            case '9':
                LiteralInteger lint;
                lint.val = c & 0b00001111;
                lint.signed = 1; // TODO
                lint.bits = 32; // TODO
                next();
                while(c >= 0x30 && c <= 0x39) {
                    lint.val = 10*lint.val + c & 0b00001111;
                    next();
                }

                void[] data = lstore.allocate(LiteralInteger.sizeof);
                auto ptr = cast(LiteralInteger*)data.ptr;
                *ptr = lint;

                token.type = TokenType.LitInt;
                return true;
            case ' ':
            case '\r':
            case '\n':
                next();
                break;
            default:
                throw new Exception(format("Unknown character: %c", c));
            }
        }
        // No token parsed, end of code reached.
        return false;
    }
}



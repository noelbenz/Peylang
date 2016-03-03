
module sm.lexer;

import pey.common;
import pey.codereader;
import pey.literals;

import sm.spec;

struct Token {
    size_t beg;       // Beginning character index (inclusive).
    size_t end;       // End character index (exclusive).
    size_t row;       // Row of the first character.
    size_t col;       // Column of the first character.
    OpCode op;        // Op code
    SubOpCode subop;  // Sub-Op code
    int imm;          // Immediate value
}

class LexerException : Exception {
    size_t beg;
    size_t row;
    size_t col;

    this(string msg, size_t beg, size_t row, size_t col) {
        super(format("[c%d r%d c%d]: %s", beg, row, col, msg));
        this.beg = beg;
        this.row = row;
        this.col = col;
    }
}

class Lexer {
    CodeReader reader;
    LiteralStorage lstore;
    dchar c;

    int pos;
    int row;
    int col;

    this(CodeReader reader) {
        this.reader = reader;
        this.lstore = new LiteralStorage();

        pos = 1;
        row = 1;
        col = 1;
    }

    @property bool empty() {
        return reader.empty;
    }

    private void next() {
        if(reader.empty) return;
        reader.next();
        pos++;
        col++;
        if(reader.empty) return;
        c = reader.c;
    }

    private void newLine() {
        row++;
        col = 1;
    }

    void fillToken(ref Token token) {
        token.beg = pos;
        token.end = pos+1;
        token.row = row;
        token.col = col;
    }

    Exception exception(string msg, size_t beg, size_t row, size_t col) {
        return new LexerException(msg, beg, row, col);
    }
    Exception exception(string msg, const ref Token token) {
        return exception(msg, token.beg, token.row, token.col);
    }
    Exception exception(string msg) {
        return exception(msg, pos, row, col);
    }

    void parseNumber(ref Token token, int init, bool negative) {
        token.imm = init;
        while(c >= 0x30 && c <= 0x39) {
            token.imm = 10*token.imm + (cast(int)c & 0b00001111);
            if(token.imm > 255)
                throw exception("Number literal is outside the allowed range [-128, 255].");
            next();
        }
        if(negative) {
            token.imm = -token.imm;
            if(token.imm < -128)
                throw exception("Number literal is outside the allowed range [-128, 255].");
        }
        token.end = pos;
    }


    bool parseToken(ref Token token) {
        c = reader.c;

        while(!empty) {
            switch(c) {
            case '-':
                fillToken(token);
                next();
                parseNumber(token, 0, true);
                return true;
            case '0': .. case'9':
                fillToken(token);
                int init = (cast(int)c & 0b00001111);
                next();
                parseNumber(token, init, false);
                return true;
            case '\n':
                next();
                newLine();
                break;
            case ' ':
            case '\t':
            case '\r':
                next();
                break;
            default:
                throw exception(format("Unknown character: %c", c));
            }
        }
        // No token parsed, end of code reached.
        return false;
    }
}




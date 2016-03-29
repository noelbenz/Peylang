
module sm.lexer;

import pey.common;
import pey.codereader;
import pey.literals;

import sm.spec;

enum TokenType {
    Op,
    Immediate,
    Identifier,
    Register,

    // Symbols
    Colon,
}
struct Token {
    size_t beg;       // Beginning character index (inclusive).
    size_t end;       // End character index (exclusive).
    size_t row;       // Row of the first character.
    size_t col;       // Column of the first character.
    TokenType type;   // Type of Token.
    OpCode op;        // Op code.
    int imm;          // Immediate value.
    dstring ident;    // Identifier.
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
    dchar c;

    int pos;
    int row;
    int col;

    enum ImmediateMax = (1 << 16) - 1;
    enum ImmediateMin = -(1 << 15);
    string ImmediateOutOfRangeMsg = format(
            "Number literal is outside the allowed range [%d, %d].",
            ImmediateMin, ImmediateMax);

    // Character length limit for identifiers.
    enum maxIdentifier = 256;
    dchar[maxIdentifier] stringBuffer;

    this(CodeReader reader) {
        this.reader = reader;

        reset();
    }

    /++
      + Returns false if there is no more code to be parsed.
      +
      + If <empty> returns true, it only means there are more characters
      + in the code reader to parse. It may be the case that none of the left
      + over characters make up a token. In other words, if <empty> returns
      + true, it is not gaurantee that <parseToken> will produce
      + another token. For that, the return value of <parseToken> should be
      + checked.
      +
     ++/
    @property bool empty() {
        return reader.empty;
    }

    void reset() {
        pos = 1;
        row = 1;
        col = 1;
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

    private void parseNumber(ref Token token, int init, bool negative) {
        token.imm = init;
        while(c >= 0x30 && c <= 0x39) {
            token.imm = 10*token.imm + (cast(int)c & 0b00001111);
            if(token.imm > ImmediateMax)
                throw exception(ImmediateOutOfRangeMsg);
            next();
        }
        if(negative) {
            token.imm = -token.imm;
            if(token.imm < ImmediateMin)
                throw exception(ImmediateOutOfRangeMsg);
        }
        token.end = pos;
        token.type = TokenType.Immediate;
    }


    /++
      + Parses a token and advances.
      +
      + Returns true iff a token was parsed. If the end of the code has been
      + reached without parsing a token, <parseToken> will return false, and
      + thus the token passed by reference contains no valuable information.
     ++/
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
            case 'r':
                dchar nextc = reader.peek(1);
                if(nextc < '0' || nextc > '9')
                    goto identifier;
                fillToken(token);
                next();
                parseNumber(token, 0, false);
                if(token.imm > 15)
                    throw exception(format("Register number %d does not exist.",
                                           token.imm));
                token.type = TokenType.Register;
                return true;
            case 'a': .. case 'q':
            case 's': .. case 'z':
            case 'A': .. case'Z':
            case '_':
            identifier:
                fillToken(token);
                stringBuffer[0] = c;
                int i = 1;
                next();
                while((c >= 'a' && c <= 'z') ||
                      (c >= 'A' && c <= 'Z') ||
                      (c >= '0' && c <= '9') ||
                      (c == '_')) {
                    if(i >= stringBuffer.length)
                        throw exception(format(
                              "Identifier exceeds maximum length of %d characters.",
                              maxIdentifier));
                    stringBuffer[i] = c;
                    i++;
                    next();
                }
                token.end = pos;
                token.ident = stringBuffer[0..i].idup;

                if(determineOpCode(token.ident, token.op))
                    token.type = TokenType.Op;
                else
                    token.type = TokenType.Identifier;

                return true;
            case ':':
                fillToken(token);
                next();
                token.type = TokenType.Colon;
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




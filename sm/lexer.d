
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

    private void parseNumber(ref Token token, bool negative) {

        int radix = 10;
        if(c == '0') {
            next();
            if(c == 'x' || c == 'X') {
                radix = 16;
                next();
            } else if(c == 'b' || c == 'B') {
                radix = 2;
                next();
            }
        }


        token.imm = 0;
        bool done;

        while(true) {
            switch(c) {
            case '0':
                token.imm = token.imm*radix + 0;
                break;
            case '1':
                token.imm = token.imm*radix + 1;
                break;
            case '2':
                if(radix < 3) throw exception(format(
                    "Radix %d number cannot contain digit %c.", radix, c));
                token.imm = token.imm*radix + 2;
                break;
            case '3':
                if(radix < 4) throw exception(format(
                    "Radix %d number cannot contain digit %c.", radix, c));
                token.imm = token.imm*radix + 3;
                break;
            case '4':
                if(radix < 5) throw exception(format(
                    "Radix %d number cannot contain digit %c.", radix, c));
                token.imm = token.imm*radix + 4;
                break;
            case '5':
                if(radix < 6) throw exception(format(
                    "Radix %d number cannot contain digit %c.", radix, c));
                token.imm = token.imm*radix + 5;
                break;
            case '6':
                if(radix < 7) throw exception(format(
                    "Radix %d number cannot contain digit %c.", radix, c));
                token.imm = token.imm*radix + 6;
                break;
            case '7':
                if(radix < 8) throw exception(format(
                    "Radix %d number cannot contain digit %c.", radix, c));
                token.imm = token.imm*radix + 7;
                break;
            case '8':
                if(radix < 9) throw exception(format(
                    "Radix %d number cannot contain digit %c.", radix, c));
                token.imm = token.imm*radix + 8;
                break;
            case '9':
                if(radix < 10) throw exception(format(
                    "Radix %d number cannot contain digit %c.", radix, c));
                token.imm = token.imm*radix + 9;
                break;
            case 'A':
            case 'a':
                if(radix < 11) throw exception(format(
                    "Radix %d number cannot contain digit %c.", radix, c));
                token.imm = token.imm*radix + 10;
                break;
            case 'B':
            case 'b':
                if(radix < 12) throw exception(format(
                    "Radix %d number cannot contain digit %c.", radix, c));
                token.imm = token.imm*radix + 11;
                break;
            case 'C':
            case 'c':
                if(radix < 13) throw exception(format(
                    "Radix %d number cannot contain digit %c.", radix, c));
                token.imm = token.imm*radix + 12;
                break;
            case 'D':
            case 'd':
                if(radix < 14) throw exception(format(
                    "Radix %d number cannot contain digit %c.", radix, c));
                token.imm = token.imm*radix + 13;
                break;
            case 'E':
            case 'e':
                if(radix < 15) throw exception(format(
                    "Radix %d number cannot contain digit %c.", radix, c));
                token.imm = token.imm*radix + 14;
                break;
            case 'F':
            case 'f':
                if(radix < 16) throw exception(format(
                    "Radix %d number cannot contain digit %c.", radix, c));
                token.imm = token.imm*radix + 15;
                break;
            case ' ':
            case '\t':
            case '\r':
            case '\n':
                done = true;
                break;
            default:
                exception(format("Expected a digit, not %d.", c));
            }

            if(token.imm > ImmediateMax)
                throw exception(ImmediateOutOfRangeMsg);

            if(done)
                break;

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
                parseNumber(token, true);
                return true;
            case '0': .. case'9':
                fillToken(token);
                parseNumber(token, false);
                return true;
            case 'r':
                dchar nextc = reader.peek(1);
                if(nextc < '0' || nextc > '9')
                    goto identifier;
                fillToken(token);
                next();
                parseNumber(token, false);
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
            case ';':
                next();
                while(c != '\n')
                    next();
                break;
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




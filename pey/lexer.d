
module pey.lexer;

import pey.common;
import pey.codereader;

/++
  + Allocates space for literals.
 ++/
class LiteralStorage {
    enum initBlocksN = 16;
    enum blockSize = 1024;

    struct Block {
        ubyte[] space;
        size_t pos;

        void init(size_t size) {
            space = new ubyte[size];
            pos = 0;
        }

        @property size_t spaceLeft() {
            return space.length - pos;
        }
        /++
          + Allocates and returns a slice of <size> bytes. An empty slice
          + is returned if there is not enough space.
         ++/
        void[] allocate(size_t size) {
            if(spaceLeft < size)
                return new ubyte[0];
            void[] slice = space[pos..pos+size];
            pos += size;
            return slice;
        }
    }

    Block[] blocks;
    size_t pos;

    this() {
        blocks = new Block[initBlocksN];
        pos = 0;
    }

    /++ Allocates a new block of space. ++/
    private void newBlock() {
        pos++;
        if(pos > blocks.length)
            blocks.length += initBlocksN;

        blocks[pos].init(blockSize);
    }

    /++ Allocates and returns a block of space that is <size> bytes. ++/
    void[] allocate(size_t size) {
        // For big blocks its best to just defer to normal allocation.
        if(size > blockSize/2)
            return new ubyte[size];

        // Find a block that has enough space.
        for(int i = 0; i <= pos; i++) {
            Block b = blocks[i];
            // If a block has enough space, allocate from it and return.
            if(b.spaceLeft > size)
                return b.allocate(size);
        }
        // No blocks that will work, need a new block.
        newBlock();
        return blocks[pos].allocate(size);
    }
}

struct LiteralInteger {
    ulong val;
    int bits;
    bool signed;
}
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



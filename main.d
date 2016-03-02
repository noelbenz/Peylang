
import io = std.stdio;
    alias File = io.File;
import utf = std.utf;
import std.format;

/++
  + Represents a position in code. Used by CodeReader to
  + return to previous code for multi-pass compilation.
 ++/
abstract class CodePosition {}
/++
  + Abstraction for reading code by character.
  +
  + Note: It is expected that the reader parses new-lines such that
  +       any new line is returned as a single 0x0a(\n) character.
  ++/
abstract class CodeReader {

    /++ Returns the current character. ++/
    @property dchar c();

    /++ Move on to the next character. ++/
    @property void next();


    /++ Gauranteed amount of characters that can always be peeked at. ++/
    @property size_t peekMin();

    /++ Maximum number of characters that can be peeked at. ++/
    @property size_t peekMax();

    /++
      + Look ahead n characters and return the value.
      + There may be limitations on the size of n depending on the
      + underlying implentation. This limitation can be tested against
      + with @peekc.
     ++/
    @property dchar peek(size_t n);

    /++ Returns false iff there is more code to be read. ++/
    @property bool empty();


    /++ Returns the position of the current code. ++/
    @property CodePosition pos();
    /++ Repositions the code reader. ++/
    @property void pos(CodePosition cp);
}

class FileCodePosition : CodePosition {
    ulong pos;

    this(ulong pos) {
        this.pos = pos;
    }
}
class FileCodeReader : CodeReader {
    private enum _peekMin = 16;
    File file;

    char[256] buffer;  // Allocated buffer space
    char[] buf;        // Buffer slice
    dchar[_peekMin*2] cbuffer; // Character buffer
    dchar[] cbuf;      // Character buffer slice
    ulong _pos;



    this(string path) {
        file = File(path, "r");
        _pos = 0;
        updateBuffers();
    }

    /++
      + Copy from one slice to another even if they overlap.
     ++/
    private void bufferCopy(T)(T[] src, T[] dest)
    in {
        assert(dest.length >= src.length);
    } body {
        // If there is overlap, copy one at a time.
        if(src.ptr - dest.ptr < src.length) {
            for(int c = 0; c < src.length; c++)
                dest[c] = src[c];
        } else {
            dest[0..src.length] = src;
        }
    }

    /++
      + Read more from the file into the buffer if needed.
      + Ensures that the number of buffered characters remains above
      + _peekMin.
     ++/
    private void updateBuffers() {
        if(cbuf.length >= _peekMin)
            return;
        // Move remaining characters to the front.
        bufferCopy(cbuf, cbuffer[0..cbuf.length]);
        // Fill in the rest.
        bool cr = false;
        dchar c;
        int i;
        for(i = cbuf.length; i < cbuffer.length; i++) {
            // Ensure there are always at least 8 bytes in the buffer.
            if(buf.length < 8) {
                // Move remaining bytes to the front.
                bufferCopy(buf, buffer[0..buf.length]);
                // Fill in the rest.
                char[] read = file.rawRead(buffer[buf.length..$]);
                // Adjust buf slice.
                buf = buffer[0..buf.length+read.length];
            }
            // Buffer is empty, no more characters.
            if(buf.length == 0)
                break;
            // Decode the next character.
            c = utf.decodeFront(buf);
            // Handle CR(0x0d \r) and LF(0x0a \n)
            if(cr && c == '\n') {
                i = i-1;
                cbuffer[i] = c;
            } else {
                cbuffer[i] = c;
            }
            // Update CR
            cr = (c == '\r');
            //io.writeln("CBUFFER[", i, "] = ", cbuffer[i]);
        }

        // Adjust cbuf slice.
        cbuf = cbuffer[0..i];
    }

    override @property bool empty() {
        return cbuf.length == 0;
    }

    override @property dchar c() {
        return cbuf[0];
    }

    override @property void next() {
        _pos += utf.codeLength!char(cbuf[0]);
        cbuf = cbuf[1..$];
        updateBuffers();
    }

    override @property size_t peekMin() {
        return _peekMin;
    }
    override @property size_t peekMax() {
        return cbuf.length;
    }

    override @property dchar peek(size_t n) {
        if(n >= cbuf.length)
            throw new Exception("Attempt to peek past the character buffer.");
        return cbuf[n];
    }

    override @property CodePosition pos() {
        return new FileCodePosition(_pos);
    }
    override @property void pos(CodePosition _cp) {
        auto cp = cast(FileCodePosition)_cp;
        file.seek(cast(long)cp.pos);
        _pos = cp.pos;
        buf = new char[0];
        cbuf = new dchar[0];
        updateBuffers();
    }
}

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

/*------------------------------------------------------
 *     opcode   | regc       | subop      | rega       |
 *------------------------------------------------------
 *  0: subop    |            | 0:  noop   |            |
 *  0: subop    | r dest     | 1:  ldmem  | r address  |
 *  0: subop    | r address  | 2:  stmem  | r val      |
 *  0: subop    | r address  | 3:  call   | r stackptr |
 *  0: subop    |            | 4:  ret    | r stackptr |
 *  0: subop    | r cond     | 5:  jump   | r address  |
 *  0: subop    | r cond     | 6:  bra    | r offset   |
 *  0: subop    |            | 7:  none0  |            |
 *  0: subop    |            | 8:  none1  |            |
 *  0: subop    | r dest     | 9:  not    | r val      |
 *  0: subop    | r dest     | 10: neg    | r val      |
 *  0: subop    | r dest     | 11: cshout | r val      |
 *  0: subop    | r dest     | 12: popcnt | r count    |
 *  0: subop    | r dest     | 13: bitrev | r val      |
 *  0: subop    | r dest     | 14: pop    | r stackptr |
 *  0: subop    | r val      | 15: push   | r stackptr |
 *------------------------------------------------------
 *     opcode   | regc       | regb       | rega       |
 *------------------------------------------------------
 *  1: add      | r dest     | r left     | r right    |
 *  2: sub      | r dest     | r left     | r right    |
 *  3: mul      | r dest     | r left     | r right    |
 *  4: div      | r dest     | r left     | r right    |
 *  5: xor      | r dest     | r left     | r right    |
 *  6: and      | r dest     | r left     | r right    |
 *  7: lor      | r dest     | r left     | r right    |
 *  8: sleft    | r dest     | r left     | r right    |
 *  9: sright   | r dest     | r left     | r right    |
 * 10: lt       | r dest     | r left     | r right    |
 * 11: lteq     | r dest     | r left     | r right    |
 * 12: cmove    | r dest     | r cond     | r value    |
 * 13: cadd     | r dest     | r cond     | r value    |
 *------------------------------------------------------
 *     opcode   | regc       | immediate               |
 *------------------------------------------------------
 * 14: immlow   | r dest     | i immediate value       |
 * 15: immhigh  | r dest     | i immediate value       |
 *------------------------------------------------------
 */

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


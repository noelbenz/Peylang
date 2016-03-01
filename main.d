
import io = std.stdio;
    alias File = io.File;
import utf = std.utf;

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
    ulong pos;



    this(string path) {
        file = File(path, "r");
        pos = 0;
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
            io.writeln("CBUFFER[", i, "] = ", cbuffer[i]);
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
        pos += utf.codeLength!char(cbuf[0]);
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
        return new FileCodePosition(pos);
    }
    override @property void pos(CodePosition _cp) {
        auto cp = cast(FileCodePosition)_cp;
        file.seek(cast(long)cp.pos);
        pos = cp.pos;
        buf = new char[0];
        cbuf = new dchar[0];
        updateBuffers();
    }
}

int main() {
    auto reader = new FileCodeReader("unicode.pey");

    while(!reader.empty) {
        io.writeln("C: ", reader.c);
        reader.next();
    }

    return 0;
}



module pey.literals;

import pey.common;

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


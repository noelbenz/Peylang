
module sm.simulator;

import pey.common;

import sm.spec;

class Simulator {
    ushort[] mem;
    ushort regs[16];
    ushort _pc;

    this(ushort[] mem, int entryAddr = 0x4000) {
        this.mem = mem;
        this.pc = cast(ushort)entryAddr;
    }


    @property ushort pc() { return _pc; }
    @property void pc(long newpc) { _pc = cast(ushort)newpc; }

    ushort read(size_t addr) {
        return mem[addr];
    }

    void write(size_t addr, ushort val) {
        mem[addr] = val;
    }

    void step() {
        ushort op = read(pc);
        pc = pc + 1;

        int opcode = (op >> 12) & 0x000F;
        int c      = (op >>  8) & 0x000F;
        int b      = (op >>  4) & 0x000F;
        int a      = (op      ) & 0x000F;

        int imm    = (op      ) & 0x00FF;

        io.writefln("%4X: [%d] (%d) %d %d %d", pc-1, opcode, imm, c, b, a);

        switch(opcode) {
        case SmOpCode.SubOp:
            switch(b) {
                case SmSubOpCode.Noop:
                    break;
                case SmSubOpCode.LoadMemory:
                    regs[c] = read(regs[a]);
                    break;
                case SmSubOpCode.StoreMemory:
                    write(regs[c], regs[a]);
                    break;
                case SmSubOpCode.Call:
                    regs[a]--;
                    write(regs[a], pc);
                    pc = regs[c];
                    break;
                case SmSubOpCode.Return:
                    pc = read(regs[a]);
                    regs[a]++;
                    break;
                case SmSubOpCode.Jump:
                    if(regs[c])
                        pc = regs[a];
                    break;
                case SmSubOpCode.Branch:
                    if(regs[c])
                        pc = pc + regs[a];
                    break;
                case SmSubOpCode.BitNot:
                    regs[c] = ~regs[a];
                    break;
                case SmSubOpCode.Negate:
                    regs[c] = -regs[a];
                    break;
                case SmSubOpCode.LogicNot:
                    regs[c] = !regs[a];
                    break;
                case SmSubOpCode.PopCount:
                    int count = 0;
                    ushort r = regs[a];
                    while(r > 0) {
                        count += r & 1;
                        r >>= 1;
                    }
                    regs[c] = cast(ushort)count;
                    break;
                case SmSubOpCode.BitReverse:
                    ushort rev = 0;
                    ushort r = regs[a];
                    rev |= (r & 0x0001) << 15;
                    rev |= (r & 0x0002) << 13;
                    rev |= (r & 0x0004) << 11;
                    rev |= (r & 0x0008) <<  9;
                    rev |= (r & 0x0010) <<  7;
                    rev |= (r & 0x0020) <<  5;
                    rev |= (r & 0x0040) <<  3;
                    rev |= (r & 0x0080) <<  1;
                    rev |= (r & 0x0100) >>  1;
                    rev |= (r & 0x0200) >>  3;
                    rev |= (r & 0x0400) >>  5;
                    rev |= (r & 0x0800) >>  7;
                    rev |= (r & 0x1000) >>  9;
                    rev |= (r & 0x2000) >> 11;
                    rev |= (r & 0x4000) >> 13;
                    rev |= (r & 0x8000) >> 15;
                    regs[c] = rev;
                    break;
                case SmSubOpCode.Pop:
                    regs[a] = read(regs[c]);
                    regs[c]++;
                    break;
                case SmSubOpCode.Push:
                    regs[c]--;
                    write(regs[c], regs[a]);
                    regs[a] = regs[c];
                    break;
                default:
                assert(false);
            }
            break;
        case SmOpCode.Add:
            regs[c] = cast(ushort)(regs[b] + regs[a]);
            break;
        case SmOpCode.Subtract:
            regs[c] = cast(ushort)(regs[b] - regs[a]);
            break;
        case SmOpCode.Multiply:
            regs[c] = cast(ushort)(regs[b] * regs[a]);
            break;
        case SmOpCode.Divide:
            regs[c] = cast(ushort)(regs[b] / regs[a]);
            break;
        case SmOpCode.BitXor:
            regs[c] = cast(ushort)(regs[b] ^ regs[a]);
            break;
        case SmOpCode.BitAnd:
            regs[c] = cast(ushort)(regs[b] & regs[a]);
            break;
        case SmOpCode.BitOr:
            regs[c] = cast(ushort)(regs[b] | regs[a]);
            break;
        case SmOpCode.ShiftLeft:
            regs[c] = cast(ushort)(regs[b] << (regs[a] & 0xF));
            break;
        case SmOpCode.ShiftRight:
            regs[c] = cast(ushort)(regs[b] >> (regs[a] & 0xF));
            break;
        case SmOpCode.LessThan:
            regs[c] = cast(ushort)(regs[b] < regs[a]);
            break;
        case SmOpCode.LessThanOrEqual:
            regs[c] = cast(ushort)(regs[b] <= regs[a]);
            break;
        case SmOpCode.ConditionalMove:
            if(regs[b])
                regs[c] = cast(ushort)(regs[a]);
            break;
        case SmOpCode.ConditionalAdd:
            if(regs[b])
                regs[c] += cast(ushort)(regs[a]);
            break;
        case SmOpCode.ImmediateLow:
            regs[c] = cast(ushort)((regs[c] & 0xFF00) | imm);
            break;
        case SmOpCode.ImmediateHigh:
            regs[c] = cast(ushort)((regs[c] & 0x00FF) | (imm << 8));
            break;
        default:
            assert(false);
        }
    }
}

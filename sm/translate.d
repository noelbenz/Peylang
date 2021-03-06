
module sm.translate;

import std.outbuffer;
import std.bitmanip;
import std.utf;

import pey.common;

import sm.spec;
import sm.parser;

const int SmVersion = 6;

//------------------------------------------------------------------------------
// Binary Translator
//------------------------------------------------------------------------------

struct ResolveNode {
    size_t relative;
    size_t memi;
    bool high;
    dstring ident;

    ResolveNode* next;
}

class BinaryTranslator {
    Parser parser;
    Instruction inst;
    size_t[dstring] labels;
    ubyte[] mem;
    size_t memi;
    size_t memhigh;

    ResolveNode* curNode = null;

    this(Parser parser) {
        this.parser = parser;

        mem = new ubyte[65536 * 2];
    }

    void addResolveNode(ResolveNode *node) {
        if(curNode == null) {
            curNode = node;
        } else {
            node.next = curNode;
            curNode = node;
        }
    }

    void write(ushort val) {
        mem[memi] = cast(ubyte)(val >> 8);
        memi++;
        mem[memi] = cast(ubyte)(val     );
        memi++;
        if(memi > memhigh)
            memhigh = memi;
    }

    void writeImmediate(SmOpCode op, int dest, int value, dstring ident) {

        bool high = (op == SmOpCode.ImmediateHigh);
        if(high)
            value >>= 8;

        ushort val = cast(ushort)op;
        val <<= 4;
        val |= dest & 0xF;
        val <<= 8;
        val |= value & 0xFF;

        if(ident.length > 0) {
            ResolveNode* node = new ResolveNode();
            node.relative = 0;
            node.high = high;
            node.ident = ident;
            node.memi = memi+1;

            addResolveNode(node);
        }

        write(val);
    }

    void outputInstruction() {

        ushort val;
        switch(inst.op) {
        case OpCode.Label:
            labels[inst.label] = memi;
            break;
        case OpCode.Data:
            write(cast(ushort)inst.data);
            break;
        case OpCode.Offset:
            memi = inst.data*2;
            break;

        case OpCode.Noop:
            write(0);
            break;

        // Reg-Reg
        case OpCode.LoadMemory: .. case OpCode.Push:
            val = cast(ushort)(inst.args[0].value & 0xF);
            val <<= 4;
            val |= toSubOpCode(inst.op) & 0xF;
            val <<= 4;
            val |= inst.args[1].value & 0xF;

            write(val);
            break;

        // Reg-Reg-Reg
        case OpCode.Add: .. case OpCode.ConditionalAdd:
            val = cast(ushort)toOpCode(inst.op);
            val <<= 4;
            val |= inst.args[0].value & 0xF;
            val <<= 4;
            val |= inst.args[1].value & 0xF;
            val <<= 4;
            val |= inst.args[2].value & 0xF;

            write(val);
            break;

        // Immediate
        case OpCode.ImmediateHigh:
        case OpCode.ImmediateLow:
            writeImmediate(toOpCode(inst.op), inst.args[0].value,
                inst.args[1].value, inst.args[1].ident);
            break;

        // Special
        case OpCode.Immediate:
            writeImmediate(SmOpCode.ImmediateLow, inst.args[0].value,
                inst.args[1].value, inst.args[1].ident);
            writeImmediate(SmOpCode.ImmediateHigh, inst.args[0].value,
                inst.args[1].value, inst.args[1].ident);
            break;

        default:
            // Cases should be complete.
            assert(false);
            break;
        }

    }

    void resolve() {
        while(curNode != null) {
            size_t* search = (curNode.ident in labels);
            if(search == null)
                throw new Exception(format("Unable to resolve label %d.", curNode.ident));

            size_t value = *search / 2;

            // TODO: Relative for branch instruction
            if(curNode.high)
                value = value >> 8;
            mem[curNode.memi] = cast(ubyte)value;

            curNode = curNode.next;
        }
    }

    ubyte[] run() {
        memi = 0;
        memhigh = 0;
        while(!parser.empty) {
            if(parser.parseInstruction(inst))
                outputInstruction();
        }

        resolve();

        return mem[0..memhigh];
    }
}

//------------------------------------------------------------------------------
// C Translator
//------------------------------------------------------------------------------

private immutable string[OpCode] convtbl;

string toOpMacro(OpCode op) {
    auto opMacro = (op in convtbl);
    if(opMacro)
        return *opMacro;
    else
        return "";
}

bool isSubOp(OpCode op) {
    return op >= OpCode.LoadMemory && op <= OpCode.Push;
}

bool isImmOp(OpCode op) {
    return op == OpCode.ImmediateLow || op == OpCode.ImmediateHigh ||
           op == OpCode.Immediate;
}

class CTranslator {
    Parser parser;
    Instruction inst;
    OutBuffer labels;
    OutBuffer code;
    uint addr;
    uint immN;

    this(Parser parser) {
        this.parser = parser;
        labels = new OutBuffer;
        code = new OutBuffer;
    }

    void outputCode() {
        if(inst.op == OpCode.Label) {
            string label = toUTF8(inst.label);
            labels.writef("const u16 L_%s = %d;\n", label, addr);
            code.writef("// %s\n", label);
            return;
        }
        if(inst.op == OpCode.Data) {
            code.writef("mem[%5d] = %d;\n", addr, inst.data);
            addr++;
            return;
        }
        if(inst.op == OpCode.Offset) {
            addr = inst.data;
            return;
        }

        string opMacro = toOpMacro(inst.op);
        if(isImmOp(inst.op)) {
            string val;
            if(inst.args[1].ident.length == 0)
                val = to!string(inst.args[1].value);
            else
                val = "L_" ~ toUTF8(inst.args[1].ident);

            if(inst.op != OpCode.Immediate) {
                string fmt = "mem[%5d] = make_inst(%8s, %16s, %4d,        0,    0);\n";
                code.writef(fmt, addr, opMacro, val, inst.args[0].value);
                addr++;
            } else {
                string fmt = "mem[%5d] = make_inst(%8s, %16s, %4d,        0,    0);\n";
                code.writef(fmt, addr, "IMMLOW", "L(" ~ val ~ ")", inst.args[0].value);
                addr++;
                code.writef(fmt, addr, "IMMHGH", "H(" ~ val ~ ")", inst.args[0].value);
                addr++;
            }
        } else if(isSubOp(inst.op)) {
            string fmt = "mem[%5d] = make_inst(%8s, %16d, %4d, %8s, %4d);\n";
            string subop;
            if(SmVersion < 5)
                subop = "SUBOP";
            else
                subop = "SUB_OP";
            code.writef(fmt, addr, subop, 0, inst.args[0].value, opMacro, inst.args[1].value);
            addr++;
        } else {
            string fmt = "mem[%5d] = make_inst(%8s, %16d, %4d, %8d, %4d);\n";
            code.writef(fmt, addr, opMacro, 0, inst.args[0].value, inst.args[1].value, inst.args[2].value);
            addr++;
        }
    }

    void run() {
        addr = 0;
        immN = 0;
        if(SmVersion < 5) {
            labels.writef("#define L(VAL) VAL & 0x00FF\n");
            labels.writef("#define H(VAL) (VAL>>8) & 0x00FF\n\n");
        } else {
            labels.writef("#define L(VAL) VAL\n");
            labels.writef("#define H(VAL) VAL\n\n");
        }
        labels.writef("// Labels\n");
        while(!parser.empty) {
            if(parser.parseInstruction(inst))
                outputCode();
        }
    }
}

static this() {
    convtbl[OpCode.Noop] = "NOOP0";

    convtbl[OpCode.LoadMemory] = "LDMEM";
    convtbl[OpCode.StoreMemory] = "STMEM";
    convtbl[OpCode.Call] = "CALL";
    convtbl[OpCode.Return] = "RET";
    convtbl[OpCode.Jump] = "JUMP";
    convtbl[OpCode.Branch] = "BRA";
    convtbl[OpCode.BitNot] = "NOT";
    convtbl[OpCode.Negate] = "NEG";
    convtbl[OpCode.LogicNot] = "CSHOUT";
    convtbl[OpCode.PopCount] = "POPCNT";
    convtbl[OpCode.BitReverse] = "BITREV";
    convtbl[OpCode.Pop] = "POP";
    convtbl[OpCode.Push] = "PUSH";

    convtbl[OpCode.Add] = "ADD";
    convtbl[OpCode.Subtract] = "SUB";
    convtbl[OpCode.Multiply] = "MUL";
    convtbl[OpCode.Divide] = "DIV";
    convtbl[OpCode.BitXor] = "XOR";
    convtbl[OpCode.BitAnd] = "AND";
    convtbl[OpCode.BitOr] = "LOR";
    convtbl[OpCode.ShiftLeft] = "SLEFT";
    convtbl[OpCode.ShiftRight] = "SRIGHT";
    convtbl[OpCode.LessThan] = "LT";
    convtbl[OpCode.LessThanOrEqual] = "LTEQ";
    convtbl[OpCode.ConditionalMove] = "CMOVE";
    convtbl[OpCode.ConditionalAdd] = "CADD";

    convtbl[OpCode.ImmediateLow] = "IMMLOW";
    convtbl[OpCode.ImmediateHigh] = "IMMHGH";
}



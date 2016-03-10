
module sm.translate;

import std.outbuffer;
import std.utf;

import pey.common;

import sm.spec;
import sm.parser;

private immutable string[OpCode] convtbl;

string toOpMacro(OpCode op) {
    auto opMacro = (op in convtbl);
    if(opMacro)
        return *opMacro;
    else
        return "";
}

bool isSubOp(OpCode op) {
    return op >= OpCode.Add && op <= OpCode.ImmediateHigh;
}

bool isImmOp(OpCode op) {
    return op == OpCode.ImmediateLow || op == OpCode.ImmediateHigh ||
           op == OpCode.Immediate;
}

/+
string toCode(Instruction inst, int address) {
    string opMacro = toOp(inst.op);
    if(isImmOp(inst.op)) {
        string fmt = "mem[%d] = make_inst(%8s, %6d, %4d,        0,    0);\n";
        return format(fmt, address, opMacro, inst.imm, inst.regc);
    } else if(isSubOp(inst.op)) {
        string fmt = "mem[%d] = make_inst(%8s,      0, %4d, %8s, %4d);\n";
        return format(fmt, address, "SUBOP", inst.regc, opMacro, inst.rega);
    } else {
        string fmt = "mem[%d] = make_inst(%8s,      0, %4d, %8d, %4d);\n";
        return format(fmt, address, opMacro, inst.regc, inst.regb, inst.rega);
    }
}
+/

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
        if(inst.label.length != 0) {
            string label = toUTF8(inst.label);
            labels.writef("const u16 L_%s = %d;\n", label, addr);
            code.writef("// %s\n", label);
            return;
        }

        string opMacro = toOpMacro(inst.op);
        if(isImmOp(inst.op)) {
            string val;
            if(inst.immL.length == 0)
                val = to!string(inst.imm);
            else
                val = "L_" ~ toUTF8(inst.immL);

            if(inst.op != OpCode.Immediate) {
                string fmt = "mem[%4d] = make_inst(%8s, %16s, %4d,        0,    0);\n";
                code.writef(fmt, addr, opMacro, val, inst.regc);
                addr++;
            } else {
                string fmt = "mem[%4d] = make_inst(%8s, %16s, %4d,        0,    0);\n";
                code.writef(fmt, addr, "IMMLOW", "L(" ~ val ~ ")", inst.regc);
                addr++;
                code.writef(fmt, addr, "IMMHGH", "H(" ~ val ~ ")", inst.regc);
                addr++;
            }
        } else if(isSubOp(inst.op)) {
            string fmt = "mem[%4d] = make_inst(%8s, %16d, %4d, %8s, %4d);\n";
            code.writef(fmt, addr, "SUBOP", 0, inst.regc, opMacro, inst.rega);
            addr++;
        } else {
            string fmt = "mem[%4d] = make_inst(%8s, %16d, %4d, %8d, %4d);\n";
            code.writef(fmt, addr, opMacro, 0, inst.regc, inst.regb, inst.rega);
            addr++;
        }

    }

    void run() {
        addr = 0;
        immN = 0;
        labels.writef("#define L(VAL) VAL & 0x00FF\n");
        labels.writef("#define H(VAL) (VAL>>8) & 0x00FF\n\n");
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



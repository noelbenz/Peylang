
module sm.spec;

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
 *  0: subop    | r dest     | 11: cnot   | r val      |
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

enum OpCode {
    SubOp = 0,
    Add = 1,
    Subtract = 2,
    Multiply = 3,
    Divide = 4,
    BitXor = 5,
    BitAnd = 6,
    BitOr = 7,
    ShiftLeft = 8,
    ShiftRight = 9,
    LessThan = 10,
    LessThanOrEqual = 11,
    ConditionalMove = 12,
    ConditionalAdd = 13,
    ImmediateLow = 14,
    ImmediateHigh = 15,
}

enum SubOpCode {
    Noop = 0,
    LoadMemory = 1,
    StoreMemory = 2,
    Call = 3,
    Return = 4,
    Jump = 5,
    Branch = 6,
    BitNot = 9,
    Negate = 10,
    LogicNot = 11,
    PopCount = 12,
    BitReverse = 13,
    Pop = 14,
    Push = 15,
}

private struct OpCodePair {
    OpCode op;
    SubOpCode subop;
}
private immutable OpCodePair[dstring] opcodeLookup;


// opcodeLookup["noop"d] = OpCodePair(OpCode.SubOp, SubOpCode.Noop);
private template opadd(string opName, string op, string subop) {
    const char[] opadd =
        "opcodeLookup[\""~opName~"\"d]="~
        "OpCodePair(OpCode."~op~", SubOpCode."~subop~");";
}
shared static this() {
    // ops
    mixin(opadd!("ld"  , "SubOp", "LoadMemory" ));
    mixin(opadd!("st"  , "SubOp", "StoreMemory"));
    mixin(opadd!("call", "SubOp", "Call"       ));
    mixin(opadd!("ret" , "SubOp", "Return"     ));
    mixin(opadd!("jmp" , "SubOp", "Jump"       ));
    mixin(opadd!("bra" , "SubOp", "Branch"     ));
    mixin(opadd!("bnot", "SubOp", "BitNot"     ));
    mixin(opadd!("neg" , "SubOp", "Negate"     ));
    mixin(opadd!("lnot", "SubOp", "LogicNot"   ));
    mixin(opadd!("popn", "SubOp", "PopCount"   ));
    mixin(opadd!("brev", "SubOp", "BitReverse" ));
    mixin(opadd!("pop" , "SubOp", "Pop"        ));
    mixin(opadd!("push", "SubOp", "Push"       ));
    // sub-ops
    mixin(opadd!("noop", "SubOp"          , "Noop"));
    mixin(opadd!("add" , "Add"            , "Noop"));
    mixin(opadd!("sub" , "Subtract"       , "Noop"));
    mixin(opadd!("mul" , "Multiply"       , "Noop"));
    mixin(opadd!("div" , "Divide"         , "Noop"));
    mixin(opadd!("bxor", "BitXor"         , "Noop"));
    mixin(opadd!("band", "BitAnd"         , "Noop"));
    mixin(opadd!("bor" , "BitOr"          , "Noop"));
    mixin(opadd!("sl"  , "ShiftLeft"      , "Noop"));
    mixin(opadd!("sr"  , "ShiftRight"     , "Noop"));
    mixin(opadd!("lt"  , "LessThan"       , "Noop"));
    mixin(opadd!("lte" , "LessThanOrEqual", "Noop"));
    mixin(opadd!("cmov", "ConditionalMove", "Noop"));
    mixin(opadd!("cadd", "ConditionalAdd" , "Noop"));
    mixin(opadd!("ilo" , "ImmediateLow"   , "Noop"));
    mixin(opadd!("ihi" , "ImmediateHigh"  , "Noop"));
}

/++
  + Determines the opcode and subopcode form a dchar op name.
  +
  + Returns false iff the op name is not a recognized opcode.
 ++/
bool determineOpCode(dstring opName, ref OpCode op, ref SubOpCode subop) {
    auto match = (opName in opcodeLookup);
    if(match == null)
        return false;
    op = match.op;
    subop = match.subop;
    return true;
}



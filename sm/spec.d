
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

// r15(stack) r14(frame) r13(condition) r12(address)
/*------------------------------------------------------
 *     opcode   | regc       | regb       | rega       |
 *------------------------------------------------------
 *  0: noop     |            |            |            |
 *  0: ld       | r dest     |            | r address  |
 *  0: st       | r address  |            | r val      |
 *  0: call     | r address  |            | r stackptr |
 *  0: ret      |            |            | r stackptr |
 *  0: jmp      | r cond     |            | r address  |
 *  0: bra      | r cond     |            | r offset   |
 *  0: bnot     | r dest     |            | r val      |
 *  0: neg      | r dest     |            | r val      |
 *  0: lnot     | r dest     |            | r val      |
 *  0: popn     | r dest     |            | r count    |
 *  0: brev     | r dest     |            | r val      |
 *  0: pop      | r dest     |            | r stackptr |
 *  0: push     | r val      |            | r stackptr |
 *------------------------------------------------------
 *  1: add      | r dest     | r left     | r right    |
 *  2: sub      | r dest     | r left     | r right    |
 *  3: mul      | r dest     | r left     | r right    |
 *  4: div      | r dest     | r left     | r right    |
 *  5: bxor     | r dest     | r left     | r right    |
 *  6: band     | r dest     | r left     | r right    |
 *  7: bor      | r dest     | r left     | r right    |
 *  8: sl       | r dest     | r left     | r right    |
 *  9: sr       | r dest     | r left     | r right    |
 * 10: lt       | r dest     | r left     | r right    |
 * 11: lte      | r dest     | r left     | r right    |
 * 12: cmov     | r dest     | r cond     | r value    |
 * 13: cadd     | r dest     | r cond     | r value    |
 *------------------------------------------------------
 *     opcode   | regc       | immediate               |
 *------------------------------------------------------
 * 14: ilo      | r dest     | i immediate value       |
 * 15: ihi      | r dest     | i immediate value       |
 *------------------------------------------------------
 *     imm      | r dest     | i immediate value       |
 *------------------------------------------------------
 */


enum OpCode {

    // Sub Ops
    Noop,
    LoadMemory,
    StoreMemory,
    Call,
    Return,
    Jump,
    Branch,
    BitNot,
    Negate,
    LogicNot,
    PopCount,
    BitReverse,
    Pop,
    Push,

    // Ops
    Add,
    Subtract,
    Multiply,
    Divide,
    BitXor,
    BitAnd,
    BitOr,
    ShiftLeft,
    ShiftRight,
    LessThan,
    LessThanOrEqual,
    ConditionalMove,
    ConditionalAdd,
    ImmediateLow,
    ImmediateHigh,

    // Phony Ops
    Immediate,
    ShortCall,

    Alias,
    Stack,
    Target,
}

enum SmOpCode {
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

    Invalid,
}

enum SmSubOpCode {
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

    Invalid,
}

SmOpCode toOpCode(OpCode op) {
    if(op < OpCode.Add)
        return SmOpCode.SubOp;
    if(op > OpCode.ImmediateHigh)
        return SmOpCode.Invalid;
    return cast(SmOpCode)(op - SmOpCode.Add + 1);
}

SmSubOpCode toSubOpCode(OpCode op) {
    if(op < OpCode.Noop || op > OpCode.Push)
        return SmSubOpCode.Invalid;
    return cast(SmSubOpCode)(op - OpCode.Noop);
}

private immutable OpCode[dstring] opcodeLookup;


// opcodeLookup["noop"d] = OpCodePair(OpCode.SubOp, SubOpCode.Noop);
private template opadd(string opName, string op) {
    const char[] opadd =
        "opcodeLookup[\""~opName~"\"d] = OpCode."~op~";";
}
shared static this() {
    // ops
    mixin(opadd!("add" , "Add"            ));
    mixin(opadd!("sub" , "Subtract"       ));
    mixin(opadd!("mul" , "Multiply"       ));
    mixin(opadd!("div" , "Divide"         ));
    mixin(opadd!("bxor", "BitXor"         ));
    mixin(opadd!("band", "BitAnd"         ));
    mixin(opadd!("bor" , "BitOr"          ));
    mixin(opadd!("sl"  , "ShiftLeft"      ));
    mixin(opadd!("sr"  , "ShiftRight"     ));
    mixin(opadd!("lt"  , "LessThan"       ));
    mixin(opadd!("lte" , "LessThanOrEqual"));
    mixin(opadd!("cmov", "ConditionalMove"));
    mixin(opadd!("cadd", "ConditionalAdd" ));
    mixin(opadd!("ilo" , "ImmediateLow"   ));
    mixin(opadd!("ihi" , "ImmediateHigh"  ));
    // static assert(false, opadd!("TEST", "OTHER"));
    // sub-ops
    mixin(opadd!("noop", "Noop"           ));
    mixin(opadd!("ld"  , "LoadMemory"     ));
    mixin(opadd!("st"  , "StoreMemory"    ));
    mixin(opadd!("call", "Call"           ));
    mixin(opadd!("ret" , "Return"         ));
    mixin(opadd!("jmp" , "Jump"           ));
    mixin(opadd!("bra" , "Branch"         ));
    mixin(opadd!("bnot", "BitNot"         ));
    mixin(opadd!("neg" , "Negate"         ));
    mixin(opadd!("lnot", "LogicNot"       ));
    mixin(opadd!("popn", "PopCount"       ));
    mixin(opadd!("brev", "BitReverse"     ));
    mixin(opadd!("pop" , "Pop"            ));
    mixin(opadd!("push", "Push"           ));
    // fake ops
    mixin(opadd!("imm"   , "Immediate"    ));
    mixin(opadd!("scll"  , "ShortCall"    ));

    mixin(opadd!("alias" , "Alias"        ));
    mixin(opadd!("stack" , "Stack"        ));
    mixin(opadd!("target", "Target"       ));
}

/++
  + Determines the opcode from a dchar op name.
  +
  + Returns false iff the op name is not a recognized opcode.
 ++/
bool determineOpCode(dstring opName, ref OpCode op) {
    auto match = (opName in opcodeLookup);
    if(match == null)
        return false;
    op = *match;
    return true;
}



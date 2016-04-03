
module sm.parser;

import std.outbuffer;

import pey.common;

import sm.spec;
import sm.lexer;

class ParserException : Exception {
    private static string fmt =
        "[c%d-%d r%d c%d]: %s";

    Token token;
    this(string msg, Token token) {
        this.token = token;
        super(format(fmt, token.beg, token.end, token.row, token.col, msg));
    }
}

struct Argument {
    dstring ident;
    int value;

    this(int value) {
        ident = new dchar[0];
        this.value = value;
    }

    this(dstring ident) {
        this.ident = ident;
    }
}

struct Instruction {
    Token token;
    OpCode op;
    Argument[3] args;

    dstring label;

    int data;
}

class Parser {

    Lexer lexer;
    Token token;
    bool empty;

    int regStack = 15;
    int regTarget = 14;

    int[dstring] aliases;

    Instruction[8] instBuf;
    Instruction[] instAux;

    this(Lexer lexer) {
        this.lexer = lexer;
        reset();
    }

    private void next() {
        if(empty) return;
        empty = !lexer.parseToken(token);
    }

    private void expect(TokenType type) {
        if(token.type != type)
            throw exception(format("Expected %s, got %s.", type, token.type));
    }

    Exception exception(string msg) {
        return new ParserException(msg, token);
    }

    void reset() {
        empty = false;
        next();
    }

    private int getRegister(int def = -1, bool gotoNext = true) {
        int reg;

        if(token.type == TokenType.Register) {
            reg = token.imm;
        } else if(token.type == TokenType.Identifier) {
            int* ptr = (token.ident in aliases);
            if(ptr == null) {
                if(def != -1) return def;
                throw exception(format("Expected a register, got %s.", token.type));
            }
            reg = *ptr;
        } else {
            if(def != -1) return def;
            throw exception(format("Expected a register, got %s.", token.type));
        }
        if(gotoNext)
            next();
        return reg;
    }

    bool parseInstruction(ref Instruction inst) {
        if(instAux.length > 0) {
            inst = instAux[0];
            instAux = instAux[1..$];
            return true;
        }
        while(!empty) {
            if(token.type == TokenType.Identifier) {
                inst.token = token;
                inst.op = OpCode.Label;
                inst.label = token.ident;
                next();
                expect(TokenType.Colon);
                next();
                return true;
            }
            if(token.type == TokenType.Immediate) {
                inst.token = token;
                inst.op = OpCode.Data;
                inst.data = token.imm;
                next();
                return true;
            }

            if(token.type != TokenType.Op)
                throw exception("Expected an Op, Identifier, or Data.");
            switch(token.op) {
                case OpCode.Noop:
                    inst.token = token;
                    inst.op = token.op;
                    next();
                    return true;
                case OpCode.Add: .. case OpCode.ConditionalAdd:
                    inst.token = token;
                    inst.op = token.op;
                    next();
                    // dest
                    inst.args[0] = Argument(getRegister());
                    // left / condition
                    inst.args[1] = Argument(getRegister());
                    // right / value
                    inst.args[2] = Argument(getRegister());
                    return true;
                case OpCode.LoadMemory:
                case OpCode.StoreMemory:
                case OpCode.Branch:
                case OpCode.BitNot:
                case OpCode.Negate:
                case OpCode.LogicNot:
                case OpCode.PopCount:
                case OpCode.BitReverse:
                    inst.token = token;
                    inst.op = token.op;
                    next();
                    // dest / condition
                    inst.args[0] = Argument(getRegister());
                    // other
                    inst.args[1] = Argument(getRegister());
                    return true;
                case OpCode.ShortJump:
                    inst.token = token;
                    next();
                    int regAddress = getRegister(-2, false);
                    // jmp LABEL (unconditional, implicit target)
                    if(regAddress == -2) {
                        expect(TokenType.Identifier);
                        inst.op = OpCode.Immediate;
                        inst.args[0] = Argument(regTarget);
                        inst.args[1] = Argument(token.ident);
                        next();

                        instBuf[0].op = OpCode.Jump;
                        instBuf[0].token = inst.token;
                        instBuf[0].args[0] = Argument(regStack);
                        instBuf[0].args[1] = Argument(regTarget);
                        instAux = instBuf[0..1];
                        return true;
                    }
                    next();
                    // jmp REG (unconditional)
                    inst.op = OpCode.Jump;
                    inst.args[0] = Argument(regStack);
                    // address
                    inst.args[1] = Argument(regAddress);
                    return true;
                case OpCode.Jump:
                    inst.token = token;
                    next();
                    int regCondition = getRegister();
                    int regAddress = getRegister(-2, false);
                    // jmp REG LABEL (implicit target)
                    if(regAddress == -2) {
                        expect(TokenType.Identifier);
                        inst.op = OpCode.Immediate;
                        inst.args[0] = Argument(regTarget);
                        inst.args[1] = Argument(token.ident);
                        next();

                        instBuf[0].op = OpCode.Jump;
                        instBuf[0].token = inst.token;
                        instBuf[0].args[0] = Argument(regCondition);
                        instBuf[0].args[1] = Argument(regTarget);
                        instAux = instBuf[0..1];
                        return true;
                    }
                    next();
                    // jmp REG REG
                    inst.op = OpCode.Jump;
                    inst.args[0] = Argument(regCondition);
                    // address
                    inst.args[1] = Argument(regAddress);
                    return true;
                case OpCode.Move:
                    inst.token = token;
                    inst.op = OpCode.ConditionalMove;
                    next();
                    // dest
                    inst.args[0] = Argument(getRegister());
                    // condition
                    inst.args[1] = Argument(regStack);
                    // source
                    inst.args[2] = Argument(getRegister());
                    return true;
                // Implicit stack ops
                case OpCode.Call:
                case OpCode.Pop:
                case OpCode.Push:
                    inst.token = token;
                    inst.op = token.op;
                    next();
                    // dest
                    inst.args[0] = Argument(getRegister());
                    // right / value
                    inst.args[1] = Argument(getRegister(regStack));
                    return true;
                case OpCode.Return:
                    inst.token = token;
                    inst.op = token.op;
                    next();
                    // stack pointer
                    inst.args[0] = Argument(getRegister(regStack));
                    return true;
                case OpCode.ShortCall:
                    inst.token = token;
                    inst.op = OpCode.Immediate;
                    next();
                    // address
                    expect(TokenType.Identifier);
                    inst.args[0] = Argument(regTarget);
                    inst.args[1] = Argument(token.ident);
                    next();

                    instBuf[0].op = OpCode.Call;
                    instBuf[0].token = token;
                    instBuf[0].args[0] = Argument(regTarget);
                    instBuf[0].args[1] = Argument(regStack);
                    instAux = instBuf[0..1];
                    return true;
                case OpCode.ImmediateLow:
                case OpCode.ImmediateHigh:
                case OpCode.Immediate:
                    inst.token = token;
                    inst.op = token.op;
                    next();
                    // dest
                    inst.args[0] = Argument(getRegister());
                    // immediate
                    if(token.type == TokenType.Immediate) {
                        inst.args[1] = Argument(token.imm);
                    } else if(token.type == TokenType.Identifier) {
                        inst.args[1] = Argument(token.ident);
                    } else {
                        exception(format(
                            "Expected immediate or identifier, got %s.",
                            token.type));
                    }
                    next();
                    return true;
                case OpCode.Alias:
                    next();
                    // name
                    expect(TokenType.Identifier);
                    dstring ident = token.ident;
                    next();
                    // value
                    expect(TokenType.Register);
                    aliases[ident] = token.imm;
                    next();
                    break;
                case OpCode.Offset:
                    inst.token = token;
                    inst.op = token.op;
                    next();
                    // address
                    expect(TokenType.Immediate);
                    inst.data = token.imm;
                    next();
                    return true;
                case OpCode.Stack:
                    next();
                    // register
                    expect(TokenType.Register);
                    regStack = token.imm;
                    next();
                    break;
                case OpCode.Target:
                    next();
                    // register
                    expect(TokenType.Register);
                    regTarget = token.imm;
                    next();
                    break;
                default:
                    throw exception(format("Unrecognized Opcode: %s", token.op));
            }
        }
        return false;
    }
}



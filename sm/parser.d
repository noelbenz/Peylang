
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
}

class Parser {

    Lexer lexer;
    Token token;
    bool empty;

    int[dstring] aliases;

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

    private int getRegister() {
        int reg;

        if(token.type == TokenType.Register) {
            reg = token.imm;
        } else if(token.type == TokenType.Identifier) {
            int* ptr = (token.ident in aliases);
            if(ptr == null)
                throw exception(format("Expected a register, got %s.", token.type));
            reg = *ptr;
        } else {
            throw exception(format("Expected a register, got %s.", token.type));
        }

        return reg;
    }

    bool parseInstruction(ref Instruction inst) {
        while(!empty) {
            if(token.type == TokenType.Identifier) {
                inst.token = token;
                inst.label = token.ident;
                next();
                expect(TokenType.Colon);
                next();
                return true;
            }

            inst.label = new dchar[0];

            if(token.type != TokenType.Op)
                throw exception("Expected an Op or Identifier.");
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
                    next();
                    // left / condition
                    inst.args[1] = Argument(getRegister());
                    next();
                    // right / value
                    inst.args[2] = Argument(getRegister());
                    next();
                    return true;
                case OpCode.LoadMemory: .. case OpCode.Call:
                case OpCode.Jump: .. case OpCode.Push:
                    inst.token = token;
                    inst.op = token.op;
                    next();
                    // dest / condition
                    inst.args[0] = Argument(getRegister());
                    next();
                    // other
                    inst.args[1] = Argument(getRegister());
                    next();
                    return true;
                case OpCode.ImmediateLow:
                case OpCode.ImmediateHigh:
                case OpCode.Immediate:
                    inst.token = token;
                    inst.op = token.op;
                    next();
                    // dest
                    inst.args[0] = Argument(getRegister());
                    next();
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
                case OpCode.Return:
                    inst.token = token;
                    inst.op = token.op;
                    next();
                    // stack pointer
                    inst.args[0] = Argument(getRegister());
                    next();
                    return true;
                default:
                    throw exception(format("Unrecognized Opcode: %s", token.op));
            }
        }
        return false;
    }
}



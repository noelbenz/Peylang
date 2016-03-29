
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

    this(Lexer lexer) {
        this.lexer = lexer;
        empty = false;
        next();
    }

    void next() {
        if(empty) return;
        empty = !lexer.parseToken(token);
    }

    void expect(TokenType type) {
        if(token.type != type)
            throw exception(format("Expected %s, got %s.", type, token.type));
    }

    Exception exception(string msg) {
        return new ParserException(msg, token);
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
                    expect(TokenType.Register);
                    inst.args[0] = Argument(token.imm);
                    next();
                    // left / condition
                    expect(TokenType.Register);
                    inst.args[1] = Argument(token.imm);
                    next();
                    // right / value
                    expect(TokenType.Register);
                    inst.args[2] = Argument(token.imm);
                    next();
                    return true;
                case OpCode.LoadMemory: .. case OpCode.Call:
                case OpCode.Jump: .. case OpCode.Push:
                    inst.token = token;
                    inst.op = token.op;
                    next();
                    // dest / condition
                    expect(TokenType.Register);
                    inst.args[0] = Argument(token.imm);
                    next();
                    // other
                    expect(TokenType.Register);
                    inst.args[1] = Argument(token.imm);
                    next();
                    return true;
                case OpCode.ImmediateLow:
                case OpCode.ImmediateHigh:
                case OpCode.Immediate:
                    inst.token = token;
                    inst.op = token.op;
                    next();
                    // dest
                    expect(TokenType.Register);
                    inst.args[0] = Argument(token.imm);
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
                case OpCode.Return:
                    inst.token = token;
                    inst.op = token.op;
                    next();
                    // stack pointer
                    expect(TokenType.Register);
                    inst.args[0] = Argument(token.imm);
                    next();
                    return true;
                default:
                    throw exception(format("Unrecognized Opcode: %s", token.op));
            }
        }
        return false;
    }
}



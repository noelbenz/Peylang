
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

struct Instruction {
    Token token;
    OpCode op;
    int rega;
    int regb;
    int regc;
    int imm;
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
            if(token.type != TokenType.Op)
                throw exception("Expected an Op.");
            switch(token.op) {
                case OpCode.Add: .. case OpCode.ConditionalAdd:
                    inst.token = token;
                    inst.op = token.op;
                    next();
                    // dest
                    expect(TokenType.Register);
                    inst.regc = token.imm;
                    next();
                    // left
                    expect(TokenType.Register);
                    inst.regb = token.imm;
                    next();
                    // right
                    expect(TokenType.Register);
                    inst.rega = token.imm;
                    next();
                    return true;
                default:
                    throw exception(format("Unrecognized Opcode: %s", token.op));
            }
        }
        return false;
    }
}




//import pey;
import pey.codereader;
import pey.common;
import sm;

import std.exception;
import std.outbuffer;
import fio = std.file;


struct Options {
    bool saveLexer = false;
    bool saveParser = false;
    bool ctranslate = false;
    bool execute = false;
    string outputFile = "out.smo";
}

class OptionException : Exception {
    this(string msg) {
        super(msg);
    }
}


void parseOptions(ref Options opt, string[] args) {
    int i = 0;
    while(i < args.length) {
        string arg = args[i];

        int j = 0;
        if(arg[j] != '-')
            throw new OptionException(format("Expected option, got %s", arg));

        j++;

        char specialOpt = 0;
        while(j < arg.length && specialOpt == 0) {
            switch(arg[j]) {
                case 'l':
                    opt.saveLexer = true;
                    break;
                case 'p':
                    opt.saveParser = true;
                    break;
                case 'c':
                    opt.ctranslate = true;
                    break;
                case 'x':
                    opt.execute = true;
                    break;
                case 'o':
                    specialOpt = arg[j];
                    break;
                default:
                    throw new OptionException(format("Unknown option: %s in %s", arg[j], arg));
            }
            j++;
        }

        // Special option that requires extra input (i.e. -o filename)
        if(specialOpt != 0) {
            string specialVal;

            // Special options consume the rest of the option
            if(j < arg.length) {
                specialVal = arg[j..$];
            // Or the next argument
            } else if(i+1 < args.length) {
                i++;
                specialVal = args[i];
            // Otherwise throw an error.
            } else {
                throw new OptionException(format("Option -%s expected an argument.", specialOpt));
            }

            // Set option
            switch(specialOpt) {
            case 'o':
                opt.outputFile = specialVal;
                break;
            default:
                // Case should be complete
                assert(false);
            }
        }

        i++;
    }
}

int compile(Options options, string filename) {

    CodeReader reader;
    try {
        reader = new FileCodeReader(filename);
    } catch(ErrnoException ex) {
        io.writefln("File %s could not be opened. (errno = %d)", filename, ex.errno);
        return 1;
    }

    auto lexer = new Lexer(reader);
    auto parser = new Parser(lexer);

    if(!options.ctranslate) {
        auto trans = new BinaryTranslator(parser);
        ubyte[] data = trans.run();

        fio.write(options.outputFile, data);
    } else {
        auto trans = new CTranslator(parser);
        trans.run();
        ubyte[] data = trans.labels.toBytes();
        data ~= trans.code.toBytes();

        fio.write(options.outputFile, data);
    }

    if(options.saveLexer) {
        reader.reset();
        lexer.reset();

        OutBuffer buffer = new OutBuffer();
        Token token;
        while(!lexer.empty) {
            if(lexer.parseToken(token)) {
                buffer.writefln(to!string(token));
            }
        }

        fio.write("lexer.out", buffer.toBytes());
    }

    if(options.saveParser) {
        reader.reset();
        lexer.reset();
        parser.reset();

        OutBuffer buffer = new OutBuffer();
        Instruction inst;
        while(!parser.empty) {
            if(parser.parseInstruction(inst)) {
                buffer.writefln(to!string(inst));
            }
        }

        fio.write("parser.out", buffer.toBytes());
    }

    return 0;
}

int execute(Options options, string filename) {

    ubyte[] code = cast(ubyte[])fio.read(filename);
    if(code.length > 65536*ushort.sizeof) {
        io.writefln("File is too large for sm: %d bytes, max is 65536.", code.length);
        return 1;
    }

    ushort[] mem = new ushort[65536];
    int i = 0;
    while(code.length > 0) {
        mem[i] = cast(ushort)((code[0] << 8) | code[1]);
        code = code[2..$];
        i++;
    }

    Simulator simulator = new Simulator(mem);

    for(i = 0; i < 1000; i++) {
        simulator.step();
    }

    io.writefln("R0 = %d", simulator.regs[0]);

    return 0;
}

int main(string[] args) {

    if(args.length < 2) {
        printHelp();
        return 1;
    }

    Options options = Options();

    try {
        parseOptions(options, args[1..$-1]);
    } catch(OptionException ex)  {
        io.writefln("Option parsing failure: %s", ex.msg);
        return 1;
    }

    if(options.execute)
        return execute(options, args[$-1]);
    else
        return compile(options, args[$-1]);
}

string help = `
Simple Microprocessor Assembler Version 0.6

            sm [options] FILE

options:
-o FILE     Output file name.
-l          Save lexer output to lexer.out
-p          Save parser output to parser.out
-c          Generate make_inst C code.
-x FILE     Executes a file using the SM simulator.
`;

void printHelp() {
    io.writeln(help);
}


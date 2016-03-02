
import pey;
import pey.common;

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
 *  0: subop    | r dest     | 11: cshout | r val      |
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

int main() {
    auto reader = new FileCodeReader("test.pey");

    /+
    while(!reader.empty) {
        io.write(reader.c);
        reader.next();
    }
    +/

    auto lexer = new Lexer(reader);
    Token token;
    while(!lexer.empty) {
        if(lexer.parseToken(token))
            io.writeln(token);
    }

    return 0;
}


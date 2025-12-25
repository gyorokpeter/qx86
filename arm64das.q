//number to hex string
.x86util.shex:{$[-4h=type x;.Q.s1 x;x<0;"-",.Q.s1 0x00 vs neg x;.Q.s1 0x00 vs x]};
.x86util.ushex:{$[-4h=type x;.Q.s1 x;.Q.s1 0x00 vs x]};

.arm64.conds:`EQ`NE`CS`CC`MI`PL`VS`VC`HI`LS`GE`LT`GT`LE`AL`NV;

.arm64.decodeBitMasks:{[size;immN;imms;immr]
    len:6-(immN,not[imms])?1b;
    ones:1+0b sv ((8-len)#0b),neg[len]#imms;
    lenn:prd len#2; //2 xexp len
    rot:`int$0b sv 00b,immr;
    rejectBits:(6-len)#immr;    //this is not to spec, but I use it to allow for an unambiguous disassembly
                                //(e.g. to distinguish rot 50 or 18 for 32-bit)
    pattern:((lenn-ones)#0b),ones#1b;
    if[0<rot; pattern:(neg[rot]#pattern),neg[rot]_pattern];
    (0b sv $[size;64;32]#pattern;rejectBits)};

.arm64.topLevels:enlist[`boolean$()]!enlist{`invalid};
.arm64.topLevels[0000b]:{[addr;bits]
    if[bits[0 1 2 7 8 9 10 11 12 13 14 15]~000000000000b;
        imm:`int$0b sv 16_bits;
        :(addr;();"UDF #",.x86util.shex[imm];`UDF;(`imm;imm));
    ];
    :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;());
    '"unknown 0000"};
.arm64.topLevels[0001b]:{[addr;bits]
    :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;());
    '"unknown 0001"};
.arm64.topLevels[0010b]:{[addr;bits]
    :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;());
    '"unknown 0010"};
.arm64.topLevels[0011b]:{[addr;bits]
    :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;());
    '"unknown 0011"};
.arm64.topLevels[0100b]:{[addr;bits]
    size:bits[0];
    regPrefix:$[size;"X";"W"];
    imm:`int$4 8[size]*0b sv bits[10 10 10 10 10 10 10 10 10 10 11 12 13 14 15 16];
    rt2:`int$0b sv bits[-1 -1 -1 17 18 19 20 21];
    rn:`int$0b sv bits[-1 -1 -1 22 23 24 25 26];
    rt:`int$0b sv bits[-1 -1 -1 27 28 29 30 31];
    if[bits[2 7]~01b;:(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;())];
    if[bits[1 2 7 8]~0101b;  //STP (Post-index)
        opcode:`STP`LDP bits[9];
        :(addr;();string[opcode]," ",regPrefix,$[rt=31;"ZR";string[`int$rt]],", ",regPrefix,$[rt2=31;"ZR";string[`int$rt2]],", [",
            $[rn=31;"SP";regPrefix,string[`int$rn]],"], #",.x86util.shex[imm]
            ;opcode;(`postindex;rt;rt2;rn;imm));
    ];
    if[bits[1 2 7 8]~0111b;  //STP (Pre-index)
        opcode:`STP`LDP bits[9];
        :(addr;();string[opcode]," ",regPrefix,$[rt=31;"ZR";string[`int$rt]],", ",regPrefix,$[rt2=31;"ZR";string[`int$rt2]],", [",
            $[rn=31;"SP";regPrefix,string[`int$rn]],", #",.x86util.shex[imm],"]!"
            ;opcode;(`preindex;rt;rt2;rn;imm));
    ];
    if[bits[1 2 7 8]~0110b;
        opcode:`STP`LDP bits[9];
        :(addr;();string[opcode]," ",regPrefix,$[rt=31;"ZR";string[`int$rt]],", ",regPrefix,$[rt2=31;"ZR";string[`int$rt2]],", [",
            $[rn=31;"SP";"X",string[`int$rn]],", #",.x86util.shex[imm],"]"
            ;opcode;(`immediate;rt;rt2;rn;imm));
    ];
    if[bits[0 1 2 7 8 9]~011101b;   //Load Pair of Registers Signed Word (offset)
        :(addr;();"LDPSW X",string[`int$rt],", X",string[`int$rt2],", [",
            $[rn=31;"SP";"X",string[`int$rn]],", #",.x86util.shex[imm],"]"
            ;`LDPSW;((`reg;rt);(`reg;rt2);(`reg;rn);(`imm;imm)));
    ];
    '"unknown 0100"};
.arm64.topLevels[0101b]:{[addr;bits]
    size:bits[0];
    op:0b sv bits[-1 -1 -1 -1 -1 -1 1 2];
    regPrefix:$[size;"X";"W"];
    rd:`int$0b sv bits[-1 -1 -1 27 28 29 30 31];
    rn:`int$0b sv bits[-1 -1 -1 22 23 24 25 26];
    rm:`int$0b sv bits[-1 -1 -1 11 12 13 14 15];
    if[(bits[7]~0b) or bits[7 10]~10b;
        shiftFlag:0b sv 000000b,bits[8 9];
        shift:`LSL`LSR`ASR`ROR shiftFlag;
        imm:`int$0b sv 00b,bits[16 17 18 19 20 21];
    ];
    if[bits[7]~0b;
        if[bits[0 16]~01b; :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;())];
        n:bits[10];
        opcode:(`AND`ORR`EOR`ANDS;`BIC`ORN`EON`BICS)[n;op];
        if[(shiftFlag=0) and (imm=0) and (rn=31);
            :(addr;();"MOV ",regPrefix,string[`int$rd],", ",regPrefix,$[rm=31;"ZR";string[`int$rm]];opcode;(`shifted;size;rd;rn;rm;shift;imm));
        ];
        :(addr;();string[opcode]," ",regPrefix,string[`int$rd],", ",regPrefix,string[`int$rn],", ",regPrefix,string[`int$rm]
            ,", ",string[shift]," #",string[imm]
            ;opcode;(`shifted;size;rd;rn;rm;shift;imm));
    ];
    if[bits[7 10]~10b;
        opcode:`ADD`ADDS`SUB`SUBS[op];
        if[(op=2) and rn=31;
            :(addr;();"NEG ",regPrefix,string[`int$rd],", ",regPrefix,string[`int$rm]
                ,$[(shiftFlag>0) or imm>0;", ",string[shift]," #",string[imm];""]
                ;opcode;(`shifted;rd;rn;rm;shift;imm));
        ];
        if[(op=3) and rd=31;
            :(addr;();"CMP ",regPrefix,string[`int$rn],", ",regPrefix,string[`int$rm]
                ,$[(shiftFlag>0) or imm>0;", ",string[shift]," #",string[imm];""]
                ;opcode;(`shifted;rd;rn;rm;shift;imm));
        ];
        :(addr;();string[opcode]," ",regPrefix,string[`int$rd],", ",regPrefix,string[`int$rn],", ",regPrefix,string[`int$rm]
            ,$[(shiftFlag>0) or imm>0;", ",string[shift]," #",string[imm];""]
            ;opcode;(`shifted;rd;rn;rm;shift;imm));
    ];
    if[bits[7 10]~11b;  //Add/subtract (extended register)
        if[not bits[8 9]~00b; :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;())];
        opcode:`ADD`ADDS`SUB`SUBS[op];
        msize:bits[17 18]~11b;
        mPrefix:$[msize;"X";"W"];
        option:0b sv 00000b,bits[16 17 18];
        imm:`int$0b sv 00000b,bits[19 20 21];
        extend:`UXTB`UXTH`UXTW`UXTX`SXTB`SXTH`SXTW`SXTX option;
        :(addr;();string[opcode]," ",$[rd=31;$[size;"SP";"WSP"];regPrefix,string[`int$rd]]
            ,", ",$[rn=31;$[size;"SP";"WSP"];regPrefix,string[`int$rn]]
            ,", ",regPrefix,string[`int$rm],", ",string[extend],$[0<>imm;" #",string[imm];""]
            ;opcode;(`extended;rd;rn;rm;msize;option;imm));
    ];
    '"unknown 0101"};
.arm64.topLevels[0110b]:{[addr;bits]
    size:0b sv bits[-1 -1 -1 -1 -1 -1 0 1];
    if[size=3; '"STP unknown case"];
    regPrefix:"SDQ"size;
    opcode:`STP`LDP bits 9;
    rt1:`int$0b sv bits[-1 -1 -1 27 28 29 30 31];
    rt2:`int$0b sv bits[-1 -1 -1 17 18 19 20 21];
    rn:`int$0b sv bits[-1 -1 -1 22 23 24 25 26];
    imm:`int$4 8 16[size]*0b sv bits[10 10 10 10 10 10 10 10 10 10 11 12 13 14 15 16];
    if[bits[2 7 8]~100b;    //Load/store no-allocate pair (offset) on page C4-309
        //Store Pair of SIMD&FP registers, with Non-temporal hint (p 2267)
        opcode:`STNP`LDNP bits 9;
        :(addr;();string[opcode]," ",regPrefix,string[rt1],", ",regPrefix,string[rt2],", [",$[rn=31;"SP";"X",string[`int$rn]]
            ,$[0<>imm;", #",.x86util.shex[imm];""],"]"
            ;opcode;((`reg;rt1);(`reg;rt2);(`reg;rn);(`offset;imm)));
    ];
    if[bits[2 7 8]~101b;    //Load/store register pair (SIMD&FP, post-indexed)
        :(addr;();string[opcode]," ",regPrefix,string[rt1],", ",regPrefix,string[rt2],", [",$[rn=31;"SP";"X",string[`int$rn]]
            ,"], #",.x86util.shex[imm]
            ;opcode;((`reg;rt1);(`reg;rt2);(`reg;rn);(`postindex;imm)));
    ];
    if[bits[2 7 8]~110b;    //Load/store register pair (SIMD&FP, offset)
        :(addr;();string[opcode]," ",regPrefix,string[rt1],", ",regPrefix,string[rt2],", [",$[rn=31;"SP";"X",string[`int$rn]]
            ,", #",.x86util.shex[imm],"]"
            ;opcode;((`reg;rt1);(`reg;rt2);(`reg;rn);(`offset;imm)));
    ];
    if[bits[2 7 8]~111b;    //Load/store register pair (SIMD&FP, pre-indexed)
        :(addr;();string[opcode]," ",regPrefix,string[rt1],", ",regPrefix,string[rt2],", [",$[rn=31;"SP";"X",string[`int$rn]]
            ,", #",.x86util.shex[imm],"]!"
            ;opcode;((`reg;rt1);(`reg;rt2);(`reg;rn);(`preindex;imm)));
    ];
    if[bits[0 2 7 10]~0001b; :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;())];
    if[bits[0 2 8 11]~0001b; :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;())];
    '"unknown 0110"};
.arm64.topLevels[0111b]:{[addr;bits]
    rd:`int$0b sv bits[-1 -1 -1 27 28 29 30 31];
    rn:`int$0b sv bits[-1 -1 -1 22 23 24 25 26];
    rm:`int$0b sv bits[-1 -1 -1 11 12 13 14 15];
    size:0b sv bits[-1 -1 -1 -1 -1 -1 8 9];
    if[bits[0 7 10 21]~0011b;   //Advanced SIMD three same (p 366)
        size:0b sv bits[-1 -1 -1 -1 -1 -1 8 9];
        opc:0b sv bits[-1 -1 -1 16 17 18 19 20];
        unsigned:bits[2];
        opcode:(``;``;``;``;``;``;``;``;`SSHL`USHL;`SQSHL`UQSHL;``;`SQRSHL`UQRSHL)[opc;unsigned];
        if[null opcode; '"unknown Advanced SIMD three same"];
        high:bits[1];
        if[(high=1) and size=3; :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;())];
        ta:(("8B";"4H";"2S";"");("16B";"8H";"4S";"2D"))[high;size];
        :(addr;();string[opcode]," V",string[rd],".",ta,", V",string[rn],".",ta,", V",string[rm],".",ta
            ;opcode;(high;size;rd;rn;rm));
    ];
    if[bits[0 7 10 20 21]~00100b;   //Advanced SIMD three different on page C4-365
        opc:0b sv bits[-1 -1 -1 -1 16 17 18 19];
        if[opc=15; :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;())];
        unsigned:bits[2];
        size:0b sv bits[-1 -1 -1 -1 -1 -1 8 9];
        high:bits[1];
        ta:("8H";"4S";"2D")size;
        tb:(("8B";"4H";"2S");("16B";"8H";"4S"))[high;size];
        if[opc=2;   //Subtract Long (signed p 2234, unsigned p 2415)
            opcode:(`SSUBL`SSUBL2;`USUBL`USUBL2)[unsigned;high];
            :(addr;();string[opcode]," V",string[rd],".",ta,", V",string[rn],".",tb,", V",string[rm],".",tb
                ;opcode;(high;size;rd;rn;rm));
        ];
        if[opc=3;   //Subtract Wide (signed p 2236, unsigned p 2417)
            opcode:(`SSUBW`SSUBW2;`USUBW`USUBW2)[unsigned;high];
            :(addr;();string[opcode]," V",string[rd],".",ta,", V",string[rn],".",ta,", V",string[rm],".",tb
                ;opcode;(high;size;rd;rn;rm));
        ];
        '"unknown Advanced SIMD three different";
    ];
    if[bits[0 7 21]~010b;   //Advanced SIMD vector x indexed element on page C4-372
        if[bits[2 8 9 16 19]~10101b;    //Floating-point Complex Multiply Accumulate (by element p 1645).
            size:0b sv bits[-1 -1 -1 -1 -1 -1 8 9];
            rot:0b sv bits[-1 -1 -1 -1 -1 -1 17 18];
            if[not size in 0x0102; :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;())];
            rm:`int$0b sv bits[-1 -1 -1 11 12 13 14 15];
            high:bits[1];
            ta:(("";"4H";"");("";"8H";"4S"))[high;size];
            tb:" HS"size;
            index:`int$0b sv $[size=1;bits[-1 -1 -1 -1 -1 -1 20 10];bits[-1 -1 -1 -1 -1 -1 -1 20]];
            :(addr;();"FCMLA V",string[rd],".",ta,", V",string[rn],".",ta,", V",string[rm],".",tb,"[",string[index],"], #"
                ,string[rot*90]
                ;`FCMLA;(size;rd;rn;rm;index;rot));
        ];
        '"unknown Advanced SIMD vector x indexed element";
    ];
    if[bits[0 7 8 21]~0101b; //Advanced SIMD shift by immediate (p 371)
        opc:0b sv bits[-1 -1 -1 16 17 18 19 20];
        if[opc in 0x01030507090b0d0f15161718191a1b1d1e;
            :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;());
        ];
        unsigned:bits[2];   //Signed saturating Shift Left (immediate, vector)
        high:bits[1];
        size:first where bits[9 10 11 12];
        shift:`int$(0b sv bits[-1 9 10 11 12 13 14 15])-64 32 16 8 size;
        ta:(("";"4S";"4H";"8B");("2D";"4S";"8H";"16B"))[high;size];
        if[opc=12;  //Signed saturating Shift Left Unsigned (immediate)
            :(addr;();"SQSHLU V",string[rd],".",ta,", V",string[rn],".",ta,", #",.x86util.shex[shift]
                ;`SQSHLU;(high;size;rd;rn;shift));
        ];
        if[opc=14;
            opcode:`SQSHL`UQSHL unsigned;
            :(addr;();string[opcode]," V",string[rd],".",ta,", V",string[rn],".",ta,", #",.x86util.shex[shift]
                ;opcode;(high;size;rd;rn;shift));
        ];
        '"unknown Advanced SIMD shift by immediate";
    ];
    if[bits[0 7 9 10 16 17 21]~0010011b;
        :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;());
    ];
    if[bits[0 7 10 13 20 21]~001110b;
        :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;());
    ];
    if[bits[0 7 8 21]~0111b; :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;())];
    '"unknown 0111"};
.arm64.topLevels[1000b]:{[addr;bits]
    if[bits[7 8]~10b;   //Add/subtract (immediate)
        size:bits[0];
        op:bits[1];
        shift:bits[2];
        opcode:(`ADD`ADDS;`SUB`SUBS)[op;shift];
        sh:bits[9];
        regPrefix:$[size;"X";"W"];
        imm0:bits[10 11 12 13 14 15 16 17 18 19 20 21];
        imm:`int$0b sv $[sh;00000000b,imm0,000000000000b;0000b,imm0];
        rn:`int$0b sv bits[-1 -1 -1 22 23 24 25 26];
        rd:`int$0b sv bits[-1 -1 -1 27 28 29 30 31];
        if[(opcode=`SUBS) and rd=31;
            :(addr;();"CMP ",regPrefix,string[`int$rn],", #",.x86util.shex[imm]
            ;opcode;(`immediate;size;rd;rn;imm));
        ];
        :(addr;();string[opcode]," ",$[rd=31;"SP";regPrefix,string[`int$rd]],", ",$[rn=31;"SP";regPrefix,string[`int$rn]],", #",.x86util.shex[imm]
            ;opcode;(`immediate;size;rd;rn;imm));
    ];
    if[bits[7]~0b;
        rd:0b sv 000b,bits[27 28 29 30 31];
        op:bits[0];
        reso:(1 4096i op);
        imm:`int$(reso xbar addr)+reso*0b sv (11#bits[8]),bits[8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 1 2];
        opcode:`ADR`ADRP op;
        :(addr;();string[opcode]," X",string[`int$rd],", #",.x86util.shex[imm]
            ;opcode;((`reg;rd);(`imm;imm)));
    ];
    '"unknown 1000"};
.arm64.topLevels[1001b]:{[addr;bits]
    size:bits[0];
    regPrefix:$[size;"X";"W"];
    if[bits[7 8]~00b;
        if[(size=0) and bits[9]=1b; :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;())];
        opc:`AND`ORR`EOR`ANDS 0b sv 000000b,bits[1 2];
        rn:`int$0b sv bits[-1 -1 -1 22 23 24 25 26];
        rd:`int$0b sv bits[-1 -1 -1 27 28 29 30 31];
        imm0:.arm64.decodeBitMasks[size;bits[9];bits[16 17 18 19 20 21];bits[10 11 12 13 14 15]];
        imm:imm0 0;
        rej:$[all 0=imm0 1;"";"/",raze string imm0 1];
        if[(rn=31) and imm=0;
            :(addr;();"MOV ",$[rd=31;$[size;"";"W"],"SP";regPrefix,string[`int$rd]],", #",.x86util.ushex[imm],rej
                ;opc;((`reg;rd);(`reg;rn);(`imm;imm)));
        ];
        :(addr;();string[opc]," ",$[rd=31;$[size;"";"W"],"SP";regPrefix,string[`int$rd]],", "
            ,regPrefix,$[31=rn;"ZR";string[rn]],", #",.x86util.ushex[imm],rej
            ;opc;((`reg;rd);(`reg;rn);(`imm;imm)));
    ];
    if[bits[1 2 7 8]~1101b;
        hw:0b sv 000000b,bits[9 10];
        rd:`int$0b sv 000b,bits[27 28 29 30 31];
        imm:`int$0b sv bits[-1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26];
        :(addr;();"MOVK ",regPrefix,string[`int$rd],", #",.x86util.shex[imm],$[(hw>0);", LSL #",string[hw*16];""]
            ;`MOVK;((`reg;rd);(`imm;imm);(`shift;hw*16)));
    ];
    if[bits[1 2 7 8]~1001b;
        hw:0b sv 000000b,bits[9 10];
        rd:`int$0b sv 000b,bits[27 28 29 30 31];
        imm:`int$0b sv bits[-1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 -1 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26];
        :(addr;();"MOVZ ",regPrefix,string[`int$rd],", #",.x86util.shex[imm],$[(hw>0);", LSL #",string[hw*16];""]
            ;`MOVZ;((`reg;rd);(`imm;imm);(`shift;hw*16)));
    ];
    if[bits[7 8]~10b;   //Bitfield
        n:bits[9];
        if[size<>n;:(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;())];
        immr:`int$0b sv bits[-1 -1 10 11 12 13 14 15];
        imms:`int$0b sv bits[-1 -1 16 17 18 19 20 21];
        rn:`int$0b sv bits[-1 -1 -1 22 23 24 25 26];
        rd:`int$0b sv bits[-1 -1 -1 27 28 29 30 31];
        if[bits[1 2]~00b;   //SBFM
            if[(immr=0) and (imms=31);
                :(addr;();"SXTW X",string[rd],", W",string[rn];`SBFM;((`reg;rd);(`reg;rn);(`imm;immr);(`imm;imms)));
            ];
            :(addr;();"SBFM ",regPrefix,string[`int$rd],", ",regPrefix,string[`int$rn],", #",.x86util.shex[immr],", #",.x86util.shex[imms];
                `SBFM;((`reg;rd);(`reg;rn);(`imm;immr);(`imm;imms)));
        ];
        if[bits[1 2]~01b;   //BFM
            if[imms<immr;
                width:32 64i size;
                :(addr;();"BFI ",regPrefix,string[`int$rd],", ",regPrefix,string[`int$rn],", #",.x86util.shex[neg[immr]mod width],", #",.x86util.shex[imms+1i];
                    `BFM;((`reg;rd);(`reg;rn);(`imm;immr);(`imm;imms)));
            ];
            :(addr;();"BFM ",regPrefix,string[`int$rd],", ",regPrefix,string[`int$rn],", #",.x86util.shex[immr],", #",.x86util.shex[imms];
                `BFM;((`reg;rd);(`reg;rn);(`imm;immr);(`imm;imms)));
        ];
        if[bits[1 2]~10b;   //UBFM
            if[(imms<>31) and imms=immr-1;
                :(addr;();"LSL ",regPrefix,string[`int$rd],", ",regPrefix,string[`int$rn],", #",string[$[size;63;31]-imms];
                    `UBFM;((`reg;rd);(`reg;rn);(`imm;immr);(`imm;imms)));
            ];
            :(addr;();"UBFM ",regPrefix,string[`int$rd],", ",regPrefix,string[`int$rn],", #",.x86util.shex[immr],", #",.x86util.shex[imms];
                `UBFM;((`reg;rd);(`reg;rn);(`imm;immr);(`imm;imms)));
        ];
    ];
    if[bits[1 2 7 8]~1110b;
        :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;());
    ];
    '"unknown 1001"};
.arm64.topLevels[1010b]:{[addr;bits]
    if[bits[0 1 2 7 27]~01000b;
        cond:0b sv 0000b,bits[28 29 30 31];
        imm:`int$addr+4*0b sv (13#bits[8]),bits[8+til 19];
        condn:.arm64.conds cond;
        :(addr;();"B.",string[condn]," #",.x86util.shex[imm];`B.cond;(condn;imm));
    ];
    if[bits[1 2]~00b;
        imm:`int$addr+4*0b sv bits[6 6 6 6 6 6 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31];
        opcode:`B`BL bits 0;
        :(addr;();string[opcode]," #",.x86util.shex[imm];opcode;enlist imm);
    ];
    if[bits[1 2]~01b;
        imm:`int$addr+4*0b sv (13#bits[8]),bits[8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26];
        size:bits[0];
        regPrefix:$[size;"X";"W"];
        rt:`int$0b sv 000b,bits[27 28 29 30 31];
        opcode:`CBZ`CBNZ bits 7;
        :(addr;();string[opcode]," ",regPrefix,string[`int$rt],", #",.x86util.shex[imm]
            ;opcode;((`reg;rt);(`imm;imm)));
    ];
    if[bits[0 1 2 7 8 9 10 27 28 29]~1100000000b;   //Supervisor call
        opcode:``SVC`HVC`SMC 0b sv bits[-1 -1 -1 -1 -1 -1 30 31];
        imm:`int$0b sv bits[11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26];
        :(addr;();string[opcode]," #",.x86util.shex[imm]
            ;opcode;enlist(`imm;imm));
    ];
    if[bits[0 1 2 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 27 28 29 30 31]~11010000001100100011111b;   //Hints
        if[bits[22 23]~00b;
            opc:0b sv bits[-1 -1 -1 -1 -1 24 25 26];
            opcode:`NOP`YIELD`WFE`WFI`SEV`SEVL`DGH` opc;
            if[null opcode;'"unknown Hint"];
            :(addr;();string[opcode];opcode;());
        ];
    ];
    if[bits[0 1 2 7]~0101b;
        :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;());
    ];
    if[bits[1 2]~11b;
        :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;());
    ];
    '"unknown 1010"};
.arm64.topLevels[1011b]:{[addr;bits]
    if[bits[1 2]~00b;   //Unconditional branch (immediate)
        opcode:`B`BL bits 0;
        imm:`int$addr+4*0b sv bits[6 6 6 6 6 6 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31];
        :(addr;();string[opcode]," #",.x86util.shex[imm];(opcode;`imm;imm));
    ];
    if[bits[1 2]~01b;   //Test and branch (immediate)
        opcode:`TBZ`TBNZ bits 7;
        size:bits[0];
        regPrefix:$[size;"X";"W"];
        rt:`int$0b sv 000b,bits[27 28 29 30 31];
        imm:`int$addr+4*0b sv bits[13 13 13 14 15 16 17 18 19 20 21 22 23 24 25 26];
        bitPos:`int$0b sv 00b,bits[0 8 9 10 11 12];
        :(addr;();string[opcode]," ",regPrefix,$[rt=31;"ZR";string[rt]],", #",string[bitPos],", #",.x86util.shex[imm]
            ;(opcode;rt;bitPos;imm));
    ];
    if[bits[0 1 2 7 8 11 12 13 14 15 16 17 18 19 20 21 27 28 29 30 31]~110001111100000000000b;
        if[bits[9 10]~10b;
            rn:`int$0b sv 000b,bits[22 23 24 25 26];
            :(addr;();"RET",$[rn<>30;" X",string[rn];""];`RET;enlist(`reg;rn));
        ];
        if[bits[9]~0b;
            rn:`int$0b sv 000b,bits[22 23 24 25 26];
            if[bits[10]~0b;
                :(addr;();"BR X",string[rn];`BR;enlist(`reg;rn));
            ];
            //bits[10]~1b
            :(addr;();"BLR X",string[rn];`BLR;enlist(`reg;rn));
        ];
    ];
    if[bits[1 2]~11b;
        :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;());
    ];
    '"unknown 1011"};
.arm64.topLevels[1100b]:{[addr;bits]
    size:bits[1];
    regPrefix:$[size;"X";"W"];
    rt:`int$0b sv 000b,bits[27 28 29 30 31];
    if[bits[0 2 7]~000b;    //Load register (literal)
        imm:`int$addr+4*0b sv bits[8 8 8 8 8 8 8 8 8 8 8 8 8 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26];
        :(addr;();"LDR ",regPrefix,$[rt=31;"ZR";string[rt]],", #",.x86util.shex[imm]
            ;`LDR;(`literal;rt;imm));
    ];
    rn:`int$0b sv 000b,bits[22 23 24 25 26];
    if[bits[0 2 7 8 10 20 21]~0100000b; //Load/Store Register Byte (unscaled)
        opcode:(`STURB`LDURB;`STURH`LDURH)[size;bits 9];
        imm:`int$0b sv bits[11 11 11 11 11 11 11 11 12 13 14 15 16 17 18 19];
        :(addr;();string[opcode]," ",regPrefix,string[rt],", [",$[rn=31;"SP";"X",string[rn]],$[0<>imm;", #",.x86util.shex[imm];""],"]"
            ;opcode;((`reg;rt);(`reg;rn);(`imm;imm)));
    ];
    if[bits[0 2 7 8 10 20 21]~1100000b; //Load/store register (unscaled immediate)
        opcode:`STUR`LDUR bits 9;
        imm:`int$0b sv bits[11 11 11 11 11 11 11 11 12 13 14 15 16 17 18 19];
        :(addr;();string[opcode]," ",regPrefix,$[rt=31;"ZR";string[rt]],", [",$[rn=31;"SP";"X",string[rn]],$[0<>imm;", #",.x86util.shex[imm];""],"]"
            ;opcode;((`reg;rt);(`reg;rn);(`imm;imm)));
    ];
    if[bits[0 2 7 8 10 20 21]~0100011b;   //Load/store register (immediate pre-indexed)
        opcode:(`STRB`LDRB;`STRH`LDRH)[size;bits 9];
        imm:`int$0b sv bits[11 11 11 11 11 11 11 11 12 13 14 15 16 17 18 19];
        :(addr;();string[opcode]," W",string[rt],", [",$[rn=31;"SP";"X",string[rn]],$[0<>imm;", #",.x86util.shex[imm];""],"]!"
            ;opcode;((`reg;rt);(`reg;rn);(`preimm;imm)));
    ];
    if[bits[0 2 7 8 10 20 21]~1100011b;   //Load/store register (immediate pre-indexed)
        opcode:`STR`LDR bits 9;
        imm:`int$0b sv bits[11 11 11 11 11 11 11 11 12 13 14 15 16 17 18 19];
        :(addr;();string[opcode]," ",regPrefix,string[rt],", [",$[rn=31;"SP";"X",string[rn]],$[0<>imm;", #",.x86util.shex[imm];""],"]!"
            ;opcode;(`preindex;rt;rn;imm));
    ];
    if[bits[0 2 7 8 10 20 21]~1100110b;  //Load register (register offset)
        opcode:`STR`LDR bits 9;
        rm:`int$0b sv 000b,bits[11 12 13 14 15];
        option:```UXTW`LSL```SXTW`SXTX `int$0b sv 00000b,bits[16 17 18];
        shift:bits[19]*(size+2*bits[0]);
        :(addr;();string[opcode]," ",regPrefix,string[rt],", [",$[rn=31;"SP";"X",string[rn]],", ",$[bits[18];"X";"W"],string[rm]
            ,$[(option<>`LSL)or 0<>shift;", ",string[option]
            ,$[0<>shift;" #",string[shift];""];""],"]"
            ;opcode;(`register;rt;rn;rm;option;bits[18];shift));
    ];
    if[bits[0 1 2 7 8 9 10 20 21]~111001001b;
        imm:`int$0b sv bits[11 11 11 11 11 11 11 11 12 13 14 15 16 17 18 19];
        :(addr;();"LDR ",regPrefix,string[rt],", [",$[rn=31;"SP";"X",string[rn]],$[0<>imm;"], #",.x86util.shex[imm];""]
            ;`LDR;((`reg;rt);(`reg;rn);(`postimm;imm)));
    ];
    if[bits[0 1 2 7 8 9 10 20 21]~001001001b;   //LDRB (immediate / post-index)
        imm:`int$0b sv bits[11 11 11 11 11 11 11 11 12 13 14 15 16 17 18 19];
        :(addr;();"LDRB ",regPrefix,string[rt],", [",$[rn=31;"SP";"X",string[rn]],"]",$[0<>imm;", #",.x86util.shex[imm];""]
            ;`LDRB;((`reg;rt);(`reg;rn);(`imm;imm)));
    ];
    if[bits[0 1 2 7 8]~01110b;  //load/store (unsigned immediate)
        opcode:`STRH`LDRH bits 9;
        imm:`int$(size+1)*0b sv 0000b,bits[10 11 12 13 14 15 16 17 18 19 20 21];
        :(addr;();string[opcode]," W",string[rt],", [",$[rn=31;"SP";"X",string[rn]],$[0<>imm;", #",.x86util.shex[imm];""],"]"
            ;opcode;((`reg;rt);(`reg;rn);(`imm;imm)));
    ];
    if[bits[0 1 2 7 8 10 20 21]~00100110b;    //Load/store register byte (register offset)
        opcode:`STRB`LDRB bits 9;
        rm:`int$0b sv 000b,bits[11 12 13 14 15];
        if[bits[16 17 18]~011b; //Shifted register variant
            :(addr;();string[opcode]," W",string[rt],", [",$[rn=31;"SP";"X",string[rn]],", X",string[rm],$[bits 19;", LSL #0";""],"]"
                ;opcode;((`reg;rt);(`reg;rn);(`reg;rm);(`amount;bits 19)));
        ];
        '"nyi LDRB extended register variant";  //Extended register variant
    ];
    if[bits[0 1 2 7 8]~00110b;  //load/store byte (unsigned immediate)
        opcode:`STRB`LDRB bits 9;
        imm:`int$(size+1)*0b sv 0000b,bits[10 11 12 13 14 15 16 17 18 19 20 21];
        :(addr;();string[opcode]," ",regPrefix,$[rt=31;"ZR";string[rt]],", [",$[rn=31;"SP";"X",string[rn]],$[0<>imm
            ;", #",.x86util.shex[imm];""],"]"
            ;opcode;((`reg;rt);(`reg;rn);(`imm;imm)));
    ];
    if[bits[0 2 7 8]~1110b;
        opcode:`STR`LDR bits 9;
        imm:`int$(size+1)*4*0b sv 0000b,bits[10 11 12 13 14 15 16 17 18 19 20 21];
        :(addr;();string[opcode]," ",regPrefix,$[rt=31;"ZR";string[rt]],", [",$[rn=31;"SP";"X",string[rn]]
            ,$[0<>imm;", #",.x86util.shex[imm];""],"]"
            ;opcode;(`offset;rt;rn;imm));
    ];
    if[bits[2 7 8]~000b;    //Load register (literal) on page C4-309
        if[bits[0 1]~10b;   //Load Register Signed Word (literal, p 1123)
            imm:`int$addr+4*0b sv bits[8 8 8 8 8 8 8 8 8 8 8 8 8 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26];
            :(addr;();"LDRSW ","X",$[rt=31;"ZR";string[rt]],", #",.x86util.shex[imm]
                ;`LDRSW;(rt;imm));
        ];
        '"unknown Load register (literal)"
    ];
    '"unknown 1100"};
.arm64.topLevels[1101b]:{[addr;bits]
    size:bits[0];
    regPrefix:$[size;"X";"W"];
    rm:`int$0b sv 000b,bits[11 12 13 14 15];
    rn:`int$0b sv 000b,bits[22 23 24 25 26];
    rd:`int$0b sv 000b,bits[27 28 29 30 31];
    if[bits[2 7 8 9 10]~00100b; //Conditional select
        op:0b sv bits[-1 -1 -1 -1 -1 -1 1 21];
        opcode:`CSEL`CSINC`CSINV`CSNEG op;
        cond:0b sv bits[-1 -1 -1 -1 16 17 18 19];
        condn:.arm64.conds cond;
        if[(op=1) and (rm=31) and (cond<14) and (rn=31);
            :(addr;();"CSET ",regPrefix,string[rd],", ",string[.arm64.conds(2 xbar cond)+1-cond mod 2]
                ;opcode;((`reg;rd);(`reg;rn);(`reg;rm);(`cond;condn)));
        ];
        :(addr;();string[opcode]," ",regPrefix,string[rd],", ",regPrefix,$[rn=31;"ZR";string[rn]]
            ,", ",regPrefix,string[rm],", ",string[condn]
            ;opcode;((`reg;rd);(`reg;rn);(`reg;rm);(`cond;condn)));
    ];
    if[bits[7]~1b;  //Data-processing (3 source) on page C4-337
        if[bits[1 2]~01b; :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;())];
        if[bits[1 2 8 9 10]~00000b;  //Multiply-Add/Subtract
            op:bits 16;
            opcode:`MADD`MSUB op;
            ra:`int$0b sv 000b,bits[17 18 19 20 21];
            if[(op=0) and ra=31;
                :(addr;();"MUL ",regPrefix,string[rd],", ",regPrefix,$[rn=31;"ZR";string[rn]]
                ,", ",regPrefix,string[rm]
                ;opcode;((`reg;rd);(`reg;rn);(`reg;rm);(`reg;ra)))
            ];
            :(addr;();string[opcode]," ",regPrefix,string[rd],", ",regPrefix,$[rn=31;"ZR";string[rn]]
                ,", ",regPrefix,string[rm],", ",regPrefix,string[ra]
                ;opcode;((`reg;rd);(`reg;rn);(`reg;rm);(`reg;ra)));
        ];
        if[bits[0 1 2 8 9 10]~100101b;  //Unsigned Multiply-Add/Subtract Long
            opcode:`UMADDL`UMSUBL bits 16;
            ra:`int$0b sv 000b,bits[17 18 19 20 21];
            :(addr;();string[opcode]," ","X",string[rd],", ","W",$[rn=31;"ZR";string[rn]]
                ,", ","W",string[rm],", ","X",string[ra]
                ;opcode;((`reg;rd);(`reg;rn);(`reg;rm);(`reg;ra)));
        ];
        if[bits[0 1 2 8 9 10 16]~1001100b;   //Unsigned Multiply High
            :(addr;();"UMULH X",string[rd],", X",string[rn],", X",string[rm]
                ;(`UMULH;rd;rn;rm));
        ];
        '"unknown Data-processing (3 source)";
    ];
    if[bits[1 2 7 8 9 10]~000110b;
        opc:0b sv bits[-1 -1 16 17 18 19 20 21];
        opcode:opcode2:```UDIV```````LSRV opc;
        if[opcode=`LSRV;opcode:`LSR];
        if[null opcode; {'x}"unknown Data-processing (2 source)"];
        :(addr;();string[opcode]," ",regPrefix,string[rd],", ",regPrefix,$[rn=31;"ZR";string[rn]]
            ,", ",regPrefix,string[rm]
            ;opcode2;(size;rd;rn;rm));
    ];
    if[bits[2 7 8 9 10 21 27]~1001000b; //Conditional compare
        opcode:`CCMN`CCMP bits 1;
        cond:0b sv 0000b,bits[16 17 18 19];
        condn:.arm64.conds cond;
        isImm:bits 20;
        :(addr;();string[opcode]," ",regPrefix,string[rn],", ",$[isImm;"#",.x86util.shex rm;regPrefix,$[rn=31;"ZR";string[rm]]]
            ,", #",string[rd],", ",string[condn]
            ;opcode;((`reg;rn);(`reg;rm);(`nzcv;rd);(`cond;condn)));
    ];
    if[bits[1 2 7 8 9 10 11 12 13 14 15]~10011000000b;  
        opc:0b sv bits[-1 -1 16 17 18 19 20 21];
        opcode:`RBIT````CLZ opc;
        if[null opcode; '"unknown Data-processing (1 source)"];
        :(addr;();string[opcode]," ",regPrefix,string[rd],", ",regPrefix,string[rn]
            ;opcode;(size;rd;rn));
    ];
    if[bits[2 7 8 9 10 20]~000100b;
        :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;());
    ];
    if[bits[1 7 8 9 10 16 17 18 19 20 21]~00000100110b; //spec hole?
        :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;());
    ];
    if[bits[1 7 8 9 10 16 17 18 19 20 21]~10000010101b; //spec hole?
        :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;());
    ];
    '"unknown 1101"};
.arm64.topLevels[1110b]:{[addr;bits]
    if[bits[2 7]~00b;   //Load register (literal) on page C4-309
        size:0b sv bits[-1 -1 -1 -1 -1 -1 0 1];
        if[size=3; :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;())];
        regPrefix:"SDQ"size;
        rt:`int$0b sv bits[-1 -1 -1 27 28 29 30 31];
        imm:`int$addr+4*0b sv bits[8 8 8 8 8 8 8 8 8 8 8 8 8 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26];
        :(addr;();"LDR ",regPrefix,string[rt],", #",.x86util.shex[imm];`LDR;(`literalFP;size;rt));
    ];
    if[bits[2 7 10 20 21]~01000b;:(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;())];
    if[bits[0 1 2 7 8 10 11 12 13 14 15 21]~000100011001b;   //spec hole?
        :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;());
    ];
    if[bits[0 1 2 7 8 10 11 12 13 14 15 20 21]~0001000110010b;  //spec hole?
        :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;());
    ];
    if[bits[0 1 2 7 8 10 11 12 13 14 15]~01010100100b;  //spec hole?
        :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;());
    ];
    if[bits[0 1 2 7 8 10 11 12 13 14 15 20 21]~1001000001011b;  //spec hole?
        :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;());
    ];
    '"unknown 1110"};
.arm64.topLevels[1111b]:{[addr;bits]
    if[bits[0 1 7 21]~0110b;    //Advanced SIMD scalar x indexed element
        opcode:0b sv bits[-1 -1 -1 -1 16 17 18 19];
        if[opcode=0; :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;())];
        if[opcode=7;    //SQDMLSL, SQDMLSL2 (by element, scalar) 
            if[bits[2]; :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;())];
            size:0b sv bits[-1 -1 -1 -1 -1 -1 8 9];
            if[size in 0x0003; :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;())];
            rn:`int$0b sv bits[-1 -1 -1 22 23 24 25 26];
            rd:`int$0b sv bits[-1 -1 -1 27 28 29 30 31];
            rm:`int$0b sv bits[-1 -1 -1 -1 12 13 14 15];
            vd:" SD"size;
            vn:" HS"size;
            index:`int$0b sv bits[$[size=1;-1 -1 -1 -1 -1 20 10 11;-1 -1 -1 -1 -1 -1 20 10]];
            :(addr;();"SQDMLSL ",vd,string[rd],", ",vn,string[rn],", V",string[rm],".",vn,"[",string[index],"]"
                ;`SQDMLSL;(size;rd;rn;rm;index));   
        ];
        '"unknown Advanced SIMD scalar x indexed element";
    ];
    if[bits[0 1 7 8 21]~01101b; //Advanced SIMD scalar shift by immediate (page 352)
        immh:0b sv bits[-1 -1 -1 -1 9 10 11 12];
        if[immh=0; :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;())];
        opcode:0b sv bits[-1 -1 -1 16 17 18 19 20];
        if[opcode in 0x01030507090b0d0f1415161718191a1b1d1e;
            :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;());
        ];
        if[bits[2];
            '"unknown Advanced SIMD scalar shift by immediate - U=1";
        ];
        if[opcode in 0x080c1011;
            :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;());
        ];
        rn:`int$0b sv bits[-1 -1 -1 22 23 24 25 26];
        rd:`int$0b sv bits[-1 -1 -1 27 28 29 30 31];
        if[opcode=6;    //Signed Rounding Shift Right and Accumulate (immediate, scalar)
            if[immh<=7; :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;())];
            shift:`int$128-(0b sv bits[-1 9 10 11 12 13 14 15]);
            :(addr;();"SRSRA D",string[rd],", D",string[rn],", #",.x86util.shex[shift]
                ;`SRSRA;(rd;rn;shift));
        ];
        if[opcode=14;   //Signed saturating Shift Left (immediate, scalar)
            size:first where bits[9 10 11 12];
            shift:`int$(0b sv bits[-1 9 10 11 12 13 14 15])-64 32 16 8 size;
            va:"DSHB"size;
            :(addr;();"SQSHL ",va,string[rd],", ",va,string[rn],", #",.x86util.shex[shift]
                ;`SQSHL;(size;rd;rn;shift));
        ];
        '"unknown Advanced SIMD scalar shift by immediate - U=0";
    ];
    if[bits[0 1]~11b;
        :(addr;();"INVALID #",.x86util.shex[0b sv bits];`INVALID;());
    ];
    '"unknown 1111"};
.arm64.disasm:{[addr;bc]
    if[4<count bc; bc:4#bc];
    bits:0b vs .x86util.le2i bc;
    topLevel:bits[3 4 5 6];
    if[not topLevel in key .arm64.topLevels; '"unknown topLevel: ",.Q.s1 topLevel];
    res:.arm64.topLevels[topLevel][addr;bits];
    res[1]:bc;
    res};

.arm64.disasmUnitTestDef:([]addr:();bc:();result:());
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x18200000; "UDF #0x00002018");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(128; 0xf7ffff17; "B #0x0000005c");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x02000014; "B #0x00000008");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(12;  0xc1050054; "B.NE #0x000000c4");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(20;  0x02000094; "BL #0x0000001c");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(128; 0xe0010036; "TBZ W0, #0, #0x000000bc");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(220; 0xa2000034; "CBZ W2, #0x000000f0");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(232; 0x420000b4; "CBZ X2, #0x000000f0");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xc0035fd6; "RET");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x40001fd6; "BR X2");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x00013fd6; "BLR X8");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x1f2003d5; "NOP");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xc10000d4; "SVC #0x00000006");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xf303012a; "MOV W19, W1");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xe0031f2a; "MOV W0, WZR");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x6e6e1272; "ANDS W14, W19, #0xffffc3ff");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x6e6e3272; "ANDS W14, W19, #0xffffc3ff/1");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xe1030032; "ORR W1, WZR, #0x00000001");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x785595f2; "MOVK X24, #0x0000aaab");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x9808a672; "MOVK W24, #0x00003044, LSL #16");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x01008052; "MOVZ W1, #0x00000000");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x20009fd2; "MOVZ X0, #0x0000f801");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x1f0000f1; "CMP X0, #0x00000000");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x3f0108eb; "CMP X9, X8");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x00001e8b; "ADD X0, X0, X30");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x29012b0b; "ADD W9, W9, W11, UXTB");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xff4302d1; "SUB SP, SP, #0x00000090");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xe803004b; "NEG W8, W0");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(128; 0x5f5f4558; "LDR XZR, #0x0008ac68");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xc00340b9; "LDR W0, [X30]");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x297d60b3; "BFI X9, X9, #0x00000020, #0x00000020");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x296d1c53; "LSL W9, W9, #4");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x080d4079; "LDRH W8, [X8, #0x00000006]");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x08104039; "LDRB W8, [X0, #0x00000004]");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x4b154038; "LDRB W11, [X10], #0x00000001");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x0a6b6838; "LDRB W10, [X24, X8]");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x1fc00039; "STRB WZR, [X0, #0x00000030]");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x01f11f38; "STURB W1, [X8, #-0x00000001]");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xbf831df8; "STUR XZR, [X29, #-0x00000028]");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xc8825ff8; "LDUR X8, [X22, #-0x00000008]");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x688640f8; "LDR X8, [X19], #0x00000008");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x087969b8; "LDR W8, [X8, X9, LSL #2]");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xe83300f9; "STR X8, [SP, #0x00000060]");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x7f6600f9; "STR XZR, [X19, #0x000000c8]");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xe82340b9; "LDR W8, [SP, #0x00000020]");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x091d4038; "LDRB W9, [X8, #0x00000001]!");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xf50f1df8; "STR X21, [SP, #-0x00000030]!");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x0a8d40f8; "LDR X10, [X8, #0x00000008]!");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x3a6968f8; "LDR X26, [X9, X8]");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x3a6928f8; "STR X26, [X9, X8]");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(128; 0x464d0c1c; "LDR S6, #0x00018a28");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(128; 0x0c970e98; "LDRSW X12, #0x0001d360");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xe9aa4029; "LDP W9, W10, [X23, #0x00000004]");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xfd7b48a9; "LDP X29, X30, [SP, #0x00000080]");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xf44fc2a8; "LDP X20, X19, [SP], #0x00000020");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xf44f07a9; "STP X20, X19, [SP, #0x00000070]");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xf44fbea9; "STP X20, X19, [SP, #-0x00000020]!");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xe61fbfad; "STP Q6, Q7, [SP, #-0x00000020]!");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x1ffc03a9; "STP XZR, XZR, [X0, #0x00000038]");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x6e74696d; "LDP D14, D29, [X3, #-0x00000170]");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xe007c1ac; "LDP Q0, Q1, [SP], #0x00000020");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x6c5f706c; "LDNP D12, D23, [X27, #-0x00000100]");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x65746169; "LDPSW X5, X29, [X3, #-0x000000f8]");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x1525b69b; "UMADDL X21, W8, W22, X9");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xca7e0a9b; "MUL X10, X22, X10");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x69a50a9b; "MSUB X9, X11, X10, X9");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x2b09ca9a; "UDIV X11, X9, X10");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x0825ca9a; "LSR X8, X8, X10");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x087dd89b; "UMULH X8, X8, X24");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x6a01c0da; "RBIT X10, X11");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x4a11c0da; "CLZ X10, X10");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(128; 0x89ffff10; "ADR X9, #0x00000070");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x010000f0; "ADRP X1, #0x00003000");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(128; 0x010000f0; "ADRP X1, #0x00003000");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xeb038b1a; "CSEL W11, WZR, W11, EQ");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xe8179f1a; "CSET W8, EQ");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x0411577a; "CCMP W8, W23, #4, NE");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x0419577a; "CCMP W8, #0x00000017, #4, NE");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x4e326e6e; "USUBW2 V14.4S, V18.4S, V14.8H");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x3a20756e; "USUBL2 V26.4S, V1.8H, V21.8H");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x6e5f656e; "UQRSHL V14.8H, V27.8H, V5.8H");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x6f46756e; "USHL V15.8H, V19.8H, V21.8H");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x64796e5f; "SQDMLSL S4, H11, V14.H[6]");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x6374696f; "UQSHL V3.2D, V3.2D, #0x00000029");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x5a4e326e; "UQSHL V26.16B, V18.16B, V18.16B");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x6174615f; "SQSHL D1, D3, #0x00000021");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x7265736f; "SQSHLU V18.2D, V11.2D, #0x00000033");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x3334675f; "SRSRA D19, D1, #0x00000019");

`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0xd8ddaa6a; "INVALID #0x6aaaddd8");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x326e6e32; "INVALID #0x326e6e32");
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x4c6f6f6b; "INVALID #0x6b6f6f4c");

//unverified
`.arm64.disasmUnitTestDef insert `addr`bc`result!(0;   0x6e32726f; "FCMLA V14.8H, V19.8H, V18.H[1], #90");

.arm64.disasmUnitTest:{
    {if[not .arm64.disasm[x`addr;x`bc][2]~x`result;{'"failed"}[]]}each .arm64.disasmUnitTestDef;
    };
.arm64.disasmUnitTest[]

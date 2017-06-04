.x86das.reg1:`AL`CL`DL`BL`AH`CH`DH`BH;
.x86das.reg2:`AX`CX`DX`BX`SP`BP`SI`DI;
.x86das.reg4:`EAX`ECX`EDX`EBX`ESP`EBP`ESI`EDI;
.x86das.sreg:`ES`CS`SS`DS`FS`GS`SEG6`SEG7;

.x86das.disasm00:{[addr;bc;prefixState]
    if[bc[0]in 0x00010203;:.x86das.twoop[addr;bc;`ADD;prefixState;`$()]];
    if[bc[0]=0x04;:.x86das.hardcodedWith1imm[addr;bc;`ADD;prefixState;(`reg;`AL)]];
    if[bc[0]=0x05;:.x86das.hardcodedWith4imm[addr;bc;`ADD;prefixState;(`reg;$[prefixState 0;`AX;`EAX])]];
    if[bc[0]=0x06;:.x86das.hardcodedArg[addr;bc;`PUSH;enlist(`reg;`ES)]];
    if[bc[0]=0x07;:.x86das.hardcodedArg[addr;bc;`POP;enlist(`reg;`ES)]];
    if[bc[0]in 0x08090a0b;:.x86das.twoop[addr;bc;`OR;prefixState;`$()]];
    if[bc[0]=0x0c;:.x86das.hardcodedWith1imm[addr;bc;`OR;prefixState;(`reg;`AL)]];
    if[bc[0]=0x0d;:.x86das.hardcodedWith4imm[addr;bc;`OR;prefixState;(`reg;$[prefixState 0;`AX;`EAX])]];
    if[bc[0]=0x0e;:.x86das.hardcodedArg[addr;bc;`PUSH;enlist(`reg;`CS)]];
    if[bc[0]in 0x10111213;:.x86das.twoop[addr;bc;`ADC;prefixState;`$()]];
    if[bc[0]=0x14;:.x86das.hardcodedWith1imm[addr;bc;`ADC;prefixState;(`reg;`AL)]];
    if[bc[0]=0x15;:.x86das.hardcodedWith4imm[addr;bc;`ADC;prefixState;(`reg;$[prefixState 0;`AX;`EAX])]];
    if[bc[0]=0x16;:.x86das.hardcodedArg[addr;bc;`PUSH;enlist(`reg;`SS)]];
    if[bc[0]=0x17;:.x86das.hardcodedArg[addr;bc;`POP;enlist(`reg;`SS)]];
    if[bc[0]in 0x18191a1b;:.x86das.twoop[addr;bc;`SBB;prefixState;`$()]];
    if[bc[0]=0x1c;:.x86das.hardcodedWith1imm[addr;bc;`SBB;prefixState;(`reg;`AL)]];
    if[bc[0]=0x1d;:.x86das.hardcodedWith4imm[addr;bc;`SBB;prefixState;(`reg;$[prefixState 0;`AX;`EAX])]];
    if[bc[0]=0x1e;:.x86das.hardcodedArg[addr;bc;`PUSH;enlist(`reg;`DS)]];
    if[bc[0]=0x1f;:.x86das.hardcodedArg[addr;bc;`POP;enlist(`reg;`DS)]];
    if[bc[0]in 0x20212223;:.x86das.twoop[addr;bc;`AND;prefixState;`$()]];
    if[bc[0]=0x24;:.x86das.hardcodedWith1imm[addr;bc;`AND;prefixState;(`reg;`AL)]];
    if[bc[0]=0x25;:.x86das.hardcodedWith4imm[addr;bc;`AND;prefixState;(`reg;$[prefixState 0;`AX;`EAX])]];
    if[bc[0]=0x27;:.x86das.static[addr;bc;`DAA]];
    if[bc[0]=0x2f;:.x86das.static[addr;bc;`DAS]];
    if[bc[0]in 0x28292a2b;:.x86das.twoop[addr;bc;`SUB;prefixState;`$()]];
    if[bc[0]=0x2c;:.x86das.hardcodedWith1imm[addr;bc;`SUB;prefixState;(`reg;`AL)]];
    if[bc[0]=0x2d;:.x86das.hardcodedWith4imm[addr;bc;`SUB;prefixState;(`reg;$[prefixState 0;`AX;`EAX])]];
    if[bc[0]in 0x30313233;:.x86das.twoop[addr;bc;`XOR;prefixState;`$()]];
    if[bc[0]=0x34;:.x86das.hardcodedWith1imm[addr;bc;`XOR;prefixState;(`reg;`AL)]];
    if[bc[0]=0x35;:.x86das.hardcodedWith4imm[addr;bc;`XOR;prefixState;(`reg;$[prefixState 0;`AX;`EAX])]];
    if[bc[0]=0x37;:.x86das.static[addr;bc;`AAA]];
    if[bc[0]in 0x38393a3b;:.x86das.twoop[addr;bc;`CMP;prefixState;`$()]];
    if[bc[0]=0x3c;:.x86das.hardcodedWith1imm[addr;bc;`CMP;prefixState;(`reg;`AL)]];
    if[bc[0]=0x3d;:.x86das.hardcodedWith4imm[addr;bc;`CMP;prefixState;(`reg;$[prefixState 0;`AX;`EAX])]];
    if[bc[0]=0x3f;:.x86das.static[addr;bc;`AAS]];
    if[bc[0]in 0x4041424344454647;:.x86das.hardcodedArg[addr;bc;`INC;enlist(`reg;$[prefixState 0;.x86das.reg2;.x86das.reg4]bc[0]-0x40)]];
    if[bc[0]in 0x48494a4b4c4d4e4f;:.x86das.hardcodedArg[addr;bc;`DEC;enlist(`reg;$[prefixState 0;.x86das.reg2;.x86das.reg4]bc[0]-0x48)]];
    if[bc[0]in 0x5051525354555657;:.x86das.hardcodedArg[addr;bc;`PUSH;enlist(`reg;$[prefixState 0;.x86das.reg2;.x86das.reg4]bc[0]-0x50)]];
    if[bc[0]in 0x58595a5b5c5d5e5f;:.x86das.hardcodedArg[addr;bc;`POP;enlist(`reg;$[prefixState 0;.x86das.reg2;.x86das.reg4]bc[0]-0x58)]];
    if[bc[0]=0x60;:.x86das.static[addr;bc;`PUSHAD]];
    if[bc[0]=0x68;:.x86das.with4imm[addr;bc;`PUSH]];
    '"failed to disasm: ",(first` vs .x86util.shex`int$addr),": ",.Q.s[bc];
    };

.x86das.disasm010:{[addr;bc;prefixState]
    if[bc[0]=0x80;:.x86das.oneopWith1imm[addr;bc;`ext1;prefixState;`$()]];
    if[bc[0]=0x81;:.x86das.oneopWith4imm[addr;bc;`ext1;prefixState;enlist`no1byte]];
    if[bc[0]=0x83;:.x86das.oneopWithsimm[addr;bc;`ext1;prefixState;`$()]];
    if[bc[0]in 0x8485;:.x86das.twoop[addr;bc;`TEST;prefixState;`$()]];
    if[bc[0]in 0x8687;:.x86das.twoop[addr;bc;`XCHG;prefixState;`forceArgSwap]];
    if[bc[0]in 0x88898a8b;:.x86das.twoop[addr;bc;`MOV;prefixState;`$()]];
    if[bc[0]in 0x8c8e;:.x86das.twoop[addr;bc;`MOV;prefixState;`no1byte`segmentReg]];
    if[bc[0]=0x8d;:.x86das.twoop[addr;bc;`LEA;prefixState;`$()]];
    if[bc[0]=0x8f;:.x86das.oneop[addr;bc;`POP;prefixState;`$()]];
    if[bc[0]=0x90;:.x86das.static[addr;bc;`NOP]];
    if[bc[0]in 0x91929394959697;:.x86das.hardcodedArg[addr;bc;`XCHG;((`reg;$[prefixState 0;`AX;`EAX]);(`reg;$[prefixState 0;.x86das.reg2;.x86das.reg4]bc[0]-0x90))]];
    if[bc[0]=0x98;:.x86das.static[addr;bc;$[prefixState 0;`CBW;`CWDE]]];
    if[bc[0]=0x99;:.x86das.static[addr;bc;$[prefixState 0;`CWD;`CDQ]]];
    if[bc[0]=0x9c;:.x86das.static[addr;bc;$[prefixState 0;`PUSHFW;`PUSHFD]]];
    if[bc[0]=0x9d;:.x86das.static[addr;bc;$[prefixState 0;`POPFW;`POPFD]]];
    if[bc[0]=0x9f;:.x86das.static[addr;bc;`LAHF]];
    if[bc[0]=0xa4;:.x86das.stringOp[addr;bc;`MOVSB;prefixState 2]];
    if[bc[0]=0xa6;:.x86das.stringOp[addr;bc;`CMPSB;prefixState 2]];
    if[bc[0]=0xa8;:.x86das.hardcodedWith1imm[addr;bc;`TEST;prefixState;(`reg;`AL)]];
    if[bc[0]=0xa9;:.x86das.hardcodedWith4imm[addr;bc;`TEST;prefixState;(`reg;$[prefixState 0;`AX;`EAX])]];
    if[bc[0]=0xaa;:.x86das.stringOp[addr;bc;`STOSB;prefixState 2]];
    if[bc[0]=0xac;:.x86das.stringOp[addr;bc;`LODSB;prefixState 2]];
    '"failed to disasm: ",(first` vs .x86util.shex`int$addr),": ",.Q.s[bc];
    };

.x86das.disasm011:{[addr;bc;prefixState]
    if[bc[0]=0xae;:.x86das.stringOp[addr;bc;`SCASB;prefixState 2]];
    if[bc[0]in 0xb0b1b2b3b4b5b6b7;:.x86das.hardcodedWith1imm[addr;bc;`MOV;prefixState;(`reg;.x86das.reg1[bc[0]-0xb0])]];
    if[bc[0]in 0xb8b9babbbcbdbebf;:.x86das.hardcodedWith4imm[addr;bc;`MOV;prefixState;(`reg;$[prefixState 0;.x86das.reg2;.x86das.reg4][bc[0]-0xb8])]];
    if[bc[0]=0xc0;:.x86das.oneopWith1imm[addr;bc;`ext3;prefixState;`$()]];
    if[bc[0]=0xc1;:.x86das.oneopWith1imm[addr;bc;`ext3;prefixState;enlist`no1byte]];
    if[bc[0]=0xc2;:.x86das.with2imm[addr;bc;`RETN]];
    if[bc[0]=0xc3;:.x86das.static[addr;bc;`RETN]];
    if[bc[0]=0xc6;:.x86das.oneopWith1imm[addr;bc;`MOV;prefixState;`$()]];
    if[bc[0]=0xc7;:.x86das.oneopWith4imm[addr;bc;`MOV;prefixState;enlist`no1byte]];
    if[bc[0]=0xcc;:.x86das.static[addr;bc;`INT3]];
    if[bc[0]in 0xd0d1;:.x86das.oneopWithHardcoded[addr;bc;`ext3;prefixState;`$();(`imm;0x01)]];
    if[bc[0]=0xd2;:.x86das.oneopWithHardcoded[addr;bc;`ext3;prefixState;`$();(`reg;`CL)]];
    if[bc[0]=0xd3;:.x86das.oneopWithHardcoded[addr;bc;`ext3;prefixState;`$();(`reg;`CL)]];
    if[bc[0]=0xd4;:.x86das.with1imm[addr;bc;`AAM]];
    if[bc[0]=0xd5;:.x86das.with1imm[addr;bc;`AAD]];
    if[bc[0]=0xe8;:.x86das.with4branch[addr;bc;`CALL;5]];
    if[bc[0]=0xe9;:.x86das.with4branch[addr;bc;`JMP;5]];
    if[bc[0]=0xf5;:.x86das.static[addr;bc;`CMC]];
    if[bc[0]in 0xf6f7;:.x86das.oneop[addr;bc;`ext5;prefixState;`$()]];
    if[bc[0]=0xf8;:.x86das.static[addr;bc;`CLC]];
    if[bc[0]=0xf9;:.x86das.static[addr;bc;`STC]];
    if[bc[0]=0xfc;:.x86das.static[addr;bc;`CLD]];
    if[bc[0]=0xfd;:.x86das.static[addr;bc;`STD]];
    if[bc[0]in 0xfeff;:.x86das.oneop[addr;bc;`ext4;prefixState;`$()]];
    '"failed to disasm: ",(first` vs .x86util.shex`int$addr),": ",.Q.s[bc];
    };

.x86das.disasm01:{[addr;bc;prefixState]
    addr:`int$addr;
    $[bc[0] within 0x80ac;.x86das.disasm010[addr;bc;prefixState];.x86das.disasm011[addr;bc;prefixState]]};

//'constants
.x86das.disasm0:{[addr;bc;prefixState]
    addr:`int$addr;
    $[bc[0] within 0x007f;.x86das.disasm00[addr;bc;prefixState];.x86das.disasm01[addr;bc;prefixState]]};

.x86das.disasm10:{[addr;bc;prefixState]
    if[bc[0]=0x31;:.x86das.static[addr;bc;`RDTSC]];
    if[bc[0]=0x80;:.x86das.with4branch[addr;bc;`JO;6]];
    if[bc[0]=0x81;:.x86das.with4branch[addr;bc;`JNO;6]];
    if[bc[0]=0x82;:.x86das.with4branch[addr;bc;`JB;6]];
    if[bc[0]=0x83;:.x86das.with4branch[addr;bc;`JNB;6]];
    if[bc[0]=0x84;:.x86das.with4branch[addr;bc;`JE;6]];
    if[bc[0]=0x85;:.x86das.with4branch[addr;bc;`JNZ;6]];
    if[bc[0]=0x86;:.x86das.with4branch[addr;bc;`JBE;6]];
    if[bc[0]=0x87;:.x86das.with4branch[addr;bc;`JA;6]];
    if[bc[0]=0x88;:.x86das.with4branch[addr;bc;`JS;6]];
    if[bc[0]=0x89;:.x86das.with4branch[addr;bc;`JNS;6]];
    if[bc[0]=0x8a;:.x86das.with4branch[addr;bc;`JPE;6]];
    if[bc[0]=0x8b;:.x86das.with4branch[addr;bc;`JPO;6]];
    if[bc[0]=0x8c;:.x86das.with4branch[addr;bc;`JL;6]];
    if[bc[0]=0x8d;:.x86das.with4branch[addr;bc;`JGE;6]];
    if[bc[0]=0x8e;:.x86das.with4branch[addr;bc;`JLE;6]];
    if[bc[0]=0x8f;:.x86das.with4branch[addr;bc;`JG;6]];
    if[bc[0]=0x90;:.x86das.oneop[addr;bc;`SETO;prefixState;`force1byte]];
    if[bc[0]=0x91;:.x86das.oneop[addr;bc;`SETNO;prefixState;`force1byte]];
    if[bc[0]=0x92;:.x86das.oneop[addr;bc;`SETB;prefixState;`force1byte]];
    if[bc[0]=0x93;:.x86das.oneop[addr;bc;`SETNB;prefixState;`force1byte]];
    if[bc[0]=0x94;:.x86das.oneop[addr;bc;`SETE;prefixState;`force1byte]];
    if[bc[0]=0x95;:.x86das.oneop[addr;bc;`SETNE;prefixState;`force1byte]];
    if[bc[0]=0x96;:.x86das.oneop[addr;bc;`SETBE;prefixState;`force1byte]];
    if[bc[0]=0x97;:.x86das.oneop[addr;bc;`SETA;prefixState;`force1byte]];
    if[bc[0]=0x98;:.x86das.oneop[addr;bc;`SETS;prefixState;`force1byte]];
    '"failed to disasm: ",(first` vs .x86util.shex`int$addr),": ",.Q.s[bc];
    };

.x86das.disasm11:{[addr;bc;prefixState]
    if[bc[0]=0x99;:.x86das.oneop[addr;bc;`SETNS;prefixState;`force1byte]];
    if[bc[0]=0x9a;:.x86das.oneop[addr;bc;`SETPE;prefixState;`force1byte]];
    if[bc[0]=0x9b;:.x86das.oneop[addr;bc;`SETPO;prefixState;`force1byte]];
    if[bc[0]=0x9c;:.x86das.oneop[addr;bc;`SETL;prefixState;`force1byte]];
    if[bc[0]=0x9d;:.x86das.oneop[addr;bc;`SETGE;prefixState;`force1byte]];
    if[bc[0]=0x9e;:.x86das.oneop[addr;bc;`SETLE;prefixState;`force1byte]];
    if[bc[0]=0x9f;:.x86das.oneop[addr;bc;`SETG;prefixState;`force1byte]];
    if[bc[0]=0xa0;:.x86das.hardcodedArg[addr;bc;`PUSH;enlist(`reg;`FS)]];
    if[bc[0]=0xa1;:.x86das.hardcodedArg[addr;bc;`POP;enlist(`reg;`FS)]];
    if[bc[0]=0xa3;:.x86das.twoop[addr;bc;`BT;prefixState;`forceArgSwap]];
    if[bc[0]=0xa4;:.x86das.twoopWith1imm[addr;bc;`SHLD;prefixState;`$()]];
    if[bc[0]=0xa5;:.x86das.twoopWithHardcoded[addr;bc;`SHLD;prefixState;`$();(`reg;`CL)]];
    if[bc[0]=0xa8;:.x86das.hardcodedArg[addr;bc;`PUSH;enlist(`reg;`GS)]];
    if[bc[0]=0xa9;:.x86das.hardcodedArg[addr;bc;`POP;enlist(`reg;`GS)]];
    if[bc[0]=0xab;:.x86das.twoop[addr;bc;`BTS;prefixState;`forceArgSwap]];
    if[bc[0]=0xac;:.x86das.twoopWith1imm[addr;bc;`SHRD;prefixState;`no1byte`forceArgSwap]];
    if[bc[0]=0xad;:.x86das.twoopWithHardcoded[addr;bc;`SHRD;prefixState;`$();(`reg;`CL)]];
    if[bc[0]=0xb3;:.x86das.twoop[addr;bc;`BTR;prefixState;`forceArgSwap]];
    if[bc[0]in 0xb6;:.x86das.twoop41[addr;bc;`MOVZX;prefixState;`$()]];
    if[bc[0]in 0xb7;:.x86das.twoop42[addr;bc;`MOVZX;prefixState;`$()]];
    if[bc[0]=0xbb;:.x86das.twoop[addr;bc;`BTC;prefixState;`forceArgSwap]];
    if[bc[0]=0xbd;:.x86das.twoop[addr;bc;`BSR;prefixState;`denyArgSwap]];
    if[bc[0]=0xbe;:.x86das.twoop42[addr;bc;`MOVSX;prefixState;`$()]];
    if[bc[0]=0xbc;:.x86das.twoop[addr;bc;`BSF;prefixState;`no1byte`denyArgSwap]];
    if[bc[0]=0xba;:.x86das.oneopWith1imm[addr;bc;`ext2;prefixState;enlist`no1byte]];
    if[bc[0]in 0xc0c1;:.x86das.twoop[addr;bc;`XADD;prefixState;`$()]];
    if[bc[0]in 0xc8c9cacbcccdcecf;:.x86das.hardcodedArg[addr;bc;`BSWAP;enlist(`reg;$[prefixState 0;.x86das.reg2;.x86das.reg4]bc[0]-0xc8)]];
    '"failed to disasm: ",(first` vs .x86util.shex`int$addr),": ",.Q.s[bc];
    };

.x86das.disasm1:{[addr;bc;prefixState]
    addr:`int$addr;
    $[bc[0] within 0x0098; .x86das.disasm10[addr;bc;prefixState]; .x86das.disasm11[addr;bc;prefixState]]};

.x86das.prefix:()!();
.x86das.prefix[0x66]:{x[0]:1;x};
.x86das.prefix[0x26]:{x[1]:`ES;x};
.x86das.prefix[0x2e]:{x[1]:`CS;x};
.x86das.prefix[0x36]:{x[1]:`SS;x};
.x86das.prefix[0x3e]:{x[1]:`DS;x};
.x86das.prefix[0x64]:{x[1]:`FS;x};
.x86das.prefix[0x65]:{x[1]:`GS;x};
.x86das.prefix[0xf2]:{x[2]:`REPNE;x};
.x86das.prefix[0xf3]:{x[2]:`REP;x};

.x86das.disasm:{[addr;bc]
    prefix:`byte$();
    prefixState:(0;`;`);    //(sizeFlag;segment;repeat)
    advanced:0b;
    while[bc[0] in key .x86das.prefix;
        prefixState:.x86das.prefix[bc[0]][prefixState];
        prefix,:1#bc;
        bc:1_bc;
    ];
    if[bc[0]=0x0f; advanced:1b; prefix,:1#bc; bc:1_bc];
    res:$[advanced;.x86das.disasm1;.x86das.disasm0][addr;bc;prefixState];
    res[1]:prefix,res[1];
    res};

.x86das.stringOp:{[addr;bc;instype;rep]
    (addr;1#bc;$[null rep;"";string[rep]," "],string[instype];instype;())};

.x86das.with4branch:{[addr;bc;instype;instsize]
    op1:addr+(`int$instsize)+.x86util.le2i 4#1_bc;
    (addr;5#bc;string[instype]," ",.x86util.shex op1;instype;enlist(`imm;op1))};

.x86das.with1imm:{[addr;bc;instype]
    op1:first 1_bc;
    (addr;2#bc;string[instype]," ",.x86util.shex op1;instype;enlist(`imm;op1))};

.x86das.with4imm:{[addr;bc;instype]
    op1:.x86util.le2i 4#1_bc;
    (addr;5#bc;string[instype]," ",.x86util.shex op1;instype;enlist(`imm;op1))};

.x86das.with2imm:{[addr;bc;instype]
    op1:.x86util.le2i 2#1_bc;
    (addr;3#bc;string[instype]," ",.x86util.shex op1;instype;enlist(`imm;op1))};

.x86das.hardcodedWith1imm:{[addr;bc;instype;prefixState;hcArg]
    size:1;
    arg1:(`imm; .x86util.le2i size#1_bc);
    args:(hcArg;arg1);
    (addr;(1+size)#bc;string[instype]," ",", "sv .x86das.argstr each args;instype;args)};

.x86das.hardcodedWith4imm:{[addr;bc;instype;prefixState;hcArg]
    size:$[prefixState 0;2;4];
    arg1:(`imm; .x86util.le2i size#1_bc);
    args:(hcArg;arg1);
    (addr;(1+size)#bc;string[instype]," ",", "sv .x86das.argstr each args;instype;args)};

.x86das.hardcodedArg:{[addr;bc;instype;args]
    (addr;1#bc;string[instype]," ",", "sv .x86das.argstr each args;instype;args)};

.x86das.static:{[addr;bc;instype]
    (addr;1#bc;string instype;instype;())};

.x86das.argstrMem:{[arg]
    comp1:$[not null arg 3;enlist string arg 3;()];
    comp2:$[not null arg 5;enlist $[1<arg 4;string[arg 4],"*";""],string arg 5;()];
    comp3:$[0<>arg 6;enlist $[-4h=type arg 6;$[0x80>arg 6;.Q.s1 arg 6;"-",.Q.s1 "x"$neg arg[6]];
        $[(0>arg 6)and 0<count comp1,comp2; "-",.x86util.shex neg arg 6; .x86util.shex arg 6]];()];
    comp:ssr[("+"sv comp1,comp2,comp3);"+-";"-"];
    :(1 2 4!("BYTE";"WORD";"DWORD"))[arg[1]]," PTR ",string[arg 2],":[",comp,"]";
    };

.x86das.argstr:{[arg]
    $[arg[0]=`reg;
        string[arg 1];
      arg[0]=`imm;
        $[-4h<>type arg[1];.x86util.shex arg[1];.Q.s1 arg[1]];
      arg[0]=`simm;
        $[0x80>arg 1;.Q.s1 arg 1;"-",.Q.s1 "x"$neg arg[1]];
      arg[0]=`mem;.x86das.argstrMem arg;
      nyi
    ]};

.x86das.argsstr:{[args]", "sv .x86das.argstr each args};

.x86das.defaultSegment:{[reg]
    $[reg in `ESP`EBP; `SS; `DS]};

.x86das.regTo4:{[reg]
    p:.x86das.reg1?reg;
    if[p=8; p:.x86das.reg2?reg];
    if[p=8; :reg];
    .x86das.reg4 p};

.x86das.regTo2:{[reg]
    p:.x86das.reg1?reg;
    if[p=8; p:.x86das.reg4?reg];
    if[p=8; :reg];
    .x86das.reg2 p};

.x86das.getoperands:{[addr;bc;instype;prefixState;options]
    oc:bc 0;
    size:oc mod 2;
    if[`no1byte in options; size:1];
    if[`force1byte in options; size:0];
    datasize:$[size;$[prefixState 0;2;4];1];
    reglist:(1 2 4!(.x86das.reg1;.x86das.reg2;.x86das.reg4))datasize;
    modrm:bc 1;
    mode:modrm div 64;
    regn:(modrm div 8) mod 8;
    if[instype=`ext1;instype:`ADD`OR`ADC`SBB`AND`SUB`XOR`CMP regn];
    if[instype=`ext2;instype:`ext20`ext21`ext22`ext23`BT`BTS`BTR`BTC regn];
    if[instype=`ext3;instype:`ROL`ROR`RCL`RCR`SHL`SHR`SAL`SAR regn];
    if[instype=`ext4;instype:`INC`DEC`CALL`CALLF`JMP`JMPF`PUSH`ext47 regn];
    if[instype=`ext5;instype:`TEST`ext51`NOT`NEG`MUL`IMUL`DIV`IDIV regn];
    reg:(`reg;$[`segmentReg in options;.x86das.sreg; reglist] regn);
    rm:modrm mod 8;
    displ:0;
    pf:2;
    $[3=mode;
        arg:(`reg;reglist rm);
      0=mode;
        displ:4*rm=5;
      1=mode;
        displ:1;
      2=mode;
        displ:4
    ];
    scale:0;
    if[(3>mode) and rm=4;
        pf:3;
        sib:bc 2;
        scale:(1 2 4 8)sib div 64;
        index:(sib div 8)mod 8;
        base:sib mod 8;
        if[base=5; displ:4];
    ];
    displv:0;
    if[displ>0;
        displv:.x86util.le2i displ#pf _bc;
    ];
    bcsize:pf;
    if[3>mode;
        basereg:.x86das.reg4 rm;
        if[(mode=0) and rm=5; basereg:`];
        indexreg:`;
        if[3=pf;
            indexreg:.x86das.reg4 index;
            if[indexreg=`ESP;indexreg:`];
            basereg:.x86das.reg4 base;
            if[base=5; basereg:`];
        ];
        arg:(`mem;$[`wordExtend in options;2;datasize];.x86das.defaultSegment[basereg]^prefixState 1;basereg;scale;indexreg;displv);
        bcsize+:displ;
    ];
    //(addr;bcsize#bc;string[instype]," ",", "sv argsstr;instype;args)};
    (bcsize;(reg;arg);instype)};

.x86das.oneop:{[addr;bc;instype;prefixState;options]
    res:.x86das.getoperands[addr;bc;instype;prefixState;options];
    bcsize:res 0;
    args:res 1;
    instype:res 2;
    args:1_args;
    if[(first[bc] in 0xf6f7) and instype=`TEST;
        immbc:$[args[0;1] in .x86das.reg1;1;
            args[0;1] in .x86das.reg2;2;
            args[0;1] in .x86das.reg4;4]#2_bc;
        args,:enlist(`imm; .x86util.le2i immbc);
        bcsize+:count immbc;
    ];
    argstr:", "sv .x86das.argstr each args;
    (addr;bcsize#bc;string[instype]," ",argstr;instype;args)};

.x86das.oneopWith1imm:{[addr;bc;instype;prefixState;options]
    res:.x86das.oneop[addr;bc;instype;prefixState;options];
    imm:first count[res 1]_bc;
    res[1],:imm;
    arg:(`imm;imm);
    res[4],:enlist arg;
    res[2],:", ",.x86das.argstr arg;
    res};

.x86das.oneopWith4imm:{[addr;bc;instype;prefixState;options]
    res:.x86das.oneop[addr;bc;instype;prefixState;options];
    size:$[prefixState 0;2;4];
    imm:size#count[res 1]_bc;
    res[1],:imm;
    arg:(`imm;.x86util.le2i imm);
    res[4],:enlist arg;
    res[2],:", ",.x86das.argstr arg;
    res};

.x86das.oneopWithsimm:{[addr;bc;instype;prefixState;options]
    res:.x86das.oneop[addr;bc;instype;prefixState;options];
    imm:first count[res 1]_bc;
    res[1],:imm;
    arg:(`simm;imm);
    res[4],:enlist arg;
    res[2],:", ",.x86das.argstr arg;
    res};

.x86das.oneopWithHardcoded:{[addr;bc;instype;prefixState;options;hcArg]
    res:.x86das.oneop[addr;bc;instype;prefixState;options];
    res[4],:enlist hcArg;
    res[2],:", ",.x86das.argstr hcArg;
    res};

.x86das.twoop:{[addr;bc;instype;prefixState;options]
    res:.x86das.getoperands[addr;bc;instype;prefixState;options];
    bcsize:res 0;
    args:res 1;
    instype:res 2;
    oc:bc 0;
    dir:(oc div 2)mod 2;
    if[((0=dir) and (instype<>`LEA) and not[`denyArgSwap in options])or `forceArgSwap in options; args:reverse args];
    argsstr:.x86das.argstr each args;
    (addr;bcsize#bc;string[instype]," ",", "sv argsstr;instype;args)};

.x86das.twoop41:{[addr;bc;instype;prefixState;options]
    res:.x86das.twoop[addr;bc;instype;prefixState;options];
    res[4;0;1]:$[prefixState 0;.x86das.regTo2;.x86das.regTo4]res[4;0;1];
    res[2]:first[" "vs res[2]]," ",.x86das.argsstr res[4];
    res};

.x86das.twoop42:{[addr;bc;instype;prefixState;options]
    res:.x86das.twoop[addr;bc;instype;prefixState;options,`wordExtend];
    res[4;0;1]:$[prefixState 0;.x86das.regTo2;.x86das.regTo4]res[4;0;1];
    res[2]:first[" "vs res[2]]," ",.x86das.argsstr res[4];
    res};

.x86das.twoopWithHardcoded:{[addr;bc;instype;prefixState;options;hcArg]
    res:.x86das.twoop[addr;bc;instype;prefixState;options];
    res[4],:enlist hcArg;
    res[2]:first[" "vs res[2]]," ",.x86das.argsstr res[4];
    res};

.x86das.twoopWith1imm:{[addr;bc;instype;prefixState;options]
    res:.x86das.twoop[addr;bc;instype;prefixState;options];
    imm:first count[res 1]_bc;
    res[1],:imm;
    arg:(`imm;imm);
    res[4],:enlist arg;
    res[2],:", ",.x86das.argstr arg;
    res};

.x86das.unitTest:{
    if[not .x86das.disasm[0;0x88C3][2]~"MOV BL, AL"; {'`failed}[]];
    if[not .x86das.disasm[0;0x89C3][2]~"MOV EBX, EAX"; {'`failed}[]];
    if[not .x86das.disasm[0;0x8AC3][2]~"MOV AL, BL"; {'`failed}[]];
    if[not .x86das.disasm[0;0x8BC3][2]~"MOV EAX, EBX"; {'`failed}[]];
    if[not .x86das.disasm[0;0x891D01020304][2]~"MOV DWORD PTR DS:[0x04030201], EBX"; {'`failed}[]];
    if[not .x86das.disasm[0;0x893B][2]~"MOV DWORD PTR DS:[EBX], EDI"; {'`failed}[]];
    if[not .x86das.disasm[0;0x897B01][2]~"MOV DWORD PTR DS:[EBX+0x01], EDI"; {'`failed}[]];
    if[not .x86das.disasm[0;0x897BFF][2]~"MOV DWORD PTR DS:[EBX-0x01], EDI"; {'`failed}[]];
    if[not .x86das.disasm[0;0x895D5D][2]~"MOV DWORD PTR SS:[EBP+0x5d], EBX"; {'`failed}[]];
    if[not .x86das.disasm[0;0x89BB01FFFFFF][2]~"MOV DWORD PTR DS:[EBX-0x000000ff], EDI"; {'`failed}[]];
    if[not .x86das.disasm[0;0x892C0501020304][2]~"MOV DWORD PTR DS:[EAX+0x04030201], EBP"; {'`failed}[]];
    if[not .x86das.disasm[0;0x8B0CBB][2]~"MOV ECX, DWORD PTR DS:[EBX+4*EDI]"; {'`failed}[]];
    if[not .x86das.disasm[0;0x890424][2]~"MOV DWORD PTR SS:[ESP], EAX"; {'`failed}[]];
    if[not .x86das.disasm[0;0x8F442424][2]~"POP DWORD PTR SS:[ESP+0x24]"; {'`failed}[]];
    if[not .x86das.disasm[0;0x660FBAE00D][2]~"BT AX, 0x0d"; {'`failed}[]];
    if[not .x86das.disasm[0;0x83ECE0][2]~"SUB ESP, -0x20"; {'`failed}[]];
    if[not .x86das.disasm[0;0x6681EEF063][2]~"SUB SI, 0x63f0"; {'`failed}[]];
    if[not .x86das.disasm[0;0x6681D6F063][2]~"ADC SI, 0x63f0"; {'`failed}[]];
    if[not .x86das.disasm[0;0x8D64243C][2]~"LEA ESP, DWORD PTR SS:[ESP+0x3c]"; {'`failed}[]];
    if[not .x86das.disasm[0;0x660FBEEA][2]~"MOVSX BP, DL"; {'`failed}[]];
    if[not .x86das.disasm[0;0x660FB706][2]~"MOVZX AX, WORD PTR DS:[ESI]"; {'`failed}[]];
    if[not .x86das.disasm[0;0x0FB70C4F][2]~"MOVZX ECX, WORD PTR DS:[EDI+2*ECX]"; {'`failed}[]];
    if[not .x86das.disasm[0;0x660FBCF9][2]~"BSF DI, CX"; {'`failed}[]];
    if[not .x86das.disasm[0;0x660FACF70C][2]~"SHRD DI, SI, 0x0c"; {'`failed}[]];
    if[not .x86das.disasm[0;0x0FBAE901][2]~"BTS ECX, 0x01"; {'`failed}[]];
    if[not .x86das.disasm[0;0x66D3D9][2]~"RCR CX, CL"; {'`failed}[]];
    if[not .x86das.disasm[0;0x66FFC1][2]~"INC CX"; {'`failed}[]];
    if[not .x86das.disasm[0;0xF6D0][2]~"NOT AL"; {'`failed}[]];
    if[not .x86das.disasm[0;0xD0D9][2]~"RCR CL, 0x01"; {'`failed}[]];
    if[not .x86das.disasm[0;0xC1C10E][2]~"ROL ECX, 0x0e"; {'`failed}[]];
    if[not .x86das.disasm[0;0xFEC0][2]~"INC AL"; {'`failed}[]];
    if[not .x86das.disasm[0;0x83C100][2]~"ADD ECX, 0x00"; {'`failed}[]];
    if[not .x86das.disasm[0;0x66F7C59E00][2]~"TEST BP, 0x009e"; {'`failed}[]];
    if[not .x86das.disasm[0;0x368B00][2]~"MOV EAX, DWORD PTR SS:[EAX]"; {'`failed}[]];
    if[not .x86das.disasm[0;0x8D34E5F413B8B7][2]~"LEA ESI, DWORD PTR DS:[0xb7b813f4]"; {'`failed}[]];
    if[not .x86das.disasm[0;0x668CD0][2]~"MOV AX, SS"; {'`failed}[]];
    if[not .x86das.disasm[0;0xC0C805][2]~"ROR AL, 0x05"; {'`failed}[]];
    if[not .x86das.disasm[0;0x6695][2]~"XCHG AX, BP"; {'`failed}[]];
    };
.x86das.unitTest[]

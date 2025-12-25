.x86asm.parseMemPart:{[part]
    if[part in string .x86das.reg4,.x86das.reg8;
        reg:`$part;
        if[reg in`ESP`RSP; :`base,reg];
        :`reg,reg;
    ];
    if[part like "0X*";
        :`displ,.x86asm.parseHexNum part;
    ];
    if[part like "-0X*";
        :`displ,neg .x86asm.parseHexNum part;
    ];
    if["*" in part;
        p2s:trim each "*"vs part;
        if[2<count p2s; {'"too many multiplicative terms"}[]];
        scale:0N;
        reg:`;
        $[p2s[0] in string .x86das.reg4;
            reg:`$p2s 0;
            [scale:"J"$p2s[0]; if[not scale in 1 2 4 8;{'"invalid reg/scale"}[]]]
        ];
        $[p2s[1] in string .x86das.reg4;
            $[null reg;reg:`$p2s 1;{'"can't do reg*reg"}[]];
            $[null scale;
                [scale:"J"$p2s[1]; if[not scale in 1 2 4 8;{'"invalid reg/scale"}[]]];
                {'"can't do num*num"}[]
            ]
        ];
        :`index,reg,scale;
    ];
    if[part like "[0-9]*";
        :`displ,"I"$part;
    ];
    {'"unknown address format: ",x}[part]};

.x86asm.parseMemArg:{[argstr]
    p:"["vs argstr;
    sizespec:" "vs p 0;
    datasize:(``BYTE`WORD`DWORD`QWORD!0N 1 2 4 8)`$sizespec 0;
    if[null datasize;{'"datasize is required"}[]];
    segment:`;
    if[":" in last sizespec; segment:`$2#-3#last sizespec; if[not segment in`CS`DS`ES`FS`GS`SS; {'"invalid segment"}[]]];
    basereg:`;
    scale:0;
    indexreg:`;
    displv:0i;
    addrparts:.x86asm.parseMemPart each trim each"+"vs ssr[first "]"vs p 1;"-";"+-"];
    types:group addrparts[;0];
    if[1<count types`base;{'"too many base registers"}[]];
    if[1<count types`index;{'"too many index registers"}[]];
    if[1<count types`displ;{'"too many displacements"}[]];
    if[2<sum count each types`base`index`reg;{'"too many registers"}[]];
    if[0<count types`displ; displv:addrparts[types[`displ;0];1]];
    if[0<count types`base;
        basereg:addrparts[types[`base;0];1];
        if[0<count types`reg;
            indexreg:addrparts[types[`reg;0];1];
            scale:1;
        ];
    ];
    if[0<count types`index;
        indexreg:addrparts[types[`index;0];1];
        scale:addrparts[types[`index;0];2];
        if[0<count types`reg;
            basereg:addrparts[types[`reg;0];1];
        ];
    ];
    if[2=count types`reg;
        basereg:addrparts[types[`reg;0];1];
        indexreg:addrparts[types[`reg;1];1];
        scale:1;
    ];
    if[1=count types`reg;
        basereg:addrparts[types[`reg;0];1];
    ];
    if[null segment; segment:$[basereg in`ESP`EBP;`SS;`DS]];
    :(`mem;datasize;segment;basereg;scale;indexreg;displv);
    };

.x86asm.parseHexNum:{[argstr]
    hx:(1+argstr?"X")_argstr;
    if[8<count hx; {'"too large number constant"}[]];
    0x00 sv "X"$2 cut ((8-count[hx])#"0"),hx};

.x86asm.parseArg:{[argstr]
    if[argstr like "0X*";
        :(`imm;.x86asm.parseHexNum argstr);
    ];
    if[argstr like "-0X*";
        :`imm,neg .x86asm.parseHexNum argstr;
    ];
    if["[" in argstr; :.x86asm.parseMemArg[argstr]];
    if[argstr in string .x86das.reg1,.x86das.reg1alt,.x86das.reg2,.x86das.reg4,.x86das.reg8,.x86das.sreg;
        :(`reg;`$argstr);
    ];
    {'"unknown arg: ",x}[argstr];
    };

.x86asm.regCode:{[reg]
    c:.x86das.reg8?reg; if[c<count .x86das.reg8;:c];
    c:.x86das.reg4?reg; if[c<count .x86das.reg4;:c];
    c:.x86das.reg2?reg; if[c<count .x86das.reg2;:c];
    c:.x86das.reg1?reg; if[c<count .x86das.reg1;:c];
    c:.x86das.reg1alt?reg; if[c<count .x86das.reg1alt;:c];
    c:.x86das.sreg?reg; if[c<count .x86das.sreg;:c];
    {'x}"unknown register ",string reg;
    };

.x86asm.oneop:{[opcode;reg;arg;options]
    opcode:(),opcode;
    rex:00000b;
    if[`altreg in options;rex[4]:1b];
    mode:0;
    rm:0;
    if[arg[0]=`reg;
        mode:3;
        rm:.x86asm.regCode arg[1];
        if[not `no1byte in options;if[arg[1] in .x86das.reg2,.x86das.reg4,.x86das.reg8; opcode[count[opcode]-1]:`byte$1+last opcode]];
        if[arg[1] in .x86das.reg2; opcode:0x66,opcode];
        if[arg[1] in .x86das.reg8;rex[0]:1b];
        if[reg>=8;rex[1]:1b;reg:reg mod 8];
        if[rm>=8;rex[3]:1b;rm:rm mod 8];
        if[not rex~00000b;opcode:(0b sv 0100b,-1_rex),opcode];
        :opcode,`byte$(mode*64)+(reg*8)+rm;
    ];
    //(`mem;datasize;segment;basereg;scale;indexreg;displv)
    datasize:arg[1];
    segment:arg[2];
    basereg:arg[3];
    scale:arg[4];
    indexreg:arg[5];
    displv:arg[6];
    if[datasize=8;rex[0]:1b];
    if[.x86das.defaultSegment[basereg]<>segment;
        $[segment=`ES; opcode:0x26,opcode;
          segment=`CS; opcode:0x2e,opcode;
          segment=`SS; opcode:0x36,opcode;
          segment=`DS; opcode:0x3e,opcode;
          segment=`FS; opcode:0x64,opcode;
          segment=`GS; opcode:0x65,opcode;
            {'"unknown segment override"}[]
        ];
    ];
    if[not `no1byte in options;if[arg[1]in 2 4 8; opcode[count[opcode]-1]:`byte$1+last opcode]];
    if[arg[1]=2;$[`diffsize in options; opcode[count[opcode]-1]:`byte$opcode[count[opcode]-1]+0x01;opcode:0x66,opcode]];
    if[(0=displv) and null[indexreg] and not basereg in``ESP`RSP;
        rm:.x86asm.regCode basereg;
        displ:();
        if[basereg=`EBP; mode:1; displ:0x00];
        :opcode,(`byte$(mode*64)+(reg*8)+rm),displ;
    ];
    if[((0<>displv) and null[indexreg] and not basereg in`ESP`RSP) or (0=displv) and null[indexreg] and null[basereg];
        $[null basereg;
            [mode:0; rm:5; displ:.x86util.i2le displv];
            [
                rm:.x86asm.regCode basereg;
                $[displv within -128 127;
                    [mode:1; displ:1#.x86util.i2le displv];
                    [mode:2; displ:.x86util.i2le displv]
                ]
            ]
        ];
        if[rm>=8;rex[3]:1b;rm:rm mod 8];
        if[not rex~00000b;opcode:(0b sv 0100b,-1_rex),opcode];
        :opcode,(`byte$(mode*64)+(reg*8)+rm),displ;
    ];
    indcode:$[(basereg in`ESP`RSP) and null indexreg; 4; .x86asm.regCode[indexreg]];
    if[indcode>=8;rex[2]:1b;indcode:indcode mod 8];
    basecode:$[null basereg;5;.x86asm.regCode basereg];
    if[basecode>=8;rex[3]:1b;basecode:basecode mod 8];
    sib:`byte$(((1 2 4 8)?scale)*64)+(indcode*8)+basecode;
    displ:`byte$();
    if[displv<>0;
        $[displv within -128 127;[
            displ:enlist `byte$displv;
            mode:1;
            ];[
            displ:.x86util.i2le displv;
            mode:$[null basereg;0;2];
            ]
        ];
    ];
    mrr:`byte$(mode*64)+(reg*8)+4;
    if[not rex~00000b;opcode:(0b sv 0100b,-1_rex),opcode];
    :opcode,mrr,sib,displ;
    {'"unknown memory addressing mode"}[];
    };

.x86asm.twoop:{[opcode;args;options]
    if[all args[;0]=`mem; {'"max. 1 memory argument"}[]];
    if[args[1;0]=`mem;
        args:reverse args;
        opcode:`byte$opcode+2;
    ];
    reg:.x86asm.regCode args[1;1];
    if[reg>=4;if[args[1;1] in .x86das.reg1alt;options,:`altreg]];
    :.x86asm.oneop[opcode;reg;args[0];options];
    };

.x86asm.jump:{[addr;opcode;args]
    if[args[0;0]=`imm; :opcode,.x86util.i2le[`int$args[0;1]-addr+4+count opcode]];
    };

.x86asm.bitshift:{[subopcode;args]
    :$[args[1;0]=`imm;
        $[1=args[1;1];
            .x86asm.oneop[0xd0;subopcode;args 0;`$()];
            .x86asm.oneop[0xc0;subopcode;args 0;`$()],`byte$args[1;1]
        ];
      args[1;0]=`reg; [if[not`CL=args[1;1];{'"bitshift can't use register other than CL"}[]];
        .x86asm.oneop[0xd2;subopcode;args 0;`$()]
      ];
      {'"bitshift: invalid argument"}[]];
    };

.x86asm.arithm:{[opcodebase;args]
    if[args[1;0]=`imm;
        if[args[0;0]=`reg;
            if[args[0;1] in `AL`AX`EAX;
                opcode:$[args[0;1]=`AX;0x66;()],`byte$4+(8*opcodebase)+args[0;1]<>`AL;
                :opcode,(`AL`AX`EAX!1 2 4)[args[0;1]]#.x86util.i2le args[1;1];
            ];
        ];
        stem:.x86asm.oneop[0x80;opcodebase;args[0];`$()];
        rexb:();
        if[64=.x86asm.mode;if[stem[0]within 0x404f;rexb:stem 0;stem:1_stem]];
        if[(stem[0]=0x81) and args[1;1] within -128 127;
            :rexb,0x83,(1_stem),`byte$args[1;1];
        ];
        size:4;
        if[stem[0]=0x66; size:2];
        if[stem[0]in 0x8083; size:1];
        :rexb,stem,size#.x86util.i2le args[1;1]
    ];
    opcode:`byte$8*opcodebase;
    if[(args[0;0]=`reg)and args[1;0]=`imm;if[args[0;1]in`AL`AX`EAX;
        opcode+:0x04;
        if[args[0;1]<>`AL; opcode+:0x01];
        if[args[0;1]=`AX; opcode:0x66,opcode];
        :opcode,.x86util.i2le args[1;1];
    ]];
    :.x86asm.twoop[opcode;args;`$()];
    };

.x86asm.bitscan:{[opcode;subopcode;args]
    $[args[1;0]=`imm;
        .x86asm.oneop[0x0fba;subopcode;args 0;`no1byte],`byte$args[1;1];
        .x86asm.twoop[opcode;args;`no1byte]]};

.x86asm.handlers:()!();
.x86asm.handlers[`MOV]:{[addr;args]
    if[(args[1;0]=`imm) and (args[0;0]=`reg);
        $[args[0;1] in .x86das.reg1; :(`byte$0xb0+.x86das.reg1?args[0;1]),.x86util.i2le`byte$args[1;1];
          args[0;1] in .x86das.reg4; :(`byte$0xb8+.x86das.reg4?args[0;1]),.x86util.i2le`int$args[1;1];
          :0x66,(`byte$0xb8+.x86das.reg2?args[0;1]),2#.x86util.i2le args[1;1]];
    ];
    if[(args[1;0]=`imm) and (args[0;0]=`mem);
        :.x86asm.oneop[0xc6;0;args[0];`$()],args[0;1]#.x86util.i2le args[1;1];
    ];
    opcode:0x88;
    options:`$();
    if[args[1;0]=`reg; if[args[1;1] in .x86das.sreg; opcode:0x8c; options,:`no1byte]];
    if[args[0;0]=`reg; if[args[0;1] in .x86das.sreg; opcode:0x8e; args:reverse args; options,:`no1byte]];
    :.x86asm.twoop[opcode;args;options];
    };
.x86asm.handlers[`LEA]:{[addr;args].x86asm.twoop[0x8d;reverse args;`no1byte]};
.x86asm.handlers[`PUSH]:{[addr;args]
    if[args[0;0]=`imm; :0x68,.x86util.i2le args[0;1]];
    if[args[0;0]=`mem; :.x86asm.oneop[0xff;6;args 0;`no1byte]];
    if[args[0;0]=`reg;
        $[args[0;1]=`ES;:enlist 0x06;
          args[0;1]=`CS;:enlist 0x0e;
          args[0;1]=`SS;:enlist 0x16;
          args[0;1]=`DS;:enlist 0x1e;
          args[0;1]=`FS;:0x0fa0;
          args[0;1]=`GS;:0x0fa8;
        [rc:.x86asm.regCode args[0;1];
            :$[rc>=8;0x41;()],`byte$0x50+rc mod 8]
        ]
    ];
    };
.x86asm.handlers[`POP]:{[addr;args]
    if[args[0;0]=`mem; :.x86asm.oneop[0x8f;0;args 0;`no1byte]];
    if[args[0;0]=`reg;
        $[args[0;1]=`ES;:enlist 0x07;
          args[0;1]=`CS;{'"no instruction for POP CS"}[];
          args[0;1]=`SS;:enlist 0x17;
          args[0;1]=`DS;:enlist 0x1f;
          args[0;1]=`FS;:0x0fa1;
          args[0;1]=`GS;:0x0fa9;
        [rc:.x86asm.regCode args[0;1];
            :$[rc>=8;0x41;()],`byte$0x58+rc mod 8]
        ]
    ];
    };
.x86asm.handlers[`INC]:{[addr;args]
    $[(64<>.x86asm.mode)and args[0;1] in .x86das.reg2,.x86das.reg4;
        $[args[0;1] in .x86das.reg2;0x66;()],`byte$0x40+.x86asm.regCode args[0;1];
        .x86asm.oneop[0xfe;0;args[0];`$()]
    ]};
.x86asm.handlers[`DEC]:{[addr;args]
    $[(64<>.x86asm.mode)and args[0;1] in .x86das.reg2,.x86das.reg4;
        $[args[0;1] in .x86das.reg2;0x66;()],`byte$0x48+.x86asm.regCode args[0;1];
        .x86asm.oneop[0xfe;1;args[0];`$()]
    ]};
.x86asm.handlers[`CALL]:{[addr;args]
    $[args[0;0]=`imm;
        .x86asm.jump[addr;0xe8;args];
        .x86asm.oneop[0xff;2;args[0];`no1byte]
    ]};
.x86asm.handlers[`JMP]:{[addr;args]
    $[args[0;0]=`imm;
        .x86asm.jump[addr;0xe9;args];
        .x86asm.oneop[0xff;4;args[0];`no1byte]
    ]};
.x86asm.handlers[`RETN]:{[addr;args]$[1=count args;0xc2,.x86util.i2le`short$args[0;1];enlist 0xc3]};
.x86asm.handlers[`PUSHAD]:{[addr;args]enlist 0x60};
.x86asm.handlers[`PUSHFD]:{[addr;args]enlist 0x9c};
.x86asm.handlers[`PUSHFW]:{[addr;args]0x669c};
.x86asm.handlers[`POPFD]:{[addr;args]enlist 0x9d};
.x86asm.handlers[`POPFW]:{[addr;args]0x669d};
.x86asm.handlers[`MOVZX]:{[addr;args]$[args[0;1] in .x86das.reg2;0x66;()],.x86asm.twoop[0x0fb6;reverse args;`no1byte`diffsize]};
.x86asm.handlers[`MOVSX]:{[addr;args]$[args[0;1] in .x86das.reg2;0x66;()],.x86asm.twoop[0x0fbe;reverse args;`no1byte`diffsize]};
.x86asm.handlers[`ADD]:{[addr;args].x86asm.arithm[0;args]};
.x86asm.handlers[`OR]:{[addr;args].x86asm.arithm[1;args]};
.x86asm.handlers[`ADC]:{[addr;args].x86asm.arithm[2;args]};
.x86asm.handlers[`SBB]:{[addr;args].x86asm.arithm[3;args]};
.x86asm.handlers[`AND]:{[addr;args].x86asm.arithm[4;args]};
.x86asm.handlers[`SUB]:{[addr;args].x86asm.arithm[5;args]};
.x86asm.handlers[`XOR]:{[addr;args].x86asm.arithm[6;args]};
.x86asm.handlers[`CMP]:{[addr;args].x86asm.arithm[7;args]};
.x86asm.handlers[`TEST]:{[addr;args]
    $[args[1;0]=`imm;
        $[args[0;1]in`AL`AX`EAX;
            $[args[0;1]=`AX;0x66;()],(`byte$0xa8+args[0;1]<>`AL),(`AL`AX`EAX!1 2 4)[args[0;1]]#.x86util.i2le args[1;1]
        ;[
        .x86asm.oneop[0xf6;0;args 0;`$()],$[args[0;1] in .x86das.reg1;1;
            args[0;1] in .x86das.reg2;2;
            args[0;1] in .x86das.reg4;4;
            '"invalid value in args[0;1]"]#.x86util.i2le args[1;1]
        ]]
    ;.x86asm.twoop[0x84;args;`$()]]};
.x86asm.handlers[`JO ]:{[addr;args].x86asm.jump[addr;0x0f80;args]};
.x86asm.handlers[`JNO]:{[addr;args].x86asm.jump[addr;0x0f81;args]};
.x86asm.handlers[`JB ]:{[addr;args].x86asm.jump[addr;0x0f82;args]};
.x86asm.handlers[`JNB]:{[addr;args].x86asm.jump[addr;0x0f83;args]};
.x86asm.handlers[`JE ]:{[addr;args].x86asm.jump[addr;0x0f84;args]};
.x86asm.handlers[`JNZ]:{[addr;args].x86asm.jump[addr;0x0f85;args]};
.x86asm.handlers[`JBE]:{[addr;args].x86asm.jump[addr;0x0f86;args]};
.x86asm.handlers[`JA ]:{[addr;args].x86asm.jump[addr;0x0f87;args]};
.x86asm.handlers[`JS ]:{[addr;args].x86asm.jump[addr;0x0f88;args]};
.x86asm.handlers[`JNS]:{[addr;args].x86asm.jump[addr;0x0f89;args]};
.x86asm.handlers[`JPE]:{[addr;args].x86asm.jump[addr;0x0f8a;args]};
.x86asm.handlers[`JPO]:{[addr;args].x86asm.jump[addr;0x0f8b;args]};
.x86asm.handlers[`JL]: {[addr;args].x86asm.jump[addr;0x0f8c;args]};
.x86asm.handlers[`JGE]:{[addr;args].x86asm.jump[addr;0x0f8d;args]};
.x86asm.handlers[`JLE]:{[addr;args].x86asm.jump[addr;0x0f8e;args]};
.x86asm.handlers[`JG]: {[addr;args].x86asm.jump[addr;0x0f8f;args]};
.x86asm.handlers[`ROL]:{[addr;args].x86asm.bitshift[0;args]};
.x86asm.handlers[`ROR]:{[addr;args].x86asm.bitshift[1;args]};
.x86asm.handlers[`RCL]:{[addr;args].x86asm.bitshift[2;args]};
.x86asm.handlers[`RCR]:{[addr;args].x86asm.bitshift[3;args]};
.x86asm.handlers[`SHL]:{[addr;args].x86asm.bitshift[4;args]};
.x86asm.handlers[`SHR]:{[addr;args].x86asm.bitshift[5;args]};
.x86asm.handlers[`SAL]:{[addr;args].x86asm.bitshift[6;args]};
.x86asm.handlers[`SAR]:{[addr;args].x86asm.bitshift[7;args]};
.x86asm.handlers[`NOT]:{[addr;args].x86asm.oneop[0xf6;2;args 0;`$()]};
.x86asm.handlers[`NEG]:{[addr;args].x86asm.oneop[0xf6;3;args 0;`$()]};
.x86asm.handlers[`MUL]:{[addr;args].x86asm.oneop[0xf6;4;args 0;`$()]};
.x86asm.handlers[`IMUL]:{[addr;args].x86asm.oneop[0xf6;5;args 0;`$()]};
.x86asm.handlers[`DIV]:{[addr;args].x86asm.oneop[0xf6;6;args 0;`$()]};
.x86asm.handlers[`IDIV]:{[addr;args].x86asm.oneop[0xf6;7;args 0;`$()]};
.x86asm.handlers[`BSF]:{[addr;args].x86asm.twoop[0x0fbc;reverse args;`no1byte]};
.x86asm.handlers[`BSR]:{[addr;args].x86asm.twoop[0x0fbd;reverse args;`no1byte]};
.x86asm.handlers[`XADD]:{[addr;args].x86asm.twoop[0x0fc0;args;`$()]};
.x86asm.handlers[`SHLD]:{[addr;args]
    if[args[2;0]=`imm;
        :.x86asm.twoop[0x0fa4;args;`no1byte],`byte$args[2;1];
    ];
    :.x86asm.twoop[0x0fa5;args;`no1byte];
    };
.x86asm.handlers[`SHRD]:{[addr;args]
    if[args[2;0]=`imm;
        :.x86asm.twoop[0x0fac;args;`no1byte],`byte$args[2;1];
    ];
    :.x86asm.twoop[0x0fad;args;`no1byte];
    };
.x86asm.handlers[`BSWAP]:{[addr;args]
    $[args[0;1] in .x86das.reg2;0x66;()],0x0f,`byte$0xc8+.x86asm.regCode args[0;1]};
.x86asm.handlers[`XCHG]:{[addr;args]
    if[(args[0]in`reg,/:`AX`EAX) and args[1;0]=`reg;
        :$[args[0;1]=`AX;0x66;()],enlist`byte$0x90+.x86asm.regCode[args[1;1]]];
    if[(args[1]in`reg,/:`AX`EAX) and args[0;0]=`reg;
        :$[args[1;1]=`AX;0x66;()],enlist`byte$0x90+.x86asm.regCode[args[0;1]]];
    .x86asm.twoop[0x86;args;`$()]};
.x86asm.handlers[`CMC]:{[addr;args]enlist 0xf5};
.x86asm.handlers[`CLC]:{[addr;args]enlist 0xf8};
.x86asm.handlers[`STC]:{[addr;args]enlist 0xf9};
.x86asm.handlers[`CLD]:{[addr;args]enlist 0xfc};
.x86asm.handlers[`STD]:{[addr;args]enlist 0xfd};
.x86asm.handlers[`BT]:{[addr;args].x86asm.bitscan[0x0fa3;4;args]};
.x86asm.handlers[`BTS]:{[addr;args].x86asm.bitscan[0x0fab;5;args]};
.x86asm.handlers[`BTR]:{[addr;args].x86asm.bitscan[0x0fb3;6;args]};
.x86asm.handlers[`BTC]:{[addr;args].x86asm.bitscan[0x0fbb;7;args]};
.x86asm.handlers[`SETO]: {[addr;args].x86asm.oneop[0x0f90;0;args 0;`$()]};
.x86asm.handlers[`SETNO]:{[addr;args].x86asm.oneop[0x0f91;0;args 0;`$()]};
.x86asm.handlers[`SETB]: {[addr;args].x86asm.oneop[0x0f92;0;args 0;`$()]};
.x86asm.handlers[`SETNB]:{[addr;args].x86asm.oneop[0x0f93;0;args 0;`$()]};
.x86asm.handlers[`SETE]: {[addr;args].x86asm.oneop[0x0f94;0;args 0;`$()]};
.x86asm.handlers[`SETNE]:{[addr;args].x86asm.oneop[0x0f95;0;args 0;`$()]};
.x86asm.handlers[`SETBE]:{[addr;args].x86asm.oneop[0x0f96;0;args 0;`$()]};
.x86asm.handlers[`SETA]: {[addr;args].x86asm.oneop[0x0f97;0;args 0;`$()]};
.x86asm.handlers[`SETS]: {[addr;args].x86asm.oneop[0x0f98;0;args 0;`$()]};
.x86asm.handlers[`SETNS]:{[addr;args].x86asm.oneop[0x0f99;0;args 0;`$()]};
.x86asm.handlers[`SETPE]:{[addr;args].x86asm.oneop[0x0f9a;0;args 0;`$()]};
.x86asm.handlers[`SETPO]:{[addr;args].x86asm.oneop[0x0f9b;0;args 0;`$()]};
.x86asm.handlers[`SETL]: {[addr;args].x86asm.oneop[0x0f9c;0;args 0;`$()]};
.x86asm.handlers[`SETGE]:{[addr;args].x86asm.oneop[0x0f9d;0;args 0;`$()]};
.x86asm.handlers[`SETLE]:{[addr;args].x86asm.oneop[0x0f9e;0;args 0;`$()]};
.x86asm.handlers[`SETG]: {[addr;args].x86asm.oneop[0x0f9f;0;args 0;`$()]};
.x86asm.handlers[`CBW]:{[addr;args]0x6698};
.x86asm.handlers[`CWDE]:{[addr;args]enlist 0x98};
.x86asm.handlers[`CWD]:{[addr;args]0x6699};
.x86asm.handlers[`CDQ]:{[addr;args]enlist 0x99};
.x86asm.handlers[`MOVSB]:{[addr;args]enlist 0xa4};
.x86asm.handlers[`CMPSB]:{[addr;args]enlist 0xa6};
.x86asm.handlers[`STOSB]:{[addr;args]enlist 0xaa};
.x86asm.handlers[`LODSB]:{[addr;args]enlist 0xac};
.x86asm.handlers[`SCASB]:{[addr;args]enlist 0xae};
.x86asm.handlers[`REPNE]:{[addr;instype]0xf2,.x86asm.handlers[instype][addr;()]};
.x86asm.handlers[`REP]:{[addr;instype]0xf3,.x86asm.handlers[instype][addr;()]};
.x86asm.handlers[`DAA]:{[addr;args]enlist 0x27};
.x86asm.handlers[`DAS]:{[addr;args]enlist 0x2f};
.x86asm.handlers[`AAA]:{[addr;args]enlist 0x37};
.x86asm.handlers[`AAS]:{[addr;args]enlist 0x3f};
.x86asm.handlers[`AAM]:{[addr;args]0xd4,`byte$args[0;1]};
.x86asm.handlers[`AAD]:{[addr;args]0xd5,`byte$args[0;1]};
.x86asm.handlers[`LAHF]:{[addr;args]enlist 0x9f};
.x86asm.handlers[`RDTSC]:{[addr;args]0x0f31};
.x86asm.handlers[`INT3]:{[addr;args]enlist 0xcc};

.x86asm.asm:{[addr;inst]
    p:" "vs upper inst;
    instype:`$p 0;
    if[instype in `REPNE`REP;
        instype2:`$p 1;
        :.x86asm.handlers[instype][addr;instype2];
    ];
    argsstr:" "sv (1_p) except enlist"";
    if[`DB=instype;
        dbarg:p 1;
        if[not (2#dbarg)~"0X"; {'"DB arg must start with 0x"}[]];
        dbarg1:2_dbarg;
        bytes:"X"$2 cut dbarg1;
        if[not dbarg1~upper raze string bytes; {'"invalid arg to DB"}[]];
        :bytes;
    ];
    args:$[0<count argsstr;.x86asm.parseArg each trim each","vs argsstr;()];
    if[not instype in key .x86asm.handlers; {'"asm: unknown instruction type: ",x}[string instype]];
    res:.x86asm.handlers[instype][addr;args];
    if[not 4h=type res; {'"asm handler returned invalid type"}[]];
    res};

.x86asm.asmAll:{[addr;insts]
    bcs:();
    labels:-1_/:insts where insts like "*:";
    dupeLabels:where 1<count each group labels;
    if[0<count dupeLabels; {'"duplicate label: ",x}[", "sv dupeLabels]];
    labelRefs:where each count each/:insts ss\:/:labels;
    labelVal:labels!count[labels]#0Ni;
    addrs:();
    idx:0;
    revisitInstr:();
    while[idx<count insts;
        inst:insts[idx];
        addrs,:addr;
        $[inst like "*:";
            [
                replaceLabels:labels where idx in/:labelRefs;
                labelVal[replaceLabels]:addr;
                newbc:`byte$();
            ];
            [
                replaceLabels:labels where idx in/:labelRefs;
                inst:{ssr[x;y[0];.x86util.shex y[1]]}/[inst;replaceLabels (;)' labelVal replaceLabels];
                newbc:.x86asm.asm[addr;inst];
                if[any null labelVal replaceLabels; revisitInstr,:idx];
            ]
        ];
        bcs,:enlist newbc;
        addr+:count newbc;
        idx+:1;
    ];
    while[0<count revisitInstr;
        idx:first revisitInstr;
        inst:insts[idx];
        replaceLabels:labels where idx in/:labelRefs;
        inst:{ssr[x;y[0];.x86util.shex y[1]]}/[inst;replaceLabels (;)' labelVal replaceLabels];
        newbc:.x86asm.asm[addrs[idx];inst];
        bcs[idx]:newbc;
        revisitInstr:1_revisitInstr;
    ];
    raze bcs};

.x86asm.unitTest:{
    .x86asm.mode:32;
    if[not `EBP=.x86asm.parseMemArg["DWORD PTR SS:[EBP]"][3];{'"failed"}[]];
    if[not -1=.x86asm.parseArg["DWORD PTR DS:[ESI-0X01]"][6];{'"failed"}[]];
    if[not `EAX=.x86asm.parseArg["DWORD PTR DS:[4*EAX+0X05772e82]"][5];{'"failed"}[]];
    if[not 0x8B0C85822E7705~.x86asm.asm[0;"MOV ECX, DWORD PTR DS:[4*EAX+0x05772e82]"];{'"failed"}[]];
    if[not 0x368B00~.x86asm.asm[0;"MOV EAX, DWORD PTR SS:[EAX]"];{'"failed"}[]];
    if[not 0x890424~.x86asm.asm[0;"MOV DWORD PTR SS:[ESP], EAX"];{'"failed"}[]];
    if[not 0x668964241C~.x86asm.asm[0;"MOV WORD PTR SS:[ESP+0x1c], SP"];{'"failed"}[]];
    if[not 0x894C2404~.x86asm.asm[0;"MOV DWORD PTR SS:[ESP+0x04], ECX"];{'"failed"}[]];
    if[not 0x8B74242C~.x86asm.asm[0;"MOV ESI, DWORD PTR SS:[ESP+0x2c]"];{'"failed"}[]];
    if[not 0x89DE~.x86asm.asm[0;"MOV ESI, EBX"];{'"failed"}[]];
    if[not 0x8D64243C~.x86asm.asm[0;"LEA ESP, DWORD PTR SS:[ESP+0x3c]"];{'"failed"}[]];
    if[not 0x8F442424~.x86asm.asm[0;"POP DWORD PTR SS:[ESP+0x24]"];{'"failed"}[]];
    if[not 0x660FBAE00D~.x86asm.asm[0;"BT AX, 0x0d"];{'"failed"}[]];
    if[not 0x84C1~.x86asm.asm[0;"TEST CL, AL"];{'"failed"}[]];
    if[not 0x6685C5~.x86asm.asm[0;"TEST BP, AX"];{'"failed"}[]];
    if[not 0x83ECE0~.x86asm.asm[0;"SUB ESP, -0x20"];{'"failed"}[]];
    if[not 0x66D3EE~.x86asm.asm[0;"SHR SI, CL"];{'"failed"}[]];
    if[not 0x6681D6AD38~.x86asm.asm[0;"ADC SI, 0x38ad"];{'"failed"}[]];
    if[not 0x66BE6584~.x86asm.asm[0;"MOV SI, 0x8465"];{'"failed"}[]];
    if[not 0x0FB6F0~.x86asm.asm[0;"MOVZX ESI, AL"];{'"failed"}[]];
    if[not 0x660FB706~.x86asm.asm[0;"MOVZX AX, WORD PTR DS:[ESI]"];{'"failed"}[]];
    if[not 0x037500~.x86asm.asm[0;"ADD ESI, DWORD PTR SS:[EBP]"];{'"failed"}[]];
    if[not 0x83C100~.x86asm.asm[0;"ADD ECX, 0x00000000"];{'"failed"}[]];
    if[not 0xD2C5~.x86asm.asm[0;"ROL CH, CL"];{'"failed"}[]];
    if[not 0xC0C006~.x86asm.asm[0;"ROL AL, 0x06"];{'"failed"}[]];
    if[not 0x66D1D5~.x86asm.asm[0;"RCL BP, 0x01"];{'"failed"}[]];
    if[not enlist[0x40]~.x86asm.asm[0;"INC EAX"];{'"failed"}[]];
    if[not enlist[0x48]~.x86asm.asm[0;"DEC EAX"];{'"failed"}[]];
    if[not 0xFEC0~.x86asm.asm[0;"INC AL"];{'"failed"}[]];
    if[not 0x80F924~.x86asm.asm[0;"CMP CL, 0x24"];{'"failed"}[]];
    if[not 0x663D8568~.x86asm.asm[0;"CMP AX, 0x6885"];{'"failed"}[]];
    if[not 0x6681E63A8A~.x86asm.asm[0;"AND SI, 0x8a3a"];{'"failed"}[]];
    if[not 0x668CD0~.x86asm.asm[0;"MOV AX, SS"];{'"failed"}[]];
    if[not 0x8B1D00000000~.x86asm.asm[0;"MOV EBX, DWORD[0]"];{'"failed"}[]];
    if[not 0x83450038~.x86asm.asm[0;"ADD DWORD PTR SS:[EBP+0x00000000], 0x00000038"];{'"failed"}[]];
    if[not 0x41E9FAFFFFFFE90100000049~.x86asm.asmAll[100;("alma:";"INC ECX";"JMP alma";"JMP dio";"DEC ECX";"dio:")];{'"failed"}[]];
    if[not 0x0102030e0f~.x86asm.asm[0;"DB 0x0102030e0f"];{'"failed"}[]];
    if[not 0xFF15252A7505~.x86asm.asm[0;"CALL DWORD PTR [0x05752a25]"];{'"failed"}[]];
    if[not 0x6695~.x86asm.asm[0;"XCHG AX, BP"];{'"failed"}[]];
    if[not "duplicate label: L1, L2"~.[.x86asm.asmAll;(100;("L1:";"L1:";"L2:";"L2:"));{x}];{'"failed"}[]];
    if[not "max. 1 memory argument"~.[.x86asm.asm;(0;("TEST DWORD [0x0], DWORD [0x0]"));{x}];{'"failed"}[]];
    };
.x86asm.unitTest[];

.x86asm.unitTest64Def:([]addr:();inst:();result:());
`.x86asm.unitTest64Def insert `addr`inst`result!(0;"PUSH RDI"                        ;enlist 0x57 );
`.x86asm.unitTest64Def insert `addr`inst`result!(0;"PUSH R15"                        ;0x4157      );
`.x86asm.unitTest64Def insert `addr`inst`result!(0;"POP RDI"                         ;enlist 0x5F );
`.x86asm.unitTest64Def insert `addr`inst`result!(0;"POP R15"                         ;0x415F      );
`.x86asm.unitTest64Def insert `addr`inst`result!(0;"INC EAX"                         ;0xFFC0      );
`.x86asm.unitTest64Def insert `addr`inst`result!(0;"INC RAX"                         ;0x48FFC0    );
`.x86asm.unitTest64Def insert `addr`inst`result!(0;"DEC EAX"                         ;0xFFC8      );
`.x86asm.unitTest64Def insert `addr`inst`result!(0;"XOR DH, DH"                      ;0x30F6      );    //or 0x32F6
`.x86asm.unitTest64Def insert `addr`inst`result!(0;"XOR SIL, SIL"                    ;0x4030F6    );
`.x86asm.unitTest64Def insert `addr`inst`result!(0;"LEA EDX, DWORD PTR DS:[RAX+0x02]";0x8D5002    );
`.x86asm.unitTest64Def insert `addr`inst`result!(0;"LEA EDX, DWORD PTR DS:[R8+0x02]" ;0x418D5002  );
`.x86asm.unitTest64Def insert `addr`inst`result!(0;"LEA ECX, DWORD PTR DS:[RAX+RCX]" ;0x8D0C08    );
`.x86asm.unitTest64Def insert `addr`inst`result!(0;"LEA ECX, DWORD PTR DS:[R8+RCX]"  ;0x418D0C08  );
`.x86asm.unitTest64Def insert `addr`inst`result!(0;"LEA ECX, DWORD PTR DS:[RAX+R9]"  ;0x428D0C08  );
`.x86asm.unitTest64Def insert `addr`inst`result!(0;"XOR EAX, ECX"                    ;0x31C8      );
`.x86asm.unitTest64Def insert `addr`inst`result!(0;"XOR R8D, ECX"                    ;0x4131C8    );
`.x86asm.unitTest64Def insert `addr`inst`result!(0;"XOR EAX, R9D"                    ;0x4431C8    );
`.x86asm.unitTest64Def insert `addr`inst`result!(0;"XOR R8D, R9D"                    ;0x4531C8    );    //or 0x4533C1
`.x86asm.unitTest64Def insert `addr`inst`result!(0;"SUB ESP, 0x28"                   ;0x83EC28    );
`.x86asm.unitTest64Def insert `addr`inst`result!(0;"SUB RSP, 0x28"                   ;0x4883EC28  );
`.x86asm.unitTest64Def insert `addr`inst`result!(0;"MOV DWORD PTR DS:[RSP+0x08], EBX";0x895C2408  );
`.x86asm.unitTest64Def insert `addr`inst`result!(0;"MOV QWORD PTR DS:[RSP+0x08], RBX";0x48895C2408);

.x86asm.unitTest64:{
    .x86asm.mode:64;
    {if[not .x86asm.asm[x`addr;x`inst]~x`result;{'"failed"}[]]}each .x86asm.unitTest64Def;
    };
.x86asm.unitTest64[]

.x86asm.mode:32;

binaryCopyable:{[bytes]" "sv upper string bytes};

.arm64.getNumber:{[arg]
    sign:1i;
    if["-"=first arg; sign:-1i; arg:1_arg];
    if[arg like "0X*";
        arg:2_arg;
        if[8<count arg;
            if[16<count arg; '"hex literal too long"];
            :sign*0x0 sv "X"$2 cut"0"^-16$arg;
        ];
        :sign*0x0 sv "X"$2 cut"0"^-8$arg;
    ];
    sign*"J"$arg};

.arm64.getLabelDest:{[labelMap;arg]
    if[not arg like "#*";
        label:`$arg;
        if[not label in key labelMap; '"unknown label ",arg];
        :labelMap label;
    ];
    .arm64.getNumber 1_arg};

.arm64.encodeBitMasks:{[size;num;rejectBits]
    bits:0b vs num;
    if[(not size) and 64=count bits;
        if[not 0=sum 32#bits; '"encodeBitMasks: number doesn't fit into 32 bits"];
        bits:32_bits;
    ];
    sizes:(2 4 8 16 32,size#64);
    cuts:distinct each sizes cut\: bits;
    cuts2:first each cuts where 1=count each cuts;
    if[0=count cuts2; '"encodeBitMasks: number is not a valid bit pattern"];
    rots0:cuts2?\:1b;
    cuts3:rots0 rotate' cuts2;
    rots1:cuts3?\:0b;
    cuts4:rots1 rotate' cuts3;
    rots:(rots0+rots1) mod count each cuts4;
    lens:1_/:where each differ each cuts4;
    goodIndex:first where 1=count each lens;
    if[null goodIndex; '"encodeBitMasks: number is not a valid bit pattern"];
    goodSize:count cuts4[goodIndex];
    goodLen:goodSize-1+lens[goodIndex;0];
    goodRot:rots goodIndex;
    n:goodSize=64;
    imms:((`s#2 4 8 16 32 64)!60 56 48 32 0 0)[goodSize]+goodLen;
    if[0<count rejectBits;
        goodRot+:0b sv 00b,rejectBits,(6-count rejectBits)#0b;
    ];
    (n;imms;goodRot)};

.arm64.parseScalarReg:{[arg;useSP]
    if[arg~"WSP"; $[useSP; :0 31; '"SP cannot be used here"]];
    if[arg~"SP"; $[useSP; :1 31; '"SP cannot be used here"]];
    if[arg~"WZR"; $[useSP; '"ZR cannot be used here";:0 31]];
    if[arg~"XZR"; $[useSP; '"ZR cannot be used here";:1 31]];
    size:$[arg[0]="W"; 0; arg[0]="X"; 1; '"invalid register name: ",arg];
    num:"J"$1_arg;
    if[null num; '"invalid register name: ",arg];
    if[not num within 0 30; '"invalid register number: ",arg];
    size,num};

.arm64.parseSimdReg:{[arg]
    sizes:"BHSDQ";
    size:sizes?arg 0;
    if[size=count sizes; '"invalid register name: ",arg];
    num:"J"$1_arg;
        if[null num; '"invalid register name: ",arg];
    if[not num within 0 31; '"invalid register number: ",arg];
    size,num};

.arm64.parseVectorReg:{[arg]
    p:"."vs arg;
    if[2<>count p; '"invalid vector register with arragement: ",arg];
    num:"J"$1_p 0;
    if[not num within 0 31; '"invalid register number: ",arg];
    arrMap:("8B";"4H";"2S";"1D";"16B";"8H";"4S";"2D")!(0 0;0 1;0 2;0 3;1 0;1 1;1 2;1 3);
    if[not p[1] in key arrMap; '"invalid arrangement specifier: ",arg];
    arrs:arrMap p 1;
    arrs,num};

.arm64.parseIndexedVectorReg:{[reg]
    //Vm.Ts[index]
    sp:"."vs reg;
    if[2<>count sp; '"vector reg must be in the form Vm.Ts[index]"];
    if[sp[0;0]<>"V"; '"vector reg must be in the form Vm.Ts[index]"];
    rm:"J"$1_sp[0];
    if[not rm within 0 31; '"vector reg: invalid register name: ",sp 0];
    tsizes:"HS";
    ts:tsizes?first sp 1;
    if[ts=count tsizes; '"vector reg: invalid register size: ",sp 1];
    ind0:1_sp 1;
    if[not "[]"~first[ind0],last[ind0]; '"vector reg: index should be surrounded by []"];
    index:"J"$1_-1_ind0;
    (ts;index;rm)};

.arm64.getSignedImmediate:{[caller;num;bits;stride]
    //get signed immediate cut down to a given number of bits
    //stride: number of bits to cut off at the end, e.g. for B, the offset should have 2 bits cut off
    d:prd stride#2;
    if[not 0=num mod d; 'caller,": constant not divisible by ",string[d]];
    num2:num div d;
    bound:prd (bits-1)#2;
    bounds:(neg bound;bound-1);
    if[not num2 within bounds; 'caller,": constant doesn't fit into ",string[bits]," bits"];
    num2 mod 2*bound};

.arm64.getUnsignedImmediate:{[caller;num;bits;stride]
    d:prd stride#2;
    if[not 0=num mod d; 'caller,": constant not divisible by ",string[d]];
    num2:num div d;
    bound:prd bits#2;
    bounds:(0;bound-1);
    if[not num2 within bounds; 'caller,": constant doesn't fit into ",string[bits]," bits"];
    num2};

.arm64.asmHandlers:(`$())!();

.arm64.asmHandlersBranch:{[op;labelMap;addr;args]
    if[not 1=count args; '"B: need exactly 1 arg"];
    dest:.arm64.getLabelDest[labelMap;first args];
    if[not 0=dest mod 4; '"B: target not divisible by 4"];
    offset:.arm64.getSignedImmediate["B";dest-addr;26;2];
    //000101 imm26
    4#.x86util.i2le (2147483648*op)+335544320i+offset};

.arm64.asmHandlersTestBranch:{[caller;op;labelMap;addr;args]
    if[3<>count args; 'caller,": need exactly 3 args"];
    if["#"<>first args 1; 'caller,": arg 2 must be an immediate"];
    rt:.arm64.parseScalarReg[args 0;0b];
    dest:.arm64.getLabelDest[labelMap;args 2];
    imm:.arm64.getUnsignedImmediate[caller;.arm64.getNumber[1_args 1];6;0];
    immhi:imm div 32;
    if[immhi<>first rt; 'caller,": register size mismatch with bit index"];
    immlo:imm mod 32;
    offset:.arm64.getSignedImmediate[caller;dest-addr;14;2];
    //immhi 011011 op immlo offset rt
    4#.x86util.i2le sum 1 2147483648 16777216 524288 32 1*(905969664;immhi;op;immlo;offset;rt[1])};

.arm64.asmHandlersAddRelative:{[caller;op;labelMap;addr;args]
    if[2<>count args; 'caller,": need exactly 2 args"];
    rd:.arm64.parseScalarReg[args 0;0b];
    if[1<>first rd; 'caller,": register must be 64-bit"];
    dest:.arm64.getLabelDest[labelMap;args 1];
    imm:.arm64.getSignedImmediate[caller;dest-$[op;4096 xbar addr;addr];21;op*12];
    immlo:imm mod 4;
    immhi:imm div 4;
    //op immlo 10000 immhi rd
    4#.x86util.i2le sum 1 2147483648 536870912 32 1*(268435456;op;immlo;immhi;rd[1])};

.arm64.asmHandlersAddSubNormal:{[caller;op;setFlags;labelMap;addr;args]
    if[3>count args; 'caller,": need at least 3 args"];
    if[4<count args; 'caller,": need at most 4 args"];
    mode:1;
    extend:0b;
    if[first[args 2]="#";
        mode:2;
    ];
    if[mode=1;  //register
        rd:.arm64.parseScalarReg[args 0;0b];
        rn:.arm64.parseScalarReg[args 1;0b];
        rm:.arm64.parseScalarReg[args 2;0b];
        if[rd[0]<>rn[0]; 'caller,": register size mismatch"];
        size:rd 0;
        shift:0;
        option:0;
        imm:0;
        if[3<count args;
            extend:1b;
            option:2+size;
            opt:" "vs args 3;
            if[2<count opt; 'caller,": invalid extend option format"];
            extend:1b;
            extendOptions:("UXTB";"UXTH";"UXTW";"UXTX";"SXTB";"SXTH";"SXTW";"SXTX");
            option:extendOptions?opt 0;
            if[option=count extendOptions;
                shiftOptions:("LSL";"LSR";"ASR");
                option:shiftOptions?opt 0;
                if[option=count shiftOptions; 'caller,": unknown extend or shift option: ",opt 0];
                extend:0b;
                shift:option;
                option:0;
            ];
            if[1<count opt;
                if[not "#"=first opt 1; 'caller,": extend parameter must be an immediate"];
                imm:.arm64.getUnsignedImmediate[caller;.arm64.getNumber 1_opt 1;3;0];
                if[imm>4; 'caller,": extend parameter must be up to 4"];
            ];
        ];
        $[extend;
            $[size=0;
                if[0<>rm[0]; 'caller,": source register must be 32-bit"];
                [
                    srcsize:3=option mod 4;
                    if[srcsize<>rm[0]; 'caller,": incorrect source register size for extend option"];
                ]
            ];
            if[rd[0]<>rm[0]; 'caller,": register size mismatch"]
        ];
        //ADD:  sf 0 0 01011 shift extend Rm imm6 Rn Rd
        //SUB:  sf 1 0 01011 shift extend Rm imm6 Rn Rd
        //SUBS: sf 1 1 01011 shift extend Rm imm6 Rn Rd
        :4#.x86util.i2le sum 1 2147483648 1073741824 536870912 4194304 2097152 65536 8192 1024 32 1*
            (184549376;size;op;setFlags;shift;extend;rm[1];option;imm;rn[1];rd[1]);
    ];
    if[mode=2;  //immediate
        rd:.arm64.parseScalarReg[args 0;not setFlags];
        rn:.arm64.parseScalarReg[args 1;1b];
        if[rd[0]<>rn[0]; 'caller,": register size mismatch"];
        shift:0;
        size:rd 0;
        imm:.arm64.getUnsignedImmediate[caller;.arm64.getNumber 1_args 2;12;0];
        //sf 1 0 100010 sh imm rn rd
        :4#.x86util.i2le sum 1 2147483648 1073741824 536870912 4194304 1024 32 1*(285212672;size;op;setFlags;shift;imm;rn[1];rd[1]);
    ];
    '"unknown add/sub";
    };

.arm64.asmHandlersMultiplyAndAddSub:{[caller;op;labelMap;addr;args]
    if[4<>count args; 'caller,": need exactly 4 args"];
    rd:.arm64.parseScalarReg[args 0;0b];
    rn:.arm64.parseScalarReg[args 1;0b];
    rm:.arm64.parseScalarReg[args 2;0b];
    ra:.arm64.parseScalarReg[args 3;0b];
    if[rd[0]<>rn[0]; 'caller,": register size mismatch"];
    if[rd[0]<>rm[0]; 'caller,": register size mismatch"];
    if[rd[0]<>ra[0]; 'caller,": register size mismatch"];
    size:rd 0;
    //sf 0 0 11011000 rm op ra rn rd
    4#.x86util.i2le sum 1 2147483648 65536 32768 1024 32 1*(452984832;size;rm[1];op;ra[1];rn[1];rd[1])};

.arm64.asmHandlersMultiplyAndAddSubLong:{[caller;unsigned;op;labelMap;addr;args]
    if[4<>count args; 'caller,": need exactly 4 args"];
    rd:.arm64.parseScalarReg[args 0;0b];
    rn:.arm64.parseScalarReg[args 1;0b];
    rm:.arm64.parseScalarReg[args 2;0b];
    ra:.arm64.parseScalarReg[args 3;0b];
    if[1<>rd[0]; 'caller,": arg 1 must be 64-bit"];
    if[0<>rn[0]; 'caller,": arg 2 must be 32-bit"];
    if[0<>rm[0]; 'caller,": arg 3 must be 32-bit"];
    if[1<>ra[0]; 'caller,": arg 4 must be 64-bit"];
    //1 00 11011 unsigned 01 rm op ra rn rd
    4#.x86util.i2le sum 1 8388608 65536 32768 1024 32 1*(2602565632;unsigned;rm[1];op;ra[1];rn[1];rd[1])};

.arm64.asmHandlersMultiplyHigh:{[caller;unsigned;labelMap;addr;args]
    if[3<>count args; 'caller,": need exactly 3 args"];
    rd:.arm64.parseScalarReg[args 0;0b];
    rn:.arm64.parseScalarReg[args 1;0b];
    rm:.arm64.parseScalarReg[args 2;0b];
    if[1<>rd[0]; 'caller,": arg 1 must be 64-bit"];
    if[1<>rn[0]; 'caller,": arg 2 must be 64-bit"];
    if[1<>rm[0]; 'caller,": arg 3 must be 64-bit"];
    //1 00 11011 unsigned 10 rm 0 11111 rn rd
    4#.x86util.i2le sum 1 8388608 65536 32 1*(2604694528;unsigned;rm[1];rn[1];rd[1])};

.arm64.asmHandlersDivide:{[caller;op;labelMap;addr;args]
    if[3<>count args; 'caller,": need exactly 3 args"];
    rd:.arm64.parseScalarReg[args 0;0b];
    rn:.arm64.parseScalarReg[args 1;0b];
    rm:.arm64.parseScalarReg[args 2;0b];
    if[rd[0]<>rn[0]; 'caller,": register size mismatch"];
    if[rd[0]<>rm[0]; 'caller,": register size mismatch"];
    size:rd 0;
    //sf 0 0 11010110 rm 00001 op rn rm
    4#.x86util.i2le sum 1 2147483648 65536 1024 32 1*(448792576;size;rm[1];op;rn[1];rd[1])};

.arm64.asmHandlersBitmask:{[caller;op;negate;labelMap;addr;args]
    if[3>count args; 'caller,": need at least 3 args"];
    if[4<count args; 'caller,": need at most 4 args"];
    rd:.arm64.parseScalarReg[args 0;1b];
    rn:.arm64.parseScalarReg[args 1;0b];
    if[rd[0]<>rn[0]; 'caller,": register size mismatch"];
    size:rd[0];
    if["#"=first args 2;
        rej:();
        num:1_args 2;
        if["/" in num;
            nump:"/"vs num;
            num:nump 0;
            rej:"B"$/:nump 1;
        ];
        mask:.arm64.encodeBitMasks[size;.arm64.getNumber num;rej];
        //sf op 100100 n immr imms rn rd
        :4#.x86util.i2le sum 1 2147483648 536870912 4194304 65536 1024 32 1*(301989888;size;op;mask 0;mask 2;mask 1;rn[1];rd[1]);
    ];
    rm:.arm64.parseScalarReg[args 2;0b];
    if[rd[0]<>rm[0]; 'caller,": register size mismatch"];
    shift:0;
    imm:0;
    if[4=count args;
        shopt:" "vs args 3;
        if[2<count shopt; 'caller,": invalid shift option format"];
        shift:("LSL";"LSR";"ASR";"ROR")?shopt 0;
        if[shift>=4; 'caller,": unknown shift option: ",shopt 0];
        if[1<count shopt;
            if[not "#"=first shopt 1; 'caller,": shift option parameter must be immediate"];
            imm:.arm64.getUnsignedImmediate[caller;.arm64.getNumber[1_shopt 1];5+size;0];
        ];
    ];
    //sf opc 01010 shift negate n=0 rm imm rn rd
    4#.x86util.i2le sum 1 2147483648 536870912 4194304 2097152 65536 1024 32 1*(167772160;size;op;shift;negate;rm 1;imm;rn 1;rd 1)};

.arm64.asmHandlersConditionalCompare:{[caller;op;labelMap;addr;args]
    if[4<>count args; 'caller,": need exactly 4 args"];
    cond2:.arm64.conds?`$args 3;
    if[cond2=count .arm64.conds; 'caller,": unknown condition code ",args 3];
    if[not "#"=first args 2; 'caller,": arg 3 must be immediate"];
    rn:.arm64.parseScalarReg[args 0;0b];
    size:first rn;
    nzcv:.arm64.getUnsignedImmediate[caller;.arm64.getNumber 1_args 2;4;0];
    isImm:"#"=first args 1;
    imm:$[isImm;
        .arm64.getUnsignedImmediate[caller;.arm64.getNumber 1_args 1;5;0];
        [
            rm:.arm64.parseScalarReg[args 1;0b];
            if[size<>first rm; 'caller,": register size mismatch"];
            rm 1
        ]
    ];
    //sf op 1 11010010 imm cond 1 0 rn nzcv
    4#.x86util.i2le sum 1 2147483648 1073741824 65536 4096 2048 32 1*(977272832;size;op;imm;cond2;isImm;rn[1];nzcv)};

.arm64.asmHandlersConditionalSelect:{[caller;op;o2;labelMap;addr;args]
    if[4<>count args; 'caller,": need exactly 4 args"];
    cond2:.arm64.conds?`$args 3;
    if[cond2=count .arm64.conds; 'caller,": unknown condition code ",args 3];
    rd:.arm64.parseScalarReg[args 0;0b];
    rn:.arm64.parseScalarReg[args 1;0b];
    rm:.arm64.parseScalarReg[args 2;0b];
    if[first[rd]<>first[rn]; 'caller,": register size mismatch"];
    size:first rd;
    //sf op 0 11010100 rm cond 0 o2 rn rd
    4#.x86util.i2le sum 1 2147483648 1073741824 65536 4096 1024 32 1*(444596224;size;op;rm[1];cond2;o2;rn[1];rd[1])};

.arm64.asmMemoryArgs:{[caller;labelMap;addr;args;unsignedImmScale]
    if[2>count args; 'caller,": need at least 2 args"];
    if[4<count args; 'caller,": need at most 4 args"];
    rt:.arm64.parseScalarReg[args 0;0b];
    size:rt[0];
    if[not "["=first args[1];
        dest:.arm64.getLabelDest[labelMap;args 1];
        offset:.arm64.getSignedImmediate[caller;dest-addr;19;2];
        :(`literal;size;offset;rt[1]);
    ];
    isImmediate:0b;
    if[2=count args;
        isImmediate:1b;
        mode:1;
        if["]"<>last args[1]; 'caller,": with 2 args, arg 2 must end with ]"];
        rn:.arm64.parseScalarReg[1_-1_args 1;1b];
        imm:0;
    ];
    if[$[3<=count args;"#"=first args[2];0b];
        isImmediate:1b;
        if["]"=last args[1];    //Post-index
            rn:.arm64.parseScalarReg[1_-1_args 1;1b];
            imm:1+4*.arm64.getSignedImmediate[caller;.arm64.getNumber[1_args 2];9;0];
            mode:0;
        ];
        if["]!"~-2#args[2];    //Pre-index
            rn:.arm64.parseScalarReg[1_args 1;1b];
            imm:3+4*.arm64.getSignedImmediate[caller;.arm64.getNumber[1_-2_args 2];9;0];
            mode:0;
        ];
        if[last[args 2]="]";    //Unsigned offset
            rn:.arm64.parseScalarReg[1_args 1;1b];
            imm:.arm64.getUnsignedImmediate[caller;.arm64.getNumber[1_-1_args 2];12;unsignedImmScale];
            mode:1;
        ];
    ];
    if[isImmediate; :(`immediate;size;mode;imm;rn[1];rt[1])];
    isRegister:0b;
    //register
    rn:.arm64.parseScalarReg[1_args 1;1b];
    if[not 1=rn 0; 'caller,": arg 2 must be a 64-bit register"];
    if[3=count args;
        isRegister:1b;
        if[not last[args 2]="]"; 'caller,": with 3 args, arg 3 must end with ]"];
        rm:.arm64.parseScalarReg[-1_args 2;0b];
        option:3;
        shift:0;
    ];
    if[4=count args;
        isRegister:1b;
        if[not last[args 3]="]"; 'caller,": with 4 args, arg 4 must end with ]"];
        rm:.arm64.parseScalarReg[args 2;0b];
        shift:0;
        opt:" "vs -1_args 3;
        if[2<count opt; 'caller,": invalid extend specifier"];
        option:(("UXTW";"LSL";"SXTW";"SXTX")!2 3 6 7)opt 0;
        if[null option; 'caller,": invalid extend option: ",opt 0];
        if[1<count opt;
            if[not "#"=first opt 1; 'caller,": extend parameter must be immediate"];
            amount:.arm64.getNumber 1_opt 1;
            shift:$[0=size;0 2!0 1;0 3!0 1][amount];
            if[null shift; 'caller,": incorrect shift amount"];
        ];
    ];
    if[isRegister; :(`register;size;rm[1];option;shift;rn[1];rt[1])];
    '"unknown memory-related args"};

.arm64.asmHandlersLoadStoreBasic:{[caller;op;op2;labelMap;addr;args]
    if[1>count args; 'caller,": need at least 1 arg"];
    if[args[0;0] in "BHSDQ"; :.arm64.asmHandlersLoadStoreSimd[caller;op;labelMap;addr;args]];
    rt:.arm64.parseScalarReg[args 0;0b];
    size:rt[0];
    ret:.arm64.asmMemoryArgs[caller;labelMap;addr;args;2+size];
    variant:ret 0;
    if[variant=`immediate;
        //(1 size) 111 0 (0 mode) (0 op) imm rn rt
        :4#.x86util.i2le sum 1 1073741824 16777216 4194304 1024 32 1*(3087007744;ret 1;ret 2;op;ret 3;ret 4;ret 5);
    ];
    if[variant=`register;
        //(1 size) 111 0 00 (0 op) 1 rm option size 10 rn rt
        :4#.x86util.i2le sum 1 1073741824 4194304 65536 8192 4096 32 1*(3089106944;ret 1;op;ret 2;ret 3;ret 4;ret 5;ret 6);
    ];
    if[variant=`literal;
        if[not op; 'caller,": literal mode only supported for LDR"];
        //LDR:   (0 size) 011 0 00 imm rt
        //LDRSW: 10       011 0 00 imm rt
        if[op2;if[1<>ret 1; '": register must be 64-bit"]; ret[1]:0];
        :4#.x86util.i2le sum 1 2147483648 1073741824 32 1*(402653184;op2;ret 1;ret 2;ret 3);
    ];
    '"unknown LDR/STR";
    };

.arm64.asmHandlersLoadStoreSimd:{[caller;op;labelMap;addr;args]
    if[2<>count args; 'caller," (SIMD): need exactly 2 args"];
    if["#"<>first args 1; 'caller," (SIMD): arg 2 must be immediate"];
    rt:.arm64.parseSimdReg[args 0];
    size:rt[0]-2;
    dest:.arm64.getLabelDest[labelMap;args 1];
    imm:.arm64.getSignedImmediate[caller;dest-addr;19;2];
    if[0=op; 'caller," (SIMD): only supported for LDR"];
    //size 011 1 00 imm rt
    4#.x86util.i2le sum 1 1073741824 32 1*(469762048;size;imm;rt 1)};

.arm64.asmHandlersLoadStoreByte:{[caller;size;op;labelMap;addr;args]
    ret:.arm64.asmMemoryArgs[caller;labelMap;addr;args;size];
    variant:ret 0;
    if[variant=`immediate;
        //LDRB, LDRH:   (0 bh) 111 0 (0 size) (0 op) imm rn rt
        :4#.x86util.i2le sum 1 1073741824 16777216 4194304 1024 32 1*(939524096;size;ret 2;op;ret 3;ret 4;ret 5);
    ];
    if[variant=`register;
        //(0 size) 111 0 00 (0 op) 1 rm option size 10 rn rt
        :4#.x86util.i2le sum 1 1073741824 4194304 65536 8192 4096 32 1*(941623296;size;op;ret 2;ret 3;ret 4;ret 5;ret 6);
    ];
    '"unknown Load/Store Byte";
    };

.arm64.asmHandlersLoadStoreUnscaled:{[caller;op;short;labelMap;addr;args]
    if[2>count args; 'caller,": need at least 2 args"];
    if[3<count args; 'caller,": need at most 3 args"];
    rt:.arm64.parseScalarReg[args 0;0b];
    size:first rt;
    if[short>-1; if[size<>0; 'caller,": arg 1 must be 32-bit"]];
    if["["<>first args 1; 'caller,": arg 2 must start with ["];
    rn:.arm64.parseScalarReg[1_args 1;1b];
    if[1<>first rn; 'caller,": index register must be 64-bit"];
    imm:0;
    if[2<count args;
        if["#"<>first args 2; 'caller,": offset must be immediate"];
        if["]"<>last args 2; 'caller,": offset must end with ]"];
        imm:.arm64.getSignedImmediate[caller;.arm64.getNumber[1_-1_args 2];9;0];
    ];
    fullsize:$[short>-1; short; 2+size];
    //size 111 0 00 (0 op) 0 imm 00 rn rt
    4#.x86util.i2le sum 1 1073741824 4194304 4096 32 1*(939524096;fullsize;op;imm;rn 1;rt 1)};

.arm64.asmHandlersLoadStorePair:{[caller;ld;sw;nonTemporal;labelMap;addr;args]
    if[3>count args; 'caller,": need at least 3 args"];
    if[4<count args; 'caller,": need at most 4 args"];
    isSimd:first[args 0] in "SDQ";
    mode:0;
    if[not "["=first args[2]; 'caller,": arg 3 must start with ["];
    if[3=count args;
        if[not "]"=last args[2]; 'caller,": with 3 args, arg 3 must end with ]"];
        mode:2;
        imm:0;
        rn:.arm64.parseScalarReg[1_-1_args 2;1b];
    ];
    if[4=count args;
        if["]"=last args[3];
            mode:2;
            imm:.arm64.getNumber 1_-1_args 3;
            rn:.arm64.parseScalarReg[1_args 2;1b];
        ];
        if["]!"~-2#args[3];
            mode:3;
            imm:.arm64.getNumber 1_-2_args 3;
            rn:.arm64.parseScalarReg[1_args 2;1b];
        ];
        if["]"=last args[2];
            mode:1;
            imm:.arm64.getNumber 1_args 3;
            rn:.arm64.parseScalarReg[1_-1_args 2;1b];
        ];
    ];
    if[0=mode; 'caller,": unknown arg combination"];
    if[1<>rn 0; 'caller,": index register must be 64-bit"];
    $[isSimd;[
        rt:.arm64.parseSimdReg[args 0];
        rt2:.arm64.parseSimdReg[args 1];
        size:first[rt]-2;
    ];[
        rt:.arm64.parseScalarReg[args 0;0b];
        rt2:.arm64.parseScalarReg[args 1;0b];
        size:first rt;
    ]];
    if[first[rt]<>first[rt2]; 'caller,": register size mismatch"];
    imm7:.arm64.getSignedImmediate[caller;imm;7;2+$[sw<0;size;0]];
    if[not isSimd; size*:2];
    if[nonTemporal and mode<>2; 'caller,": non-temporal mode needs args similar to signed offset mode"];
    if[sw>0;
        if[isSimd; 'caller,": SIMD and SW not allowed at the same time"];
        size:sw;
    ];
    //size 101 isSimd mode ld imm7 rt2 rn rt
    4#.x86util.i2le sum 1 1073741824 67108864 8388608 4194304 32768 1024 32 1*
        (671088640;size;isSimd;$[nonTemporal;0;mode];ld;imm7;rt2 1;rn 1;rt 1)};

.arm64.asmHandlersAddSubWide:{[caller;high;unsigned;op;labelMap;addr;args]
    if[3<>count args; 'caller,": need exactly 3 args"];
    rd:.arm64.parseVectorReg[args 0];
    rn:.arm64.parseVectorReg[args 1];
    rm:.arm64.parseVectorReg[args 2];
    if[rd[0]=0; 'caller,": arg 1 incompatible size"];
    if[rd[1]=0; 'caller,": arg 1 incompatible arrangement"];
    $[0=op mod 2;
        if[rd[1]<>rn[1]; 'caller,": arg 1 and 2 arrangement mismatch"];
        if[rn[1]<>rm[1]; 'caller,": arg 2 and 3 arrangement mismatch"]];
    if[rm[0]<>high; 'caller,": arg 3 arrangement doesn't match '2' flag"];
    if[rm[1]=3; 'caller,": arg 3 incompatible arrangement"];
    size:rd[1]-1;
    if[size<>rm[1]; 'caller,": arg 1 and 3 size mismatch"];
    //0 high unsigned 01110 size 1 rm 00 op 1 00 rn rd
    //USUBL, USUBL2: 0 high unsigned 01110 size 1 rm 00  1 0 00 rn rd
    4#.x86util.i2le sum 1 1073741824 536870912 4194304 65536 4096 32 1*(236982272;high;unsigned;size;rm 2;op;rn 2;rd 2)};

.arm64.asmHandlersSatDblMultAddSubLong:{[caller;op;high;labelMap;addr;args]
    if[3<>count args; 'caller,": need exactly 3 args"];
    rd:.arm64.parseSimdReg[args 0];
    if[not rd[0] within 2 3; 'caller,": unsupported register size for arg 1"];
    size:rd[0]-1;
    rn:.arm64.parseSimdReg[args 1];
    if[rn[0]<>size; 'caller,": register size mismatch between args 1 and 2"];

    rm:.arm64.parseIndexedVectorReg[args 2];
    if[not rm[1] within 0,$[size=1;7;3]; 'caller,": index out of range"];

    m:$[size=1; rm[1] mod 2; 0];
    l:$[size=1; (rm[1] div 2)mod 2; rm[1] mod 2];
    h:$[size=1; rm[1] div 4; rm[1] div 2];

    //0 high 0 11111 size L M rm 0 op 11 H 0 rn rd
    4#.x86util.i2le sum 1 1073741824 4194304 2097152 1048576 65536 16384 2048 32 1*(520105984;high;size;l;m;rm[2] mod 16;op;h;rn 1;rd 1)};

.arm64.asmHandlersMOVZ:{[caller;op;labelMap;addr;args]
    if[2>count args; 'caller,": need at least 2 args"];
    if[3<count args; 'caller,": need at most 3 args"];
    if[not args[1] like "#*"; caller,": arg 2 must be an immediate"];
    rd:.arm64.parseScalarReg[args 0;0b];
    size:rd[0];
    hw:0;
    if[3=count args;
        if[not args[2] like "LSL #*"; 'caller,": 3rd arg must be in the form LSL #x"];
        shift:.arm64.getNumber 5_args 2;
        hw:.arm64.getUnsignedImmediate[caller;shift;1+size;4];
    ];
    imm:.arm64.getUnsignedImmediate[caller;.arm64.getNumber 1_args 1;16;0];
    //sf 1 op 100101 hw imm rd
    4#.x86util.i2le sum 1 2147483648 536870912 2097152 32 1*(1384120320;size;op;hw;imm;rd[1])};

.arm64.asmHandlersSystemCall:{[caller;op;labelMap;addr;args];
    if[1<>count args; 'caller,": need exactly 1 arg"];
    if["#"<>first args 0; 'caller,": arg must be immediate"];
    imm:.arm64.getUnsignedImmediate[caller;.arm64.getNumber 1_args 0;16;0];
    //11010100 000 imm 000 op
    4#.x86util.i2le sum 1 32 1*(3556769792;imm;op)};

.arm64.asmHandlersCountLeading:{[caller;op;labelMap;addr;args]
    if[2<>count args; 'caller,": need exactly 2 args"];
    rd:.arm64.parseScalarReg[args 0;0b];
    rn:.arm64.parseScalarReg[args 1;0b];
    if[rd[0]<>rn[0]; 'caller,": register size mismatch"];
    size:rd[0];
    //size 1 0 11010110 00000 000010 op rn rd
    4#.x86util.i2le sum 1 2147483648 1024 32 1*(1522536448;size;op;rn[1];rd[1])};

.arm64.asmHandlersShiftVariable:{[caller;op;labelMap;addr;args]
    if[3<>count args; 'caller,": need exactly 3 args"];
    rd:.arm64.parseScalarReg[args 0;0b];
    rn:.arm64.parseScalarReg[args 1;0b];
    rm:.arm64.parseScalarReg[args 2;0b];
    if[rd[0]<>rn[0]; 'caller,": register size mismatch"];
    if[rd[0]<>rm[0]; 'caller,": register size mismatch"];
    size:rd 0;
    //sf 0 0 11010110 rm 0010 op rn rd
    4#.x86util.i2le sum 1 2147483648 65536 1024 32 1*(448798720;size;rm[1];op;rn[1];rd[1])};

.arm64.asmHandlersBitfieldMove:{[caller;op;labelMap;addr;args]
    if[not 4=count args; 'caller,": need exactly 4 args"];
    if[not "#"=first args 2; 'caller,": arg 3 must be immediate"];
    if[not "#"=first args 3; 'caller,": arg 4 must be immediate"];
    rd:.arm64.parseScalarReg[args 0;0b];
    rn:.arm64.parseScalarReg[args 1;0b];
    if[rd[0]<>rn[0]; 'caller,": register size mismatch"];
    size:rd 0;
    immr:.arm64.getUnsignedImmediate[caller;.arm64.getNumber 1_args 2;5+size;0];
    imms:.arm64.getUnsignedImmediate[caller;.arm64.getNumber 1_args 3;5+size;0];
    //sf op (100110) n immr imms rn rd
    4#.x86util.i2le sum 1 2147483648 536870912 4194304 65536 1024 32 1*(318767104;size;op;size;immr;imms;rn[1];rd[1])};

.arm64.asmHandlersRegShiftLeft:{[caller;unsigned;op;labelMap;addr;args]
    if[3<>count args; 'caller,": need exactly 3 args"];
    if["V"<>first args 0; 'caller,": scalar version NYI"];
    rd:.arm64.parseVectorReg args 0;
    rn:.arm64.parseVectorReg args 1;
    rm:.arm64.parseVectorReg args 2;
    if[rd[0]<>rn[0]; 'caller,": register size mismatch"];
    if[rd[0]<>rm[0]; 'caller,": register size mismatch"];
    if[rd[1]<>rn[1]; 'caller,": register size mismatch"];
    if[rd[1]<>rm[1]; 'caller,": register size mismatch"];
    if[(rd[0]=0) and (rd[1]=3); 'caller,": incompatible arrangement"];
    s:0b;
    //SQRSHL, UQRSHL: 0 Q u S 1110 size 1 rm 010 r=1 s=1 1 rn rd
    //SSHL, USHL:     0 Q u S 1110 size 1 rm 010   0   0 1 rn rd
    //SQSHL, UQSHl:   0 Q u S 1110 size 1 rm 010   0   1 1 rn rd
    4#.x86util.i2le sum 1 1073741824 536870912 268435456 4194304 65536 2048 32 1*(236995584;rd[0];unsigned;s;rd[1];rm[2];op;rn[2];rd[2])};

.arm64.asmHandlersShiftLeft:{[caller;unsigned;op;labelMap;addr;args]
    if[3<>count args; 'caller,": need exactly 3 args"];
    if["#"<>first args 2;
        opMap:(`s#enlist[7])!enlist 1;
        if[not op in key opMap; 'caller,": register version NYI"];
        :.arm64.asmHandlersRegShiftLeft[caller;unsigned;opMap op;labelMap;addr;args];
    ];
    scalar:"V"<>first args 0;
    $[scalar;[
        rds:.arm64.parseSimdReg args 0;
        rns:.arm64.parseSimdReg args 1;
        if[rds[0]<>rns[0]; 'caller,": register size mismatch"];
        q:1;
        size:rds 0;
        rd:rds 1;
        rn:rns 1;
    ];[
        rdv:.arm64.parseVectorReg args 0;
        rnv:.arm64.parseVectorReg args 1;
        if[rdv[0]<>rnv[0]; 'caller,": register size mismatch"];
        if[rdv[1]<>rnv[1]; 'caller,": register size mismatch"];
        if[(rdv[0]=0) and rdv[1]=3; 'caller,": incompatible arrangement"];
        q:rdv 0;
        size:rdv 1;
        rd:rdv 2;
        rn:rnv 2;
    ]];
    if[size=4; 'caller,": unsupported register size"];
    imm:.arm64.getUnsignedImmediate[caller;.arm64.getNumber 1_args 2;3+size;0];
    $[op=3;[
        imm2:128-imm;
        immh:imm2 div 8;
        immb:imm2 mod 8;
    ];[
        immh:(imm div 8)+1 2 4 8 size;
        immb:imm mod 8;
    ]];
    //Q always 1 for scalar
    //S=1 for scalar, 0 for vector
    //SQSHL, UQSHL:   0 Q u S 11110 immh immb 011101 rn rd
    //SQSHLU:         0 Q u S 11110 immh immb 011001 rn rd
    //SRSRA:          0 Q u S 11110 immh immb 001101 rn rd  imm subtracted
    //SHL, SLI:       0 Q u S 11110 immh immb 010101 rn rd
    //SSHLL, USHLL:   0 Q u S 11110 immh immb 101001 rn rd
    4#.x86util.i2le sum 1 1073741824 536870912 268435456 524288 65536 4096 32 1*(251659264;q;unsigned;scalar;immh;immb;op;rn;rd)};

.arm64.asmHandlers[`ADD]:{[labelMap;addr;args].arm64.asmHandlersAddSubNormal["ADD";0b;0b;labelMap;addr;args]};

.arm64.asmHandlers[`ADR]:{[labelMap;addr;args].arm64.asmHandlersAddRelative["ADR";0b;labelMap;addr;args]};
.arm64.asmHandlers[`ADRP]:{[labelMap;addr;args].arm64.asmHandlersAddRelative["ADRP";1b;labelMap;addr;args]};
.arm64.asmHandlers[`AND]:{[labelMap;addr;args].arm64.asmHandlersBitmask["AND";0;0b;labelMap;addr;args]};
.arm64.asmHandlers[`ANDS]:{[labelMap;addr;args].arm64.asmHandlersBitmask["ANDS";3;0b;labelMap;addr;args]};
.arm64.asmHandlers[`ASRV]:{[labelMap;addr;args].arm64.asmHandlersShiftVariable["LSLV";2;labelMap;addr;args]};

.arm64.asmHandlers[`B]:{[labelMap;addr;args].arm64.asmHandlersBranch[0b;labelMap;addr;args]};

.arm64.asmHandlers[`B.cond]:{[labelMap;addr;args]
    if[2<>count args; '"B.cond: need exactly 2 args"];
    cond:"."vs args 0;
    if[2<>count cond; '"invalid syntax for B.cond: ",args 0];
    cond2:.arm64.conds?`$cond 1;
    if[cond2=count .arm64.conds; '"B.cond: unknown condition code ",cond 1];
    dest:.arm64.getLabelDest[labelMap;args 1];
    if[not 0=dest mod 4; '"B.cond: target not divisible by 4"];
    offset:.arm64.getSignedImmediate["B.cond";dest-addr;19;2];
    //01010100 imm19 0 cond
    4#.x86util.i2le sum 1 32 1*(1409286144i;offset;cond2)};

.arm64.asmHandlers[`BFI]:{[labelMap;addr;args]
    if[4<>count args; '"BFI: need exactly 4 args"];
    if[not "#"=first args 2; '"BFI: arg 3 must be immediate"];
    if[not "#"=first args 3; '"BFI: arg 4 must be immediate"];
    lsb:.arm64.getNumber 1_args 2;
    width:.arm64.getNumber 1_args 3;
    size:args[0;0]<>"W";
    limit:$[size;64;32];
    .arm64.asmHandlers[`BFM][labelMap;addr;(2#args),("#",string neg[lsb]mod limit;"#",string width-1)]};

.arm64.asmHandlers[`BFM]:{[labelMap;addr;args].arm64.asmHandlersBitfieldMove["BFM";1;labelMap;addr;args]};

.arm64.asmHandlersBR:{[caller;op;labelMap;addr;args]
    if[1<>count args; 'caller,": need exactly 1 arg"];
    rn:.arm64.parseScalarReg[args 0;0b];
    if[1<>rn 0; '"BR: register must be 64-bit"];
    //1101011 0 0 0 op 11111 0000 0 0 rn 00000
    4#.x86util.i2le sum 1 2097152 32*(3592355840;op;rn[1])};

.arm64.asmHandlers[`BIC]:{[labelMap;addr;args].arm64.asmHandlersBitmask["BIC";0;1b;labelMap;addr;args]};
.arm64.asmHandlers[`BICS]:{[labelMap;addr;args].arm64.asmHandlersBitmask["BICS";3;1b;labelMap;addr;args]};
.arm64.asmHandlers[`BL]:{[labelMap;addr;args].arm64.asmHandlersBranch[1b;labelMap;addr;args]};
.arm64.asmHandlers[`BLR]:{[labelMap;addr;args].arm64.asmHandlersBR["BR";1b;labelMap;addr;args]};
.arm64.asmHandlers[`BR]:{[labelMap;addr;args].arm64.asmHandlersBR["BR";0b;labelMap;addr;args]};

.arm64.asmHandlersCBZ:{[caller;op;labelMap;addr;args]
    if[2<>count args; 'caller,": need exactly 2 args"];
    rt:.arm64.parseScalarReg[args 0;0b];
    size:rt 0;
    dest:.arm64.getLabelDest[labelMap;args 1];
    imm:.arm64.getSignedImmediate[caller;dest-addr;19;2];
    //sf 011010 op imm rt
    4#.x86util.i2le sum 1 2147483648 16777216 32 1*(872415232;size;op;imm;rt[1])};

.arm64.asmHandlers[`CBNZ]:{[labelMap;addr;args].arm64.asmHandlersCBZ["CBNZ";1b;labelMap;addr;args]};
.arm64.asmHandlers[`CBZ]:{[labelMap;addr;args].arm64.asmHandlersCBZ["CBZ";0b;labelMap;addr;args]};
.arm64.asmHandlers[`CCMN]:{[labelMap;addr;args].arm64.asmHandlersConditionalCompare["CCMN";0b;labelMap;addr;args]};
.arm64.asmHandlers[`CCMP]:{[labelMap;addr;args].arm64.asmHandlersConditionalCompare["CCMP";1b;labelMap;addr;args]};
.arm64.asmHandlers[`CLS]:{[labelMap;addr;args].arm64.asmHandlersCountLeading["CLS";1b;labelMap;addr;args]};
.arm64.asmHandlers[`CLZ]:{[labelMap;addr;args].arm64.asmHandlersCountLeading["CLZ";0b;labelMap;addr;args]};

.arm64.asmHandlers[`CMP]:{[labelMap;addr;args]
    if[0=count args; '"CMP: need at least 1 arg"];
    reg:$[args[0;0]="W";"WZR";"XZR"];
    .arm64.asmHandlers[`SUBS][labelMap;addr;enlist[reg],args]};

.arm64.asmHandlers[`CSEL]:{[labelMap;addr;args].arm64.asmHandlersConditionalSelect["CSEL";0b;0b;labelMap;addr;args]};

.arm64.asmHandlers[`CSET]:{[labelMap;addr;args]
    if[2<>count args; '"CSET: need exactly 2 args"];
    cond2:.arm64.conds?`$args 1;
    reg:$[args[0;0]="W";"WZR";"XZR"];
    if[cond2=count .arm64.conds; '"B.cond: unknown condition code ",args 1];
    .arm64.asmHandlers[`CSINC][labelMap;addr;(args 0;reg;reg;string .arm64.conds(2 xbar cond2)+1-cond2 mod 2)]};

.arm64.asmHandlers[`CSINC]:{[labelMap;addr;args].arm64.asmHandlersConditionalSelect["CSINC";0b;1b;labelMap;addr;args]};
.arm64.asmHandlers[`CSINV]:{[labelMap;addr;args].arm64.asmHandlersConditionalSelect["CSINV";1b;0b;labelMap;addr;args]};
.arm64.asmHandlers[`CSNEG]:{[labelMap;addr;args].arm64.asmHandlersConditionalSelect["CSNEG";1b;1b;labelMap;addr;args]};
.arm64.asmHandlers[`EON]:{[labelMap;addr;args].arm64.asmHandlersBitmask["EON";2;1b;labelMap;addr;args]};
.arm64.asmHandlers[`EOR]:{[labelMap;addr;args].arm64.asmHandlersBitmask["EOR";2;0b;labelMap;addr;args]};

.arm64.asmHandlers[`FCMLA]:{[labelMap;addr;args]
    if[4<>count args; '"FCMLA: need exactly 4 args"];
    if["#"<>first args[3]; '"FCMLA: arg 4 must be immediate"];
    rd:.arm64.parseVectorReg args 0;
    rn:.arm64.parseVectorReg args 1;
    rm:.arm64.parseIndexedVectorReg args 2;
    imm:.arm64.getNumber 1_args 3;
    if[not imm in 0 90 180 270; '"FCMLA: immediate must be one of 0 90 180 270"];
    rot:imm div 90;
    size:rm[0]+1;
    q:rd 1;
    h:$[1=size;rm[1] div 2;index];
    m:rm[2] div 16;
    l:$[1=size;rm[1] mod 2;0];
    if[h>=2; '"FCMLA: index out of range"];
    //0 Q 1 01111 size L M rm 0 rot 1 h 0 rn rd
    4#.x86util.i2le sum 1 1073741824 4194304 2097152 1048576 65536 8192 2048 32 1*(788533248;q;size;l;m;rm[2] mod 16;rot;h;rn[2];rd[2])};

.arm64.asmHandlers[`HVC]:{[labelMap;addr;args].arm64.asmHandlersSystemCall["HVC";2;labelMap;addr;args]};

.arm64.asmHandlers[`INVALID]:{[labelMap;addr;args]
    if[not 1=count args; '"INVALID: need exactly 1 arg"];
    arg:first args;
    if[not "#"=first arg; '"INVALID takes a literal"];
    .x86util.i2le .arm64.getNumber 1_arg};

.arm64.asmHandlers[`LDNP]:{[labelMap;addr;args].arm64.asmHandlersLoadStorePair["LDNP";1b;-1;1b;labelMap;addr;args]};
.arm64.asmHandlers[`LDP]:{[labelMap;addr;args].arm64.asmHandlersLoadStorePair["LDP";1b;-1;0b;labelMap;addr;args]};
.arm64.asmHandlers[`LDPSW]:{[labelMap;addr;args].arm64.asmHandlersLoadStorePair["LDP";1b;1;0b;labelMap;addr;args]};
.arm64.asmHandlers[`LDR]:{[labelMap;addr;args].arm64.asmHandlersLoadStoreBasic["LDR";1b;0b;labelMap;addr;args]};

.arm64.asmHandlers[`LDRB]:{[labelMap;addr;args].arm64.asmHandlersLoadStoreByte["LDRB";0b;1b;labelMap;addr;args]};
.arm64.asmHandlers[`LDRH]:{[labelMap;addr;args].arm64.asmHandlersLoadStoreByte["LDRH";1b;1b;labelMap;addr;args]};
.arm64.asmHandlers[`LDRSW]:{[labelMap;addr;args].arm64.asmHandlersLoadStoreBasic["LDRSW";1b;1b;labelMap;addr;args]};
.arm64.asmHandlers[`LDUR]:{[labelMap;addr;args].arm64.asmHandlersLoadStoreUnscaled["LDUR";1b;-1;labelMap;addr;args]};
.arm64.asmHandlers[`LDURB]:{[labelMap;addr;args].arm64.asmHandlersLoadStoreUnscaled["LDURB";1b;0;labelMap;addr;args]};
.arm64.asmHandlers[`LDURB]:{[labelMap;addr;args].arm64.asmHandlersLoadStoreUnscaled["LDURB";1b;1;labelMap;addr;args]};

.arm64.asmHandlers[`LSL]:{[labelMap;addr;args]
    if[3<>count args; '"LSL: need exactly 3 args"];
    if["#"=first args 2;    //immediate
        rd:.arm64.parseScalarReg[args 0;0b];
        limit:32 64 first rd;
        num:.arm64.getNumber 1_args 2;
        :.arm64.asmHandlers[`UBFM][labelMap;addr;(2#args),("#",string neg[num]mod limit;"#",string -1+limit-num)];
    ];
    //register
    .arm64.asmHandlers[`LSLV][labelMap;addr;args]};
.arm64.asmHandlers[`LSLV]:{[labelMap;addr;args].arm64.asmHandlersShiftVariable["LSLV";0;labelMap;addr;args]};

.arm64.asmHandlers[`LSR]:{[labelMap;addr;args]
    if[3<>count args; '"LSR: need exactly 3 args"];
    if["#"=first args 2;    //immediate
        rd:.arm64.parseScalarReg[args 0;0b];
        limit:32 64 first rd;
        num:.arm64.getNumber 1_args 2;
        :.arm64.asmHandlers[`UBFM][labelMap;addr;(2#args),("#",string[num];"#",string limit-1)];
    ];
    //register
    .arm64.asmHandlers[`LSRV][labelMap;addr;args]};
.arm64.asmHandlers[`LSRV]:{[labelMap;addr;args].arm64.asmHandlersShiftVariable["LSLV";1;labelMap;addr;args]};

.arm64.asmHandlers[`MADD]:{[labelMap;addr;args].arm64.asmHandlersMultiplyAndAddSub["MADD";0b;labelMap;addr;args]};

.arm64.asmHandlers[`MOV]:{[labelMap;addr;args]
    if[2<>count args; '"MOV: need exactly 2 args"];
    //MOV (register)
    rd:.arm64.parseScalarReg[args 0;0b];
    rm:.arm64.parseScalarReg[args 1;0b];
    if[rd[0]<>rm[0]; '"MOV: register size mismatch"];
    size:rd[0];
    //sf 0 0 100010 0 000000000000 rn rd    //this encoding gives ADD Rn, Rd, #
    //4#.x86util.i2le sum 2147483648 1 32 1*(size;285212672;rn[1];rd[1])
    //sf 01 01010 00 0 rm 000000 111111 rd
    4#.x86util.i2le sum 2147483648 1 65536 1*(size;704644064;rm[1];rd[1])};

.arm64.asmHandlers[`MOVK]:{[labelMap;addr;args].arm64.asmHandlersMOVZ["MOVK";1b;labelMap;addr;args]};
.arm64.asmHandlers[`MOVZ]:{[labelMap;addr;args].arm64.asmHandlersMOVZ["MOVZ";0b;labelMap;addr;args]};
.arm64.asmHandlers[`MSUB]:{[labelMap;addr;args].arm64.asmHandlersMultiplyAndAddSub["MSUB";1b;labelMap;addr;args]};

.arm64.asmHandlers[`MUL]:{[labelMap;addr;args]
    if[0=count args; '"MUL: need at least 1 arg"];
    reg:$[args[0;0]="W";"WZR";"XZR"];
    .arm64.asmHandlers[`MADD][labelMap;addr;args,enlist[reg]]};

.arm64.asmHandlers[`NEG]:{[labelMap;addr;args]
    if[2>count args; '"NEG: need at least 2 args"];
    reg:$[args[0;0]="W";"WZR";"XZR"];
    .arm64.asmHandlers[`SUB][labelMap;addr;(1#args),enlist[reg],1_args]};

.arm64.asmHandlers[`NOP]:{[labelMap;addr;args]0x1f2003d5};
.arm64.asmHandlers[`ORN]:{[labelMap;addr;args].arm64.asmHandlersBitmask["ORN";1;1b;labelMap;addr;args]};
.arm64.asmHandlers[`ORR]:{[labelMap;addr;args].arm64.asmHandlersBitmask["ORR";1;0b;labelMap;addr;args]};

.arm64.asmHandlers[`RBIT]:{[labelMap;addr;args]
    if[2<>count args; '"RBIT: need exactly 2 args"];
    rd:.arm64.parseScalarReg[args 0;0b];
    rn:.arm64.parseScalarReg[args 1;0b];
    if[rd[0]<>rn[0]; '"RBIT: register size mismatch"];
    size:rd[0];
    //size 1 0 11010110 00000 0000 00 rn rd
    4#.x86util.i2le sum 1 2147483648 32 1*(1522532352;size;rn[1];rd[1])};

.arm64.asmHandlers[`RET]:{[labelMap;addr;args]
    if[1<count args; '"RET: need at most 1 arg"];
    rn:1 30;
    if[1=count args;
        rn:.arm64.parseScalarReg[args 0;0b];
        if[1<>first rn; '"RET: register must be 64-bit"];
    ];
    4#.x86util.i2le sum 1 32*(3596550144;rn[1])};

.arm64.asmHandlers[`RORV]:{[labelMap;addr;args].arm64.asmHandlersShiftVariable["LSLV";3;labelMap;addr;args]};
.arm64.asmHandlers[`SADDW]:{[labelMap;addr;args].arm64.asmHandlersAddSubWide["SADDW";0b;0b;0;labelMap;addr;args]};
.arm64.asmHandlers[`SADDW2]:{[labelMap;addr;args].arm64.asmHandlersAddSubWide["SADDW2";1b;0b;0;labelMap;addr;args]};
.arm64.asmHandlers[`SBFM]:{[labelMap;addr;args].arm64.asmHandlersBitfieldMove["SBFM";0;labelMap;addr;args]};
.arm64.asmHandlers[`SDIV]:{[labelMap;addr;args].arm64.asmHandlersDivide["SDIV";1b;labelMap;addr;args]};
.arm64.asmHandlers[`SMADDL]:{[labelMap;addr;args].arm64.asmHandlersMultiplyAndAddSubLong["SMADDL";0b;0b;labelMap;addr;args]};
.arm64.asmHandlers[`SMC]:{[labelMap;addr;args].arm64.asmHandlersSystemCall["SMC";3;labelMap;addr;args]};
.arm64.asmHandlers[`SMSUBL]:{[labelMap;addr;args].arm64.asmHandlersMultiplyAndAddSubLong["SMSUBL";0b;1b;labelMap;addr;args]};
.arm64.asmHandlers[`SMULH]:{[labelMap;addr;args].arm64.asmHandlersMultiplyHigh["SMULH";0b;labelMap;addr;args]};
.arm64.asmHandlers[`SQDMLAL]:{[labelMap;addr;args].arm64.asmHandlersSatDblMultAddSubLong["SQDMLAL";0b;1;labelMap;addr;args]};
.arm64.asmHandlers[`SQDMLSL]:{[labelMap;addr;args].arm64.asmHandlersSatDblMultAddSubLong["SQDMLSL";1b;1;labelMap;addr;args]};
.arm64.asmHandlers[`SQRSHL]:{[labelMap;addr;args].arm64.asmHandlersRegShiftLeft["SQRSHL";0b;3;labelMap;addr;args]};
.arm64.asmHandlers[`SQSHL]:{[labelMap;addr;args].arm64.asmHandlersShiftLeft["SQSHL";0b;7;labelMap;addr;args]};
.arm64.asmHandlers[`SQSHLU]:{[labelMap;addr;args].arm64.asmHandlersShiftLeft["SQSHLU";1b;6;labelMap;addr;args]};
.arm64.asmHandlers[`SRSRA]:{[labelMap;addr;args].arm64.asmHandlersShiftLeft["SRSRA";0b;3;labelMap;addr;args]};
.arm64.asmHandlers[`SSHL]:{[labelMap;addr;args].arm64.asmHandlersRegShiftLeft["SSHL";0b;0;labelMap;addr;args]};
.arm64.asmHandlers[`SSUBW]:{[labelMap;addr;args].arm64.asmHandlersAddSubWide["SADDW";0b;0b;2;labelMap;addr;args]};
.arm64.asmHandlers[`SSUBW2]:{[labelMap;addr;args].arm64.asmHandlersAddSubWide["SSUBW2";1b;0b;2;labelMap;addr;args]};
.arm64.asmHandlers[`STP]:{[labelMap;addr;args].arm64.asmHandlersLoadStorePair["STP";0b;-1;0b;labelMap;addr;args]};
.arm64.asmHandlers[`STPSW]:{[labelMap;addr;args].arm64.asmHandlersLoadStorePair["STP";0b;1;0b;labelMap;addr;args]};
.arm64.asmHandlers[`STR]:{[labelMap;addr;args].arm64.asmHandlersLoadStoreBasic["STR";0b;0b;labelMap;addr;args]};
.arm64.asmHandlers[`STRB]:{[labelMap;addr;args].arm64.asmHandlersLoadStoreByte["STRB";0b;0b;labelMap;addr;args]};
.arm64.asmHandlers[`STRH]:{[labelMap;addr;args].arm64.asmHandlersLoadStoreByte["STRH";1b;0b;labelMap;addr;args]};
.arm64.asmHandlers[`STUR]:{[labelMap;addr;args].arm64.asmHandlersLoadStoreUnscaled["STUR";0b;-1;labelMap;addr;args]};
.arm64.asmHandlers[`STURB]:{[labelMap;addr;args].arm64.asmHandlersLoadStoreUnscaled["STUR";0b;0;labelMap;addr;args]};
.arm64.asmHandlers[`STURH]:{[labelMap;addr;args].arm64.asmHandlersLoadStoreUnscaled["STUR";0b;1;labelMap;addr;args]};
.arm64.asmHandlers[`SUB]:{[labelMap;addr;args].arm64.asmHandlersAddSubNormal["SUB";1b;0b;labelMap;addr;args]};
.arm64.asmHandlers[`SUBS]:{[labelMap;addr;args].arm64.asmHandlersAddSubNormal["SUBS";1b;1b;labelMap;addr;args]};

.arm64.asmHandlers[`SVC]:{[labelMap;addr;args].arm64.asmHandlersSystemCall["SVC";1;labelMap;addr;args]};

.arm64.asmHandlers[`SXTW]:{[labelMap;addr;args]
    if[2<>count args; '"SXTW: need exactly 2 args"];
    rd:.arm64.parseScalarReg[args 0;0b];
    rn:.arm64.parseScalarReg[args 1;0b];
    if[rd[0]=0; '"SXTW: destination register must be 64-bit"];
    if[rn[0]=1; '"SXTW: source register must be 32-bit"];
    //1 00 100110 1 000000 011111 rn rd
    4#.x86util.i2le sum 1 32 1*(2470476800;rn[1];rd[1])};

.arm64.asmHandlers[`TBNZ]:{[labelMap;addr;args].arm64.asmHandlersTestBranch["TBNZ";1b;labelMap;addr;args]};
.arm64.asmHandlers[`TBZ]:{[labelMap;addr;args].arm64.asmHandlersTestBranch["TBZ";0b;labelMap;addr;args]};

.arm64.asmHandlers[`UADDW]:{[labelMap;addr;args].arm64.asmHandlersAddSubWide["UADDW";0b;1b;0;labelMap;addr;args]};
.arm64.asmHandlers[`UADDW2]:{[labelMap;addr;args].arm64.asmHandlersAddSubWide["UADDW2";1b;1b;0;labelMap;addr;args]};
.arm64.asmHandlers[`UBFM]:{[labelMap;addr;args].arm64.asmHandlersBitfieldMove["UBFM";2;labelMap;addr;args]};
.arm64.asmHandlers[`UDF]:{[labelMap;addr;args]
    if[not 1=count args; '"UDF: need exactly 1 arg"];
    arg:first args;
    if[not "#"=first arg; '"UDF takes a literal"];
    .x86util.i2le .arm64.getNumber 1_arg};

.arm64.asmHandlers[`UDIV]:{[labelMap;addr;args].arm64.asmHandlersDivide["UDIV";0b;labelMap;addr;args]};
.arm64.asmHandlers[`UMADDL]:{[labelMap;addr;args].arm64.asmHandlersMultiplyAndAddSubLong["UMADDL";1b;0b;labelMap;addr;args]};
.arm64.asmHandlers[`UMSUBL]:{[labelMap;addr;args].arm64.asmHandlersMultiplyAndAddSubLong["UMSUBL";1b;1b;labelMap;addr;args]};
.arm64.asmHandlers[`UMULH]:{[labelMap;addr;args].arm64.asmHandlersMultiplyHigh["UMULH";1b;labelMap;addr;args]};
.arm64.asmHandlers[`UQRSHL]:{[labelMap;addr;args].arm64.asmHandlersRegShiftLeft["UQRSHL";1b;3;labelMap;addr;args]};
.arm64.asmHandlers[`UQSHL]:{[labelMap;addr;args].arm64.asmHandlersShiftLeft["UQSHL";1b;7;labelMap;addr;args]};
.arm64.asmHandlers[`USHL]:{[labelMap;addr;args].arm64.asmHandlersRegShiftLeft["USHL";1b;0;labelMap;addr;args]};
.arm64.asmHandlers[`USUBL]:{[labelMap;addr;args].arm64.asmHandlersAddSubWide["USUBW";0b;1b;1;labelMap;addr;args]};
.arm64.asmHandlers[`USUBL2]:{[labelMap;addr;args].arm64.asmHandlersAddSubWide["USUBW2";1b;1b;1;labelMap;addr;args]};
.arm64.asmHandlers[`USUBW]:{[labelMap;addr;args].arm64.asmHandlersAddSubWide["USUBW";0b;1b;2;labelMap;addr;args]};
.arm64.asmHandlers[`USUBW2]:{[labelMap;addr;args].arm64.asmHandlersAddSubWide["USUBW2";1b;1b;2;labelMap;addr;args]};

`s#key .arm64.asmHandlers;
.arm64.asmHandlers:asc[key .arm64.asmHandlers]#.arm64.asmHandlers;

.arm64.asm:{[labelMap;addr;inst]
    addr:`int$addr;
    p:(" "vs upper inst);
    opcode:`$first p;
    argsstr:" "sv (1_p) except enlist"";
    args:$[0<count argsstr;trim each","vs argsstr;()];
    if[opcode like "B.*"; opcode:`B.cond; args:(1#p),args];
    if[not opcode in key .arm64.asmHandlers; '"unknown instruction: ",first p];
    .arm64.asmHandlers[opcode][labelMap;addr;args]};

.arm64.asmAll:{[addr;insts]
    if[10h=type insts; insts:"\n"vs insts];
    addrs:`int$addr+4*til count insts;
    labelMap:()!();
    raze .arm64.asm[labelMap]'[addrs;insts]};

.arm64.asmUnitTestDef:([]addr:`int$();inst:();result:());
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"ADD X0, X0, X30";0x00001e8b);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"ADD W9, W9, W11, UXTB";0x29012b0b);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"ADD X9, X9, X10, LSL #2";0x29090a8b);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"ADD X29, SP, #0x80";0xfd030291);
`.arm64.asmUnitTestDef insert `addr`inst`result!(128;"ADR X9, #-0x10";0x89fbff10);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"ADRP X1, #0x3000";0x010000f0);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"ANDS W14, W19, #0xffffc3ff";0x6e6e1272);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"ANDS W14, W19, #0xffffc3ff/1";0x6e6e3272);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"B #0x8";0x02000014);
`.arm64.asmUnitTestDef insert `addr`inst`result!(128;"B.NE #0x000000c4";0x21020054);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"BFI X9, X9, #0x20, #0x20";0x297d60b3);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"BIC X11, X11, X8, LSL #0";0x6b01288a);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"BICS W5, W27, W2, LSR #19";0x654f626a);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"BL #0x8";0x02000094);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"BR X2";0x40001fd6);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"BLR X8";0x00013fd6);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"CBNZ W8, #0x1f4";0xa80f0035);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"CBZ W2, #0xf0";0x82070034);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"CCMP W8, W23, #4, NE";0x0411577a);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"CCMP W8, #0x17, #4, NE";0x0419577a);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"CLZ X10, X10";0x4a11c0da);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"CSEL W11, WZR, W11, EQ";0xeb038b1a);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"CSET W8, EQ";0xe8179f1a);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"EOR W9, W11, W9, LSL #0";0x6901094a);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"FCMLA V14.8H, V19.8H, V18.H[1], #90";0x6e32726f);    //unconfirmed
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"LDNP D12, D23, [X27, #-0x100]";0x6c5f706c);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"LDR W0, [X30]";0xc00340b9);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"LDR X1, [X1, #0x1a8]";0x21d440f9);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"LDR W8, [X8, X9, LSL #2]";0x087969b8);
`.arm64.asmUnitTestDef insert `addr`inst`result!(128;"LDR XZR, #0x8d248";0x5f8e4658);
`.arm64.asmUnitTestDef insert `addr`inst`result!(128j;"LDR S6, #0x1b234";0xa68d0d1c);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"LDRB W11, [X1]";0x2b004039);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"LDRB W10, [X24, X8]";0x0a6b6838);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"LDRB W8, [X0, #4]";0x08104039);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"LDRH W8, [X8, #0x6]";0x080d4079);
`.arm64.asmUnitTestDef insert `addr`inst`result!(128j;"LDRSW X12, #0x1fc88";0x4ce00f98);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"LDUR X8, [X22, #-0x8]";0xc8825ff8);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"LSL W9, W9, #4";0x296d1c53);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"LSR X8, X8, X10";0x0825ca9a);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"MOV W19, W1";0xf303012a);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"MOV W0, WZR";0xe0031f2a);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"MOVK W24, #0x3044, LSL #16";0x9808a672);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"MOVZ W1, #0x0";0x01008052);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"MOVZ W1, #0x0, LSL #16";0x0100a052);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"MUL X10, X22, X10";0xca7e0a9b);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"MSUB X9, X11, X10, X9";0x69a50a9b);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"NEG W8, W0";0xe803004b);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"NOP";0x1f2003d5);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"ORR X24, XZR, #0xaaaaaaaaaaaaaaaa";0xf8f301b2);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"ORR X24, XZR, #-0x5555555555555556";0xf8f301b2);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"ORR W1, WZR, #0x1";0xe1030032);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"RBIT X10, X11";0x6a01c0da);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"RET";0xc0035fd6);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"RET X1";0x20005fd6);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"STR X8, [SP, #0x60]";0xe83300f9);
`.arm64.asmUnitTestDef insert `addr`inst`result!(128;"TBZ W0, #0, #0x00000bdc";0xe05a0036);
`.arm64.asmUnitTestDef insert `addr`inst`result!(128;"TBNZ W0, #0, #0x00000bdc";0xe05a0037);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"LDP X29, X30, [SP, #0x80]";0xfd7b48a9);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"LDPSW X5, X29, [X3, #-0xf8]";0x65746169);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"SQDMLSL S4, H11, V14.H[6]";0x64796e5f);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"SQSHL D1, D3, #0x21";0x6174615f);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"SQSHLU V18.2D, V11.2D, #0x33";0x7265736f);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"SRSRA D19, D1, #0x19";0x3334675f);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"STP Q6, Q7, [SP, #-0x20]!";0xe61fbfad);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"STR X26, [X9, X8]";0x3a6928f8);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"STR X8, [SP, #0x60]";0xe83300f9);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"STURB W1, [X8, #-0x1]";0x01f11f38);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"SUB X2, X2, X0";0x420000cb);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"SUB SP, SP, #0x90";0xff4302d1);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"SUBS XZR, X9, X8";0x3f0108eb);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"SUBS XZR, X20, X8, LSR #4";0x9f1248eb);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"SVC #6";0xc10000d4);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"SXTW X0, W0";0x007c4093);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"UDIV X11, X9, X10";0x2b09ca9a);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"UMADDL X21, W8, W22, X9";0x1525b69b);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"UMULH X8, X8, X24";0x087dd89b);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"USHL V15.8H, V19.8H, V21.8H";0x6f46756e);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"UQRSHL V14.8H, V27.8H, V5.8H";0x6e5f656e);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"UQSHL V3.2D, V3.2D, #0x29";0x6374696f);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"UQSHL V26.16B, V18.16B, V18.16B";0x5a4e326e);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"USUBL2 V26.4S, V1.8H, V21.8H";0x3a20756e);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"USUBW2 V14.4S, V18.4S, V14.8H";0x4e326e6e);
//aliases
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"CMP X0, #0";0x1f0000f1);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"CMP X9, X8";0x3f0108eb);
`.arm64.asmUnitTestDef insert `addr`inst`result!(0;"CMP X20, X8, LSR #4";0x9f1248eb);

.arm64.asmUnitTest:{
    if[not .arm64.encodeBitMasks[1b;6148914691236517205j;()]~(0b;60j;0j); {'"failed"}[]];
    if[not .arm64.encodeBitMasks[1b;4919131752989213764j;()]~(0b;56j;2j); {'"failed"}[]];
    if[not .arm64.encodeBitMasks[1b;-17590038560769j;()]~(1b;50j;20j); {'"failed"}[]];
    if[not .arm64.encodeBitMasks[1b;1i;()]~(0b;0j;0j); {'"failed"}[]];
    if[not .arm64.encodeBitMasks[1b;-268304385i;()]~(0b;20j;4j); {'"failed"}[]];
    {if[not .[.arm64.asmAll;(x`addr;x`inst);{x}]~x`result;{'"failed"}[]]}each .arm64.asmUnitTestDef;
    };
.arm64.asmUnitTest[];

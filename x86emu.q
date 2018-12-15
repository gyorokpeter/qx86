.x86emu.blankState:{
    st:enlist[`]!enlist(::);
    st[`EAX`ECX`EDX`EBX`ESP`EBP`ESI`EDI]:0i;
    st[`ESP]:0x00 sv 0x0019FF84;
    st[`F0`F1`CF`PF`AF`ZF`SF`TF`DF`OF]:0100000000b; //f0/f1 are "always false/true" for the hardcoded flags
    st[`memmap]:.blockmem.new[];
    st};

.x86emu.eflags:{[state]
    `int$0b sv state[`F0`F0`F0`F0`OF`DF`F1`TF`SF`ZF`F0`AF`F0`PF`F1`CF]};

.x86emu.uneflags:{[val]
    `OF`TF`SF`ZF`AF`PF`CF!(-16#0b vs val)[4 7 8 9 11 13 15]};

.x86emu.smv:{[state;addr;bytes]
    state[`memmap]:.blockmem.write[state`memmap;addr;bytes];
    state};

.x86emu.gmv:{[state;addr;size]
    .x86util.le2i .blockmem.read[state[`memmap];addr;size]};

.x86emu.lea:{[state;arg]
    addr:arg[6];
    if[not null arg[3]; addr+:state[arg 3]];
    if[not null arg[5]; addr+:arg[4]*state[arg 5]];
    addr};

.x86emu.evalOperand:{[state;arg]
    if[arg[0]=`imm; :arg 1];
    if[arg[0]=`simm; :$[arg[1]>=0x80;neg`byte$neg arg 1;arg 1]];
    if[arg[0]=`reg;
        if[arg[1] in key state; :state arg 1];
        if[arg[1] in .x86das.reg2; :0x00 sv 2_0x00 vs state[.x86das.reg4 .x86das.reg2?arg 1]];
        if[arg[1] like "?L"; :last 0x00 vs state[`$"E",first[string arg 1],"X"]];
        if[arg[1] like "?H"; :(0x00 vs state[`$"E",first[string arg 1],"X"])[2]];
    ];
    if[arg[0]=`mem; :.x86emu.gmv[state;.x86emu.lea[state;arg];arg[1]]];
    };

.x86emu.push:{[state;int]
    sz:$[-6=type int; 4i;
         -5=type int; 2i;
         {'"push: wrong size"}[]];
    state:.x86emu.smv[state;state[`ESP]-sz;.x86util.i2le int];
    state[`ESP]-:sz;
    state};

.x86emu.set:{[state;dest;src]
    if[dest[0]=`reg;
        if[dest[1] in key state; state[dest 1]:src];
        if[dest[1] like "?X";
            reg:`$"E",string[dest 1];
            state[reg]:0x00 sv (2#0x00 vs state[reg]),-2#0x00 vs src;
        ];
        if[dest[1] like "?L";
            reg:`$"E",first[string dest 1],"X";
            state[reg]:0x00 sv (3#0x00 vs state[reg]),$[-4h=type src;src;-1#0x00 vs src];
        ];
        if[dest[1] like "?H";
            reg:`$"E",first[string dest 1],"X";
            v:0x00 vs state[reg];
            v[2]:$[-4h=type src;src;last 0x00 vs src];
            state[reg]:0x00 sv v;
        ];
    ];
    if[dest[0]=`mem; :.x86emu.smv[state;.x86emu.lea[state;dest];.x86util.i2le src]];
    state};

.x86emu.typematch:{[dest;src]
    byp:0x00 vs src;
    t:type dest;
    res:$[t=-6; src;
      t=-5; 0x00 sv -2#byp;
      t=-4; last byp;
      {'".x86emu.typematch: unknown dest type"}[]];
    res};

.x86emu.operandSize:{[op]
    $[`mem=first op;
        op 1;
      `reg=first op;
        $[op[1] in .x86das.reg4; 4;
          op[1] in .x86das.reg2,.x86das.sreg; 2;
          op[1] in .x86das.reg1; 1;
          {'"unknown register size"}[]];
      `imm=first op;
        $[-6h=type op 1; 4;
          -5h=type op 1; 2;
          -4h=type op 1; 1;
          {'"unknown register size"}[]];
      {'"unknown operand size"}[]]};

.x86emu.sx:{[refval;val]
    if[(type[refval]=-6) and (type[val]=-4); :.x86util.sx32[val]];
    val};

.x86emu.setFlags:{[state;res]
    resbp:0b vs res;
    state[`ZF]:0=res;
    state[`SF]:first resbp;
    state[`PF]:`boolean$(1+sum[-8#resbp])mod 2;
    state[`OF]:0b;
    state};

.x86emu.handlers:()!();
.x86emu.handlers[`MOV]:{[state;inst]
    .x86emu.set[state;inst[4;0];.x86emu.evalOperand[state;inst[4;1]]]};
.x86emu.handlers[`LEA]:{[state;inst]
    .x86emu.set[state;inst[4;0];`int$.x86emu.lea[state;inst[4;1]]]};
.x86emu.handlers[`MOVZX]:{[state;inst]
    dest:0b vs .x86emu.evalOperand[state;inst[4;0]];
    destsize:count dest;
    src:0b vs .x86emu.evalOperand[state;inst[4;1]];
    srcsize:count src;
    .x86emu.set[state;inst[4;0];0b sv ((destsize-srcsize)#0b),src]};
.x86emu.handlers[`MOVSX]:{[state;inst]
    dest:0b vs .x86emu.evalOperand[state;inst[4;0]];
    destsize:count dest;
    src:0b vs .x86emu.evalOperand[state;inst[4;1]];
    srcsize:count src;
    .x86emu.set[state;inst[4;0];0b sv ((destsize-srcsize)#first src),src]};
.x86emu.handlers[`PUSH]:{[state;inst]
    .x86emu.push[state;.x86emu.evalOperand[state;inst[4;0]]]};
.x86emu.handlers[`POP]:{[state;inst]
    sz:.x86emu.operandSize inst[4;0];
    val:.x86emu.gmv[state;state`ESP;sz];
    state[`ESP]+:`int$sz;
    .x86emu.set[state;inst[4;0];val]};
.x86emu.handlers[`POPFD]:{[state;inst]
    state[`ESP]+:4i;
    state};
.x86emu.handlers[`POPFW]:{[state;inst]
    val:.x86emu.gmv[state;state`ESP;2];
    state[`ESP]+:2i;
    state,:.x86emu.uneflags val;
    state};
.x86emu.handlers[`PUSHAD]:{[state;inst]
    vals:state`EAX`ECX`EDX`EBX`ESP`EBP`ESI`EDI;
    .x86emu.push/[state;vals]};
.x86emu.handlers[`PUSHFD]:{[state;inst]
    .x86emu.push[state;.x86emu.eflags[state]]};
.x86emu.handlers[`PUSHFW]:{[state;inst]
    .x86emu.push[state;`short$.x86emu.eflags[state]]};
.x86emu.handlers[`CALL]:{[state;inst]
    state:.x86emu.push[state;state`EIP];
    state[`EIP]:.x86emu.evalOperand[state;inst[4;0]];
    state};
.x86emu.handlers[`RETN]:{[state;inst]
    state[`EIP]:.x86emu.gmv[state;state`ESP;4];
    state[`ESP]+:4i+$[0<count inst[4];`int$inst[4;0;1];0i];
    state};
.x86emu.handlers[`JMP]:{[state;inst]
    state[`EIP]:.x86emu.evalOperand[state;inst[4;0]];
    state};
.x86emu.handlers[`JS]:{[state;inst]
    if[state[`SF]=1b;state[`EIP]:.x86emu.evalOperand[state;inst[4;0]]];
    state};
.x86emu.handlers[`JNS]:{[state;inst]
    if[state[`SF]=0b;state[`EIP]:.x86emu.evalOperand[state;inst[4;0]]];
    state};
.x86emu.handlers[`JO]:{[state;inst]
    if[state[`OF]=1b;state[`EIP]:.x86emu.evalOperand[state;inst[4;0]]];
    state};
.x86emu.handlers[`JNO]:{[state;inst]
    if[state[`OF]=0b;state[`EIP]:.x86emu.evalOperand[state;inst[4;0]]];
    state};
.x86emu.handlers[`JA]:{[state;inst]
    if[(state[`CF]=0b) and state[`ZF]=0b;state[`EIP]:.x86emu.evalOperand[state;inst[4;0]]];
    state};
.x86emu.handlers[`JB]:{[state;inst]
    if[state[`CF]=1b;state[`EIP]:.x86emu.evalOperand[state;inst[4;0]]];
    state};
.x86emu.handlers[`JNB]:{[state;inst]
    if[state[`CF]=0b;state[`EIP]:.x86emu.evalOperand[state;inst[4;0]]];
    state};
.x86emu.handlers[`JE]:{[state;inst]
    if[state[`ZF]=1b;state[`EIP]:.x86emu.evalOperand[state;inst[4;0]]];
    state};
.x86emu.handlers[`JNZ]:{[state;inst]
    if[state[`ZF]=0b;state[`EIP]:.x86emu.evalOperand[state;inst[4;0]]];
    state};
.x86emu.handlers[`JBE]:{[state;inst]
    if[(state[`CF]=1b) or state[`ZF]=1b;state[`EIP]:.x86emu.evalOperand[state;inst[4;0]]];
    state};
.x86emu.handlers[`JPO]:{[state;inst]
    if[state[`PF]=0b;state[`EIP]:.x86emu.evalOperand[state;inst[4;0]]];
    state};
.x86emu.handlers[`JPE]:{[state;inst]
    if[state[`PF]=1b;state[`EIP]:.x86emu.evalOperand[state;inst[4;0]]];
    state};
.x86emu.handlers[`JL]:{[state;inst]
    if[state[`SF]<>state[`OF];state[`EIP]:.x86emu.evalOperand[state;inst[4;0]]];
    state};
.x86emu.handlers[`JGE]:{[state;inst]
    if[state[`SF]=state[`OF];state[`EIP]:.x86emu.evalOperand[state;inst[4;0]]];
    state};
.x86emu.handlers[`JLE]:{[state;inst]
    if[(state[`ZF]=1b) or state[`SF]<>state[`OF];state[`EIP]:.x86emu.evalOperand[state;inst[4;0]]];
    state};
.x86emu.handlers[`JG]:{[state;inst]
    if[(state[`ZF]=0b) and state[`SF]=state[`OF];state[`EIP]:.x86emu.evalOperand[state;inst[4;0]]];
    state};
.x86emu.handlers[`TEST]:{[state;inst]
    bp1:0b vs .x86emu.evalOperand[state;inst[4;0]];
    bp2:0b vs .x86emu.evalOperand[state;inst[4;1]];
    temp:bp1 and bp2;
    state[`ZF]:0=sum temp;
    state[`SF]:first temp;
    state[`PF]:`boolean$sum[-8#temp]mod 2;
    state[`CF]:0b;
    state[`OF]:0b;
    state};
.x86emu.handlers[`CMP]:{[state;inst]
    dest:.x86emu.evalOperand[state;inst[4;0]];
    src:.x86emu.evalOperand[state;inst[4;1]];
    temp:dest-src;
    state:.x86emu.setFlags[state;temp];
    state[`CF]:{s:x-y;p:(s?-1);(p<count x)and not 1 in p#s}[0b vs dest;0b vs src];
    state};
.x86emu.handlers[`INC]:{[state;inst]
    dest:.x86emu.evalOperand[state;inst[4;0]];
    state:.x86emu.set[state;inst[4;0];.x86emu.typematch[dest;dest+1i]];
    state};
.x86emu.handlers[`DEC]:{[state;inst]
    dest:.x86emu.evalOperand[state;inst[4;0]];
    state:.x86emu.set[state;inst[4;0];neg[type dest]$$[dest~-32767h;0Nh;dest-1i]];
    state};
.x86emu.handlers[`ADC]:{[state;inst]
    dest:.x86emu.evalOperand[state;inst[4;0]];
    src:.x86emu.evalOperand[state;inst[4;1]];
    temp:dest+src+state[`CF];
    tempbp:0b vs temp;
    state:.x86emu.setFlags[state;temp];
    state[`CF]:{s:x+y;s[count[s]-1]:2&1+last s;p:(s?2);(p<count x)and not 0 in p#s}[0b vs dest;0b vs src];
    state:.x86emu.set[state;inst[4;0];temp];
    state};
.x86emu.handlers[`ADD]:{[state;inst]
    dest:.x86emu.evalOperand[state;inst[4;0]];
    src:.x86emu.sx[dest;.x86emu.evalOperand[state;inst[4;1]]];
    temp:$[0Ni~src;
        {0b sv not[first x],1_x}0b vs dest;
        dest+src];
    temp:.x86emu.typematch[dest;temp];
    state:.x86emu.set[state;inst[4;0];temp];
    state:.x86emu.setFlags[state;temp];
    state[`CF]:{s:x+y;p:(s?2);(p<count x)and not 0 in p#s}[0b vs dest;0b vs src];
    state};
.x86emu.handlers[`SUB]:{[state;inst]
    dest:.x86emu.evalOperand[state;inst[4;0]];
    src:.x86emu.evalOperand[state;inst[4;1]];
    temp:.x86emu.typematch[dest;
        $[0Ni~src;
            {0b sv not[first x],1_x}0b vs dest;
        dest-src]];
    tempbp:0b vs temp;
    state[`ZF]:0=temp;
    state[`SF]:first tempbp;
    state[`PF]:`boolean$sum[-8#tempbp]mod 2;
    state[`CF]:0b;
    state[`OF]:0b;
    state:.x86emu.set[state;inst[4;0];temp];
    state};
.x86emu.handlers[`SBB]:{[state;inst]
    dest:.x86emu.evalOperand[state;inst[4;0]];
    src:.x86emu.evalOperand[state;inst[4;1]];
    temp:neg[type dest]$dest-src+state[`CF];
    tempbp:0b vs temp;
    state[`ZF]:0=temp;
    state[`SF]:first tempbp;
    state[`PF]:`boolean$sum[-8#tempbp]mod 2;
    state[`CF]:0b;
    state[`OF]:0b;
    state:.x86emu.set[state;inst[4;0];temp];
    state};
.x86emu.handlers[`NOT]:{[state;inst]
    dest:0b vs .x86emu.evalOperand[state;inst[4;0]];
    tempbp:not dest;
    temp:0b sv tempbp;
    state[`ZF]:0=temp;
    state[`SF]:first tempbp;
    state[`PF]:`boolean$sum[-8#tempbp]mod 2;
    state[`CF]:0b;
    state[`OF]:0b;
    state:.x86emu.set[state;inst[4;0];temp];
    state};
.x86emu.handlers[`NEG]:{[state;inst]
    dest:.x86emu.evalOperand[state;inst[4;0]];
    state:.x86emu.set[state;inst[4;0];neg[type dest]$neg dest];
    state};
.x86emu.handlers[`XOR]:{[state;inst]
    dest:0b vs .x86emu.evalOperand[state;inst[4;0]];
    src:0b vs .x86emu.evalOperand[state;inst[4;1]];
    tempbp:(dest or src) and not (dest and src);
    temp:0b sv tempbp;
    state[`ZF]:0=temp;
    state[`SF]:first tempbp;
    state[`PF]:`boolean$sum[-8#tempbp]mod 2;
    state[`CF]:0b;
    state[`OF]:0b;
    state:.x86emu.set[state;inst[4;0];temp];
    state};
.x86emu.handlers[`AND]:{[state;inst]
    dest:0b vs .x86emu.evalOperand[state;inst[4;0]];
    src:0b vs .x86emu.evalOperand[state;inst[4;1]];
    tempbp:dest and src;
    temp:0b sv tempbp;
    state[`ZF]:0=temp;
    state[`SF]:first tempbp;
    state[`PF]:`boolean$sum[-8#tempbp]mod 2;
    state[`CF]:0b;
    state[`OF]:0b;
    state:.x86emu.set[state;inst[4;0];temp];
    state};
.x86emu.handlers[`OR]:{[state;inst]
    dest:0b vs .x86emu.evalOperand[state;inst[4;0]];
    src:0b vs .x86emu.evalOperand[state;inst[4;1]];
    tempbp:dest or src;
    temp:0b sv tempbp;
    state[`ZF]:0=temp;
    state[`SF]:first tempbp;
    state[`PF]:`boolean$sum[-8#tempbp]mod 2;
    state[`CF]:0b;
    state[`OF]:0b;
    state:.x86emu.set[state;inst[4;0];temp];
    state};
.x86emu.handlers[`SHLD]:{[state;inst]
    dest:0b vs .x86emu.evalOperand[state;inst[4;0]];
    src:0b vs .x86emu.evalOperand[state;inst[4;1]];
    temp:dest,src;
    cnt:.x86emu.evalOperand[state;inst[4;2]] mod count temp;
    temp:0b sv neg[count dest]#(cnt _temp),cnt#temp;
    state:.x86emu.set[state;inst[4;0];temp];
    state};
.x86emu.handlers[`SHRD]:{[state;inst]
    dest:0b vs .x86emu.evalOperand[state;inst[4;0]];
    src:0b vs .x86emu.evalOperand[state;inst[4;1]];
    temp:dest,src;
    cnt:.x86emu.evalOperand[state;inst[4;2]] mod count temp;
    temp:0b sv neg[count dest]#(cnt _temp),cnt#temp;
    state:.x86emu.set[state;inst[4;0];temp];
    state};
.x86emu.handlers[`SHL]:{[state;inst]
    dest:0b vs .x86emu.evalOperand[state;inst[4;0]];
    cnt:.x86emu.evalOperand[state;inst[4;1]] mod count dest;
    temp:0b sv (cnt _dest),cnt#0b;
    state:.x86emu.set[state;inst[4;0];temp];
    state};
.x86emu.handlers[`SHR]:{[state;inst]
    dest:0b vs .x86emu.evalOperand[state;inst[4;0]];
    cnt:.x86emu.evalOperand[state;inst[4;1]] mod count dest;
    temp:0b sv (cnt#0b),neg[cnt]_dest;
    state:.x86emu.set[state;inst[4;0];temp];
    state:.x86emu.setFlags[state;temp];
    state[`CF]:dest[count[dest]-cnt];
    state};
.x86emu.handlers[`SAL]:{[state;inst]
    dest:0b vs .x86emu.evalOperand[state;inst[4;0]];
    cnt:.x86emu.evalOperand[state;inst[4;1]];
    temp:0b sv (neg[cnt]#0b),neg[cnt]_dest;
    state:.x86emu.set[state;inst[4;0];temp];
    state};
.x86emu.handlers[`SAR]:{[state;inst]
    dest:0b vs .x86emu.evalOperand[state;inst[4;0]];
    cnt:.x86emu.evalOperand[state;inst[4;1]]mod 32;
    temp:0b sv (cnt#first dest),neg[cnt]_dest;
    state:.x86emu.set[state;inst[4;0];temp];
    state};
.x86emu.handlers[`RCL]:{[state;inst]
    dest:0b vs .x86emu.evalOperand[state;inst[4;0]];
    cnt:.x86emu.evalOperand[state;inst[4;1]] mod count dest;
    temp:state[`CF],dest;
    tempbp:(neg[cnt]#temp),(neg[cnt]_temp);
    state[`CF]:first tempbp;
    state:.x86emu.set[state;inst[4;0];0b sv 1_tempbp];
    state};
.x86emu.handlers[`RCR]:{[state;inst]
    dest:0b vs .x86emu.evalOperand[state;inst[4;0]];
    cnt:(.x86emu.evalOperand[state;inst[4;1]])mod count[dest]+1;
    temp:state[`CF],dest;
    tempbp:(neg[cnt]#temp),neg[cnt]_temp;
    state[`CF]:first tempbp;
    state:.x86emu.set[state;inst[4;0];0b sv 1_tempbp];
    state};
.x86emu.handlers[`ROL]:{[state;inst]
    dest:0b vs .x86emu.evalOperand[state;inst[4;0]];
    cnt:(.x86emu.evalOperand[state;inst[4;1]])mod count dest;
    temp:0b sv (cnt _ dest),cnt#dest;
    state:.x86emu.set[state;inst[4;0];temp];
    state};
.x86emu.handlers[`ROR]:{[state;inst]
    dest:0b vs .x86emu.evalOperand[state;inst[4;0]];
    cnt:(.x86emu.evalOperand[state;inst[4;1]])mod count dest;
    temp:0b sv (neg[cnt]#dest),neg[cnt]_dest;
    state:.x86emu.set[state;inst[4;0];temp];
    state};
.x86emu.handlers[`CLC]:{[state;inst]
    state[`CF]:0b;
    state};
.x86emu.handlers[`STC]:{[state;inst]
    state[`CF]:1b;
    state};
.x86emu.handlers[`CMC]:{[state;inst]
    state[`CF]:not state[`CF];
    state};
.x86emu.handlers[`CLD]:{[state;inst]
    state[`DF]:0b;
    state};
.x86emu.handlers[`STD]:{[state;inst]
    state[`DF]:1b;
    state};
.x86emu.handlers[`BSF]:{[state;inst]
    src:reverse 0b vs .x86emu.evalOperand[state;inst[4;0]];
    bitpos:first where src;
    if[not null bitpos; .x86emu.set[state;inst[4;0];bitpos]];
    state};
.x86emu.handlers[`BSR]:{[state;inst]
    src:0b vs .x86emu.evalOperand[state;inst[4;0]];
    bitpos:count[src]-1+first where src;
    if[not null bitpos; .x86emu.set[state;inst[4;0];bitpos]];
    state};
.x86emu.handlers[`BT]:{[state;inst]
    base:reverse 0b vs .x86emu.evalOperand[state;inst[4;0]];
    bitpos:.x86emu.evalOperand[state;inst[4;1]];
    state[`CF]:base[bitpos mod count base];
    state};
.x86emu.handlers[`BTS]:{[state;inst]
    base:reverse 0b vs .x86emu.evalOperand[state;inst[4;0]];
    bitpos:.x86emu.evalOperand[state;inst[4;1]];
    state[`CF]:base[bitpos mod count base];
    base[bitpos mod count base]:1b;
    state:.x86emu.set[state;inst[4;0];0b sv base];
    state};
.x86emu.handlers[`BTR]:{[state;inst]
    base:reverse 0b vs .x86emu.evalOperand[state;inst[4;0]];
    bitpos:.x86emu.evalOperand[state;inst[4;1]];
    state[`CF]:base[bitpos mod count base];
    base[bitpos mod count base]:0b;
    state:.x86emu.set[state;inst[4;0];0b sv base];
    state};
.x86emu.handlers[`BTC]:{[state;inst]
    base:reverse 0b vs .x86emu.evalOperand[state;inst[4;0]];
    bitpos:.x86emu.evalOperand[state;inst[4;1]];
    state[`CF]:base[bitpos mod count base];
    base[bitpos mod count base]:not base[bitpos mod count base];
    state:.x86emu.set[state;inst[4;0];0b sv base];
    state};
.x86emu.handlers[`BSWAP]:{[state;inst]
    dest:0x00 vs .x86emu.evalOperand[state;inst[4;0]];
    temp:$[4=count dest; 0x00 sv reverse dest; 0h];
    state:.x86emu.set[state;inst[4;0];temp];
    state};
.x86emu.handlers[`XCHG]:{[state;inst]
    dest:.x86emu.evalOperand[state;inst[4;0]];
    src:.x86emu.evalOperand[state;inst[4;1]];
    state:.x86emu.set[state;inst[4;0];src];
    state:.x86emu.set[state;inst[4;1];dest];
    state};
.x86emu.handlers[`XADD]:{[state;inst]
    dest:.x86emu.evalOperand[state;inst[4;0]];
    src:.x86emu.evalOperand[state;inst[4;1]];
    temp:dest+src;
    state:.x86emu.set[state;inst[4;0];temp];
    state:.x86emu.set[state;inst[4;1];src];
    state};
.x86emu.handlers[`SETA]:{[state;inst]
    state:.x86emu.set[state;inst[4;0];`byte$(state[`CF]=0b)and state[`ZF]=0b];
    state};
.x86emu.handlers[`SETB]:{[state;inst]
    state:.x86emu.set[state;inst[4;0];`byte$state[`CF]=1b];
    state};
.x86emu.handlers[`SETNB]:{[state;inst]
    state:.x86emu.set[state;inst[4;0];`byte$state[`CF]=0b];
    state};
.x86emu.handlers[`SETE]:{[state;inst]
    state:.x86emu.set[state;inst[4;0];`byte$state[`ZF]=1b];
    state};
.x86emu.handlers[`SETNE]:{[state;inst]
    state:.x86emu.set[state;inst[4;0];`byte$state[`ZF]=0b];
    state};
.x86emu.handlers[`SETBE]:{[state;inst]
    state:.x86emu.set[state;inst[4;0];`byte$(state[`CF]=1b)or state[`ZF]=1b];
    state};
.x86emu.handlers[`SETGE]:{[state;inst]
    state:.x86emu.set[state;inst[4;0];`byte$state[`SF]=state[`OF]];
    state};
.x86emu.handlers[`SETG]:{[state;inst]
    state:.x86emu.set[state;inst[4;0];`byte$(state[`ZF]=0b)and state[`SF]=state[`OF]];
    state};
.x86emu.handlers[`SETO]:{[state;inst]
    state:.x86emu.set[state;inst[4;0];`byte$state[`OF]=1b];
    state};
.x86emu.handlers[`SETNO]:{[state;inst]
    state:.x86emu.set[state;inst[4;0];`byte$state[`OF]=0b];
    state};
.x86emu.handlers[`SETPE]:{[state;inst]
    state:.x86emu.set[state;inst[4;0];`byte$state[`PF]=1b];
    state};
.x86emu.handlers[`SETPO]:{[state;inst]
    state:.x86emu.set[state;inst[4;0];`byte$state[`PF]=0b];
    state};
.x86emu.handlers[`SETNS]:{[state;inst]
    state:.x86emu.set[state;inst[4;0];`byte$state[`SF]=0b];
    state};
.x86emu.handlers[`SETS]:{[state;inst]
    state:.x86emu.set[state;inst[4;0];`byte$state[`SF]=1b];
    state};
.x86emu.handlers[`SETL]:{[state;inst]
    state:.x86emu.set[state;inst[4;0];`byte$state[`SF]<>state[`OF]];
    state};
.x86emu.handlers[`SETLE]:{[state;inst]
    state:.x86emu.set[state;inst[4;0];`byte$(state[`ZF]=1b) or state[`SF]<>state[`OF]];
    state};
.x86emu.handlers[`CBW]:{[state;inst]
    state:.x86emu.set[state;`reg`AX;0b sv {(8#x[0]),x}-8#0b vs state`EAX];
    state};
.x86emu.handlers[`CWDE]:{[state;inst]
    state:.x86emu.set[state;`reg`EAX;0b sv {(16#x[0]),x}(-16#0b vs state`EAX)];
    state};
.x86emu.handlers[`CWD]:{[state;inst]
    state:.x86emu.set[state;`reg`DX;0b sv 16#first -16#0b vs state`EAX];
    state};
.x86emu.handlers[`CDQ]:{[state;inst]
    state:.x86emu.set[state;`reg`EDX;0b sv 32#first 0b vs state`EAX];
    state};
.x86emu.handlers[`RDTSC]:{[state;inst]
    state};
.x86emu.handlers[`LAHF]:{[state;inst]
    state};
.x86emu.handlers[`AAM]:{[state;inst]
    state};
.x86emu.handlers[`AAA]:{[state;inst]
    state};
.x86emu.handlers[`AAS]:{[state;inst]
    state};
.x86emu.handlers[`AAD]:{[state;inst]
    state};
.x86emu.handlers[`DAA]:{[state;inst]
    state};
.x86emu.handlers[`DAS]:{[state;inst]
    state};
.x86emu.handlers[`LODSB]:{[state;inst]
    state:.x86emu.set[state;`reg`AL;.x86emu.evalOperand[state;(`mem;1;`DS;`ESI;0;`;0)]];
    state[`ESI]+:$[state`DF;-1i;1i];
    state};
.x86emu.handlers[`STOSB]:{[state;inst]
    state:.x86emu.set[state;(`mem;1;`ES;`EDI;0;`;0);.x86emu.evalOperand[state;`reg`AL]];
    state[`EDI]+:$[state`DF;-1i;1i];
    state};
.x86emu.handlers[`MOVSB]:{[state;inst]
    state:.x86emu.set[state;(`mem;1;`ES;`EDI;0;`;0);.x86emu.evalOperand[state;(`mem;1;`DS;`ESI;0;`;0)]];
    state[`ESI]+:$[state`DF;-1i;1i];
    state[`EDI]+:$[state`DF;-1i;1i];
    state};

.x86emu.prof:()!();

.x86emu.runDebug:0b;
.x86emu.run:{[state;inst]
    tm:.z.P;
    if[.x86emu.runDebug; show inst];
    state[`EIP]+:`int$count inst 1;
    if[not inst[3] in key .x86emu.handlers; {'"nyi instruction: ",x}[inst[2]]];
    $[inst[2] like "REP *S[BWD]";
        [
            state:.x86emu.handlers[inst 3][;inst]/[`long$state[`ECX];state];
            state[`ECX]:0i;
        ];
        state:.x86emu.handlers[inst 3][state;inst]
    ];
    tm1:.z.P;
    .x86emu.prof[inst 3]+:tm1-tm;
    if[.x86emu.runDebug; show state];
    state};

.x86emu.runSequence:{[state;insts]
    if[.x86emu.runDebug; show state];
    state:.x86emu.run/[state;insts];
    state};

.x86emu.unitTest1:{
    st:.x86emu.blankState[];
    if[.x86emu.eflags[st]<>514i; {'`failed}[]];
    if[.x86emu.evalOperand[st;(`simm;0xe0)]<>-32; {'`failed}[]];
    if[.x86emu.handlers[`JMP][st;.x86das.disasm[0;0xE9CF0F0000]][`EIP]<>4052i; {'`failed}[]];
    st[`EBP]:0x00 sv 0x01020304;if[.x86emu.evalOperand[st;`reg`BP]<>0x00 sv 0x0304; {'`failed}[]];
    if[type[.x86emu.run[st;.x86das.disasm[0;enlist 0x46]][`ESI]]<>-6h; {'`failed}[]];
    st[`ESI]:0x00 sv 0x00001000;if[.x86emu.run[st;.x86das.disasm[0;0xC1CE16]][`ESI]<>0x00 sv 0x00400000; {'`failed}[]];
    st[`ESI]:0x00 sv 0x00001000;if[.x86emu.run[st;.x86das.disasm[0;0xC1C61A]][`ESI]<>0x00 sv 0x00000040; {'`failed}[]];
    st[`ESP]:0x00 sv 0x0019FF48;if[.x86emu.run[st;.x86das.disasm[0;0x83ECE0]][`ESP]<>0x00 sv 0x0019FF68; {'`failed}[]];
    if[-6h<>type .x86emu.run[st;.x86das.disasm[0;0x8d3c8dbdfb0d53]][`EDI]; {'`failed}[]];
    if[-6h<>type .x86emu.run[st;.x86das.disasm[0;0x00d8]][`EAX]; {'`failed}[]];
    if[-6h<>type .x86emu.run[st;.x86das.disasm[0;0x8a06]][`EAX]; {'`failed}[]];
    st[`EDX]:-1749409708i;if[-6h<>type .x86emu.run[st;.x86das.disasm[0;0x660fbcd2]][`EDX]; {'`failed}[]];
    st[`EAX]:0x00 sv 0x0000fec2;if[.x86emu.run[st;.x86das.disasm[0;0x86E0]][`EAX]<>0x00 sv 0x0000c2fe; {'`failed}[]];
    st[`EAX]:0x00 sv 0x000054a2;st[`EBX]:0x00 sv 0x9752c340;if[.x86emu.run[st;.x86das.disasm[0;0x6629d8]][`EAX]<>0x00 sv 0x00009162; {'`failed}[]];
    st[`EAX]:0x00 sv 0x00007fff;if[.x86emu.run[st;.x86das.disasm[0;0x66FFC0]][`EAX]<>0x00 sv 0x00008000; {'`failed}[]];
    st[`EAX]:0x00 sv 0x80000000;st[`EBX]:0x00 sv 0xa6ac48cd;if[.x86emu.run[st;.x86das.disasm[0;0x01C3]][`EBX]<>0x00 sv 0x26AC48CD; {'`failed}[]];
    };

.x86emu.unitTest2:{
    st:.x86emu.blankState[];
    st[`EAX]:0x00 sv 0x80000000;st[`EBX]:0x00 sv 0x63C2FD05;if[.x86emu.run[st;.x86das.disasm[0;0x29C3]][`EBX]<>0x00 sv 0xE3C2FD05; {'`failed}[]];
    st[`EDX]:0x00 sv 0x00401080;if[.x86emu.run[st;.x86das.disasm[0;0x00D2]][`ZF]<>1b; {'`failed}[]];
    st[`EDX]:0x00 sv 0x00401080;if[.x86emu.run[st;.x86das.disasm[0;0x00D2]][`CF]<>1b; {'`failed}[]];
    st[`EDX]:0x00 sv 0x00401080;if[.x86emu.run[st;.x86das.disasm[0;0x00D2]][`PF]<>1b; {'`failed}[]];
    st[`EDX]:0x00 sv 0x0040101b;if[.x86emu.run[st;.x86das.disasm[0;0x80c2ef]][`CF]<>1b; {'`failed}[]];
    st[`EDX]:0x00 sv 0x004010CD;st[`CF]:1b;if[.x86emu.run[st;.x86das.disasm[0;0x10D2]][`CF]<>1b; {'`failed}[]];
    st[`ESI]:0i;st[`EDI]:100i;st[`ECX]:4i;st[`memmap]:.blockmem.write[.blockmem.new[];0i;0x01020304];if[not 0x01020304~.blockmem.read[.x86emu.run[st;.x86das.disasm[0;0xf3a4]][`memmap];100i;4]; {'`failed}[]];
    st[`EDX]:0x00 sv 0x00401000;st[`CF]:1b;if[.x86emu.run[st;.x86das.disasm[0;0xc0da06]][`EDX]<>0x00 sv 0x00401004; {'`failed}[]];
    st[`ESP]:0x00 sv 0x0019ff58;if[.x86emu.run[st;.x86das.disasm[0;0x83c420]][`ESP]<>0x00 sv 0x0019ff78; {'`failed}[]];
    st[`ESP]:0x00 sv 0x0019ff58;st[`CF]:0b;st[`memmap]:.blockmem.write[.blockmem.new[];0x00 sv 0x0019ff58;0x470a];if[.x86emu.run[st;.x86das.disasm[0;0x669d]][`CF]<>1b; {'`failed}[]];
    st[`EAX]:0x00 sv 0x0000000f;st[`CF]:0b;if[.x86emu.run[st;.x86das.disasm[0;0xd1e8]][`CF]<>1b; {'`failed}[]];
    st[`EAX]:0x00 sv 0x00000003;st[`ZF]:1b;if[.x86emu.run[st;.x86das.disasm[0;0xd1e8]][`ZF]<>0b; {'`failed}[]];
    st[`EAX]:0x00 sv 0x00000082;st[`CF]:0b;if[.x86emu.run[st;.x86das.disasm[0;0x3d007d0000]][`CF]<>1b; {'`failed}[]];
    st[`EAX]:0x00 sv 0x00000001;if[.x86emu.run[st;.x86das.disasm[0;0xc1e008]][`EAX]<>0x00 sv 0x00000100; {'`failed}[]];
    st[`EBX]:0x00 sv 0x000000f2;st[`ECX]:0x00 sv 0x00000010;st[`CF]:1b;if[.x86emu.run[st;.x86das.disasm[0;0xd2db]][`EBX]<>0x00 sv 0x000000cb; {'`failed}[]];
    st[`EAX]:0x00 sv 0x00008001;if[.x86emu.run[st;.x86das.disasm[0;0x66ffc8]][`EAX]<>0x00 sv 0x00008000; {'`failed}[]]; //DEC AX: 0x00008001 -> 0x00008000
    st[`ECX]:0x00 sv 0x00000024;if[.x86emu.run[st;.x86das.disasm[0;0xd2f9]][`ECX]<>0x00 sv 0x00000002; {'`failed}[]]; //SAR CL, CL: 0x24 -> 0x02    
    };

.x86emu.unitTest:{
    .x86emu.unitTest1[];
    .x86emu.unitTest2[];
    };

.x86emu.unitTest[]

.arm64.blankState:{
    st:enlist[`]!enlist(::);
    st[`ip]:0;
    st[`reg]:32#0;
    st[`simd]:32#0;
    st[`N`Z`C`V]:0000b;
    st[`memmap]:.blockmem.new[];
    st};

.arm64.addAndGetFlags:{[a;b]
    r:$[null a; .x86util.flipTopBit b;
        null b; .x86util.flipTopBit a;
        a+b];
    n:r<0;
    z:r=0;
    c:(a<0)and b<0;
    v:(a>0) and (b>0) and r<0;
    (r;n;z;c;v)};

.arm64.conditionHolds:{[cond;state]
    $[cond=`EQ; state`Z;
      cond=`NE; not state`Z;
      cond=`CS; state`C;
      cond=`CC; not state`C;
      cond=`MI; state`N;
      cond=`PL; not state`N;
      cond=`VS; state`V;
      cond=`VC; not state`V;
      cond=`HI; state[`C] and not state[`Z];
      cond=`LS; not[state`C] or state[`Z];
      cond=`GE; state[`N]=state[`V];
      cond=`LT; state[`N]<>state[`V];
      cond=`GT; (state[`N]=state[`V]) and not state[`Z];
      cond=`LE; (state[`N]<>state[`V]) or state[`Z];
      cond=`AL; 1b;
      cond=`NV; 1b;
    '"invalid condition: ",string cond]};

.arm64.execHandlers:()!();
.arm64.execHandlers[`B]:{[state;instr]
    state[`ip]:instr[4;0];
    state};
.arm64.execHandlers[`B.cond]:{[state;instr]
    if[.arm64.conditionHolds[instr[4;0];state];
        state[`ip]:instr[4;1];
    ];
    state};
.arm64.execHandlers[`ORR]:{[state;instr]
    if[instr[4;0]=`shifted;
        val1:state[`reg]instr[4;3];
        val2:state[`reg]instr[4;4];
    ];
    res:0b sv (0b vs val1) or 0b vs val2;
    if[instr[4;2]<31; state[reg;instr[4;2]]:res 0];
    state};
.arm64.execHandlers[`SUBS]:{[state;instr]
    if[instr[4;0]=`immediate;
        val1:state[`reg]instr[4;3];
        val2:instr[4;4];
    ];
    res:.arm64.addAndGetFlags[val1;neg val2];
    if[instr[4;2]<31; state[reg;instr[4;2]]:res 0];
    state[`N`Z`C`V]:1_res;
    state};

`s#key .arm64.execHandlers;
.arm64.execHandlers:asc[key .arm64.execHandlers]#.arm64.execHandlers;

.arm64.doInstr:{[state;instr]
    if[not instr[3] in key .arm64.execHandlers; '"unknown instruction: ",string[instr 3]];
    state[`ip]+:4;
    state:.arm64.execHandlers[instr 3][state;instr];
    state};

.arm64.step:{[state]
    addr:state`ip;
    bc:.blockmem.read[state[`memmap];addr;4];
    instr:.arm64.disasm[addr;bc];
    state:.arm64.doInstr[state;instr];
    state};

.arm64.emuUnitTest:{
    if[not .arm64.addAndGetFlags[0W;0]~0W,0000b; {'x}"failed"];
    if[not .arm64.addAndGetFlags[0W;1]~0N,1001b; {'x}"failed"];
    if[not .arm64.addAndGetFlags[1;0W]~0N,1001b; {'x}"failed"];
    if[not .arm64.addAndGetFlags[0;0]~0,0100b; {'x}"failed"];
    if[not .arm64.addAndGetFlags[0N;0N]~0,0110b; {'x}"failed"];
    if[not .arm64.addAndGetFlags[0N;0W]~-1,1000b; {'x}"failed"];
    if[not .arm64.addAndGetFlags[0W;0N]~-1,1000b; {'x}"failed"];
    };
.arm64.emuUnitTest[];

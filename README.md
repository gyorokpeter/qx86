# qx86
x86 assembler, disassembler and emulator in Q

# Loading 
Requires KDB 3.5 for the enhanced lambda metadata

```q
\l path/to/qx86/x86.q
```

# Usage
## Disassembler
```q
.x86das.disasm[addr;bytecode]
```
The address is used for jumps and calls.

Example:
```q
q).x86das.disasm[0;0x0FB70C4F]
0i
0x0fb70c4f
"MOVZX ECX, WORD PTR DS:[EDI+2*ECX]"
`MOVZX
(`reg`ECX;(`mem;2;`DS;`EDI;2;`ECX;0))
```

The return value has the following elements:
1. Address
2. Bytecode (if the input had more bytes after the instruction, only the actual bytes belonging to the instruction are returned)
3. String representation of the instruction
4. Instruction type
5. Arguments as a list
  * Immediate operand is (`imm;number)
  * Register operand is (`reg;regname)
  * Memory operand is (`mem;size;segment;basereg;multiplier;indexreg;offset)

## Assembler
```q
.x86asm.asm[addr;instruction]
.x86asm.asmAll[addr;instructions]
```

Example:
```q
q).x86asm.asm[0;"MOVZX ECX, WORD PTR DS:[EDI+2*ECX]"]
0x0fb70c4f
```

```q
q).x86asm.asmAll[0;("JMP L1";"DATA:";"DB 0x90909090";"L1:";"MOV DWORD PTR [DATA],0x01020304")]
0xe90400000090909090c7050500000004030201
```

Notes:
  * Memory operands always need size (e.g. DWORD PTR)
  * Max. 32-bit ints. Make sure to cast to int before using .x86util.shex on the number.
  * Only DB supported for literal data.
  * Only .x86asm.asmAll supports labels. Label definition is "LABEL:" on its own line. Labels are dumb search-and-replace, so don't make labels that may appear in other places than derefrences.

## Emulator

```q
.x86emu.blankState[]
.x86emu.run[st;inst]
```

inst must be the output from .x86das.disasm.

Example:
```q
q)st:.x86emu.blankState[];
q)st:.x86emu.run[st;.x86das.disasm[0;0xB804030201]]
q)st`EAX
16909060i
```

Use .x86emu.smv[state;addr;bytes] to initialize memory and .x86emu.gmv[state;addr;size] to extract bytes from memory.

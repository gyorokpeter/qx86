if[.z.K<3.5; '"KDB 3.5 required"];
{
    path:"/"sv -1_"/"vs ssr[;"\\";"/"]first -3#value .z.s;
    system"l ",path,"/util.q";
    system"l ",path,"/blockmem.q";
    system"l ",path,"/x86das.q";
    system"l ",path,"/x86asm.q";
    system"l ",path,"/x86emu.q";
    }[];

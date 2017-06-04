//number to hex string
.x86util.shex:{first ` vs .Q.s $[-4h=type x;x;0x00 vs x]};

//number to little-endian byte list
.x86util.i2le:{$[-4h=type x;enlist x;reverse 0x00 vs x]};

//little-endian byte list to number
.x86util.le2i:{$[1=count x;x[0];0x00 sv reverse x]};

//sign-exend to 32 bits
.x86util.sx32:{bp:0b vs x;0b sv ((32-count bp)#first bp),bp};
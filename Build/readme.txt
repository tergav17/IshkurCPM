Welcome,

thanks to turbocat2001@github
this is version 4.4.x of the Z80 assembler zasm for Windows 64 bit for the command line.

Install:
	copy 'zasm.exe' and 'cygwin1.dll' where you like.
	if needed add the folder path to your PATH environment variable.

Homepage, downloads & documentation:
	https://k1.spdns.de/Develop/Projects/zasm/

Source:
	https://github.com/Megatokio/zasm

Send bug reports and requests to:
	https://github.com/Megatokio/zasm/issues
	mailto:kio@little-bat.de
	Bugs which aren't reported can't be fixed.

Included 3rd party sources:
	Einar Saukas' ZX7 "optimal" LZ77 packer.
	The compressor and decompressors were written by Einar Saukas and others.
	Examples are in folder Examples/.

Documentation:
	https://k1.spdns.de/Develop/Projects/zasm/Documentation/
	Start zasm without arguments to show all command line options.
	Source code examples are in folder Examples/.


New in version 4.4:
	Run automated tests on the generated code.


Overview:

zasm is a 8080, Z80 and Z180 assembler.

zasm accepts source code using 8080 and Z80 syntax and can convert 8080 syntax to Z80.
zasm supports various historically used syntax variants and the syntax emitted by sdcc.

zasm can generate binary files or Intel Hex or Motorola S19 files.
zasm can generate various specialized files for Sinclair and Jupiter Ace and .tzx tape files.
zasm can include the generated code and accumulated cpu cycles in the list output file.

zasm supports
- character set conversion, e.g. for the ZX80 and ZX81 and proper decoding of utf-8 in text literals.
- multiple code segments
- including and compiling of c source with sdcc.
- automatic resolving of missing labels from libraries
- automatic compression using ZX7
- well known illegal instructions
- multiple instructions per line using '\' separator

the source can start with a BOM and with a shebang '#!' in line 1.
the source (text literals) must either to be 7-bit clean or utf-8 encoded.


Have Fun,

	Kio !


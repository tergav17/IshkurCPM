@ECHO OFF
cd ..\System

REM Assemble the CP/M system into a binary image
REM Then move to outputs folder
..\Build\zasm CPM22.asm -u -w -b CPM22.bin
move CPM22.bin ..\Output >NUL

REM Assemble the disk image
cd ..\Build\cpmtools
.\mkfs.cpm -f osborne1 ishkar.img
move ishkar.img ..\..\Output >NUL

REM This loop is needed because winblows sucks
for %%f in (..\..\Directory\*) do (
	copy %%f %%~nf%%~xf >NUL
	echo Writing %%~nf%%~xf to image
	cpmcp -f osborne1 -t ..\..\Output\ishkar.img %%~nf%%~xf 0:
	del %%~nf%%~xf
)
@ECHO OFF
cd ..\System

REM Assemble the CP/M system into a binary image
REM Then move to outputs folder

REM Floppy kernel
copy config\config_fdc.asm config.asm >NUL
..\Build\zasm cpm22.asm -u -w -b cpm22.bin
move cpm22.bin bin\cpm22_fdc.bin >NUL
move cpm22.lst ..\Output\Listings\cpm22_fdc.lst >NUL

REM NDSK kernel
copy config\config_ndsk.asm config.asm >NUL
..\Build\zasm cpm22.asm -u -w -b cpm22.bin
move cpm22.bin ..\Output\NDSK_CPM22.SYS >NUL
move cpm22.lst ..\Output\Listings\cpm22_ndsk.lst >NUL

REM Delete temp config file
del /Q config.asm >NUL

REM Move resource into outputs
copy res\licca_font.bin ..\Output\FONT.GRB >NUL

REM Assemble the boot programs
..\Build\zasm boot\boot_fdc.asm -u -w -b boot_fdc.bin
move boot_fdc.bin bin >NUL
move boot\boot_fdc.lst ..\Output\Listings >NUL

..\Build\zasm boot\boot_ndsk.asm -u -w -b boot_ndsk.bin
copy boot_ndsk.bin ..\Output\NDSK_BOOT.nabu >NUL
move boot_ndsk.bin bin >NUL
move boot\boot_ndsk.lst ..\Output\Listings >NUL

REM Build Ishkur-specific applications
cd ..\Applications
..\Build\zasm init.asm -u -w -b init.com
move init.com ..\Directory >NUL
move init.lst ..\Output\Listings >NUL

REM Assemble the disk image
cd ..\Build\cpmtools
.\mkfs.cpm -f osborne1 -b ..\..\System\bin\boot_fdc.bin -b ..\..\System\res\licca_font.bin -b ..\..\System\bin\cpm22_fdc.bin ishkur_fdc_ssdd.img
move ishkur_fdc_ssdd.img ..\..\Output >NUL
.\mkfs.cpm -f nshd8 NDSK_DEFAULT.IMG
move NDSK_DEFAULT.IMG ..\..\Output >NUL

REM This loop is needed because winblows sucks
for %%f in (..\..\Directory\*) do (
	copy %%f %%~nf%%~xf >NUL
	echo Writing %%~nf%%~xf to image
	cpmcp -f osborne1 ..\..\Output\ishkur_fdc_ssdd.img %%~nf%%~xf 0:
	cpmcp -f nshd8 ..\..\Output\NDSK_DEFAULT.IMG %%~nf%%~xf 0:
	del %%~nf%%~xf
)

REM Resize the file
REM If only I had to `dd` command...
cd ..\..\Output
python ..\Build\e5pad.py ishkur_fdc_ssdd.img 204800
python ..\Build\e5pad.py NDSK_DEFAULT.IMG 8388608
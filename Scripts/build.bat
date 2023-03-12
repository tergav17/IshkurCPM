@ECHO OFF
cd ..\System

REM Assemble the CP/M system into a binary image
REM Then move to outputs folder
copy config\config_fdc.asm config.asm
..\Build\zasm cpm22.asm -u -w -b cpm22.bin
move cpm22.bin bin\cpm22_fdc.bin >NUL
move cpm22.lst ..\Output\Listings\cpm22_fdc.lst >NUL

copy config\config_nhacp.asm config.asm >NUL
..\Build\zasm cpm22.asm -u -w -b cpm22.bin
move cpm22.bin ..\Output\NHACP_CPM22.SYS >NUL
move cpm22.lst ..\Output\Listings\cpm22_nhacp.lst >NUL

REM Delete temp config file
del /Q config.asm >NUL

REM Assemble the boot programs
..\Build\zasm boot\boot_fdc.asm -u -w -b boot_fdc.bin
move boot_fdc.bin bin >NUL
move boot\boot_fdc.lst ..\Output\Listings >NUL

..\Build\zasm boot\boot_nhacp.asm -u -w -b boot_nhacp.bin
copy boot_nhacp.bin ..\Output\NHACP_BOOT.nabu >NUL
move boot_nhacp.bin bin >NUL
move boot\boot_nhacp.lst ..\Output\Listings >NUL

REM Build Ishkur-specific applications
cd ..\Applications
..\Build\zasm init.asm -u -w -b init.com
move init.com ..\Directory >NUL
move init.lst ..\Output\Listings >NUL

REM Assemble the disk image
cd ..\Build\cpmtools
.\mkfs.cpm -f osborne1 -b ..\..\System\bin\boot_fdc.bin -b ..\..\System\res\licca_font.bin -b ..\..\System\bin\cpm22_fdc.bin ishkur_fdc_ssdd.img
move ishkur_fdc_ssdd.img ..\..\Output >NUL

REM This loop is needed because winblows sucks
for %%f in (..\..\Directory\*) do (
	copy %%f %%~nf%%~xf >NUL
	echo Writing %%~nf%%~xf to image
	cpmcp -f osborne1 ..\..\Output\ishkur_fdc_ssdd.img %%~nf%%~xf 0:
	del %%~nf%%~xf
)

REM Resize the file
REM If only I had to `dd` command...
cd ..\..\Output
python ..\Build\e5pad.py ishkur_fdc_ssdd.img 204800
cd ..\System

REM Assemble the CP/M system into a binary image
REM Then copy to outputs folder
..\Build\zasm CPM22.asm -u -w -b CPM22.bin

copy CPM22.bin ..\Output >NUL
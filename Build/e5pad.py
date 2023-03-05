# I hate windows because it has dogshit command line utilties
# This utility will pad a file with 0xE5 until it reaches
# a certain size
import sys
import os

if len(sys.argv) != 3:
    print("usage: python e5pad.py [filename] [length]")
    exit()
    
# grab file size
try:
    fsize = os.path.getsize(sys.argv[1])
except:
    print("cannot find file!")
    exit()

# calculate number of bytes to write
try:
    nbytes = int(sys.argv[2])- fsize
    if nbytes < 0:
        nbytes = 0
except:
    print("invalid size!")
    exit()

with open(sys.argv[1], "ab") as f:
    while nbytes > 0:
        f.write(b'\xE5')
        nbytes -= 1
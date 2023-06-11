# WIP DO NOT USE!

SYS = ../System
CONF = $(SYS)/config
DEV = $(SYS)/dev
BIN = $(SYS)/bin
RES = $(SYS)/res
DIRCT = ../Directory
OUT = ../Output
CPMSYS = $(SYS)/bios.asm $(SYS)/CPM22.asm
BUILD = ../Build

all: nabu
	
nabu: nabu_fdc

# STUFF FOR NABU FDC STARTS HERE:

OUT_NFDC = $(OUT)/Nabu_FDC
	
nabu_fdc: $(OUT)/Nabu_FDC/ishkur_fdc_ssdd.img
	
$(OUT)/Nabu_FDC/ishkur_fdc_ssdd.img: $(BIN)/boot_fdc.bin $(BIN)/cpm22_fdc.bin $(DIRCT)/*
	mkfs.cpm -f osborne1 -b $(BIN)/boot_fdc.bin -b $(RES)/licca_font.bin -b $(BIN)/cpm22_fdc.bin $(OUT_NFDC)/ishkur_fdc_ssdd.img
	cd $(DIRCT) ; cpmcp -f osborne1 ../$(OUT_NFDC)/ishkur_fdc_ssdd.img * 0:
	
$(OUT)/Nabu_FDC/ishkur_fdc_ssdd_empty.img:
	mkfs.cpm -f osborne1 $(OUT_NFDC)/ishkur_fdc_ssdd_empty.img
	python 

$(BIN)/cpm22_fdc.bin: $(CPMSYS) $(CONF)/config_fdc.asm $(DEV)/*
	cd $(CONF) ; zasm config_fdc.asm -u -w -b cpm22.bin
	mv $(CONF)/cpm22.bin $(BIN)/cpm22_fdc.bin
	mv $(CONF)/*.lst $(OUT_NFDC)/Listings
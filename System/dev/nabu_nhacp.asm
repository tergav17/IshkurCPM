;
;**************************************************************
;*
;*   N A B U   N H A C P   F I L E S Y S T E M   D R I V E R
;*
;*     This driver allows for IshkurCP/M to mount external
;*     directories as file systems using the NHACP protocol.
;*     Unlike standard CP/M drivers, this is done by 
;*     directly intercepting BDOS calls. As a result, most
;*     BIOS calls are ignored, and a dummy DPH is provided
;*     is is enough for CP/M to select the driver without
;*     issue. As a result, the following line must be added
;*     to the 'syshook:' function in config.asm:
;*
;*     `call	nh_sysh`
;*
;*     This particular driver uses the Nabu HCCA port to 
;*     facilitate communication between it and an adapter
;*
;*     Logical devices are defined by numbered directories
;*     in the root NHACP storage areas. For example, minor
;*     device 0 is stored in the '0' directory.
;*
;*     In order to service CCP and GRB requests, the 
;*     following special files must exist:
;*
;*     '0/CPM22.SYS' <- For CP/M system components
;*     '0/FONT.GRB' <- For graphical driver components
;*
;*     Device requires 256 bytes of bss space (nh_bss)
;* 
;**************************************************************
;

;
;**************************************************************
;*
;*         D I S K   D R I V E   G E O M E T R Y
;* 
;**************************************************************
;

; TODO

; Driver entry point
; a = Command #
;
; uses: all
nhadev:	ret

; CP/M system hook
; Used to intercept certain syscalls
nh_sysh:ret
	

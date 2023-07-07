# Ishkur CP/M
An open source, modular CP/M distribution for the NABU computer. It is designed to work with both cloud based and local storage options. It is still very much a work in progress.

One of the core design ideas behind Ishkur is device modularity. Unlike standard CP/M, devices in Ishkur CP/M are self-contained. The only file that needs to be modified in order to add, remove, or reconfigure device drivers is `config.asm`. This makes spinning up a custom distribution that matches a target machine's hardware capabilities very easy. The hope is that this will facilitate support for a wide range of custom hobbyist hardware and software projects.

## Progress
As of updating this file. The NHACP-based system is nominally functional on real hardware. The FDC-based system works both in emulator and on hardware. Right now, the system is fairly bare-bones. However, the following features are included:

- Emulated VDP terminal with ADM-3A escape code support
- 80 column screen scrolling
- F18A 80 column mode
- Multi-directory submit files
- PROFILE.SUB auto execution at startup
- Full support for SSDD floppy disks on the FDC
- Ability to access virtual disks over a NHACP connection
- Direct file access over a NHACP connection
- Modified IOBYTE device redirection
- NABU printer support
- NABU serial option card support

Near-term goals include printer support, serial card support, and console redirection over NHACP, and maybe NABU-IDE support.

## Platform Distributions
### NABU FDC
Fairly self-explanatory. This is your classic CP/M operational environment. This allows the NABU to run completely disconnected from adapter software. Assuming the boot ROM is correct, this `ishkur_fdc_ssdd.img` disk image will self boot and contain a minimal set of CP/M software.

In order to modify or create a new disk image, cpmtools can be used. The disk format being used for this device is the `osborne1` diskdef. This also means that this distribution is capable of reading and writing from genuine Osborne 1 disk images. This is a fairly common disk format, so it can allow the NABU to act as a data transfer intermediate between a modern computer and older CP/M machines.

### NHACP NDSK
This distribution boots up from a NHACP-based network disk image. This image is treated as a normal drive by CP/M, and therefore contains a full CP/M 2.2 file system. The capacity of this emulated drive is 8MB, so there is plenty of space for programs and data. The disk format being used for this device is the `nshd8` diskdef.

It should be noted that the virtual disk image must be at least 8196 bytes long, or else it will result in read errors.

In order to boot NDSK from NHACP, the following files must be setup from the `Output_NDSK` directory:

1. `Output/FONT.GRB` must be moved to the NHACP root directory
2. `NDSK_CPM22.SYS` must be renamed to `CPM22.SYS` and moved to the NHACP root directory
3. `NDSK_DEFAULT.IMG` must be renamed to `NDSK_A.IMG` and moved to the NHACP root directory
4. `NDSK_BOOT.nabu` must be renamed to `000001.nabu` and moved to your adapter homebrew directory

### NHACP NDSK + FDC (Hybrid)
This build works exactly like the standard NHACP NDSK build, but has added support for the floppy drives. Logical drives C: and D: are mapped to floppy drive 0 and 1 respectively. 

### NHACP NFS
Similar to the NDSK distribution in that it functions over NHACP. However, it does not utilize a virtual disk image, and instead accesses remote file systems directly. This works by intercepting BDOS calls directly instead of servicing BIOS calls like a standard CP/M driver. However, NFS is still able to work alongside more traditional storage drivers by only intercepting calls that pertain to it.

Under NFS, each logical drive and user number combination corresponds to a different folder on the host system. The logical device will be converted to a letter A-P, and the user number will be converted to hexadecimal 0-F. For example, device 0 with user 0 will convert to the directory `A0/`. For most distribution, CP/M drives are mapped 1-1 with similarly named folders on the host system.

In order to boot NFS from NHACP, the following files must be setup from the `Output/Nabu_NFS` directory:

1. `Output/FONT.GRB` must be moved to `A0/` in the NHACP root directory
2. Optionally, all files in the `Directory` folder should be moved into `A0/` to give you some software to run on boot
3. `NDSK_CPM22.SYS` must be renamed to `CPM22.SYS` and moved to `A0/` in the NHACP root directory
4. `NFS_BOOT.nabu` must be renamed to `000001.nabu` and moved to your adapter homebrew directory

### NFS NDSK + FDC (Hybrid)
Similar to NDSK hybrid. Logical drives C: and D: are mapped to floppy drive 0 and 1 respectively. 

### NABU-IDE
Unlike the other builds, there is no disk image available to install this version. Instead, the `IDEGEN.COM` utility must be used to generate a system on the attached IDE drive. When the program is run, the user will be prompted to choose a system image. It is recommended that the `IDE + NFS` system is built first so that software can be downloaded onto the IDE drive later. Formatting can be disabled to allow user data to persist during a system generate.

Currently, the IDE driver allocates 32MB of the disk. This is divided up into four 8MB partitions, and mapped to A: - D: respectivly. The IDE drive must be at least 32MB in size, and free of any errors. 

## Building
### Windows
In order to build on Windows, ensure the following programs are installed:

- Python3

After that, go into the `Scripts` directory and run `build.bat`. This will take care of all assembly and boot image creation.

### UNIX-likes
There is a makefile in development to build all of the different Ishkur configurations. Hopefully this will become the default build method once it is finished.

# Ishkur CP/M
An open source, modular CP/M distribution for the NABU computer. It is designed to work with both cloud based and local storage options. It is still very much a work in progress.

One of the core design ideas behind Ishkur is device modularity. Unlike standard CP/M, devices in Ishkur CP/M are self-contained. The only file that needs to be modified in order to add, remove, or reconfigure device drivers is `config.asm`. This makes spinning up a custom distribution that matches a target machine's hardware capabilities very easy. The hope is that this will facilitate support for a wide range of custom hobbyist hardware and software projects.

## Progress
As of updating this file. The NHACP-based system is nominally functional on real hardware. The FDC-based system works in emulator, but has yet to be tested on hardware. Right now, the system is fairly bare-bones. However, the following features are included:

- Emulated VDP terminal with ADM-3A escape code support
- 80 column screen scrolling
- Full support for SSDD floppy disks on the FDC
- Ability to access virtual disks over an NHACP connection
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

In order to boot NDSK from NHACP, the following files must be setup from the `Output` directory:

1. `FONT.GRB` must be moved to the NHACP root directory
2. `NDSK_CPM22.SYS` must be renamed to `CPM22.SYS` and moved to the NHACP root directory
3. `NDSK_DEFAULT.IMG` must be renamed to `NDSK_A.IMG` and moved to the NHACP root directory
4. `NDSK_BOOT.nabu` must be renamed to `000001.nabu` and moved to your adapter homebrew directory

## Building
### Windows
In order to build on Windows, ensure the following programs are installed:

- Python3

After that, go into the `Scripts` directory and run `build.bat`. This will take care of all assembly and boot image creation.

### UNIX-likes
There is currently no pre-built shell script to build Ishkur. This will hopefully change soon.

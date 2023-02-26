# Ishkur CP/M
An open source, modular CP/M distribution for the NABU computer. It is (will be) designed to work with both cloud based and local storage options. It is still very much a work in progress.

One of the core design ideas behind  Ishkur is device modularity. Unlike standard CP/M, devices in Ishkur CP/M are fairly self-contained. This makes it fairly easy to create builds with significantly different abilities in terms of device accessibility. The goal here is to easily support third party hobbyist hardware, as well as reproduction NABU local storage options. Ishkur also deviates from standard CP/M BDOS + BIOS architecture, allowing for modification of the BDOS itself. This will allow for direct access to files on an external device, making Ishkur truly "cloud capable".  

## Progress
Right now, the goal is to get a minimal viable system booting on the NABU. This will be done with the NABU FDC as a local storage device. After that, efforts will begin to make the NABU capable of accessing external files through the network adapter.

# How to build and deploy vault boot

## Background
VaultBoot is based on [heads](https://github.com/osresearch/heads). Basically, its build system generates an ordinary Linux kernel image and an initrd containing various tools to act as its user space, and they can be run in various ways, such as being loaded by coreboot as a Linux payload, or being loaded by other boot loaders capable to load a Linux kernel with initrd.

If configured for coreboot, the original build system for Heads will try build a coreboot image and integrate resulted Linux kernel image and initrd into it, and the maintainer of Heads is focused on "adding more mainboard support to Heads", because they regard Heads as a project for firmware which can run directly on mainboards.

However, technically the payload (Linux kernel image and initrd) and coreboot could, and should be adjusted independently, so VaultBoot modifies the build system to make it possible to build the Linux kernel image and initrd only, and coreboot could be configured and built separately, only use VaultBoot as its payload.

## Configure Vaultboot
The top level config of Vaultboot is a "board" config, which lies on `boards/${boardname}/${boardname}.config`, and it refers to a coreboot config file and a linux config file. It is basically a list of Unix shell variable definitions, controlling the buildtime behavior of Vaultboot, and some are exported, which will be picked into the runtime config file in initrd, and affects the runtime behavior of Vaultboot. The referred linux config file and coreboot config file are their ordinary Kconfig file respectively.

Most buildtime options are defined in the main Makefile and module definitions under `modules` subdir, and runtime options are defined in shell scripts under `initrd`. Their role could be learned from these code.

Currently there are 3 generic "board" configs for x86_64 architecture: qemu-hvault-tpm2, qemu-hvault-generic, and qemu-hvault-legacy, which supports tpm2, tpm1 and no tpm, respectively. Despite their name, their resulted payload has no problem running on real mainboards. coreboot images for qemu will be built if you choose to build coreboot firmware for them.

USB stack will not be loaded by default. If you need to use USB keyboards, add a runtime option `export CONFIG_USB_KEYBOARD=y` to your "board" config.

## Customize your own Vaultboot
Put one of your OpenPGP public key under `initrd/.gnupg/keys/` with `.asc` or `.key` externsion. This key will be imported into the runtime GnuPG keyring and used to verify the signature of boot profiles.

### Customize Linux kernel
Invoke make against the cross toolchain and "board" config you choose to config Linux kernel
```
$ make BOARD=${boardname} CROSS=${cross_toolchain_prefix} linux.menuconfig
```
After this, invoking
```
$ make BOARD=${boardname} CROSS=${cross_toolchain_prefix} linux.saveconfig
```
will save your changes to the Linux config file referenced by the "board" config.

## Build Vaultboot
Selecting different "board" config builds different components, so which board config to use should always be assigned on the make(1) invocation, although the host tools could be shared.

First, build host tools, including special version of make and gawk, and cross compiler:

```
$ make BOARD=${boardname} musl-cross
```

Then, the payload could be built:

```
$ make BOARD=${boardname} CROSS=${cross_toolchain_prefix} payload
```

The result payload will appear as `build/${boardname}/bzImage` and `build/${boardname}/initrd.cpio.xz`

If building for aarch64, the "bzImage" is actually a gzip-compressed raw binary executable (Image.gz).

Currently, valid value of ${CROSS} could be `$(pwd)/crossgcc/bin/aarch64-linux-musl-`, `$(pwd)/crossgcc/bin/x86_64-linux-musl-` and `$(pwd)/crossgcc/bin/i386-linux-musl-`

If building for x86_64, ${CROSS} could be omitted and host tools will be automatically built prior to the payload, but this practice is not recommended, especially when host tools are already available.

Note: If you once built Vaultboot for an architecture, and you are going to build for another architecture, you should delete all possible remaining object files which may potentially interfere the build process before building, by invoking

```
$ make BOARD=${boardname} CROSS=${cross_toolchain_prefix} real.clean
```

otherwise remaining object files may be erronously linked against, and ruin the build process. If you are going to build for another board with the same architecture, real.clean is not necessary.

"grub-wrapped payloads" mentioned in `Handle-FB.md` can be build with

```
$ make BOARD=${boardname} CROSS=${cross_toolchain_prefix} gwpl
```
and the result will appear as `build/${boardname}/gwpl.elf`.

## Integrate Vaultboot payload to coreboot
Copy or symlink resulted bzImage and initrd.cpio.xz into a directory convenient for the coreboot repository, and config coreboot with menuconfig, nconfig, etc:

```
$ make menuconfig
```

Step into "Payload" submenu, choose "A Linux payload" in "Add a payload" (Kconfig option `PAYLOAD_LINUX=y`), type the path to bzImage to "Linux path and filename" (Kconfig option `PAYLOAD_FILE`), type the path to initrd.cpio.xz to "Linux initrd" (Kconfig option `LINUX_INITRD`).

A "grub-wrapped payload" could be added as "An ELF executable payload" (Kconfig option `PAYLOAD_ELF=y`), type the path to gwpl file to "Payload path and filename" (Kconfig option `PAYLOAD_FILE`). To make full use of gwpl, the coreboot had better be configured to use "Linear 'high-resolution' framebuffer" (in submenu Devices/Display/"Framebuffer mode", corresponding to Kconfig option `GENERIC_LINEAR_FRAMEBUFFER=y` and `VGA_TEXT_FRAMEBUFFER` disabled).

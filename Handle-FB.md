# An approach for a better video compatibility around Linux payloads
## Framebuffer issue around Linux payloads
On X86, coreboot can initialize graphic subsystem in two ways: A legacy text mode framebuffer, or a linear "high-resolution" framebuffer. A Linux payload can handle legacy text mode framebuffer natively, and linear framebuffer with driver `simplefb`.

However, while a completely installed GNU/Linux OS usually work well upon them, as native drivers like i915 can perform mode settings, their installation environments may have problem when launched via `kexec` from a A Linux payload directly booted from coreboot. These installation environments usually have console or X-based graphic UI, but the linux kernel of most distribution does not have `simplefb` support, which means they cannot display anything on a framebuffer compatible with `simplefb`, like the linear framebuffer coreboot initializes.

Although they can display on legacy text mode, the more advanced usage, like displaying non-european characters or X-based graphic UI, needs a working video BIOS (usually provided by SeaBIOS payload), but it is usually not available when using a Linux payload, so installation environments can only display the most basic UI on it.

## A working walkaround: grub-wrapped payload
As noted in `BOOTMAGIC.md`, grub payload can convert coreboot's linear framebuffer into one compatible with `efifb`, and most installation environments support `efifb` out of the box, so if a coreboot sets up linear framebuffer and launches grub payload first, and grub then launches our Linux payload, it will work on `efifb`, together with installation environments launched from it, and they turn out to be working very well, either console or graphic UI, with quite "high-resolution", as if they were launched by a real UEFI.

However, we may have measured boot enabled on coreboot, and what grub payload loads (from CBFS or elsewhere) is not measured, so letting grub payload load our Linux payload from CBFS or elsewhere may not be acceptible.

Fortunately, grub provides the tool grub-mkimage, which can combine the kernel of grub, a lot of modules, a config script, and a tar file used as memdisk into a standalone ELF executable which suits coreboot as "ELF executable payload". When loaded, it will load all embedded modules, and execute the embedded config script. Thus, if we put the Linux payload (vmlinuz and initrd) into the tar memdisk, and write the config script so that its only purpose is to launch the Linux payload inside the memdisk, we can essentially turn grub into a stub for Linux payload, which can convert coreboot's linear framebuffer into one compatible with `efifb`, and because we pack the Linux payload and the grub "stub" into **one** payload executable to be loaded by coreboot, it will not break the measured boot, as nothing should be loaded from CBFS or elsewhere any more.

The procedure described above has been written into a script under `bin/grub-wrap`, which needs an installation of grub built for i386-coreboot (grub-coreboot-bin) to work.

By wrapping a Linux payload with grub in this way, we can have a powerful Linux payload, while keeping the graphic compatibility with the installation environment of most GNU/Linux distributions, at the cost of a little capacity (less than 100kB).

Note that to make full use of "grub-wrapped payload", it had better be loaded from a coreboot configured to set up linear "high-resolution" framebuffer ("simplefb"), which will be converted to "efifb" later by the "stubbed" grub. If loaded from a coreboot setting up a legacy text mode framebuffer, we can still only get a text mode environment without a video bios, that has very limited graphic capability.

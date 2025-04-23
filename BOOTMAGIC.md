# The magic about how modern OS boot

## Linux kernel
Under x86/amd64 architecture, Linux kernel is usually packed into `bzImage` format, which contains a partially-filled data structure for boot parameter, and multiple entry points of stages for 16-bit real mode, 32-bit protected mode, and 64-bit long mode if built for amd64, the last stage is a self-decompressing flat binary, which will decompress and execute the gzip-compressed kernel image proper, also in the format of flat binary, stored in its data segment. Each stage will initialize the proper execution environment for the next stage, switch CPU to the mode in which the the next stage can work, and then execute the next stage.

Of course Linux kernel is able to boot from 16-bit real mode, but it also allows a bootloader to prepare an execution environment (e.g. 32-bit protected mode or 64-bit long mode) for a later stage, and execute Linux kernel from the corresponding entry point. For example, if a bootloader itself mainly works in 32-bit protected mode, then booting Linux kernel from its 32-bit protected mode entry point would be the most efficient way, and a Linux kernel built for amd64 will choose the entry point for 64-bit long mode when booting another Linux kernel built for amd64 with kexec.

## SeaBIOS
SeaBIOS itself mostly works in 32-bit protected mode, with plain paging (in which a virtual address equals to the corresponding physical address), and only works in 16-bit real mode when responding BIOS interrupt call, during which SeaBIOS will switch to 32-bit protected mode for the actual handing, then switch back to real mode and return to the caller, as well as executing the boot sector (via BIOS interrupt call 0x19). If executing a Multiboot-compliant payload working in 32-bit protected mode, SeaBIOS will load and execute it directly, without actually switching to real mode.

## Grub2
Under x86/amd64 architecture, only building against UEFI for amd64 will Grub2 run in 64-bit long mode. In most other cases,  Grub2, as a Multiboot-compliant boot loader,  mostly runs in 32-bit protected mode. Even when launched from a boot sector (built for i386-pc), Grub2 will soon switch from real mode to protected mode.

If launched from a boot sector, Grub2 will make use of virtual 8086 mode to perform BIOS interrupt calls in order to access hardware, and generates video outputs by calling video BIOS (via BIOS interrupt call 0x10).

If working as a UEFI application, Grub2 could directly call UEFI funtions for hardware access, use the UEFI GOP driver for video outputs, and leave the framebuffer provided by GOP driver to the OS it boots.

If built as a coreboot payload, Grub2 mostly uses its native drivers for hardware access. For video outputs, Grub2 as a coreboot payload will directly use the framebuffer initialized by coreboot, but interestingly, if coreboot provides a linear "high-resolution" framebuffer, Grub2 will wrap this framebuffer into one like "efifb", (because Linux kernel would use driver `efifb` for video outputs after booted from Grub2 payload. When directly booted from coreboot, Linux kernel uses `simplefb` to handle such linear "high-resolution" framebuffer) though no real EFI involved.

When booting a Linux kernel with its `linux` command, Grub2 will choose the protected mode entry point.

# A weird bug of QEMU and how to walk around it
Recently, [a bug of QEMU](https://lore.kernel.org/all/YjHMEsXiraMrOLN4@MiWiFi-R3L-srv/T/) causes kernel panic after kexec because kexec-ed kernel will fail to decompress a compressed initrd. This bug only affects kexec-ing a new Linux kernel with a compressed initrd in QEMU. kexec on physical machines, as well as other ways to boot Linux kernel with a compressed initrd in QEMU, are unaffected.

Furtunately, kexec-ing a new Linux kernel with an UNcompressed initrd in QEMU works, so if you want to use a kexec-based bootloader in in QEMU, you may have to use uncompressed initrd for the target system to boot.

However, out-of-the-box Debian-based GNU/Linux distributions can only generate compressed initrd, with an option to select compression algorithm (excluding "none"), so in order to generate uncompressed initrd, you may have to patch `/usr/sbin/mkinitramfs` with the patch below, set `COMPRESS=none` to /etc/initramfs-tools/initramfs.conf, and regenerate initrd by executing `# update-initramfs -ck all`.

```
--- /usr/sbin/mkinitramfs	2022-06-30 15:18:48.958885506 +0800
+++ /tmp/mkinitramfs	2022-06-30 15:19:50.609315049 +0800
@@ -169,7 +169,7 @@ if [ -z "${compress:-}" ]; then
 fi
 unset COMPRESS
 
-if ! command -v "${compress}" >/dev/null 2>&1; then
+if [ "${compress}" != "none" ] && ! command -v "${compress}" >/dev/null 2>&1; then
 	echo "W: No ${compress} in ${PATH}, using gzip" >&2
 	compress=gzip
 fi
@@ -177,7 +177,7 @@ fi
 # Check that kernel supports selected compressor, and fall back to gzip.
 # Exit if even gzip is not supported.
 case "${compress}" in
-gzip)	kconfig_sym=CONFIG_RD_GZIP ;;
+gzip|none)	kconfig_sym=CONFIG_RD_GZIP ;;
 bzip2)	kconfig_sym=CONFIG_RD_BZIP2 ;;
 lzma)	kconfig_sym=CONFIG_RD_LZMA ;;
 xz)	kconfig_sym=CONFIG_RD_XZ ;;
@@ -216,6 +216,9 @@ xz)	compress="xz --check=crc32"
 bzip2|lzma|lzop)
 	# no parameters needed
 	;;
+none)
+	compress="cat"
+	;;
 *)	echo "W: Unknown compression command ${compress}" >&2 ;;
 esac
 
@@ -467,8 +470,13 @@ if [ -s "${__TMPEARLYCPIO}" ]; then
 	cat "${__TMPEARLYCPIO}" || exit 1
 fi
 
-$compress -c "${__TMPMAINCPIO}" ||
-	{ echo "E: mkinitramfs failure $compress $?" >&2; exit 1; }
+{
+if [ "$compress" = "cat" ]; then
+$compress "${__TMPMAINCPIO}"
+else
+$compress -c "${__TMPMAINCPIO}"
+fi
+} || { echo "E: mkinitramfs failure $compress $?" >&2; exit 1; }
 
 if [ -s "${__TMPCPIOGZ}" ]; then
 	cat "${__TMPCPIOGZ}" || exit 1
```

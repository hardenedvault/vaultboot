# Setup TPM-based Full-disk Encryption Unlocking

If TPM is available, and the OS has a LUKS to unlock during the boot process, Vaultboot can add a random key to the LUKS, and seal the key into the TPM (If runtime config `CONFIG_AUTO_UNLOCK` is not set to y, the key needs a passphrase to unseal). If the key could be successfully unsealed, Vaultboot will copy the initrd of the OS to its tmpfs, append the key and a crypttab item into the copied initrd, and boot the OS with the modified initrd, so the LUKS will be unlocked by the key during the boot process.

After adding the key, the LUKS header will be measured into a PCR, which is one of the PCRs against which the unlocking key is sealed. Thus if the firmware or the LUKS header is altered, the key will not be unsealed anymore and the automated boot process will be interrupted. If it is intended, a new key could be generated and sealed for the LUKS, if there are other means to unlock the LUKS to add the new key.

## Prerequest
An ordinary GNU/Linux installation with separate, unencrypted boot partition, and valid `grub.cfg`. Its LUKS container(s) are to be unlocked with the same passphrase from key slot 0 by the initrd during boot process via `crypttab`.

## Preparation
In order to make the installation capable to be unlocked by Vaultboot, the target system itself needs some midifications.

First of all, Vaultboot will use "LABEL=boot" as a hint to find the boot partition, so you should change the volume label of the boot partition to "boot", and ensure no other partition use such label.

Second, Vaultboot unlocks the LUKS of the target system by generating a crypttab file, in which the LUKSes to unlock is configured to be decrypted by a key file unsealed from the TPM, packing the crypttab and the key file into a cpio archive, and then append the cpio archive to the initrd of the target system copied into the tmpfs of Vaultboot. After this, Vaultboot kexec the kernel of the target system with the modified initrd, and then the crypttab in the append archive will override the one in the original initrd to unlock the LUKSes with the key file.

In the generated crypttab, Vaultboot always names the LUKSes to unlock in the format of "luks-$uuid", so you should modify the first field of the line for the volume to be unlocked by Vaultboot in the crypttab of the target system to the same "luks-$uuid" format, otherwise the boot sequence will get stuck when OS is trying to unlock them again, with a different name.

Third, the path to store the crypttab in the initrd may differ among distros, but finding it at runtime needs to unpack the initrd, which may be hard to do, because of various compression method and possible prepending microcodes, so the path to crypttab in the initrd is made overridable with a file at `/boot/kexec_initrd_crypttab_path.txt`, whose content could be obtained with `$ lsinitramfs ${initrd} | grep crypttab` . If `/boot/kexec_initrd_crypttab_path.txt` is absent, the default path is `etc/crypttab`.

## Setup
Besides normal provision, TPM-helped unlocking needs some additional info to set up.

After you select a default boot item, and decide to make it default, Vaultboot will ask "Do you wish to add a disk encryption to the TPM [y/N]: ". If you choose "Y", Vaultboot will ask you `LVM group containing Encrypted LVs` (if present) and `Encrypted devices`, note: the actual effect values of these two fields only depend on what you type, and the old values are only shown as hints. so if you want to keep old values, you should type them again.

If Vaultboot successfully finds the LUKSes to unlock, it generates a random key file, and you will be asked for the same passphrase to unlock every LUKSes, and the passphrase to unseal the key file if so configured. Vaultboot will add key slot 1 to each LUKS to unlock, and key slot 1 will be unlocked with the key file.

After the key slots for file are added, Vaultboot will extract headers from all LUKSes to be unlock by Vaultboot, measure them to PCR 6, seal the key file against PCR 0,1,2,3,4,5,6,7, then reboot. You do not need to manually unlock affected LUKSes after the key file is successfully unsealed.

If the signature of the boot hash tree becomes invalid because key components (e.g. Linux kernel and/or initrd) get updated, without affecting the LUKSes, you should answer `N` when asked "Do you wish to add a disk encryption to the TPM [y/N]: " during signing the regenerated boot hash tree, since there is no need to do so in this situation.

## Suggestion
Since Vaultboot assume all LUKSes to be unlocked by it could be unlocked by the same passphrase, if you have multiple LUKSes to be unlocked by different passphrases, you could chain them in other way, and only configure the LUKS containing the root file system to be unlocked by Vaultboot.

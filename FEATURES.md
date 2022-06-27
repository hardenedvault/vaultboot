# Introduction

VaultBoot is a coreboot payload (but also capable to build into a UEFI boot manager) highly focus on firmware security, trusted computing and advanced defense. It implements many features which will be described below.

## Architecture
VaultBoot is mainly a Linux kernel packaged with an initrd used as its own user space. With bundled tools and scripts, it can find and mount the partition containing the Linux kernel and initrd installed by the operating system (the boot partition), and parsing the corresponding grub.cfg. It can boot the kernel of the OS via kexec. With boot configurations stored in the boot partition, the boot process can be automated.

## Verified boot
Also known as Secure Boot in UEFI circle, this feature means only signed kernel as well as accompanied data (e.g. initrd) could be loaded to boot in normal boot process.

In UEFI circle, the signature should be stored in the same file of the kernel, thus dedicated tool is needed, and the signing process is hard to operate.

In Vaultboot, signature verification process is done by the bundled gnupg tool. A dedicated gnupg keychain containing the public keys could be bundled into its initrd. The kernel, initrd and boot config would be siged by the corresponding private key stored in a smartcard, and the signature would be stored in the boot partition as a separated file, and the following signing processes could be done in the os, without modifying the kernel file itself. If the signature becomes invalid, the automated boot process will be interrupted, and Vaultboot will provide a recovery shell for the administrator to manually boot the OS, or fix the signing chain.

## Measured boot
If the mainboard is equipped with a TPM, coreboot could also be built to measure all components it loads (including the payload). Vaultboot could also be built with TPM (1 or 2) capability. If so, it can seal a random secret into the TPM, against the PCRs coreboot uses to measure itself, and present the random secret as a TOTP in the boot process for the administrator to verify. If the firmware is altered, the PCRs will change, and the sealed secret verified by the administrator can no longer be unsealed out of the TPM, in order to alert the administrator for unintended modifications of the firmware.

This could be a form of local attestation. If verifing the TOTP in the boot process is inconvenient, remote attestation could be used.

If the secret failed to be unsealed, the automated boot process will be interrupted, and a recovery shell will be provided.

## TPM-based FDE (Full-disk encryption)
If TPM is available, and the OS has a LUKS to unlock during the boot process, Vaultboot can add a random key to the LUKS, and seal the key into the TPM (with or without a passphrase). If the key could be successfully unsealed, Vaultboot will copy the initrd of the OS to its tmpfs, append the key and a crypttab item into the copied initrd, and boot the OS with the modified initrd, so the LUKS will be unlocked by the key during the boot process.

After adding the key, the LUKS header will be measured into a PCR, which is one of the PCRs against which the unlocking key is sealed. Thus if the firmware or the LUKS header is altered, the key will not be unsealed anymore and the automated boot process will be interrupted. If it is intended, a new key could be generated and sealed for the LUKS, if there are other means to unlock the LUKS to add the new key.

## Parameter Encryption
In TPM2, a new feature is introduced to encrypt the sensitive parameters (e.g. the plaintext to seal/unseal) with a session key exchanged with keys generated inside TPM. Vaultboot will make use of this feature to defend physical attacks such as TPM Genie.

## Remote attestation
Vaultboot is now capable to do remote attestation during TPM-based full-disk encryption unlocking, and will refuse to proceed if remote attestation is not passed.

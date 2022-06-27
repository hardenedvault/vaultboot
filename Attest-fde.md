# Setup TPM-based Full-disk Encryption Unlocking With Remote Attestation

With scripts from `V-Attest` introduced, now Vaultboot is capable to do remote attestation during TPM-based full-disk encryption unlocking, and will refuse to proceed if remote attestation is not passed.

## Prerequisites
* Vaultboot firmware with remote attestation enabled
* An ordinary GNU/Linux installation fit the need of TPM-based Full-disk Encryption Unlocking

## Vaultboot Configuration
To enable remote attestation capability, the following configs should be added to the "board" level config file before build Vaultboot:

```
CONFIG_CURL=y
CONFIG_BASH=y
CONFIG_VIM_XXD=y
export CONFIG_ATTEST_TOOLS=y
```

because scripts from "attest-tools" (V-Attest) need `bash` to interpret and `curl` for http communication, and the `xxd` tool shipped with `vim` should be used instead of the one included in `busybox` for their different behavior.

The address and port where the attestation server is listening (e.g. `192.168.1.2:8080`) should be saved to kexec_attest_server.txt along with other kexec_*.txt files on disk. The address part could be IPv4 address or DNS domain name, but mDNS domain name is not supported currently, due to the limitation of musl libc.

Additional preparations to fit the needs of TPM-based Full-disk Encryption Unlocking are also necessary.

## Setup
Extract public part of the Endorsement Key with the following command: (either under recovery shell of Vaultboot or under OS)

```
$ tpm2 createek -G rsa -c ek.ctx -u ek.pub
```

Send ek.pub to the administrator of attestation server, and then ask them to enroll data and accept trial attestation for your EK.

Following the ordinary procedure to setup TPM-based Full-disk Encryption Unlocking. During the process, Vault boot will generate quote against PCR 0,1,2,3,4,5,6,7 and send to the attestation server. Because PCR 6 (containing measurement of the LUKSes to be unlocked) cannot hold the final value in this phase for the key to unlock them has not set yet, trial attestation in this phase is necessary, and it will pass if only the EK given to the administrator of attestation server match the one stored in the TPM2. A random key encrypted against the EK during enrollment could be decrypted with the help of TPM2, if only PCR 11 keeps all zero. The rest procedure and mechanism is nearly identical to TPM-based Full-disk Encryption Unlocking, with the only exception that the key sealed into TPM should be concatenated with the key obtained from attestation server to form the final key to unlock LUKSes.

After the boot hash tree is signed, Vaultboot will reboot itself. This time it will perform remote attestation during boot procedure, and PCR 6 will have the expected value. It should boot into OS if all configs are green. After having confirmed this, you could ask the administrator of attestation server to turn on formal attestation for (the EK of) you. The first PCR value list sent to the attestation server after formal attestation is turned on will be trusted and stored on the server, and mismatch against it will fail the remote attestation.

After some legal upgrades causing concerned PCRs to change (e.g. change the firmware and/or the LUKSes), you should ask the administrator of attestation server to invalidate the old trusted PCR value list and turn on trial attestation for you, and redo the whole setup.

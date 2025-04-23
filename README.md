## [VaultBoot](https://hardenedvault.net/vaultboot/)
In the highest level of security profile (CRITICAL), the Vault 111 hardware node enables multi-trust anchors through the chip security features. The Next-Gen firmware architecture deal with hardware initialization and execution payload separately. Vaultboot is based on [heads](https://github.com/osresearch/heads). It's developed and maintained by HardenedVault. HardenedVault upstreamed a several features as well. Vaultboot is a firmware security payload highly focus on trusted computing and advanced defense, e.g: Verified boot (also known as Secure Boot) and measured boot, TPMv2 based FDE (Full-disk encryption), local/remote attestation, built-in DH key exchange against physical attack such as TPM Genie.

## Why not contribute to the "upstream"

* Heads is an open source project initiated by Trammel Hudson in the early years (2016) with the goal of replacing the bloated UEFI DXE drviers with Linux payload. But Mr.Hudson did not participate much in the work of heads since 2017.

* In 2017, heads changed their original goal, that is, the heads existed as the payload of coreboot, and we don't quite understand why heads tested coreboot and payload as a whole, which is a time-consuming work even for a regular regressional test, which may be one of the reasons why heads seem to be more "active" although most of commits aren't features-related.
   
* The prototype of VaultBoot's development began in 2019, when HardenedLinux used SMI handler (via SMM) for lock reg on chipset, and later VaultBoot continued to develop many features including TPM2 support, TPM-based FDE, and params encryption due to the need for advanced threat protection nodes. The philosophy of heads and vaultboot is different, heads see themselves as a complete solution (don't remember when they deleted the option which allows you to choose build heads as a complete firmware or only build it as a Linux payload for coreboot), while VaultBoot continues to stick with KISS principles and exists only as a Linux payload (which can work with coreboot but also UEFI and even legacy BIOS, with necessary adaptions). On the other hand, heads targets individual users, and VaultBoot's main goal is to reduce the deployment cost of advanced threat protection technology so that more SMEs and NGOs can use it.

## VaultBoot features
Check the detail in [FEATURES](https://github.com/hardenedvault/vaultboot/blob/master/FEATURES.md) or our previous [write-up](https://hardenedvault.net/blog/2021-09-19-vaultboot/). Please noted that we only tested VaultBoot on rpi4. This is the features listed:

|Features     | x86_64 | arm64 |
|:-----------:|:------:|:-----:|
|Verified boot| YES   | YES    |
|Measured boot|TPMv1.2/v2.0    | TPMv2.0   |
|DRTM         | Partially CBnT| N/A    |
|[TPM-based FDE (Full-disk encryption)](https://github.com/hardenedvault/vaultboot/blob/master/Autoboot-fde.md)| YES   | YES    |
|Parameter Encryption| YES   | YES    |
|[Remote attestation](https://github.com/hardenedvault/vaultboot/blob/master/Attest-fde.md)| YES   | YES    |

Contrast to tpm1, tpm2-tools does not support sealing that requires both PCRs and password being correct to unseal, so when using tpm2, openssl executable is used to handle the passphrase.

## How to build VaultBoot
Please check the [HowtoBuild document](https://github.com/hardenedvault/vaultboot/blob/master/Howtobuild.md).

## What's the typical attestation look like?
![](https://hardenedvault.net/images/products/attestation_huf5b4407823571d8d0e8cc33f4d50f1ef_233100_996x311_fit_q100_h2_box_3.webp)

## Example of remote attestation with FDE (full-disk encryption)
![](https://hardenedvault.net/images/products/aaas_hu650bdf8a2d23b53ed32ff830fdaf970f_68933_1049x461_fit_q100_h2_box_3.webp)

Step 1: node extracts the public part of EK, sends it to the admin of atestation server.

Step 2: admin genrates enrollment data for the ek (containing symmetric key encrypted against the EK) and deploy them to the attestation server, enabling trial attestation for this EK (ignore PCR value).

Step 3: node generates one-time AK and AK-signed quote, sends quote to attestation server.

Step 4: During trial attestation, server verifies quote is AK-signed and AK is enrolled, sends encrypted enrollment data against EK to node.

Step 5: node decrypts encrypted enrollment data and further obtains symmetric key，set up FDE with symmetric key combined with local key.

Step 6: node confirms bootable under trial attestation, ask admin of attestation server to enable formal attestation for their EK (trust first received PCR value after enabling).

Step 7: node boot under formal attestation.

## [SaaS (Security as a Service)](https://hardenedvault.net/saas)
VaultBoot plays the crucial role for SaaS provided by HardenedVault. We will continue to support the open source cause to benefit both community and our clients.

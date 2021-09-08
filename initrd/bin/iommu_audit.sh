#!/bin/sh

#    shopt -s nullglob
echo "###########################################################################"
echo -e "[+] \e[93mChecking Peripheral devices on IOMMU\e[0m"
echo "---------------------------------------------------------------------------"

devs=`lspci -nn|cut -d" " -f1`
iommu_dev=`for d in /sys/kernel/iommu_groups/*/devices/*; do echo ${d#/*devices/} | cut -c 6-; done;`

for d in $devs; do
	echo "$iommu_dev" | grep -q $d
	if [ $? -eq 0 ]; then
		echo -e "IOMMU group `for d2 in /sys/kernel/iommu_groups/*/devices/*; do n=${d2#*/iommu_groups/*}; echo ${d2#*/iommu_groups/*} | grep -F "$d" | cut -d"/" -f1;done;` :`lspci -nns $d` :\e[92m Pass\e[0m"
	else
		echo -e "Warning:\e[91m High risk device( `lspci -nns $d` ) has been found \e[0m, please contact your security consultant!"
	fi
done


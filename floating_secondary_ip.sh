#!/bin/bash

#####Hardset Variables
#OCID of the secondary IP. This needs to be created in the OCI console if it's not already built.
###Example
#secondary_private_ip_ocid=ocid1.privateip.oc1.iad.aaaaaaaaoxd26mmgbduy5dxthw5dt64nofwepkcbrun4qfesc3w4e3eadrua
secondary_private_ip_ocid=

######Script#####
#Make sure the secondary_private_ip_ocid variable is set.
if [ -z "$secondary_private_ip_ocid" ]; then
    echo "secondary_private_ip_ocid needs to be set before the script can run."
    exit 0
fi

#Collect the OCID of the primary vNIC from the OCI Metadata service.
compute_instance_vnic=$(curl -s -H 'Authorization: Bearer Oracle' http://169.254.169.254/opc/v2/vnics | jq '.[].vnicId' | tr -d "'\"")
echo "Compute Instance vNIC, $compute_instance_vnic"

#Query the OCI CLI to find which vNIC has the secondary IP address.
secondary_ip_vnic=$(oci network private-ip get --private-ip-id $secondary_private_ip_ocid --auth instance_principal --query data.\"vnic-id\"| tr -d "'\"")
secondary_ip_address=$(oci network private-ip get --private-ip-id $secondary_private_ip_ocid --auth instance_principal --query data.\"ip-address\" | tr -d "'\"")
echo "Secondary vNIC OCID, $secondary_ip_vnic"
echo "Secondary vNIC IP Address, $secondary_ip_address"

#Check ff the Compute vNIC is already assigned the secondary/floating IP address.
if [ $secondary_ip_vnic == $compute_instance_vnic ]; then
    echo "The instance vNIC and secondary IP address vNIC already match"
    echo "Checking if ens3 already as the IP assignment."
fi

#If the assigned vNIC for the secondary IP and the compute instance vNIC are not the same, float the IP to the new vNIC.
if [ $secondary_ip_vnic != $compute_instance_vnic ]; then
    echo "Secondary IP address $secondary_ip_address is floating to this instance"
    float_secondary_ip=$(oci network vnic assign-private-ip --unassign-if-already-assigned --auth instance_principal --vnic-id $compute_instance_vnic --ip-address $secondary_ip_address)
fi

#Find if secondary IP is assigned to the local machine
local_machine_secondary_ip=$(ip a | grep "secondary ens3" | awk -F ' ' '{print $2}')
local_machine_secondary_netmask=$(ip a | grep "dynamic ens3" | awk -F ' ' '{print $2}' | awk -F '/' '{print "/"$2}')

#If the secondary IP exists, make sure it matches the floating IP.
#If secondary ens3 doesn't exist, get the subnet mask of the primary IP address and add the secondary IP address. 
#NOTE: Both IP's will be in the same subnet as a requirement of secondary IP's

#If the script wasn't able to find an assigned secondary IP address, the local_machine_secondary_ip variable will be empty and we will assign it here.
if [ -z "$local_machine_secondary_ip" ]; then
    echo "Setting the IP address of the vNIC, since it's not currently configured"
    sudo ip addr add $secondary_ip_address$local_machine_secondary_netmask dev ens3
fi

#If the secondary IP address is already set, make sure it's the correct IP address before exiting the script.
if [ ! -z "$local_machine_secondary_ip" ]; then
    echo "Checking secondary IP assignment on ens3"
    if [ "$secondary_ip_address$local_machine_secondary_netmask" != "$local_machine_secondary_ip" ]; then
            echo "ERROR: This script can delete the mismatched IP configuration here, but there is most likely a bigger problem going on."
            echo "The IP address has not been added to the ens3 instance of this instance."
            #sudo ip addr del $local_machine_secondary_ip
            exit 0
    else
        echo "Secondary IP $secondary_ip_address is already assigned to ens3"
    fi
fi

echo ""
echo "Script complete!"
echo "Floating IP has moved to the local OCI instance."
echo "The ens3 interface has $secondary_ip_address assigned as a secondary IP address."
exit 0

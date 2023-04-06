#!/bin/bash

#####Hardset Variables
#OCID of the secondary IP. This needs to be created in the OCI console if it's not already built.
secondary_private_ip_ocid=ocid1.privateip.oc1.iad.aaaaaaaaoxd26mmgbduy5dxthw5dt64nofwepkcbrun4qfesc3w4e3eadrua

#####Description of the script
#1.) Compares the secondary IP Address vNIC to the instance assigned vNIC and move the secondary IP address over to the primary vNIC of the compute instance.
#2.) If the ens3 interface doesn't have the secondary IP address assigned, update the local interface with the IP address of the secondary IP.

#####Pre-Reqs
#1.) Install the OCI CLI for Oracle Linux 8 before being to use this script. https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm#InstallingCLI__oraclelinux8
#2.) If you want this script to update the secondary IP address on ens3, the user needs to have SUDO capabilities.
#3.) Setup a dynamic group and policy for instance principal authentication (Instructions below)

#DYNAMIC GROUP AND POLICY CREATION REQUIREMENTS
#1.) create dynamic group "highly-available-instances
#2.) add a policy that adds the instance OCID for all of the instances.

#DYNAMIC GROUP AND POLICY CREATION EXAMPLE
#Dynamic Group Name - highly-available-instances
#Dynamic Group Rules - Any {instance.id = 'ocid1.instance.oc1.iad.anuwcljtc3adhhqcuw2vbj2dkpnikln3e6r6jjngpa7f5p6mxuhp5kz3ej3a', instance.id = 'ocid1.instance.oc1.iad.anuwcljtc3adhhqcygfloziau6nzmwfjwoyevvgifenjjlujmgiqm73fajpq'}
#Policy Name - Floating-IP-Policy
#Policy Rules - 
#1.) allow group highly-available-instances to use private-ips in compartment Bloom
#2.) allow group highly-available-instances to use vnics in compartment Bloom

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

#Authored by Jake Bloom
#Version 1.0

***This script was Authored by Jake Bloom OCI Principal Network Solution Architect. This is not an Oracle supported script. No liability from this script will be assumed and support is best effort.***

# float_secondary_ip
To install the script, run the following.

1.) curl https://raw.githubusercontent.com/jake-oci/float_secondary_ip/main/floating_secondary_ip.sh --output floating_secondary_ip.sh && chmod +x floating_secondary_ip.sh

2.) Update the "secondary_private_ip_ocid" variable with the OCID of your secondary private IP "ocid1.privateip.xxx"

3.) Run "./floating_secondary_ip.sh"

## Description
Float the secondary IP address of an Oracle Linux 8 Instance

This script is intended to provide a failover mechanism for secondary IP addresses to "float" the IP address to the active node. This script might pair well with cluster IP services such as keepalived, but has not been tested at this time. 

## Functionality

1.) Compares the secondary IP Address vNIC to the instance assigned vNIC and move the secondary IP address over to the primary vNIC of the compute instance.

2.) If the ens3 interface doesn't have the secondary IP address assigned, update the local interface with the IP address of the secondary IP.

## Pre-Reqs

1.) Install the OCI CLI for Oracle Linux 8 before being to use this script. https://docs.oracle.com/en-us/iaas/Content/API/SDKDocs/cliinstall.htm#InstallingCLI__oraclelinux8

2.) If you want this script to update the secondary IP address on ens3, the user needs to have SUDO capabilities.

3.) Setup a dynamic group and policy for instance principal authentication (Instructions below)

## DYNAMIC GROUP AND POLICY CREATION REQUIREMENTS

1.) Create dynamic group "highly-available-instances" and add each of the instance OCID's to the dynamic group. 

2.) Add a policy that adds the instance OCID for all of the instances.

**DYNAMIC GROUP AND POLICY CREATION EXAMPLE
**

**Dynamic Group Name -**

highly-available-instances

**Dynamic Group Rules -**

Any {instance.id = 'ocid1.instance.oc1.iad.anuwcljtc3adhhqcuw2vbj2dkpnikln3e6r6jjngpa7f5p6mxuhp5kz3ej3a', instance.id = 'ocid1.instance.oc1.iad.anuwcljtc3adhhqcygfloziau6nzmwfjwoyevvgifenjjlujmgiqm73fajpq'}

**Policy Name -** 

Floating-IP-Policy

**Policy Rules -**

1.) allow group highly-available-instances to use private-ips in compartment Bloom

2.) allow group highly-available-instances to use vnics in compartment Bloom

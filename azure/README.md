
## Building NetLab in Azure Cloud

**Ensure you have a Microsoft Azure account and Contributor access to a Azure Subscription.**

[**Azure**](https://azure.microsoft.com/en-gb/pricing/purchase-options/azure-account)

### Install Prerequisite Software on Window Client

All Provisioning was performed on a Windows Enterprise 10 Build 19045 Client 

Install Azure CLI: [**Azure CLI**](https://learn.microsoft.com/en-us/cli/azure/install-azure-cli-windows?view=azure-cli-latest&pivots=winget)

Install Git for Windows: [**Git for Windows**](https://gitforwindows.org/)

Install OpenVPN: [**OpenVPN**](https://openvpn.net/community-downloads/)

Install Hashicorp Packer: [**Packer**](https://developer.hashicorp.com/packer/install)

Install Hashicorp Terraform: [**Terraform**](https://developer.hashicorp.com/terraform/install) 

Verify Installation of all prerequesite software through the Powershell CLI:  

```
az --version
git --version
openvpn --version
ssh -V
packer --version 
terraform --version
```

### Image Build + Instance Provisioning

Authenticate to Azure and select the correct subscription to build resources.

```
az login
az account list
az account show
az account set --name "Systal DevTest"
```

The "*Systal DevTest*" is a subscription where I have Contributor role which 
enables me to create and delete Azure resources such as Images, Virtual 
Network, Network Security Group + Virtual Machine Instances.

Create a Resource Group for the Packer Image builds. The Resource Group name must be unique within the Azure Subscription.

```
az group create --name <RG-NAME> --location ukwest
```

Locally create keys for necessary for SSH and OpenVPN.

```
git clone
cd packer
ssh-keygen -f ~/.ssh/netlab -t rsa -b 4096 -N ""
openvpn --genkey secret secret.key
```
Verify the Resource Group is created. No resources should currently exist of course. 

```
az resource list --resource-group RG.LAB-Images | grep id
```
Create a NetLab base image using Packer. 

```
packer validate ubuntu-24.04.pkr.hcl
packer build ubuntu-24.04.pkr.hcl
```

The build process should take a few minutes and will install NetLab on a Ubuntu LTS base image together with prerequisite software.Additionally any Vagrant KVM boxes in the local *image* directory will be copied to the NetLab base image.

![NetLAB-Build](screenshots/netlab-image-build.jpg)

The Resource Group should now contain the new NetLab base image. Copy the *image-id* displayed as it will be used to launch an the NetLab instance through Terraform. When prompted by Terraform in the plan and apply process for the base-image variable paste in the *image-id*. Reply *yes* to the approval prompts in both the plan and apply process.     

```
az resource list --resource-group RG.LAB-Images | grep id

cd ../terraform

terraform init
terraform plan
terraform apply
```
Once the instance provisioning has completed start the OpenVPN client with the *clinet.conf.opvn* configuration file either through the client GUI or from the command line.

```
 openvpn --config <HOME-DIRECTORY-PATH>/OpenVPN/config/client.conf.ovpn --secret <HOME-DIRECTORY-PATH>/OpenVPN/config/secret.key
```
Using the OpenVPN GUI will probably be the better option as the command line execution may fail without administration level privileges. 

Once the VPN is established logon via ssh to the VM instance and verify that NetLab is installed correctly with both Containerlab and Libvirt virtualisation providers.

```
ssh -l netlab -i ~/.ssh/netlab -o StrictHostKeyChecking=no 192.168.122.1

netlab version
netlab test libvirt
netlan test clab
```
An initial 2-node lab can be deployed with the libvirt provider using isov image.

```
cd ~/initial
netlab up
netlab status
```
Access the routers within the topology via either the *netlab connect* command or direct via the ssh command.

```
netlab connect r1
ssh -l vagrant 192.168.121.101
```
Router configuration can now be protyped and tested. When complete destory the topology.    

```
netlab down
```

Logoff the and destory the VM instance.

```
az resource list --resource-group <IMAGE-RG> | grep id

terraform apply --destroy
```

## End
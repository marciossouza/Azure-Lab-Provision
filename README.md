# Azure-Lab-Provision
Create resources on Azure for Azure Active Directory LABS using Bicep

```
az deployment sub create --template-file <AADC-ADFS-LAB.bicep> --location "eastus" --parameters name="<ResourceGroupName>" adminPasswordOrKey="<UserPassword>" allowRDPFromAddress="$(curl ifconfig.me)"

```

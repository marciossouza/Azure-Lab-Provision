// =========================================================================================
// Deploy a LAB with 3 DC | 3 Windows Servers | 1 Windows 11 | 2 VNET | 3 Subnets
// =========================================================================================

targetScope = 'subscription'

@description('Name used for resource group, and base name for VM & resources')
param name string
@description('Azure region for all resources')
param location string = deployment().location

@description('Username for windows local admin')
param adminUser string = 'vmadmin'

@description('Admin password for windows local admin')
@secure()
param adminPasswordOrKey string

@description('Instance size of VM to deploy')
param size string = 'Standard_B2s'

@description('Create and assign a user managed identity to the VM')
param assignManagedIdentity bool = false

@description('Limit the NSG rule for RDP to certain addresses')
param allowRDPFromAddress string = '201.77.175.127'

// ===== Modules & Resources ==================================================

resource resGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: name
  location: location
}

module subnetNsg 'modules/network/nsg.bicep' = {
  scope: resGroup
  name: 'WinLabNSG'
  params: {
    name: 'vNet-LAB-NSG'
    location: location
    sourceAddress: allowRDPFromAddress
    openPorts: [
      '3389'
    ]
  }
}

module netSP 'modules/network/network.bicep' = {
  scope: resGroup
  name: 'SP-LAB-VNET'
  params: {
    name: 'SP-LAB-VNET'
    location: location
    defaultSubnetName: 'SP-Subnet'
    defaultSubnetCidr:'10.100.1.0/24'
    addressSpace:'10.100.0.0/23'
    nsgId: subnetNsg.outputs.nsgId
  }
}

// module snetSP 'modules/network/subnet.bicep' = {
//   scope: resGroup
//   name: 'Server-Subnet'
//   params:{
//     name: 'Server-Subnet'
//     vnetName: netSP.name
//     nsgId: subnetNsg.outputs.nsgId
//     addressPrefix: '10.100.2.0/24'
//   }
//   dependsOn: [
//     netSP
//   ]
// }

module netMG 'modules/network/network.bicep' = {
  scope: resGroup
  name: 'MG-LAB-VNET'
  params: {
    name: 'MG-LAB-VNET'
    location: location
    defaultSubnetName: 'MG-Subnet'
    defaultSubnetCidr:'10.200.1.0/24'
    addressSpace:'10.200.0.0/23'
    nsgId: subnetNsg.outputs.nsgId
  }
}

// module snetMG 'modules/network/subnet.bicep' = {
//   scope: resGroup
//   name: 'MG-Subnet'
//   params:{
//     name: 'MG-Subnet'
//     vnetName: netMG.name
//     nsgId: subnetNsg.outputs.nsgId
//     addressPrefix: '10.200.2.0/24'
//   }
//   dependsOn: [
//     netMG
//   ]

// }

// Domain Controllers
module DomainController1 'modules/compute/win2022-vm.bicep' = {
  scope: resGroup
  name: 'DC01'

  params: {
    location: location
    name: 'DC01'
    subnetId: netSP.outputs.subnetId
    adminPasswordOrKey: adminPasswordOrKey
    publicIp: true
    PrivateIp: '10.100.1.4'
    size: size
    adminUser: adminUser
    userIdentityResourceId: assignManagedIdentity ? managedIdentity.outputs.resourceId : ''
  }
}

module shutdownDC 'modules/misc/autoshutdown.bicep' = {
  scope: resGroup
  name: 'autoshutdown'

  params: {
    vmName: DomainController1.name
    location: location
    targetVmId: DomainController1.outputs.vmID
    shutdownTime: '2300'
    timeZone: 'Bahia Standard Time'
  }
  dependsOn:[
    DomainController1
  ]
}
module DomainController2 'modules/compute/win2022-vm.bicep' = {
  scope: resGroup
  name: 'DC02'

  params: {
    location: location
    name: 'DC02'
    subnetId: netSP.outputs.subnetId
    adminPasswordOrKey: adminPasswordOrKey
    publicIp: true
    PrivateIp: '10.100.1.5'
    size: size
    adminUser: adminUser
    userIdentityResourceId: assignManagedIdentity ? managedIdentity.outputs.resourceId : ''
  }
}

module shutdownDC2 'modules/misc/autoshutdown.bicep' = {
  scope: resGroup
  name: 'autoshutdownDC2'

  params: {
    vmName: DomainController2.name
    location: location
    targetVmId: DomainController2.outputs.vmID
    shutdownTime: '2300'
    timeZone: 'Bahia Standard Time'
  }
  dependsOn:[
    DomainController2
  ]
}

module DomainController3 'modules/compute/win2022-vm.bicep' = {
  scope: resGroup
  name: 'DC03'

  params: {
    location: location
    name: 'DC03'
    subnetId: netMG.outputs.subnetId
    adminPasswordOrKey: adminPasswordOrKey
    publicIp: true
    PrivateIp: '10.200.1.4'
    size: size
    adminUser: adminUser
    userIdentityResourceId: assignManagedIdentity ? managedIdentity.outputs.resourceId : ''
  }
}

module shutdownDC3 'modules/misc/autoshutdown.bicep' = {
  scope: resGroup
  name: 'autoshutdownDC3'

  params: {
    vmName: DomainController3.name
    location: location
    targetVmId: DomainController3.outputs.vmID
    shutdownTime: '2300'
    timeZone: 'Bahia Standard Time'
  }
  dependsOn:[
    DomainController3
  ]
}

// Windows Servers

module FileServer 'modules/compute/win2022-vm.bicep' = {
  scope: resGroup
  name: 'FileServer'

  params: {
    location: location
    name: 'FileServer'
    subnetId: netSP.outputs.subnetId
    adminPasswordOrKey: adminPasswordOrKey
    publicIp: true
    PrivateIp: '10.100.1.10'
    size: size
    adminUser: adminUser
    userIdentityResourceId: assignManagedIdentity ? managedIdentity.outputs.resourceId : ''
  }
  dependsOn:[
    netSP
  ]
}

module shutdownFS 'modules/misc/autoshutdown.bicep' = {
  scope: resGroup
  name: 'autoshutdown-FS'

  params: {
    vmName: FileServer.name
    location: location
    targetVmId: FileServer.outputs.vmID
    shutdownTime: '2300'
    timeZone: 'Bahia Standard Time'
  }
  dependsOn: [
    FileServer
  ]
  
}


module managedIdentity 'modules/identity/user-managed.bicep' = if (assignManagedIdentity) {
  scope: resGroup
  params:{ 
    location: location
  }
  name: 'managedIdentity'
}

// ===== Outputs ==========================az==================================

output DC1privateIp string = DomainController1.outputs.privateIp
output DC1publicIp string = DomainController1.outputs.publicIP
output DC1dnsName string = DomainController1.outputs.dnsName

output DC2privateIp string = DomainController2.outputs.privateIp
output DC2publicIp string = DomainController2.outputs.publicIP
output DC2dnsName string = DomainController2.outputs.dnsName

output DC3privateIp string = DomainController3.outputs.privateIp
output DC3publicIp string = DomainController3.outputs.publicIP
output DC3dnsName string = DomainController3.outputs.dnsName

output FSprivateIp string = FileServer.outputs.privateIp
output FSpublicIp string = FileServer.outputs.publicIP
output FSdnsName string = FileServer.outputs.dnsName



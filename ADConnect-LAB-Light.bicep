// =========================================================================================
// Deploy a LAB with 1 DC | 1 ADFS Proxy Server | 1 AD Connect Server | 1 VNET | 3 Subnets
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
param allowRDPFromAddress string = '*'

// ===== Modules & Resources ==================================================

resource resGroup 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: name
  location: location
}

module subnetNsg 'modules/network/nsg.bicep' = {
  scope: resGroup
  name: 'subnetNSG'
  params: {
    name: 'vNet-AADC-NSG'
    location: location
    sourceAddress: allowRDPFromAddress
    openPorts: [
      '3389'
    ]
  }
}

module network 'modules/network/network.bicep' = {
  scope: resGroup
  name: 'AADC-LAB-VNET'
  params: {
    name: 'AADC-LAB-VNET'
    location: location
    defaultSubnetName: 'DC-Subnet'
    nsgId: subnetNsg.outputs.nsgId
  }
}

module snetAADC 'modules/network/subnet.bicep' = {
  scope: resGroup
  name: 'AADC-Subnet'
  params:{
    name: 'AADC-Subnet'
    vnetName: network.name
    nsgId: subnetNsg.outputs.nsgId
    addressPrefix: '10.200.1.0/24'
  }
  dependsOn: [
    network
  ]

}

module DomainController 'modules/compute/win2019-vm.bicep' = {
  scope: resGroup
  name: 'DC01'

  params: {
    location: location
    name: 'DC01'
    subnetId: network.outputs.subnetId
    adminPasswordOrKey: adminPasswordOrKey
    publicIp: true
    PrivateIp: '10.200.0.4'
    size: size
    adminUser: adminUser
    userIdentityResourceId: assignManagedIdentity ? managedIdentity.outputs.resourceId : ''
  }
}

module shutdownDC 'modules/misc/autoshutdown.bicep' = {
  scope: resGroup
  name: 'autoshutdown'

  params: {
    vmName: DomainController.name
    location: location
    targetVmId: DomainController.outputs.vmID
    shutdownTime: '2300'
    timeZone: 'Bahia Standard Time'
  }
  dependsOn:[
    DomainController
  ]
}

module AADC 'modules/compute/win2019-vm.bicep' = {
  scope: resGroup
  name: 'AADC01'

  params: {
    location: location
    name: 'AADC01'
    subnetId: snetAADC.outputs.subnetId
    adminPasswordOrKey: adminPasswordOrKey
    publicIp: true
    PrivateIp: '10.200.1.4'
    size: size
    adminUser: adminUser
    userIdentityResourceId: assignManagedIdentity ? managedIdentity.outputs.resourceId : ''
  }
  dependsOn:[
    snetAADC
  ]
}

module shutdownAADC 'modules/misc/autoshutdown.bicep' = {
  scope: resGroup
  name: 'autoshutdown-AADC'

  params: {
    vmName: AADC.name
    location: location
    targetVmId: AADC.outputs.vmID
    shutdownTime: '2300'
    timeZone: 'Bahia Standard Time'
  }
  dependsOn: [
    AADC
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

output DCprivateIp string = DomainController.outputs.privateIp
output DCpublicIp string = DomainController.outputs.publicIP
output DCdnsName string = DomainController.outputs.dnsName

output AADCprivateIp string = AADC.outputs.privateIp
output AADCpublicIp string = AADC.outputs.publicIP
output AADCdnsName string = AADC.outputs.dnsName



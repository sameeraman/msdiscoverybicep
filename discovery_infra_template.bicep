@description('Deployment name')
param deploymentName string = 'discovery1'

@description('Managed Identity Name')
param mIdentityName string = '${deploymentName}-uami'

@description('Microsoft Discovery Storage Name')
param msDiscoveryStorageName string = '${deploymentName}-storage'

@description('Microsoft Discovery SuperComputer Name')
param msDiscoverySuperComputerName string = '${deploymentName}-supercomputer'

@description('Microsoft Discovery Workspace Name')
param msDiscoveryWorkspaceName string = '${deploymentName}-workspace'

@description('Virtual Network name')
param vnetName string = '${deploymentName}-vnet-${location}'

@description('Location for all resources')
param location string = 'eastus2'

@description('Virtual Network address prefix')
param vnetAddressPrefix string = '10.0.0.0/22'

@description('Supercomputer nodepool subnet address prefix')
param supercomputerNodepoolSubnetPrefix string = '10.0.2.0/24'

@description('AKS subnet address prefix')
param aksSubnetPrefix string = '10.0.3.0/24'

@description('Azure Storage Blob subnet address prefix')
param storageBlobSubnetPrefix string = '10.0.4.0/24'

@description('Storage subnet address prefix (NetApp)')
param storageSubnetPrefix string = '10.0.1.0/26'

@description('Kind of backing store (e.g., AzureNetApp)')
param discoveryStoreKind string

@description('VM size for nodes in the nodepool')
param nodePoolVmSize string

@description('Maximum number of nodes allowed in the nodepool')
param maxNPNodeCount int

@description('Tags for the resources')
param tags object

@description('Globally unique storage account name (lowercase, 3-24 chars). Defaults to deployment-based name; override if collision occurs.')
@minLength(3)
@maxLength(24)
param storageAccountName string = toLower(replace('${deploymentName}${substring(uniqueString(resourceGroup().id), 0, 4)}', '-', ''))

@description('Optional client public IPv4 address (e.g. 203.0.113.10) to allow for blob access. Leave empty to skip.')
@allowed([
  ''
])
param clientPublicIp string = ''

// Built-in / preview role definition GUIDs
// var discoveryContributorRoleId = '01288891-85ee-45a7-b367-9db3b752fc65'
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
// Role definition for Storage Blob Data Contributor (already declared above) reused for storage account scope assignment

var subSuperComputer = 'supercomputer-nodepool-subnet'
var subAks = 'aks-subnet'
var subAzureStorage = 'azure-storage-blob-subnet'
var subStorage = 'storage-subnet'


// Helper: subnet resource IDs for storage account network rules
var subnetIdsForStorage = [
  resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, subSuperComputer)
  resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, subAks)
  resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, subAzureStorage)
  resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, subStorage)
]

// Virtual network
resource virtualNetwork 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    enableDdosProtection: false
    subnets: [
      {
        name: subSuperComputer
        properties: {
          addressPrefix: supercomputerNodepoolSubnetPrefix
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [
                location
              ]
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          defaultOutboundAccess: false
        }
      }
      {
        name: subAks
        properties: {
          addressPrefix: aksSubnetPrefix
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [
                location
              ]
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          defaultOutboundAccess: false
        }
      }
      {
        name: subAzureStorage
        properties: {
          addressPrefix: storageBlobSubnetPrefix
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [
                location
              ]
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          defaultOutboundAccess: false
        }
      }
      {
        name: subStorage
        properties: {
          addressPrefix: storageSubnetPrefix
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
              locations: [
                location
              ]
            }
          ]
          delegations: [
            {
              name: 'Microsoft.Netapp/volumes'
              properties: {
                serviceName: 'Microsoft.Netapp/volumes'
              }
            }
          ]
          privateEndpointNetworkPolicies: 'Disabled'
          privateLinkServiceNetworkPolicies: 'Enabled'
          defaultOutboundAccess: false
        }
      }
    ]
    virtualNetworkPeerings: []
  }
}

// User Assigned Managed Identity. Use the existing
resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: mIdentityName
}


// Microsoft Discovery Storage
resource storage 'Microsoft.Discovery/storages@2025-07-01-preview' = {
  name: msDiscoveryStorageName
  location: location
  tags: tags
  properties: {
    store: {
      kind: discoveryStoreKind
    }
    subnetId: '${virtualNetwork.id}/subnets/${subStorage}'
  }
}


// Azure Storage Account (Blob) for investigation outputs
resource sa 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: storageAccountName
  location: location
  tags: tags
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    allowCrossTenantReplication: true
    publicNetworkAccess: 'Enabled'
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      virtualNetworkRules: [
        for subnetId in subnetIdsForStorage: {
          id: subnetId
        }
      ]
      ipRules: (clientPublicIp != '')
        ? [
            {
              action: 'Allow'
              value: clientPublicIp
            }
          ]
        : []
    }
    encryption: {
      services: {
        blob: {
          enabled: true
        }
        file: {
          enabled: true
        }
      }
      keySource: 'Microsoft.Storage'
    }
    accessTier: 'Hot'
    supportsHttpsTrafficOnly: true
  }
}

// Blob service CORS configuration
resource saBlobService 'Microsoft.Storage/storageAccounts/blobServices@2023-05-01' = {
  name: 'default'
  parent: sa
  properties: {
    cors: {
      corsRules: [
        {
          allowedOrigins: ['https://studio.discovery.microsoft.com']
          allowedMethods: ['GET', 'DELETE', 'PUT']
          allowedHeaders: ['*']
          exposedHeaders: ['*']
          maxAgeInSeconds: 200
        }
      ]
    }
  }
}


// Output container
resource saOutputsContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  name: 'discoveryoutputs'
  parent: saBlobService
  properties: {
    publicAccess: 'None'
  }
}

// Grant Storage Blob Data Contributor to UAMI at storage account scope
resource raSaBlobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(sa.id, uami.id, storageBlobDataContributorRoleId)
  scope: sa
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      storageBlobDataContributorRoleId
    )
    principalId: uami.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// tag for super computer capacity issue (eastus deployments only)
var supercomputerCapacityTag = {
  //'discovery.systemsku': 'Standard_D4as_v5'
}

var supercomputerUnionTag = union(tags, supercomputerCapacityTag)

// Microsoft Discovery SuperComputer
resource supercomputer 'Microsoft.Discovery/supercomputers@2025-07-01-preview' = {
  name: msDiscoverySuperComputerName
  location: location
  tags: supercomputerUnionTag
  properties: {
    subnetId: resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetwork.name, subAks)
    identities: {
      clusterIdentity: {
        id: uami.id
      }
      kubeletIdentity: {
        id: uami.id
      }
      workloadIdentities: {
        '${uami.id}': {}
      }
    }
  }
}

// Microsoft Discovery Nodepool resource under a supercomputer
resource nodepool 'Microsoft.Discovery/supercomputers/nodepools@2025-07-01-preview' = {
  name: '${supercomputer.name}/nodepool1'
  location: location
  properties: {
    vmSize: nodePoolVmSize
    subnetId: '${virtualNetwork.id}/subnets/${subSuperComputer}'
    maxNodeCount: maxNPNodeCount
  }
}


// Microsoft Discovery Workspace
resource workspace 'Microsoft.Discovery/workspaces@2025-07-01-preview' = {
  name: msDiscoveryWorkspaceName
  location: location
  tags: tags
  properties: {
    supercomputerIds: [supercomputer.id]
    storageIds: [storage.id]
    workspaceIdentity: { 
      id: uami.id 
    }
  }
}



// Outputs
output vnetName string = virtualNetwork.name

output storageAccountName string = sa.name
output storageAccountResourceId string = sa.id

@description('Microsoft Discovery Supercomputer resource ID')
output supercomputerId string = supercomputer.id

@description('Microsoft Discovery workspace resource ID')
output workspaceId string = workspace.id

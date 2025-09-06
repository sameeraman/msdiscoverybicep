targetScope = 'subscription'

@description('Managed Identity Name')
param mIdentityName string = 'discovery1'

@description('Name of the resource group to create/use for the managed identity')
param resourceGroupName string = 'discovery-uami-rg'

@description('Deployment location (applies to RG and identity). Defaults to deployment location.')
param location string = deployment().location

@description('Tags applied to created resources')
param tags object = {}

@description('Object ID of the control-plane service principal (e.g., AIFSPInfrastructure or Discovery control-plane service app).')
param controlPlaneSpObjectId string = 'e42dc5f7-1922-429d-a667-3ed3b959d9d8'


// Built-in / preview role definition GUIDs
var discoveryContributorRoleId = '01288891-85ee-45a7-b367-9db3b752fc65'
var storageBlobDataContributorRoleId = 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d'
// Additional built-in role IDs for control-plane service principal
var networkContributorRoleId = 'b24988ac-6180-42a0-ab88-20f7382dd24c'
var storageAccountContributorRoleId = '17d1049b-9a84-46fb-8f53-869881c3d3ab'
var readerRoleId = 'acdd72a7-3385-48ef-bd42-f606fba81ae7'

// Resource Group
resource rg 'Microsoft.Resources/resourceGroups@2024-03-01'  = {
  name: resourceGroupName
  location: location
  tags: tags
}

// Deploy the UAMI into the resource group via a module (cross-scope requires module)
// Module deploying the user assigned managed identity into the resource group
module uamiModule './modules/uami.module.bicep' = {
  name: 'uamiModule'
  scope: rg
  params: {
    uamiName: mIdentityName
    location: location
    tags: tags
  }
}

// ------------ Assign the Managed Identity role assignments  ------------

// Role assignment: Discovery Platform Contributor (Preview)
resource raDiscoveryContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, mIdentityName, discoveryContributorRoleId)
  scope: subscription()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', discoveryContributorRoleId)
    principalId: uamiModule.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// Role assignment: Storage Blob Data Contributor
resource raStorageBlobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, mIdentityName, storageBlobDataContributorRoleId)
  scope: subscription()
  properties: {
    roleDefinitionId: subscriptionResourceId(
      'Microsoft.Authorization/roleDefinitions',
      storageBlobDataContributorRoleId
    )
    principalId: uamiModule.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// Role assignment: AcrPull
resource raAcrPull 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, mIdentityName, acrPullRoleId)
  scope: subscription()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
    principalId: uamiModule.outputs.principalId
    principalType: 'ServicePrincipal'
  }
}

// ------------ Control-plane service principal role assignments (require controlPlaneSpObjectId) ------------

// Role assignment: Network Contributor role on Control-plane service principal
resource raCpNetworkContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, controlPlaneSpObjectId, networkContributorRoleId)
  scope: subscription()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', networkContributorRoleId)
    principalId: controlPlaneSpObjectId
    principalType: 'ServicePrincipal'
  }
}

// Role assignment: Storage Account Contributor role on Control-plane service principal
resource raCpStorageAccountContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(subscription().id, controlPlaneSpObjectId, storageAccountContributorRoleId)
  scope: subscription()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageAccountContributorRoleId)
    principalId: controlPlaneSpObjectId
    principalType: 'ServicePrincipal'
  }
}

// Role assignment: Storage Blob Data Contributor role on Control-plane service principal
resource raCpStorageBlobDataContributor 'Microsoft.Authorization/roleAssignments@2022-04-01' =  {
  name: guid(subscription().id, controlPlaneSpObjectId, storageBlobDataContributorRoleId)
  scope: subscription()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', storageBlobDataContributorRoleId)
    principalId: controlPlaneSpObjectId
    principalType: 'ServicePrincipal'
  }
}

// Role assignment: Reader role on Control-plane service principal
resource raCpReader 'Microsoft.Authorization/roleAssignments@2022-04-01' =  {
  name: guid(subscription().id, controlPlaneSpObjectId, readerRoleId)
  scope: subscription()
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', readerRoleId)
    principalId: controlPlaneSpObjectId
    principalType: 'ServicePrincipal'
  }
}

@description('Managed Identity resource ID')
output identityId string = uamiModule.outputs.identityId

@description('Principal (service principal) object ID of the managed identity')
output principalId string = uamiModule.outputs.principalId

@description('Client ID of the managed identity')
output clientId string = uamiModule.outputs.clientId

@description('Resource group name where the identity resides')
output ResourceGroupName string = rg.name

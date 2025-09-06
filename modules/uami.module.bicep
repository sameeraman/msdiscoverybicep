@description('Name of the User Assigned Managed Identity')
param uamiName string

@description('Location for the managed identity')
param location string

@description('Tags applied to the managed identity')
param tags object = {}

resource uami 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: uamiName
  location: location
  tags: tags
}

@description('Managed Identity resource ID')
output identityId string = uami.id

@description('Principal (service principal) object ID of the managed identity')
output principalId string = uami.properties.principalId

@description('Client ID of the managed identity')
output clientId string = uami.properties.clientId

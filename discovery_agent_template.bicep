@description('Agent resource name')
param agentName string

@description('Deployment location')
param location string

@description('Tags-by-resource object (expects keys like "Microsoft.Discovery/agents")')
param tags object

// File is in the same folder as this Bicep template
var fileDefinitionContent = json(loadTextContent('definitions/example-agent-definition.json'))

@description('Agent version string')
param agentVersion string

@description('Model name / path')
param modelName string

@description('Tools array for the agent')
param tools array = []

@description('Agents array (nested agents)')
param agents array = []

@description('Knowledge bases array (objects with name & knowledgeBaseId)')
param knowledgeBases array = []


resource agent 'Microsoft.Discovery/agents@2025-07-01-preview' = {
  name: agentName
  location: location
  tags: tags
  properties: {
    definitionContent: fileDefinitionContent
    version: agentVersion
    modelName: modelName
    tools: tools
    agents: agents
    knowledgeBases: [for kb in knowledgeBases: kb != null ? kb : null]
  }
}

output agentId string = agent.id
output agentName string = agent.name

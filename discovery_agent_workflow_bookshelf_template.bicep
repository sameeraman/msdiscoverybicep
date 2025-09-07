@description('Agent resource name')
param agentName string

@description('Deployment location')
param location string

@description('Tags-by-resource object (expects keys like "Microsoft.Discovery/agents")')
param tags object

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

@description('Workflow resource name')
param workflowName string

@description('Workflow version string')
param workflowVersion string

@description('Bookshelf resource name')
param bookshelfName string


// File is in the same folder as this Bicep template
var fileAgentDefinitionContent = json(loadTextContent('definitions/example-agent-definition.json'))


// Load default definition from co-located JSON file if param not supplied
var fileWorkflowDefinition = json(loadTextContent('definitions/example-workflow-definition.json'))




resource agent 'Microsoft.Discovery/agents@2025-07-01-preview' = {
  name: agentName
  location: location
  tags: tags
  properties: {
    definitionContent: fileAgentDefinitionContent
    version: agentVersion
    modelName: modelName
    tools: tools
    agents: agents
    knowledgeBases: [for kb in knowledgeBases: kb != null ? kb : null]
  }
}


resource workflow 'Microsoft.Discovery/workflows@2025-07-01-preview' = {
  name: workflowName
  location: location
  tags: tags
  properties: {
    definitionContent: fileWorkflowDefinition
    version: workflowVersion
  }
}

resource bookshelf 'Microsoft.Discovery/bookshelves@2025-07-01-preview' = {
  name: bookshelfName
  location: location
  tags: tags
  properties: {}
}

output workflowId string = workflow.id
output workflowName string = workflow.name

output agentId string = agent.id
output agentName string = agent.name

output bookshelfId string = bookshelf.id
output bookshelfName string = bookshelf.name

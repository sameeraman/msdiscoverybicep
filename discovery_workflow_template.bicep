@description('Deployment location')
param location string

@description('Tags for the resource")')
param tags object

@description('Workflow resource name')
param workflowName string

@description('Workflow version string')
param workflowVersion string


// Load default definition from co-located JSON file if param not supplied
var fileWorkflowDefinition = json(loadTextContent('Discovery_WorkflowCreate/example-workflow-definition.json'))


resource workflow 'Microsoft.Discovery/workflows@2025-07-01-preview' = {
  name: workflowName
  location: location
  tags: tags
  properties: {
    definitionContent: fileWorkflowDefinition
    version: workflowVersion
  }
}

output workflowId string = workflow.id
output workflowName string = workflow.name

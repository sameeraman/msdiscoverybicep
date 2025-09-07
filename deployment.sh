# Register the resource providers
for ns in Microsoft.Discovery Microsoft.Network Microsoft.Compute Microsoft.Storage Microsoft.ManagedIdentity Microsoft.AlertsManagement Microsoft.Authorization Microsoft.CognitiveServices Microsoft.ContainerInstance Microsoft.ContainerRegistry Microsoft.ContainerService Microsoft.DocumentDB Microsoft.Features Microsoft.KeyVault Microsoft.MachineLearningServices Microsoft.NetApp Microsoft.OperationalInsights Microsoft.ResourceGraph Microsoft.Search Microsoft.Web Microsoft.Insights Microsoft.Resources Microsoft.Sql Microsoft.App; do
  echo "Registering $ns..."
  az provider register -n "$ns" --only-show-errors >/dev/null || echo "Failed: $ns"
done

# Check Registration of the resource providers
for p in Microsoft.Discovery Microsoft.Network Microsoft.Compute Microsoft.Storage Microsoft.ManagedIdentity Microsoft.AlertsManagement Microsoft.Authorization Microsoft.CognitiveServices Microsoft.ContainerInstance Microsoft.ContainerRegistry Microsoft.ContainerService Microsoft.DocumentDB Microsoft.Features Microsoft.KeyVault Microsoft.MachineLearningServices Microsoft.NetApp Microsoft.OperationalInsights Microsoft.ResourceGraph Microsoft.Search Microsoft.Web Microsoft.Insights Microsoft.Resources Microsoft.Sql Microsoft.App; do
  az provider show --namespace "$p" --query "{Provider:namespace,State:registrationState}" -o table
done


rgName=ai-eus2-npe-arg-sp5                              # Resource group name
mIdentityName=msdisc5-mi                                # management identity resource name, I noted that MI name has to be less than 10 characters for the deployment to be successful. 
deploymentName=disc5-eus2                               # Deployment name less than 10 characters
location=eastus2
subscriptionId=<subscription-id>
adminuser=<identity-upn-or-object-id>                   # admin user to assign roles and run the deployment



## Create Admin Role assignments
# Create Microsoft Discovery Platform Administrator role assignment
az role assignment create --assignee $adminuser --role "7a2b6e6c-472e-4b39-8878-a26eb63d75c6" --scope /subscriptions/$subscriptionId


# Microsoft Discovery Platform Contributor role assignment
az role assignment create --assignee $adminuser --role "01288891-85ee-45a7-b367-9db3b752fc65" --scope /subscriptions/$subscriptionId


# Create the resource group manually
#az group create --name $rgName --location $location


# Create resource group and the managed identity along with its permissions
az deployment sub create --name $deploymentName-uami-deploy --location $location --template-file discovery_midentity_template.bicep --parameters @discovery_midentity_template.parameters.json mIdentityName=$mIdentityName resourceGroupName=$rgName location=$location

# Deploy the discovery infrastructure resources
az deployment group create --name $deploymentName-infra-deploy --resource-group $rgName --template-file discovery_infra_template.bicep --parameters @discovery_infra_template.parameters.json deploymentName=$deploymentName mIdentityName=$mIdentityName location=$location --debug 

# Deploy the Agent, workflow and bookshelf 
az deployment group create --name $deploymentName-ag-wf-bs-deploy --resource-group $rgName --template-file discovery_agent_workflow_bookshelf_template.bicep --parameters @discovery_agent_workflow_bookshelf_template.parameters.json location=$location --debug
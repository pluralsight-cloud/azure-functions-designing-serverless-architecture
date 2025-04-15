/********************************************************************************
    Bicep file:
     - A storage account
     - An Event Grid system topic (tied to the storage account)
     - A Basic (B1) App Service Plan
     - Application Insights
     - A Python Function App
********************************************************************************/

// Change all the previously-defined parameters to variables
var location = resourceGroup().location
var storageAccountName = 'st${uniqueString(resourceGroup().id)}'
var appServicePlanName = 'asp${uniqueString(resourceGroup().id)}'
var functionAppName = 'func${uniqueString(resourceGroup().id)}'
var systemTopicName = 'stTopic${uniqueString(resourceGroup().id)}'
var applicationInsightsName = 'app${uniqueString(resourceGroup().id)}'

// Create a storage account
resource storageAccount 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
}

// Create an Event Grid System Topic of type microsoft.storage.storageaccounts
resource systemTopic 'Microsoft.EventGrid/systemTopics@2022-06-15' = {
  name: systemTopicName
  location: location
  properties: {
    source: storageAccount.id
    topicType: 'microsoft.storage.storageaccounts'
  }
}

// Create the App Service Plan (Basic B1)
resource appServicePlan 'Microsoft.Web/serverfarms@2022-03-01' = {
  name: appServicePlanName
  location: location
  sku: {
    name: 'B1'
    tier: 'Basic'
    size: 'B1'
  }
  kind: 'linux'
  properties: {
    reserved: true
  }
}

// Create Application Insights resource
resource applicationInsight 'Microsoft.Insights/components@2020-02-02' = {
  name: applicationInsightsName
  location: location
  tags: {
    'hidden-link:${resourceId('Microsoft.Web/sites', functionAppName)}': 'Resource'
  }
  properties: {
    Application_Type: 'web'
  }
  kind: 'web'
}

// Create a Python Function App
resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'python|3.11'
      appSettings: [
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${storageAccountName};AccountKey=${listKeys(storageAccount.id, '2022-05-01').keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: reference(resourceId('Microsoft.Insights/components', applicationInsightsName), '2020-02-02').InstrumentationKey
        }
      ]
    }
  }
}

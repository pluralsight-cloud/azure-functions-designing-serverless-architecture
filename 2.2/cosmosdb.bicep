/********************************************************************************
    Bicep file:
     - A Basic (B1) App Service Plan
     - Application Insights
     - A C# Function App
     - A NoSQL (Core API) Cosmos DB account
********************************************************************************/

// Location is now a var, relying on resourceGroup() for the default
var location = resourceGroup().location

// Names for Azure resources changed from param to var
var appServicePlanName = 'asp${uniqueString(resourceGroup().id)}'
var functionAppName = 'func${uniqueString(resourceGroup().id)}'
var applicationInsightsName = 'app${uniqueString(resourceGroup().id)}'
var cosmosAccountName = 'cosmos${uniqueString(resourceGroup().id)}'

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

// Create Application Insights
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

// Create a C# Function App
resource functionApp 'Microsoft.Web/sites@2022-03-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux'
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'DOTNET|8.0'
      appSettings: [
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'dotnet'
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

// Cosmos DB account (Core API / NoSQL) in serverless mode
resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2021-07-01-preview' = {
  name: cosmosAccountName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    createMode: 'Default'
    databaseAccountOfferType: 'Standard'
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
  }
}

// Create a SQL database (NoSQL / Core API) in the Cosmos DB account
resource cosmosDbDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2021-07-01-preview' = {
  name: '${cosmosAccount.name}/sales'
  properties: {
    resource: {
      id: 'sales'
    }
    options: {}
  }
  dependsOn: [
    cosmosAccount
  ]
}

// Create a container within the SQL database
resource cosmosDbContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2021-07-01-preview' = {
  name: '${cosmosDbDatabase.name}/items'
  properties: {
    resource: {
      id: 'items'
      partitionKey: {
        paths: [
          '/PartitionKey'
        ]
        kind: 'Hash'
      }
    }
    options: {}
  }
  dependsOn: [
    cosmosDbDatabase
  ]
}

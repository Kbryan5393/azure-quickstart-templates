# PowerShell Script for Deploying Oraql Tech Legal Platform on Azure

Param(
    [string] [Parameter(Mandatory = $true)] $Location = "EastUS",
    [string] $ResourceGroupName = "OraqlResourceGroup",
    [string] $AppServicePlanName = "OraqlAppServicePlan",
    [string] $WebAppName = "OraqlWebApp",
    [string] $SQLServerName = "oraqlsqlserver",
    [string] $SQLDatabaseName = "OraqlDatabase",
    [string] $KeyVaultName = "OraqlKeyVault"
)

# Login to Azure
Write-Output "Logging into Azure..."
Connect-AzAccount

# Create Resource Group
Write-Output "Creating resource group..."
if (-not (Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue)) {
    New-AzResourceGroup -Name $ResourceGroupName -Location $Location
}

# Create an App Service Plan
Write-Output "Creating App Service Plan..."
$AppServicePlan = New-AzAppServicePlan -ResourceGroupName $ResourceGroupName -Name $AppServicePlanName -Location $Location -Tier "Standard" -NumberofWorkers 1

# Create a Web App for Oraql's main platform
Write-Output "Creating Web App..."
$WebApp = New-AzWebApp -ResourceGroupName $ResourceGroupName -Name $WebAppName -Location $Location -AppServicePlan $AppServicePlanName

# Set up Application Insights for monitoring
Write-Output "Setting up Application Insights..."
$AppInsights = New-AzApplicationInsights -ResourceGroupName $ResourceGroupName -Name "$WebAppName-Insights" -Location $Location -Kind "web"

# Integrate Application Insights with the Web App
Set-AzWebAppApplicationSettings -ResourceGroupName $ResourceGroupName -Name $WebAppName -AppSettings @{
    "APPINSIGHTS_INSTRUMENTATIONKEY" = $AppInsights.InstrumentationKey
}

# Create a SQL Server for secure data storage
Write-Output "Creating SQL Server..."
$SQLServer = New-AzSqlServer -ResourceGroupName $ResourceGroupName -ServerName $SQLServerName -Location $Location -SqlAdministratorCredentials (Get-Credential)

# Create a SQL Database for client data
Write-Output "Creating SQL Database..."
$SQLDatabase = New-AzSqlDatabase -ResourceGroupName $ResourceGroupName -ServerName $SQLServerName -DatabaseName $SQLDatabaseName -Edition "Standard"

# Create a Key Vault for secure management of API keys and secrets
Write-Output "Creating Key Vault..."
$KeyVault = New-AzKeyVault -ResourceGroupName $ResourceGroupName -VaultName $KeyVaultName -Location $Location -Sku Standard

# Store sensitive information in Key Vault
Write-Output "Storing secrets in Key Vault..."
$SQLConnectionString = "Server=tcp:$SQLServerName.database.windows.net,1433;Initial Catalog=$SQLDatabaseName;Persist Security Info=False;User ID=YOUR_SQL_ADMIN_USER;Password=YOUR_SQL_ADMIN_PASSWORD;MultipleActiveResultSets=False;Encrypt=True;TrustServerCertificate=False;Connection Timeout=30;"
Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name "SQLConnectionString" -SecretValue (ConvertTo-SecureString $SQLConnectionString -AsPlainText -Force)

# Set up API keys (example for Clio and MyCase API keys)
Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name "ClioApiKey" -SecretValue (ConvertTo-SecureString "YOUR_CLIO_API_KEY" -AsPlainText -Force)
Set-AzKeyVaultSecret -VaultName $KeyVaultName -Name "MyCaseApiKey" -SecretValue (ConvertTo-SecureString "YOUR_MYCASE_API_KEY" -AsPlainText -Force)

# Configure Web App settings to access Key Vault secrets
Write-Output "Configuring Web App to access Key Vault secrets..."
Set-AzWebAppApplicationSettings -ResourceGroupName $ResourceGroupName -Name $WebAppName -AppSettings @{
    "SQLConnectionString" = "@Microsoft.KeyVault(SecretUri=https://$KeyVaultName.vault.azure.net/secrets/SQLConnectionString)"
    "ClioApiKey" = "@Microsoft.KeyVault(SecretUri=https://$KeyVaultName.vault.azure.net/secrets/ClioApiKey)"
    "MyCaseApiKey" = "@Microsoft.KeyVault(SecretUri=https://$KeyVaultName.vault.azure.net/secrets/MyCaseApiKey)"
}

Write-Output "Deployment completed. Oraql Tech's Azure environment is set up successfully."

# 1. Resource Group
resource "azurerm_resource_group" "aks_rg" {
  name     = var.resource_group_name
  location = var.location
}

# 2. Azure Container Registry (ACR)
resource "azurerm_container_registry" "acr" {
  name                = var.acr_name
  resource_group_name = azurerm_resource_group.aks_rg.name
  location            = azurerm_resource_group.aks_rg.location
  sku                 = "Basic"
  admin_enabled       = false
}

# 3. AKS Cluster (Updated to v11)
module "aks" {
  source  = "Azure/aks/azurerm"
  version = "11.0.0" 

  resource_group_name = azurerm_resource_group.aks_rg.name
  location            = azurerm_resource_group.aks_rg.location
  prefix              = var.dns_prefix
  cluster_name        = var.cluster_name

  identity_type                     = "SystemAssigned"
  role_based_access_control_enabled = true
  rbac_aad_azure_rbac_enabled = false

  # FIX 2: Force the module to wait for the resource group to be created
  depends_on = [azurerm_resource_group.aks_rg]

  network_plugin = "azure"
  network_policy = "azure"

  agents_count = var.node_count
  agents_size  = "Standard_D2s_v3"

  log_analytics_workspace_enabled = false
}

# 4. Role Assignment (Updated for AzureRM v4 compatibility)
resource "azurerm_role_assignment" "aks_to_acr" {
  principal_id                     = module.aks.kubelet_identity[0].object_id
  role_definition_name             = "AcrPull"
  scope                            = azurerm_container_registry.acr.id
  skip_service_principal_aad_check = true
  principal_type                   = "ServicePrincipal" # Required in AzureRM v4 when skipping AAD check
}

# 5. Outputs
output "cluster_name" {
  value = module.aks.aks_name
}

output "resource_group_name" {
  value = azurerm_resource_group.aks_rg.name
}

output "acr_login_server" {
  value = azurerm_container_registry.acr.login_server
}

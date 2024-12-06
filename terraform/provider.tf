provider "azurerm" {
  features {
    // empty, but required
  }
  subscription_id            = var.subscription_id
  environment                = "public"
  use_msi                    = false
  use_cli                    = true
  use_oidc                   = false
}

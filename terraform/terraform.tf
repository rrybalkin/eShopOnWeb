terraform {
  backend "local" {}

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
      version = "4.12.0"
    }
    null = {
      source = "hashicorp/null"
      version = "3.2.3"
    }
  }
}

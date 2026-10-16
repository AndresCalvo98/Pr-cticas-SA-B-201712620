terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 3.100.0, < 5.0.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.26.0"
    }
  }

  backend "azurerm" {
    resource_group_name  = "rg-sa-p9-dr"
    storage_account_name = "sasp9tfstate10854"
    container_name       = "tfstate"
    key                  = "p9.terraform.tfstate"
    # Azure Blob Storage native state lease locking habilitado (lock)
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = false
    }
  }
}

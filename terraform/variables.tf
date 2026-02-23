terraform {
  required_version = ">= 1.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  
  skip_provider_registration = true
}

# ============================================
# VARIABLES
# ============================================

variable "location" {
  description = "Región de Azure"
  type        = string
  default     = "eastus"
}

variable "environment" {
  description = "Ambiente de despliegue"
  type        = string
  default     = "prod"
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment must be dev, staging, or prod"
  }
}

variable "resource_group_name" {
  description = "Nombre del grupo de recursos"
  type        = string
  default     = "rg-private-serverless"
}

variable "vnet_cidr" {
  description = "CIDR de la Virtual Network"
  type        = string
  default     = "10.0.0.0/16"
}

variable "function_subnet_cidr" {
  description = "CIDR de la subnet para Azure Function"
  type        = string
  default     = "10.0.1.0/24"
}

variable "eventgrid_subnet_cidr" {
  description = "CIDR de la subnet para Event Grid"
  type        = string
  default     = "10.0.2.0/24"
}

variable "function_sku" {
  description = "SKU del App Service Plan"
  type        = string
  default     = "EP1"
}

variable "tags" {
  description = "Tags para los recursos"
  type        = map(string)
  default = {
    Environment = "prod"
    Project     = "AzurePrivateServerless"
    ManagedBy   = "Terraform"
  }
}

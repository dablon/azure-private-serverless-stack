# 🔐 Azure Private Serverless Stack

> Arquitectura serverless privada: Azure Function + Event Grid Topic conectados mediante VNet privada con Private Endpoints.

## 📋 Descripción

Este repositorio contiene la documentación completa y código de automatización para implementar una arquitectura serverless segura en Azure donde:

- **Azure Function** procesa eventos de forma serverless
- **Event Grid Topic** gestione y distribuya eventos
- Toda la comunicación es **100% privada** a través de una Virtual Network

## 🏗️ Arquitectura

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           AZURE VIRTUAL NETWORK                             │
│                                                                             │
│  ┌──────────────────────┐         ┌─────────────────────────────────────┐  │
│  │   AZURE FUNCTION     │         │         EVENT GRID TOPIC            │  │
│  │                      │         │                                     │  │
│  │  ┌────────────────┐  │         │  ┌───────────────────────────────┐   │  │
│  │  │ Function App   │  │         │  │   Private Endpoint           │   │  │
│  │  │ (Premium Plan) │◄─┼─────────┼─►│   (topic.eventgrid.azure.net)│   │  │
│  │  └────────────────┘  │         │  └───────────────────────────────┘   │  │
│  │         ▲            │         │                                     │  │
│  │         │ VNet       │         │                                     │  │
│  │  ┌─────┴──────────┐  │         │                                     │  │
│  │  │ Private        │  │         │                                     │  │
│  │  │ Endpoint       │  │         │                                     │  │
│  │  └────────────────┘  │         │                                     │  │
│  └──────────┬───────────┘         └─────────────────────────────────────┘  │
│             │                                                                   │
│  ┌──────────┴───────────┐                                                      │
│  │   Subnets            │                                                      │
│  │   - snet-function    │                                                      │
│  │   - snet-eventgrid   │                                                      │
│  └───────────────────────┘                                                      │
│                                                                             │
│  ┌─────────────────────────────────────────────────────────────────────────┐ │
│  │                    Private DNS Zones                                     │ │
│  │   - privatelink.azurewebsites.net                                        │ │
│  │   - privatelink.eventgrid.azure.net                                      │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

## 📁 Estructura del Repositorio

```
azure-private-serverless/
├── docs/
│   └── azure-function-eventgrid-vnet.md    # Documentación completa
├── scripts/
│   └── Deploy-AzureServerlessStack.ps1      # Script PowerShell
├── terraform/
│   └── azure-private-endpoints/
│       ├── main.tf                          # Recursos principales
│       ├── variables.tf                     # Variables
│       ├── outputs.tf                       # Outputs
│       └── terraform.tfvars                 # Valores
└── README.md                                 # Este archivo
```

## 🚀 Opciones de Despliegue

### Opción 1: PowerShell (Az CLI + Módulos)

```powershell
# Ejecutar el script
.\scripts\Deploy-AzureServerlessStack.ps1 `
  -ResourceGroupName "rg-private-serverless" `
  -Location "eastus" `
  -Environment "prod"
```

### Opción 2: Terraform

```bash
# Inicializar Terraform
cd terraform/azure-private-endpoints
terraform init

# Plan de despliegue
terraform plan -var-file="terraform.tfvars"

# Aplicar
terraform apply -var-file="terraform.tfvars"
```

## 📋 Documentación

La documentación completa incluye:

- ✅ Configuración paso a paso
- ✅ Flujo de comunicación privada
- ✅ Scripts PowerShell
- ✅ Código Terraform (IaC)
- ✅ Consideraciones de seguridad

Ver [docs/azure-function-eventgrid-vnet.md](docs/azure-function-eventgrid-vnet.md)

## ⚠️ Requisitos

| Recurso | Descripción |
|---------|-------------|
| **Azure Subscription** | Suscripción activa con permisos de Contributor |
| **PowerShell** | Az Module instalado |
| **Terraform** | Versión >= 1.0 |
| **Azure CLI** | Última versión |

## 🔒 Seguridad

- **Private Endpoints**: Ambos servicios expuestos solo dentro de la VNet
- **DNS Privado**: Resolución de nombres interna
- **TLS 1.2+**: Minimum TLS requerido
- **Firewall**: Storage account con reglas de red restrictivas
- **System Identity**: Managed Identity para acceder a recursos Azure

## 📊 Recursos Crea dos

| Recurso | Tipo |
|---------|------|
| Virtual Network | 10.0.0.0/16 |
| Subnets | 3 (/24) |
| Azure Function | Premium Plan (EP1) |
| Event Grid Topic | CloudEvent Schema |
| Private Endpoints | 2 |
| Private DNS Zones | 2 |
| Storage Account | Standard LRS |

## 📝 Licencia

MIT License - feel free to use and modify.

---

_Construido con ☁️ por OpenClaw_

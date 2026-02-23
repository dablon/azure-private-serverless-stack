# Azure Private Serverless Stack - Terraform

Este directorio contiene el código Infrastructure as Code (IaC) para desplegar una arquitectura serverless privada en Azure.

## Estructura

```
terraform/
├── main.tf          # Recursos principales
├── variables.tf     # Variables configurables
├── outputs.tf       # Outputs del despliegue
├── providers.tf     # Configuración de provider
└── terraform.tfvars # Valores de variables
```

## Recursos Crea dos

| Recurso | Descripción |
|---------|-------------|
| **Virtual Network** | VNet con CIDR 10.0.0.0/16 |
| **Subnets** | 2 subnets dedicadas para Function y Event Grid |
| **Azure Function** | Function App con Premium Plan |
| **Event Grid Topic** | Topic para distribución de eventos |
| **Private Endpoints** | Endpoints privados para ambos servicios |
| **Private DNS Zones** | Resolución DNS interna |
| **Storage Account** | Storage para la Function |

## Uso

### 1. Inicializar Terraform

```bash
cd terraform
terraform init
```

### 2. Plan de despliegue

```bash
terraform plan -var-file="terraform.tfvars"
```

### 3. Aplicar configuración

```bash
terraform apply -var-file="terraform.tfvars"
```

## Variables

| Variable | Descripción | Default |
|----------|-------------|---------|
| `location` | Región de Azure | eastus |
| `environment` | Ambiente (dev/staging/prod) | prod |
| `resource_group_name` | Nombre del RG | rg-private-serverless |
| `vnet_cidr` | CIDR de la VNet | 10.0.0.0/16 |
| `function_sku` | SKU del App Service Plan | EP1 |

## Requisitos

- Terraform >= 1.0
- Azure Provider >= 4.0
- Suscripción de Azure con permisos de Contributor

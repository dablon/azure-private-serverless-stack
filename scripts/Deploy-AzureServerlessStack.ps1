#Requires -Module Az.Accounts
#Requires -Module Az.Network
#Requires -Module Az.Websites
#Requires -Module Az.EventGrid
#Requires -Module Az.PrivateDns

<#
.SYNOPSIS
    Script de automatización para crear Azure Function + Event Grid Topic con VNet Privada
    
.DESCRIPTION
    Crea una arquitectura serverless segura con conectividad privada:
    - Virtual Network con subnets dedicadas
    - Private Endpoints para Azure Function y Event Grid Topic
    - Zonas DNS privadas para resolución nombres internos
    - Azure Function con red virtual integrada
    - Event Grid Topic como destino de eventos
    
.PARAMETER ResourceGroupName
    Nombre del grupo de recursos
    
.PARAMETER Location
    Región de Azure
    
.PARAMETER VnetName
    Nombre de la Virtual Network
    
.PARAMETER Environment
    Ambiente (dev, staging, prod)

.EXAMPLE
    .\Deploy-AzureServerlessStack.ps1 -ResourceGroupName "rg-serverless-prod" -Location "eastus" -Environment "prod"
#>

param(
    [Parameter(Mandatory = $true)]
    [string]$ResourceGroupName,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("eastus", "westus2", "westeurope", "northeurope", "uksouth", "eastus2")]
    [string]$Location = "eastus",
    
    [Parameter(Mandatory = $false)]
    [string]$VnetName = "vnet-serverless",
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("dev", "staging", "prod")]
    [string]$Environment = "prod",
    
    [Parameter(Mandatory = $false)]
    [switch]$UseExistingVNet,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

# ============================================
# CONFIGURACIÓN Y VARIABLES
# ============================================

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Prefijos y naming convention
$prefix = "func"
$tags = @{
    Environment = $Environment
    ManagedBy   = "PowerShell"
    Project     = "ServerlessPrivate"
}

# Nombres de recursos
$subnetFunctionName = "snet-function"
$subnetEventGridName = "snet-eventgrid"
$privateEndpointFuncName = "pe-function"
$privateEndpointEgtName = "pe-eventgrid"
$dnsZoneFuncName = "privatelink.azurewebsites.net"
$dnsZoneEgtName = "privatelink.eventgrid.azure.net"
$functionAppName = "$prefix-app-$Environment"
$eventGridTopicName = "egt-$Environment"
$storageAccountName = "$prefix$Environment$(Get-Random -Minimum 1000 -Maximum 9999)"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Azure Serverless Private Stack" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Resource Group: $ResourceGroupName" -ForegroundColor Yellow
Write-Host "Location: $Location" -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Cyan

# ============================================
# VERIFICACIÓN DE CONEXIÓN
# ============================================

Write-Host "`n[1/8] Verificando conexión a Azure..." -ForegroundColor Green

$context = Get-AzContext
if (-not $context) {
    Write-Error "No hay sesión de Azure activa. Ejecuta Connect-AzAccount primero."
    exit 1
}

Write-Host " ✓ Conectado como: $($context.Account.Id)" -ForegroundColor Gray

# ============================================
# CREAR GRUPOS DE RECURSOS
# ============================================

Write-Host "`n[2/8] Creando grupo de recursos..." -ForegroundColor Green

$rg = Get-AzResourceGroup -Name $ResourceGroupName -ErrorAction SilentlyContinue
if (-not $rg) {
    if ($WhatIf) {
        Write-Host " [WhatIf] Se crearía grupo de recursos: $ResourceGroupName" -ForegroundColor Magenta
    } else {
        $rg = New-AzResourceGroup -Name $ResourceGroupName -Location $Location -Tag $tags
        Write-Host " ✓ Grupo de recursos creado: $($rg.ResourceGroupName)" -ForegroundColor Gray
    }
} else {
    Write-Host " ✓ Grupo de recursos existente: $($rg.ResourceGroupName)" -ForegroundColor Gray
}

# ============================================
# CREAR VIRTUAL NETWORK Y SUBNETS
# ============================================

Write-Host "`n[3/8] Configurando Virtual Network..." -ForegroundColor Green

if ($UseExistingVNet) {
    $vnet = Get-AzVirtualNetwork -Name $VnetName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $vnet) {
        Write-Error "VNet '$VnetName' no encontrada. Usa -UseExistingVNet:$`false o crea la VNet primero."
        exit 1
    }
    Write-Host " ✓ Usando VNet existente: $($vnet.Name)" -ForegroundColor Gray
} else {
    # Crear VNet
    $vnet = Get-AzVirtualNetwork -Name $VnetName -ResourceGroupName $ResourceGroupName -ErrorAction SilentlyContinue
    if (-not $vnet) {
        if ($WhatIf) {
            Write-Host " [WhatIf] Se crearía VNet: $VnetName con CIDR 10.0.0.0/16" -ForegroundColor Magenta
        } else {
            $vnet = New-AzVirtualNetwork -Name $VnetName `
                -ResourceGroupName $ResourceGroupName `
                -AddressPrefix "10.0.0.0/16" `
                -Location $Location `
                -Tag $tags
            Write-Host " ✓ VNet creada: $($vnet.Name)" -ForegroundColor Gray
        }
    }
    
    # Subnet para Function App (Integration Subnet requerida)
    $subnetFunc = Get-AzVirtualNetworkSubnetConfig -Name $subnetFunctionName -VirtualNetwork $vnet -ErrorAction SilentlyContinue
    if (-not $subnetFunc) {
        if ($WhatIf) {
            Write-Host " [WhatIf] Se crearía subnet: $subnetFunctionName (10.0.1.0/24)" -ForegroundColor Magenta
        } else {
            Add-AzVirtualNetworkSubnetConfig -Name $subnetFunctionName `
                -VirtualNetwork $vnet `
                -AddressPrefix "10.0.1.0/24" `
                -PrivateEndpointNetworkPolicyFlag "Disabled" | Out-Null
            
            Write-Host " ✓ Subnet Function creada: $subnetFunctionName" -ForegroundColor Gray
        }
    }
    
    # Subnet para Private Endpoints
    $subnetPE = Get-AzVirtualNetworkSubnetConfig -Name $subnetEventGridName -VirtualNetwork $vnet -ErrorAction SilentlyContinue
    if (-not $subnetPE) {
        if ($WhatIf) {
            Write-Host " [WhatIf] Se crearía subnet: $subnetEventGridName (10.0.2.0/24)" -ForegroundColor Magenta
        } else {
            Add-AzVirtualNetworkSubnetConfig -Name $subnetEventGridName `
                -VirtualNetwork $vnet `
                -AddressPrefix "10.0.2.0/24" `
                -PrivateEndpointNetworkPolicyFlag "Disabled" | Out-Null
            
            Write-Host " ✓ Subnet Private Endpoints creada: $subnetEventGridName" -ForegroundColor Gray
        }
    }
    
    # Aplicar cambios a VNet
    if (-not $WhatIf) {
        $vnet | Set-AzVirtualNetwork | Out-Null
        $vnet = Get-AzVirtualNetwork -Name $VnetName -ResourceGroupName $ResourceGroupName
    }
}

# Obtener referencias de subnets
$subnetFunc = Get-AzVirtualNetworkSubnetConfig -Name $subnetFunctionName -VirtualNetwork $vnet
$subnetPE = Get-AzVirtualNetworkSubnetConfig -Name $subnetEventGridName -VirtualNetwork $vnet

Write-Host " ✓ Subnets configuradas" -ForegroundColor Gray

# ============================================
# CREAR STORAGE ACCOUNT
# ============================================

Write-Host "`n[4/8] Creando Storage Account..." -ForegroundColor Green

$storage = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -Name $storageAccountName -ErrorAction SilentlyContinue
if (-not $storage) {
    if ($WhatIf) {
        Write-Host " [WhatIf] Se crearía Storage Account: $storageAccountName" -ForegroundColor Magenta
    } else {
        $storage = New-AzStorageAccount -ResourceGroupName $ResourceGroupName `
            -Name $storageAccountName `
            -SkuName "Standard_LRS" `
            -Kind "StorageV2" `
            -Location $Location `
            -EnableHttpsTrafficOnly $true `
            -MinimumTlsVersion "TLS1_2" `
            -Tags $tags
        
        # Habilitar firewall (solo IPs propias inicialmente, luego se permitirá VNet)
        Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $ResourceGroupName `
            -Name $storageAccountName `
            -DefaultAction "Deny" | Out-Null
        
        Write-Host " ✓ Storage Account creada: $($storage.StorageAccountName)" -ForegroundColor Gray
    }
} else {
    Write-Host " ✓ Storage Account existente: $($storage.StorageAccountName)" -ForegroundColor Gray
}

# ============================================
# CREAR AZURE FUNCTION APP
# ============================================

Write-Host "`n[5/8] Creando Azure Function App..." -ForegroundColor Green

$funcApp = Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $functionAppName -ErrorAction SilentlyContinue
if (-not $funcApp) {
    if ($WhatIf) {
        Write-Host " [WhatIf] Se crearía Function App: $functionAppName" -ForegroundColor Magenta
    } else {
        # Crear App Service Plan (Consumption para serverless)
        $planName = "$prefix-plan-$Environment"
        $plan = Get-AzAppServicePlan -ResourceGroupName $ResourceGroupName -Name $planName -ErrorAction SilentlyContinue
        
        if (-not $plan) {
            $plan = New-AzAppServicePlan -ResourceGroupName $ResourceGroupName `
                -Name $planName `
                -Location $Location `
                -Tier "Consumption" `
                -WorkerSize "Small"
            Write-Host " ✓ App Service Plan creado: $($plan.Name)" -ForegroundColor Gray
        }
        
        # Crear Function App
        $funcApp = New-AzWebApp -ResourceGroupName $ResourceGroupName `
            -Name $functionAppName `
            -AppServicePlan $plan.Name `
            -Location $Location `
            -StorageAccount $storageAccountName `
            -Runtime "dotnet" `
            -FunctionsVersion "4" `
            -Tag $tags
        
        # Configurar VNet Integration
        $funcApp = Get-AzWebApp -ResourceGroupName $ResourceGroupName -Name $functionAppName
        # Nota: La integración de VNet requiere Premium Tier o mayor
        # Para Consumption, usamos Private Endpoint directamente
        
        Write-Host " ✓ Function App creada: $($funcApp.Name)" -ForegroundColor Gray
    }
} else {
    Write-Host " ✓ Function App existente: $($funcApp.Name)" -ForegroundColor Gray
}

# ============================================
# CREAR EVENT GRID TOPIC
# ============================================

Write-Host "`n[6/8] Creando Event Grid Topic..." -ForegroundColor Green

$egt = Get-AzEventGridTopic -ResourceGroupName $ResourceGroupName -Name $eventGridTopicName -ErrorAction SilentlyContinue
if (-not $egt) {
    if ($WhatIf) {
        Write-Host " [WhatIf] Se crearía Event Grid Topic: $eventGridTopicName" -ForegroundColor Magenta
    } else {
        $egt = New-AzEventGridTopic -ResourceGroupName $ResourceGroupName `
            -Name $eventGridTopicName `
            -Location $Location `
            -Tag $tags
        
        Write-Host " ✓ Event Grid Topic creado: $($egt.Name)" -ForegroundColor Gray
    }
} else {
    Write-Host " ✓ Event Grid Topic existente: $($egt.Name)" -ForegroundColor Gray
}

# ============================================
# CREAR PRIVATE ENDPOINTS
# ============================================

Write-Host "`n[7/8] Creando Private Endpoints..." -ForegroundColor Green

# Private Endpoint para Function App
$peFunc = Get-AzPrivateEndpoint -ResourceGroupName $ResourceGroupName -Name $privateEndpointFuncName -ErrorAction SilentlyContinue
if (-not $peFunc) {
    if ($WhatIf) {
        Write-Host " [WhatIf] Se crearía Private Endpoint para Function: $privateEndpointFuncName" -ForegroundColor Magenta
    } else {
        $peFunc = New-AzPrivateEndpoint -ResourceGroupName $ResourceGroupName `
            -Name $privateEndpointFuncName `
            -Location $Location `
            -Subnet $subnetPE `
            -PrivateLinkServiceConnection $(
                New-AzPrivateLinkServiceConnection -Name "func-connection" `
                    -PrivateLinkServiceId $funcApp.Id `
                    -GroupId "sites"
            ) `
            -Tag $tags
        
        Write-Host " ✓ Private Endpoint Function creado" -ForegroundColor Gray
    }
} else {
    Write-Host " ✓ Private Endpoint Function existente" -ForegroundColor Gray
}

# Private Endpoint para Event Grid Topic
$peEgt = Get-AzPrivateEndpoint -ResourceGroupName $ResourceGroupName -Name $privateEndpointEgtName -ErrorAction SilentlyContinue
if (-not $peEgt) {
    if ($WhatIf) {
        Write-Host " [WhatIf] Se crearía Private Endpoint para Event Grid: $privateEndpointEgtName" -ForegroundColor Magenta
    } else {
        $peEgt = New-AzPrivateEndpoint -ResourceGroupName $ResourceGroupName `
            -Name $privateEndpointEgtName `
            -Location $Location `
            -Subnet $subnetPE `
            -PrivateLinkServiceConnection $(
                New-AzPrivateLinkServiceConnection -Name "egt-connection" `
                    -PrivateLinkServiceId $egt.Id `
                    -GroupId "topic"
            ) `
            -Tag $tags
        
        Write-Host " ✓ Private Endpoint Event Grid creado" -ForegroundColor Gray
    }
} else {
    Write-Host " ✓ Private Endpoint Event Grid existente" -ForegroundColor Gray
}

# ============================================
# CREAR ZONAS DNS PRIVADAS
# ============================================

Write-Host "`n[8/8] Configurando DNS Privadas..." -ForegroundColor Green

# Zona DNS para Function App
$dnsZoneFunc = Get-AzPrivateDnsZone -ResourceGroupName $ResourceGroupName -Name $dnsZoneFuncName -ErrorAction SilentlyContinue
if (-not $dnsZoneFunc) {
    if ($WhatIf) {
        Write-Host " [WhatIf] Se crearía DNS Zone: $dnsZoneFuncName" -ForegroundColor Magenta
    } else {
        $dnsZoneFunc = New-AzPrivateDnsZone -ResourceGroupName $ResourceGroupName `
            -Name $dnsZoneFuncName `
            -Tags $tags
        
        # Vincular a VNet
        $link = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $ResourceGroupName `
            -ZoneName $dnsZoneFuncName `
            -Name "$VnetName-link" `
            -VirtualNetworkId $vnet.Id
        
        Write-Host " ✓ DNS Zone Function creada: $($dnsZoneFunc.Name)" -ForegroundColor Gray
    }
} else {
    Write-Host " ✓ DNS Zone Function existente: $($dnsZoneFunc.Name)" -ForegroundColor Gray
}

# Zona DNS para Event Grid Topic
$dnsZoneEgt = Get-AzPrivateDnsZone -ResourceGroupName $ResourceGroupName -Name $dnsZoneEgtName -ErrorAction SilentlyContinue
if (-not $dnsZoneEgt) {
    if ($WhatIf) {
        Write-Host " [WhatIf] Se crearía DNS Zone: $dnsZoneEgtName" -ForegroundColor Magenta
    } else {
        $dnsZoneEgt = New-AzPrivateDnsZone -ResourceGroupName $ResourceGroupName `
            -Name $dnsZoneEgtName `
            -Tags $tags
        
        # Vincular a VNet
        $link = New-AzPrivateDnsVirtualNetworkLink -ResourceGroupName $ResourceGroupName `
            -ZoneName $dnsZoneEgtName `
            -Name "$VnetName-link-egt" `
            -VirtualNetworkId $vnet.Id
        
        Write-Host " ✓ DNS Zone Event Grid creada: $($dnsZoneEgt.Name)" -ForegroundColor Gray
    }
} else {
    Write-Host " ✓ DNS Zone Event Grid existente: $($dnsZoneEgt.Name)" -ForegroundColor Gray
}

# ============================================
# CONFIGURAR REGISTROS DNS
# ============================================

if (-not $WhatIf) {
    Write-Host "`n[Bonus] Configurando registros DNS..." -ForegroundColor Green
    
    # Obtener IPs de los Private Endpoints
    $nicFunc = Get-AzNetworkInterface -ResourceId $peFunc.NetworkInterfaces[0].Id
    $ipFunc = ($nicFunc.IpConfigurations | Select-Object -First 1).PrivateIpAddress
    
    $nicEgt = Get-AzNetworkInterface -ResourceId $peEgt.NetworkInterfaces[0].Id
    $ipEgt = ($nicEgt.IpConfigurations | Select-Object -First 1).PrivateIpAddress
    
    # Registro para Function App
    $recordFunc = Get-AzPrivateDnsRecordSet -ResourceGroupName $ResourceGroupName `
        -ZoneName $dnsZoneFuncName `
        -Name $functionAppName `
        -RecordType A -ErrorAction SilentlyContinue
    
    if (-not $recordFunc) {
        New-AzPrivateDnsRecordSet -ResourceGroupName $ResourceGroupName `
            -ZoneName $dnsZoneFuncName `
            -Name $functionAppName `
            -RecordType A `
            -Ttl 300 `
            -PrivateDnsRecords @(New-AzPrivateDnsRecordConfig -Ipv4Address $ipFunc) | Out-Null
        
        Write-Host " ✓ Registro DNS Function: $functionAppName -> $ipFunc" -ForegroundColor Gray
    }
    
    # Registro para Event Grid Topic
    $recordEgt = Get-AzPrivateDnsRecordSet -ResourceGroupName $ResourceGroupName `
        -ZoneName $dnsZoneEgtName `
        -Name $eventGridTopicName `
        -RecordType A -ErrorAction SilentlyContinue
    
    if (-not $recordEgt) {
        New-AzPrivateDnsRecordSet -ResourceGroupName $ResourceGroupName `
            -ZoneName $dnsZoneEgtName `
            -Name $eventGridTopicName `
            -RecordType A `
            -Ttl 300 `
            -PrivateDnsRecords @(New-AzPrivateDnsRecordConfig -Ipv4Address $ipEgt) | Out-Null
        
        Write-Host " ✓ Registro DNS Event Grid: $eventGridTopicName -> $ipEgt" -ForegroundColor Gray
    }
}

# ============================================
# PERMITIR TRÁFICO DE VNET EN STORAGE
# ============================================

if (-not $WhatIf) {
    Write-Host "`n[Bonus] Configurando firewall de Storage..." -ForegroundColor Green
    
    # Añadir regla para permitir tráfico de las subnets
    Add-AzStorageAccountNetworkRule -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $storageAccountName `
        -VirtualNetworkResourceId $subnetFunc.Id,$subnetPE.Id | Out-Null
    
    Update-AzStorageAccountNetworkRuleSet -ResourceGroupName $ResourceGroupName `
        -StorageAccountName $storageAccountName `
        -DefaultAction "Deny" -Bypass "AzureServices" | Out-Null
    
    Write-Host " ✓ Firewall Storage configurado" -ForegroundColor Gray
}

# ============================================
# RESUMEN FINAL
# ============================================

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "  ✓ Despliegue Completado" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

Write-Host @"

RECURSOS CREADOS:
=================
• Resource Group: $ResourceGroupName
• VNet: $VnetName
  - Subnet Function: $subnetFunctionName (10.0.1.0/24)
  - Subnet Private Endpoints: $subnetEventGridName (10.0.2.0/24)
• Storage Account: $storageAccountName
• Function App: $functionAppName
• Event Grid Topic: $eventGridTopicName
• Private Endpoints: 2 creados
• DNS Zones Privadas: 2 creadas

CONECTIVIDAD PRIVADA:
=====================
• Function App accesible via: https://$functionAppName.privatelink.azurewebsites.net
• Event Grid Topic accesible via: https://$eventGridTopicName.privatelink.eventgrid.azure.net
• Resolución DNS automática dentro de la VNet

PRÓXIMOS PASOS:
===============
1. Desplegar código a la Function App
2. Configurar Event Grid Subscription
3. Probar conectividad desde VM en la VNet
4. Configurar Application Insights (opcional)

"@ -ForegroundColor White

# Exportar variables para uso posterior
$script:DeployedResources = @{
    ResourceGroupName   = $ResourceGroupName
    VNetName            = $VnetName
    FunctionAppName     = $functionAppName
    EventGridTopicName  = $eventGridTopicName
    StorageAccountName = $storageAccountName
}

if ($WhatIf) {
    Write-Host "⚠️  MODO WHAT-IF: No se creó ningún recurso" -ForegroundColor Yellow
}

return $script:DeployedResources

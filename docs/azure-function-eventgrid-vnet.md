# Guía Completa: Conectar Azure Function a Event Grid Topic mediante VNet Privada

## 📋 Overview

Esta guía describe cómo configurar una conexión privada entre una **Azure Function** y un **Event Grid Topic** usando Private Endpoints, evitando el tráfico por internet público.

---

## 🏗️ Arquitectura del Flujo

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           AZURE VIRTUAL NETWORK                             │
│                                                                             │
│  ┌──────────────────────┐         ┌─────────────────────────────────────┐  │
│  │   AZURE FUNCTION     │         │         EVENT GRID TOPIC            │  │
│  │                      │         │                                     │  │
│  │  ┌────────────────┐  │         │  ┌───────────────────────────────┐   │  │
│  │  │ Function App   │  │         │  │   Private Endpoint           │   │  │
│  │  │ (Premium/      │◄─┼─────────┼─►│   (topic.eventgrid.azure.net)│   │  │
│  │  │  Dedicated)    │  │         │  └───────────────────────────────┘   │  │
│  │  └────────────────┘  │         │                                     │  │
│  │         ▲            │         │                                     │  │
│  │         │ VNet       │         │                                     │  │
│  │  ┌─────┴──────────┐  │         │                                     │  │
│  │  │ Private        │  │         │                                     │  │
│  │  │ Endpoint       │  │         │                                     │  │
│  │  │ (outbound)     │  │         │                                     │  │
│  │  └────────────────┘  │         │                                     │  │
│  └──────────┬───────────┘         └─────────────────────────────────────┘  │
│             │                                                                   │
│  ┌──────────┴───────────┐                                                      │
│  │   Subnet            │                                                      │
│  │   (FunctionsSubnet) │                                                      │
│  └─────────────────────┘                                                      │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Flujo de Datos:
1. **Evento** → Llega al Event Grid Topic
2. **Private Endpoint** → Recibe el evento dentro de la VNet
3. **VNet Integration** → La Function recibe el evento vía IP privada
4. **Procesamiento** → La Function procesa el evento sin exponer datos al exterior

---

## ✅ Prerrequisitos

| Recurso | Descripción |
|---------|-------------|
| **Azure Subscription** | Suscripción activa con permisos de contributor |
| **Virtual Network** | VNet existente en la misma región |
| **Subnet** | Subnet dedicada para Azure Functions (/27 mínimo) |
| **Azure Function** | Plan Premium o Dedicated (App Service) |
| **Event Grid Topic** | Custom Topic (no funciona con System Topics) |

---

## 🔧 Paso 1: Configurar la Virtual Network

### 1.1 Crear la VNet (si no existe)

```bash
az network vnet create \
  --name myVNet \
  --resource-group myResourceGroup \
  --location eastus \
  --address-prefix 10.0.0.0/16 \
  --subnet-name FunctionsSubnet \
  --subnet-prefix 10.0.1.0/27
```

### 1.2 Delegar subnet para Azure Functions

```bash
az network vnet subnet update \
  --name FunctionsSubnet \
  --vnet-name myVNet \
  --resource-group myResourceGroup \
  --delegations Microsoft.App/environments
```

> **Nota:** Para planes Elastic Premium/Dedicated usa `Microsoft.Web/sites`

---

## 🔧 Paso 2: Configurar Azure Function con VNet Integration

### 2.1 Crear Function App (si no existe)

```bash
az functionapp create \
  --name myFunctionApp \
  --resource-group myResourceGroup \
  --storage-account mystorageaccount \
  --plan myPremiumPlan \
  --runtime dotnet-isolated \
  --functions-version 4
```

### 2.2 Habilitar Virtual Network Integration

**Via Azure Portal:**
1. Ir a **Function App** → **Networking**
2. En "Virtual network integration", seleccionar **Click here to configure**
3. Agregar VNet → Seleccionar tu VNet y subnet
4. Guardar

**Via CLI:**
```bash
az functionapp vnet-integration add \
  --name myFunctionApp \
  --resource-group myResourceGroup \
  --vnet myVNet \
  --subnet FunctionsSubnet
```

### 2.3 Configurar la Function como Event Handler

La función debe tener un trigger de tipo **EventGrid**:

```csharp
[Function("EventGridTrigger")]
public async Task Run(
    [EventGridTrigger] CloudEvent cloudEvent,
    ILogger log)
{
    log.LogInformation("Event received: {type}", cloudEvent.Type);
    // Procesar evento
}
```

O usar webhook genérico:

```csharp
[Function("WebhookTrigger")]
public async Task<HttpResponseData> Run(
    [HttpTrigger(AuthorizationLevel.Function, "post")] HttpRequestData req,
    ILogger log)
{
    // Procesar evento HTTP desde Event Grid
}
```

---

## 🔧 Paso 3: Configurar Private Endpoint en Event Grid Topic

### 3.1 Crear Private Endpoint

**Via Azure Portal:**

1. Ir al **Event Grid Topic** → **Networking**
2. Seleccionar **Private endpoints only** en "Public access"
3. Click en **+ Private endpoint**

```
Configuración:
├── Name: myTopicPrivateEndpoint
├── Region: eastus
├── Target sub-resource: topic
├── Virtual Network: myVNet
├── Subnet: FunctionsSubnet
└── Integrate with DNS: Yes (Private DNS Zone)
```

4. Completar el wizard y crear

### 3.2 Aprobar la conexión del Private Endpoint

```bash
# Obtener el ID del private endpoint connection
az network private-endpoint-connection list \
  --resource-group myResourceGroup \
  --name myEventGridTopic

# Aprobar la conexión
az network private-endpoint-connection approve \
  --resource-group myResourceGroup \
  --name myEventGridTopic \
  --description "Approved for VNet integration"
```

---

## 🔧 Paso 4: Suscribir la Function al Topic

### 4.1 Crear Event Subscription

```bash
az eventgrid event-subscription create \
  --resource-group myResourceGroup \
  --topic-name myEventGridTopic \
  --name myFunctionSubscription \
  --endpoint-type webhook \
  --endpoint-url "https://myfunctionapp.azurewebsites.net/runtime/webhooks/eventgrid?functionName=EventGridTrigger"
```

### 4.2 Verificar que la suscripción use el Private Endpoint

```bash
az eventgrid event-subscription show \
  --resource-group myResourceGroup \
  --topic-name myEventGridTopic \
  --name myFunctionSubscription \
  --query "deliveryConfiguration"
```

---

## 🔧 Paso 5: Configurar DNS Privado (Opcional pero Recomendado)

### 5.1 Crear Private DNS Zone

```bash
az network private-dns zone create \
  --resource-group myResourceGroup \
  --name "privatelink.eventgrid.azure.net"
```

### 5.2 Vincular DNS Zone a la VNet

```bash
az network private-dns link vnet create \
  --resource-group myResourceGroup \
  --name myDnsLink \
  --zone-name "privatelink.eventgrid.azure.net" \
  --virtual-network myVNet \
  --registration-enabled false
```

### 5.3 Verificar resolución DNS

Desde una VM en la VNet:
```bash
nslookup mytopic.eventgrid.azure.net
```

Debería resolver a una IP privada (10.0.x.x)

---

## 🧪 Paso 6: Prueba de la Integración

### 6.1 Enviar evento de prueba

```bash
az eventgrid event create \
  --resource-group myResourceGroup \
  --topic-name myEventGridTopic \
  --event-type "Microsoft.Storage.BlobCreated" \
  --subject "/blobServices/default/containers/test/blob.txt" \
  --data '{"blobName":"test.txt","size":1024}'
```

### 6.2 Verificar en los logs de la Function

```bash
az functionapp logs show \
  --name myFunctionApp \
  --resource-group myResourceGroup \
  --tail 50
```

---

## 📊 Estados de Conexión

| Estado | Significado | Acción Requerida |
|--------|-------------|------------------|
| `Pending` | Esperando aprobación | Aprobar manualmente |
| `Approved` | Conexión activa | ✅ Correcto |
| `Rejected` | Conexión denegada | Revisar configuración |
| `Disconnected` | Conexión eliminada | Recrear el endpoint |

---

## ⚠️ Consideraciones Importantes

### Plan de Hosting
| Plan | Soporte VNet Integration | Soporte Private Endpoint |
|------|---------------------------|---------------------------|
| Consumption | ❌ | ❌ |
| Flex Consumption | ✅ | ✅ (inbound) |
| Premium (EP) | ✅ | ✅ |
| Dedicated (App Service) | ✅ | ✅ |

### Restricciones
- **No se puede** usar private endpoint con System Topics
- La Function debe tener **VNet Integration** habilitada para recibir eventos
- Ambos recursos deben estar en la **misma región** (o regiones emparejadas)

### Seguridad Adicional
1. **Habilitar TLS** en la Function (minimum TLS 1.2)
2. **Restringir IPs** inbound en la Function
3. **Usar Managed Identity** para acceder a recursos Azure

---

## 🔗 Recursos Adicionales

- [Azure Functions Networking Options](https://learn.microsoft.com/en-us/azure/azure-functions/functions-networking-options)
- [Event Grid Private Endpoints](https://learn.microsoft.com/en-us/azure/event-grid/configure-private-endpoints)
- [Azure Private Link](https://learn.microsoft.com/en-us/azure/private-link/private-endpoint-overview)

---

*Documento generado: 2024 | Última actualización: Ver fecha en metadatos*

# 🐳 Docker Test Environment

Este directorio contiene la configuración Docker para ejecutar los tests de forma reproducible y containerizada.

## 📋 Requisitos

- Docker 20.10+
- Docker Compose 2.0+
- 4GB RAM disponibles

## 🚀 Uso Rápido

```bash
# Entrar al directorio docker
cd docker

# Ejecutar todos los tests
./run-tests.sh full

# Ejecutar solo tests Pester
./run-tests.sh pester

# Ejecutar solo Terraform
./run-tests.sh terraform

# Ejecutar seguridad
./run-tests.sh security

# Limpiar
./run-tests.sh clean
```

## 📦 Servicios Disponibles

| Servicio | Descripción | Perfil |
|----------|-------------|--------|
| `pester-tests` | Unit + E2E tests con Pester | `test`, `pester` |
| `terraform-validate` | Terraform init + validate + plan | `test`, `terraform` |
| `security-scan` | Checkov security scanning | `test`, `security` |
| `tfsec-scan` | TFSec security scanning | `test`, `security` |
| `full-test-suite` | Suite completa de tests | `test`, `full` |
| `lint` | Linting de scripts | `lint` |

## 🎯 Comandos Docker Compose

```bash
# Build de imágenes
docker compose build

# Run specific service
docker compose run --rm pester-tests

# Run with profile
docker compose --profile test run --rm full-test-suite

# Ver logs
docker compose logs -f pester-tests

# Stop all
docker compose down
```

## 🔧 Configuración de Entorno

### Variables de Entorno

| Variable | Default | Descripción |
|----------|---------|-------------|
| `TEST_MODE` | `all` | Modo de test (all/pester/terraform/security) |
| `COVERAGE_THRESHOLD` | `90` | Porcentaje mínimo de coverage |

### Volúmenes

Los resultados de tests se guardan en:
- `./test-results/` - Resultados en formato JUnit XML

## 🧪 Ejecutar Tests Específicos

### Solo Pester (PowerShell)
```bash
docker compose --profile pester run --rm pester-tests
```

### Solo Terraform
```bash
docker compose --profile terraform run --rm terraform-validate
```

### Solo Security
```bash
docker compose --profile security run --rm security-scan
```

### Suite Completa
```bash
docker compose --profile full run --rm full-test-suite
```

## 📊 Coverage

Los tests Pester están configurados para:
- **Target**: >90% cobertura
- **Salida**: JUnit XML en `./test-results/`

Para ver coverage en local:
```bash
docker compose run --rm pester-tests pwsh -Command "
    Invoke-Pester -Path /app/tests -CodeCoverage -CodeCoverageThreshold 90
"
```

## 🔐 Security Scans

### Checkov
```bash
docker compose run --rm security-scan checkov -d /app/terraform --output cli
```

### TFSec
```bash
docker compose run --rm tfsec-scan tfsec /app/terraform
```

## 🧹 Limpieza

```bash
# Limpiar contenedores
docker compose down

# Limpiar contenedores y volúmenes
docker compose down -v

# Reconstruir imágenes
docker compose build --no-cache
```

## 📝 Notas

- Las imágenes se build desde `Dockerfile.test`
- El directorio de trabajo es `/app` dentro del contenedor
- Los resultados de tests se mountan desde el host para persistencia

## 🚨 Troubleshooting

### Error de permisos
```bash
chmod +x run-tests.sh
```

### Docker no disponible
```bash
# Verificar Docker
docker version

# Iniciar Docker
sudo systemctl start docker
```

### Tests fallan por timeout
```bash
# Aumentar timeout en docker-compose.yml
# o ejecutar con más recursos
```

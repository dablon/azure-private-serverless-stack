# 🚨 Configuración de Protección de Rama - Acciones Requeridas

## Estado: ⚠️ Requiere Configuración Manual

El token de GitHub actual no tiene permisos de `workflow` para configurar la protección de rama automáticamente.

## 📋 Pasos para configurar en GitHub:

### 1. Proteger rama `main`

1. Ir a: https://github.com/dablon/azure-private-serverless-stack/settings/branches
2. Click **"Add branch protection rule"**
3. Configurar:
   - **Branch name pattern**: `main`
   - ✅ **Require pull request reviews before merging**
   - ✅ **Require approvals**: 1
   - ✅ **Dismiss stale reviews when new commits are pushed**
   - ✅ **Require review from @reviewer**

### 2. Agregar secrets/tokens (opcional para CI/CD)

Ir a: https://github.com/dablon/azure-private-serverless-stack/settings/secrets

---

## ✅ Checklist de @reviewer

El reviewer debe verificar antes de aprobar cualquier PR:

### Generales
- [ ] Tests pasan
- [ ] Cobertura >90%
- [ ] Sin secretos en código
- [ ] Documentación actualizada

### Terraform
- [ ] `terraform validate` exitoso
- [ ] Variables documentadas
- [ ] Recursos con tags

### PowerShell
- [ ] Sin errores de sintaxis
- [ ] Parámetros documentados
- [ ] Idempotente

---

## 📦 Archivos de Review Incluidos

- `.github/workflows/review-check.yml` - Workflow de validación
- `REVIEW_CHECKLIST.md` - Checklist completo

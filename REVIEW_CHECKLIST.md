# Review Checklist - Azure Private Serverless Stack

## 📋 Proceso de Code Review

### Antes de aprobar un PR:

- [ ] **Tests pasan** (Unit + E2E)
- [ ] **Cobertura >90%**
- [ ] **Sin secretos/credenciales** en código
- [ ] **Documentación actualizada**
- [ ] **Terraform válido** (`terraform validate`)
- [ ] **PowerShell sin errores** de sintaxis

### Para componentes específicos:

#### PowerShell Script
- [ ] Parámetros bien documentados
- [ ] Manejo de errores adecuado
- [ ] Idempotencia verificada

#### Terraform
- [ ] Variables con defaults razonables
- [ ] Outputs útiles definidos
- [ ] Recursos con tags apropiados

#### Documentación
- [ ] Diagramas actualizados
- [ ] Pasos son reproducibles

---

## 🔧 Configuración de Rama Protegida

**Main branch**: `main`
- ✅ Require pull request reviews before merging
- ✅ Require approvals: 1
- ✅ Require review from @reviewer

---

## 📌 Flujo de Trabajo

```
1. Crear branch: feature/nombre-rama
2. Hacer cambios y commits
3. Push y crear PR
4. @reviewer revisa y aprueba
5. Merge a main (solo si approved)
```

## ✅ Comando para revisar PR localmente

```bash
# Ver cambios
gh pr checkout <PR-number>
git log --oneline -10

# Tests
cd terraform/azure-private-endpoints && terraform validate
pwsh -File scripts/Deploy-AzureServerlessStack.ps1 -WhatIf
```

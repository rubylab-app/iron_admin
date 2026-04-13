# Cómo configurar Copilot Code Review automático en cualquier repositorio

## Prerequisitos

- GitHub Copilot Business o Enterprise (el plan individual gratuito no incluye review de PRs)
- Permisos de admin en el repositorio

---

## Paso 1: Crear las instrucciones de review

Crea el archivo `.github/copilot-review-instructions.md` en tu repositorio. Este archivo le dice a Copilot **qué revisar y qué ignorar** — es el equivalente a un CLAUDE.md pero para Copilot.

```markdown
# Copilot Code Review Instructions

## Project Context
[Describe tu proyecto aquí — stack, arquitectura, convenciones]

## What to Review
- [Lista de cosas que Copilot debe verificar]
- Security: SQL injection, XSS, strong params
- Testing: convenciones de tu equipo
- Architecture: patrones que deben seguirse

## What NOT to Flag
- [Cosas que Copilot debe ignorar]
- Código fuera del diff
- Preferencias de estilo que tu linter ya cubre
```

Copilot lee este archivo automáticamente cuando hace review. No necesita configuración adicional.

---

## Paso 2: Activar review automático via Rulesets (API)

Ejecuta este comando reemplazando `OWNER/REPO` con tu repositorio y `RULESET_ID` con el ID de tu ruleset:

### 2a. Si ya tienes un ruleset, obtén su ID:

```bash
gh api repos/OWNER/REPO/rulesets --jq '.[].id'
```

### 2b. Si NO tienes ruleset, créalo desde cero:

```bash
gh api repos/OWNER/REPO/rulesets -X POST --input - <<'JSON'
{
  "name": "Protect main",
  "target": "branch",
  "enforcement": "active",
  "conditions": {
    "ref_name": {
      "include": ["refs/heads/main"],
      "exclude": []
    }
  },
  "rules": [
    {
      "type": "pull_request",
      "parameters": {
        "required_approving_review_count": 0,
        "dismiss_stale_reviews_on_push": false,
        "require_code_owner_review": false,
        "require_last_push_approval": false,
        "required_review_thread_resolution": false,
        "allowed_merge_methods": ["merge", "squash", "rebase"]
      }
    },
    {
      "type": "copilot_code_review",
      "parameters": {
        "review_on_push": true,
        "review_draft_pull_requests": false
      }
    }
  ],
  "bypass_actors": []
}
JSON
```

### 2c. Si ya tienes un ruleset, agrégale la regla de Copilot:

```bash
# Primero obtén el ruleset actual
gh api repos/OWNER/REPO/rulesets/RULESET_ID > /tmp/ruleset.json

# Agrégale la regla copilot_code_review al array de rules
# y actualízalo (ver ejemplo abajo)
```

El campo clave es:
```json
{
  "type": "copilot_code_review",
  "parameters": {
    "review_on_push": true,
    "review_draft_pull_requests": false
  }
}
```

---

## Paso 3: Activar "Review on push" desde la UI

**IMPORTANTE:** La API agrega la regla pero `review_on_push: true` puede no persistir via API. Debes confirmarlo manualmente:

1. Ve a `https://github.com/OWNER/REPO/rules/RULESET_ID`
2. Busca la sección **"Copilot code review"**
3. Marca la casilla **"Review on push"**
4. Opcionalmente marca **"Review draft pull requests"** si quieres que revise borradores
5. Guarda

---

## Paso 4: Verificar que funciona

1. Crea un PR nuevo en el repositorio
2. En la timeline del PR deberías ver:
   - **"Copilot review requested due to automatic review settings"**
   - **"Copilot started reviewing on behalf of [usuario]"**
3. Después de 1-5 minutos, Copilot dejará comentarios inline en el diff

---

## Cómo se ve cuando funciona

En la timeline del PR aparece:

```
👁 Copilot (AI) review requested due to automatic review settings
🔄 Copilot started reviewing on behalf of @tu-usuario    [View session]
```

Y luego un review con:
- Resumen del PR (overview)
- Tabla de archivos revisados
- Comentarios inline en líneas específicas del diff

---

## Parámetros del ruleset

| Parámetro | Tipo | Descripción |
|-----------|------|-------------|
| `review_on_push` | Boolean | Solicitar review automáticamente en cada push al PR |
| `review_draft_pull_requests` | Boolean | También revisar PRs en estado draft |

---

## Troubleshooting

### Copilot no revisa el PR
- Verifica que el plan de Copilot incluye code review (Business/Enterprise)
- Verifica que `review_on_push` está en `true` en el ruleset
- El PR no debe tener solo archivos no soportados (imágenes, binarios)

### Los comentarios no siguen las instrucciones
- Verifica que `.github/copilot-review-instructions.md` existe en la rama default (main)
- El archivo debe estar en la rama **base** del PR, no en la rama del PR

### La API no persiste `review_on_push: true`
- Esto es una limitación conocida. Actívalo desde la UI del ruleset
- URL: `https://github.com/OWNER/REPO/rules/RULESET_ID`

---

## Resumen rápido (TL;DR)

```bash
# 1. Crea instrucciones de review
cat > .github/copilot-review-instructions.md << 'EOF'
# Review Instructions
[Tu contenido aquí]
EOF

# 2. Agrega la regla al ruleset
gh api repos/OWNER/REPO/rulesets -X POST --input - <<'JSON'
{
  "name": "Protect main",
  "target": "branch",
  "enforcement": "active",
  "conditions": {"ref_name": {"include": ["refs/heads/main"], "exclude": []}},
  "rules": [
    {"type": "pull_request", "parameters": {"required_approving_review_count": 0}},
    {"type": "copilot_code_review", "parameters": {"review_on_push": true}}
  ],
  "bypass_actors": []
}
JSON

# 3. Ve a la UI del ruleset y confirma que "Review on push" está marcado
# https://github.com/OWNER/REPO/settings/rules
```

Listo. Cada PR nuevo será revisado automáticamente por Copilot.

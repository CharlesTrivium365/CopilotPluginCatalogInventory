# Journal des modifications

## 1.0.0 (2026-11-02)

- Première version publique.
- Inventaire en lecture seule des packages du catalogue d'administration Microsoft Copilot par GET /v1.0/copilot/admin/catalog/packages.
- Sortie en objets PowerShell ou en JSON (-AsJson).
- Rapport HTML facultatif (-HtmlReportPath) compatible avec -WhatIf et -Confirm.
- Réutilisation d'une session Microsoft Graph existante (-SkipConnect).

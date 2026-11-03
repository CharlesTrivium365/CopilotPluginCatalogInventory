# CopilotPluginCatalogInventory

Script PowerShell en lecture seule qui dresse l'inventaire des packages du catalogue d'administration Microsoft Copilot (anciennement Microsoft 365 Copilot) par l'API Microsoft Graph. Il renvoie des objets PowerShell que vous pouvez explorer ou filtrer. Il peut aussi produire une sortie JSON ou un rapport HTML simple.

## Pourquoi maintenant

Le 30 septembre 2026, le blogue Microsoft Copilot a annoncé le registre des plugins Microsoft (Microsoft plugin registry). Un plugin regroupe des skills (des instructions réutilisables), des connecteurs (un accès approuvé à des services et à des données) et des agents. Pour les utilisateurs, une page Plugins remplace la page Agents dans les expériences Copilot prises en charge : Home (Chat et Cowork), Code, Autopilot, les applications Microsoft 365 (Word, Excel et PowerPoint) et SharePoint.

Le registre se gère dans l'expérience Agent 365 du centre d'administration Microsoft 365, sous Agents puis Tools. Les administrateurs peuvent y activer, désactiver, bloquer ou attribuer des plugins à des utilisateurs ou à des groupes. Microsoft annonce plus de 100 plugins déjà offerts et le déploiement est progressif : selon votre locataire, le registre n'est pas forcément visible tout de suite.

Avant d'activer ou de bloquer quoi que ce soit, il est utile de savoir ce que le catalogue contient déjà. Cet outil reprend le script de l'article et le rend réutilisable : connexion facultative, objets PowerShell, sortie JSON et rapport HTML.

## Ce que fait l'outil

- Se connecte à Microsoft Graph avec l'étendue CopilotPackages.Read.All (sauf si vous utilisez -SkipConnect).
- Envoie une seule requête GET vers https://graph.microsoft.com/v1.0/copilot/admin/catalog/packages.
- Renvoie chaque package sous forme d'objet PowerShell sans renommer ni filtrer ses propriétés, puisque le schéma est en préversion.
- Produit au besoin une sortie JSON (-AsJson) ou un rapport HTML (-HtmlReportPath).
- Ne modifie aucun réglage du locataire.

## Lecture seule

L'outil n'offre aucun paramètre -Apply parce qu'il n'effectue aucune modification du locataire. Les sources utilisées pour ce dépôt ne décrivent aucun point d'API d'écriture pour le catalogue : l'activation, le blocage et l'attribution des plugins se font dans le centre d'administration Microsoft 365.

Seule l'écriture du rapport HTML sur le disque local passe par ShouldProcess. Elle respecte donc -WhatIf et -Confirm. Avec -WhatIf, la connexion et la lecture du catalogue ont quand même lieu puisqu'elles ne changent rien.

## Prérequis

- Windows PowerShell 5.1 ou PowerShell 7.
- Module Microsoft.Graph.Authentication, qui fournit Connect-MgGraph et Invoke-MgGraphRequest.
- Rôle minimal : AI Administrator (ou Global Administrator).
- Permission Microsoft Graph minimale : CopilotPackages.Read.All, avec consentement accordé.
- Licence Microsoft Agent 365 : l'API de gestion des packages du catalogue l'exige.
- Gardez en tête que cette API porte le libellé preview (préversion).

Les fonctions de base du registre et de sa gestion dans le portail sont incluses avec les abonnements Microsoft cloud admissibles selon Microsoft. L'automatisation par l'API demande en plus la licence Microsoft Agent 365.

## Installation

```powershell
Install-Module -Name Microsoft.Graph.Authentication -Scope CurrentUser
```

Téléchargez ensuite le fichier Get-CopilotPluginCatalog.ps1 de ce dépôt (ou clonez le dépôt) dans un dossier de travail. Si la stratégie d'exécution de votre poste bloque les scripts téléchargés, réglez la question selon les règles de votre organisation.

## Utilisation

Afficher l'inventaire dans la console :

```powershell
.\Get-CopilotPluginCatalog.ps1
```

Produire un rapport HTML :

```powershell
.\Get-CopilotPluginCatalog.ps1 -HtmlReportPath .\catalogue-plugins.html
```

Simuler l'écriture du rapport sans créer le fichier :

```powershell
.\Get-CopilotPluginCatalog.ps1 -HtmlReportPath .\catalogue-plugins.html -WhatIf
```

Obtenir la structure brute en JSON, comme le script de l'article :

```powershell
.\Get-CopilotPluginCatalog.ps1 -AsJson -JsonDepth 8 | Out-File -FilePath .\catalogue-plugins.json -Encoding utf8
```

Réutiliser une session Microsoft Graph déjà ouverte :

```powershell
Connect-MgGraph -Scopes 'CopilotPackages.Read.All'
.\Get-CopilotPluginCatalog.ps1 -SkipConnect -Verbose
```

Explorer les propriétés réelles avant de filtrer sur un champ précis :

```powershell
$packages = .\Get-CopilotPluginCatalog.ps1
$packages.Count
$packages[0] | Format-List -Property *
```

## Paramètres

| Paramètre | Rôle |
| --- | --- |
| SkipConnect | Réutilise la session Microsoft Graph courante au lieu d'appeler Connect-MgGraph. |
| AsJson | Renvoie une chaîne JSON au lieu d'objets PowerShell. |
| JsonDepth | Profondeur de sérialisation JSON pour -AsJson et pour les valeurs imbriquées du rapport HTML (5 par défaut). |
| HtmlReportPath | Chemin du rapport HTML à créer. Compatible avec -WhatIf et -Confirm. |

## Exemple de sortie (fictif)

L'exemple suivant est fictif. Les noms de propriétés sont des espaces réservés : les vrais noms dépendent de la préversion de l'API et peuvent changer.

```text
VERBOSE: Connecting to Microsoft Graph with scope CopilotPackages.Read.All.
VERBOSE: GET https://graph.microsoft.com/v1.0/copilot/admin/catalog/packages
VERBOSE: 2 package(s) returned.

proprieteA : valeur fictive 1
proprieteB : valeur fictive 2

proprieteA : valeur fictive 3
proprieteB : valeur fictive 4
```

Le rapport HTML affiche une ligne par package et une colonne par propriété trouvée. Les valeurs imbriquées y apparaissent en JSON compact.

## Limites connues

- L'API est en préversion : les champs retournés peuvent varier. Lisez la sortie complète avant de filtrer sur une propriété.
- Sans licence Microsoft Agent 365, sans le rôle requis ou sans consentement pour CopilotPackages.Read.All, l'appel peut échouer. Le message d'erreur rappelle ces conditions.
- L'outil envoie une seule requête et ne suit aucun lien de pagination, car les sources consultées ne décrivent pas ce comportement pour ce point d'API. Comparez le nombre obtenu avec celui affiché dans le centre d'administration.
- Le registre est en déploiement progressif : le résultat peut être vide ou partiel dans certains locataires. Microsoft précise aussi que certains connecteurs sont encore en cours de déploiement.
- L'outil ne fait aucune action de gestion (activer, bloquer, attribuer ou retirer un plugin).
- Seul le point de terminaison https://graph.microsoft.com est utilisé.
- Copilot Studio, GitHub Copilot et Microsoft Foundry ne sont qu'annoncés pour le registre, sans date précise.

Avant d'attribuer un connecteur, vérifiez quelles données il expose à Copilot et à qui. Plusieurs connecteurs cités par Microsoft donnent accès à des services externes qui contiennent des renseignements personnels.

## Liens

- Article : [Le registre des plugins réunit skills, connecteurs et agents de Microsoft Copilot](https://trivium365.com/blog/registre-plugins-microsoft-copilot-gouvernance/)
- Source Microsoft : [Introducing the plugin registry, blogue Microsoft Copilot, 30 septembre 2026](https://techcommunity.microsoft.com/blog/microsoft-copilot-blog/introducing-the-plugin-registry---one-place-to-discover-and-govern-plugins-for-m/4559682)
- Les détails d'API, de permission, de rôle et de licence proviennent des faits vérifiés sur Microsoft Learn cités dans l'article (registre des packages Copilot).

## Licence

Distribué sous licence MIT. Consultez le fichier LICENSE.

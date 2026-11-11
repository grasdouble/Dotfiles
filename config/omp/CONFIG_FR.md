# Tarifs GPT et profils Vibe — Oh My Pi

**Mise à jour : 11 novembre 2026 — presets renommés selon leur usage.** Référence : configuration OMP recommandée.

## 1. Tarifs des modèles GPT

Tarifs officiels **OpenAI API Standard**, en **USD par million de tokens**, contexte court. Les coûts réels dépendent du cache, du contexte et des options de traitement.

| Modèle | Entrée | Entrée en cache | Sortie | Exemple de coût* |
|---|---:|---:|---:|---:|
| **GPT-6 Luna** | 0,10 $ | 0,01 $ | 0,50 $ | 0,15 $ |
| **GPT-6.1 Terra** | 1,00 $ | 0,05 $ | 5,00 $ | 1,50 $ |
| **GPT-6.1 Sol** | 2,00 $ | 0,10 $ | 10,00 $ | 3,00 $ |
| **GPT-6 Astra** | 10,00 $ | 1,00 $ | 50,00 $ | 15,00 $ |

*Exemple : 1 million de tokens d'entrée non cachée et 100 000 tokens de sortie, hors frais annexes.*

> **Important :** ces tarifs sont ceux de l'API OpenAI, et **non les tarifs ou crédits réellement débités** par `openai-codex` ou `github-copilot`, qui suivent leurs propres quotas et conditions. Le contexte long, certains modes de traitement et la résidence des données peuvent changer le prix.

### Positionnement des modèles

- **Luna :** modifications délimitées, tâches mécaniques et volume important.
- **Terra :** raisonnement visuel, interfaces, automatisation d'écran et correctifs localisés.
- **Sol :** développement complexe et bon compromis capacités/coût.
- **Astra :** raisonnement exigeant, décisions d'architecture et audits difficiles.

## 2. Fenêtres de contexte par fournisseur

La **fenêtre de contexte** est la quantité de tokens que le modèle peut prendre en compte (instructions, historique, fichiers, résultats d’outils, etc.). Il faut distinguer la fenêtre théorique annoncée pour le modèle et les limites réellement exposées par le fournisseur dans OMP.

| Modèle | OpenAI API (fenêtre totale annoncée) | `openai-codex` standard | `openai-codex` étendu | `github-copilot` standard | `github-copilot` étendu |
|---|---:|---:|---:|---:|---:|
| GPT-6 Luna | 1 050 000 | 272 000 | 872 000 | À vérifier | À vérifier (`luna-1m`) |
| GPT-6.1 Terra | 1 050 000 | À vérifier | À vérifier | À vérifier | À vérifier |
| GPT-6.1 Sol | 1 050 000 | 500 000 | 922 000 | 272 000* | 922 000* |
| GPT-6 Astra | 1 050 000 | 272 000 | 922 000 | À vérifier | À vérifier |

**Lecture du tableau :** les valeurs Codex proviennent des informations de limites évoquées dans notre comparaison précédente ; elles sont **indicatives et non vérifiées sur ton installation**. Les valeurs marquées * pour Copilot Sol sont des paliers rapportés, qui ne garantissent pas leur disponibilité dans OMP. Les valeurs OpenAI API ne garantissent pas la même fenêtre pour `openai-codex` ou `github-copilot`. Une fenêtre totale ne se confond pas avec le seul budget d'entrée : la sortie et l'outillage peuvent en utiliser une partie.

Le modèle `github-copilot/gpt-6-luna-1m` utilisé pour ton rôle `Jarvis` porte « 1m » dans son identifiant, **mais ce nom ne prouve pas à lui seul qu’OMP permet effectivement un million de tokens**. Il faut vérifier le contexte reconnu par le fournisseur.

### Vérifier le contexte dans OMP

- Affiche les modèles et leurs propriétés avec `omp models --kind chat` (les options détaillées varient selon la version).
- Dans ta session, vérifie le contexte affiché par OMP, puis les commandes proposées par `/extended-context` si elles sont disponibles dans ta version.
- Active le contexte étendu seulement quand le volume de fichiers ou d'historique l'exige : un grand contexte peut accroître le coût ou la consommation de quotas.

Les données doivent être reconfirmées dans le catalogue des modèles de ton installation avant d'être utilisées comme limites contractuelles.

## 3. Comment fonctionnent les rôles Vibe

OMP distingue le **modèle principal** de la session et deux catégories de workers. Le mode Vibe transforme le modèle principal en **directeur** qui coordonne les délégations ; les workers exécutent les travaux attribués. Les intitulés `fast` et `good` expriment le **type de travail**, pas nécessairement un niveau de qualité garanti.

| Rôle de configuration | Fonction en mode Vibe | À privilégier pour | À éviter si possible |
|---|---|---|---|
| `default` | **Directeur** : interprète le besoin, planifie, choisit les workers, contrôle les résultats et synthétise | Décisions d'architecture, découpage de tâches, arbitrage, validation | Micro-modifications exécutables sans coordination |
| `fast_worker` | **Worker rapide** (`sonic`) : exécute des consignes précises et délimitées | Renommages, ajustements simples, génération de tests ciblés, tâches répétitives | Conception système ambiguë, refactoring transversal délicat |
| `good_worker` | **Worker approfondi** (`task`) : résout les problèmes nécessitant du raisonnement et de l'autonomie | Fonctionnalités importantes, investigation de bugs complexes, refactoring, revue critique | Travaux mécaniques pouvant être traités à moindre coût |

### Le rôle `default` quand Vibe est désactivé

- **Vibe OFF :** `default` définit le modèle principal de conversation et de développement interactif, sous réserve d'un modèle choisi explicitement dans la session.
- **Vibe ON :** ce même rôle est utilisé pour le directeur, chargé d'orchestrer le travail ; c'est pour cela que nos presets Vibe changent son modèle.
- `fast_worker` et `good_worker` sont des rôles de délégation : les déclarer ne crée pas à elles seules de workers actifs.

### Comment OMP associe les rôles aux workers

Dans ta configuration :

```yaml
task:
  agentModelOverrides:
    sonic: "@fast_worker"
    task: "@good_worker"
```

Ici, **`sonic` est routé vers `fast_worker`** et **`task` vers `good_worker`**. Le directeur délègue les tâches selon la nature du problème. Les workers peuvent être réutilisés, ce qui limite les redémarrages et les relectures de contexte.

### Exemples concrets

1. **« Corrige une faute de typage dans un composant React »** : le directeur peut demander au worker `fast` de faire la correction et lancer un test ciblé.
2. **« Refactorise la gestion de l'état entre plusieurs modules »** : le directeur confie l'implémentation au worker `good`, puis vérifie les interfaces et les tests.
3. **« Définis l'architecture d'une nouvelle fonctionnalité »** : le directeur prépare le plan, délègue les travaux indépendants et arbitre leurs résultats.
4. **« Crée un dashboard React à partir d’une maquette »** : `vibe-2-feature` associe Terra à la coordination, Luna aux tâches simples et Sol aux développements complexes.

**Thinking :** `low`, `medium` et `high` règlent l'effort de raisonnement du modèle sélectionné, **pas la mission du worker**. Un `fast_worker` en `low` convient surtout aux tâches spécifiées précisément ; augmenter l'effort peut aider sur des problèmes ambigus mais accroît généralement la consommation.

## 4. Les cinq profils OMP recommandés

Les presets décrivent **l’usage prévu**, pas le nom des modèles. `default` est le directeur Vibe ; `fast_worker` (`sonic`) et `good_worker` (`task`) sont les deux rôles de délégation.

| Preset | Directeur | Fast | Good | Utilisation |
|---|---|---|---|---|
| `normal` | Luna `medium` | Luna `low` | Luna `high` | Développement interactif sans Vibe |
| `vibe-1-maintenance` | Luna `high` | Luna `low` | Luna `high` | Bugs simples, tests et nettoyage |
| `vibe-2-feature` | Terra `medium` | Luna `medium` | Sol `high` | Fonctionnalités, pages React, intégration API |
| `vibe-3-engineering` | Sol `high` | Luna `medium` | Sol `high` | Refactoring transversal, débogage complexe |
| `vibe-4-architecture` | Astra `medium` | Luna `medium` | Sol `high` | Conception de systèmes et migrations majeures |

### Descriptions et exemples concrets

#### `normal` — Développement interactif sans Vibe

Pour les questions, l’exploration de code et les modifications ponctuelles.

- Directeur / modèle principal : `openai-codex/gpt-6-luna:medium`
- Worker `fast` : `openai-codex/gpt-6-luna:low`
- Worker `good` : `openai-codex/gpt-6-luna:high`
- `defaultThinkingLevel` : `medium`
- Rôle `Jarvis` : `github-copilot/gpt-6-luna-1m:medium`

#### `vibe-1-maintenance` — Bugs simples, tests et nettoyage

« Corrige ce bug de validation, ajoute des tests et supprime le code inutilisé. »

- Directeur / modèle principal : `openai-codex/gpt-6-luna:high`
- Worker `fast` : `openai-codex/gpt-6-luna:low`
- Worker `good` : `openai-codex/gpt-6-luna:high`
- `defaultThinkingLevel` : `high`

#### `vibe-2-feature` — Fonctionnalités, pages React, intégration API

« Crée un dashboard React avec filtres, graphiques et synchronisation des données. »

- Directeur / modèle principal : `openai-codex/gpt-6.1-terra:medium`
- Worker `fast` : `openai-codex/gpt-6-luna:medium`
- Worker `good` : `openai-codex/gpt-6.1-sol:high`
- `defaultThinkingLevel` : `medium`

#### `vibe-3-engineering` — Refactoring transversal, débogage complexe

« Refactorise notre système de state management sans modifier le comportement existant. »

- Directeur / modèle principal : `openai-codex/gpt-6.1-sol:high`
- Worker `fast` : `openai-codex/gpt-6-luna:medium`
- Worker `good` : `openai-codex/gpt-6.1-sol:high`
- `defaultThinkingLevel` : `high`

#### `vibe-4-architecture` — Conception de systèmes et migrations majeures

« Conçois une architecture modulaire pour faire évoluer notre application vers plusieurs services. »

- Directeur / modèle principal : `openai-codex/gpt-6-astra:medium`
- Worker `fast` : `openai-codex/gpt-6-luna:medium`
- Worker `good` : `openai-codex/gpt-6.1-sol:high`
- `defaultThinkingLevel` : `medium`

**`Jarvis` est défini exclusivement dans `normal`**, pas dans les presets Vibe. Les modèles principaux utilisent `openai-codex`.

### Bloc `modelPresets` de référence

```yaml
modelPresets:
  # Développement interactif sans Vibe
  normal:
    modelRoles:
      default: openai-codex/gpt-6-luna:medium
      fast_worker: openai-codex/gpt-6-luna:low
      good_worker: openai-codex/gpt-6-luna:high
      Jarvis: github-copilot/gpt-6-luna-1m:medium
    defaultThinkingLevel: medium

  # Bugs simples, tests et nettoyage
  vibe-1-maintenance:
    modelRoles:
      default: openai-codex/gpt-6-luna:high
      fast_worker: openai-codex/gpt-6-luna:low
      good_worker: openai-codex/gpt-6-luna:high
    defaultThinkingLevel: high

  # Fonctionnalités, pages React, intégration API
  vibe-2-feature:
    modelRoles:
      default: openai-codex/gpt-6.1-terra:medium
      fast_worker: openai-codex/gpt-6-luna:medium
      good_worker: openai-codex/gpt-6.1-sol:high
    defaultThinkingLevel: medium

  # Refactoring transversal, débogage complexe
  vibe-3-engineering:
    modelRoles:
      default: openai-codex/gpt-6.1-sol:high
      fast_worker: openai-codex/gpt-6-luna:medium
      good_worker: openai-codex/gpt-6.1-sol:high
    defaultThinkingLevel: high

  # Conception de systèmes et migrations majeures
  vibe-4-architecture:
    modelRoles:
      default: openai-codex/gpt-6-astra:medium
      fast_worker: openai-codex/gpt-6-luna:medium
      good_worker: openai-codex/gpt-6.1-sol:high
    defaultThinkingLevel: medium

```

> Les commentaires peuvent disparaître quand OMP réécrit `config.yml`. Conserve une copie versionnée.

## 5. Fallbacks : OpenAI Codex vers GitHub Copilot

Le repli est configuré au niveau **du modèle**, et non indépendamment à l'intérieur de chaque preset. Il est déclenché selon `fallbackOn: usage-limit`.

| Modèle principal | Ordre des modèles de secours |
|---|---|
| `openai-codex/gpt-6-luna` | `github-copilot/gpt-6-luna-1m` |
| `openai-codex/gpt-6.1-terra` | `github-copilot/gpt-6.1-terra` → `github-copilot/gpt-6-luna-1m` |
| `openai-codex/gpt-6.1-sol` | `github-copilot/gpt-6.1-sol` → `github-copilot/gpt-6-luna-1m` |
| `openai-codex/gpt-6-astra` | `github-copilot/gpt-6-astra` → `github-copilot/gpt-6.1-sol` → `github-copilot/gpt-6-luna-1m` |

Les réglages `rateLimitWalksChain: true` et `fallbackRevertPolicy: cooldown-expiry` sont conservés.

> Les modèles Terra, Sol et Astra de GitHub Copilot doivent être disponibles sur ton compte. Si un modèle n'est pas proposé, son maillon de fallback ne peut pas être considéré comme garanti.

## 6. Choisir et activer un profil

Dans OMP :

```text
/modelpreset switch normal
/modelpreset switch vibe-1-maintenance
/modelpreset switch vibe-2-feature
/modelpreset switch vibe-3-engineering
/modelpreset switch vibe-4-architecture
```

Exécute ensuite `/vibe` si tu souhaites activer Vibe : un changement de preset **n’active ni ne désactive automatiquement Vibe**.

Pour vérifier les modèles disponibles :

```bash
omp models --kind chat
```

## 7. Recommandations pour maîtriser la consommation

1. **Développement interactif :** `normal`.
2. **Bugs simples et tests :** `vibe-1-maintenance`, Luna uniquement.
3. **Fonctionnalités quotidiennes :** `vibe-2-feature`, Terra dirige et Sol implémente les travaux complexes.
4. **Refactorings et débogage difficiles :** `vibe-3-engineering`, avec Sol pour la coordination et les travaux complexes.
5. **Conception et migrations sensibles :** `vibe-4-architecture`, à réserver aux situations où Astra justifie son coût.
6. **Consommation :** limiter le parallélisme, réutiliser les workers et éviter les revues redondantes.

## 8. Sources

- [Tarification OpenAI API](https://developers.openai.com/api/docs/pricing) — consultée le 11 novembre 2026.
- [Catalogue des modèles OpenAI](https://developers.openai.com/api/docs/models).
- [Guide de sélection des modèles](https://developers.openai.com/api/docs/guides/model-selection).
- [Modèles et presets OMP](https://github.com/can1357/oh-my-pi/blob/main/docs/models.md).
- Presets : configuration recommandée dans cette conversation. Fallbacks : configuration OMP précédemment discutée, à vérifier localement.

**Limite :** ces presets sont recommandés, mais leur prise en charge et la disponibilité des modèles doivent être vérifiées dans ton installation OMP.

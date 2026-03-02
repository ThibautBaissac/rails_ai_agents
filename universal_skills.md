# Agent Skills Standard — Guide de compatibilite cross-outils

> Reference pour creer des skills compatibles avec Claude Code, Mistral Vibe, GitHub Copilot, OpenAI Codex, Cursor, Gemini CLI, Roo Code, et 30+ autres outils.

**Specification officielle** : [agentskills.io/specification](https://agentskills.io/specification)
**Depot** : [github.com/agentskills/agentskills](https://github.com/agentskills/agentskills) (Apache 2.0)
**Exemples officiels** : [github.com/anthropics/skills](https://github.com/anthropics/skills)

---

## Table des matieres

1. [Qu'est-ce qu'une Skill ?](#quest-ce-quune-skill)
2. [Structure de fichiers](#structure-de-fichiers)
3. [Format du SKILL.md](#format-du-skillmd)
4. [Champs du frontmatter](#champs-du-frontmatter)
5. [Modele de chargement progressif](#modele-de-chargement-progressif)
6. [Chemins de decouverte par outil](#chemins-de-decouverte-par-outil)
7. [Extensions specifiques par outil](#extensions-specifiques-par-outil)
8. [Regles de portabilite](#regles-de-portabilite)
9. [Bonnes pratiques](#bonnes-pratiques)
10. [Scripts et ressources](#scripts-et-ressources)
11. [Outils adoptant le standard](#outils-adoptant-le-standard)
12. [Validation](#validation)

---

## Qu'est-ce qu'une Skill ?

Une skill est un **dossier contenant un fichier `SKILL.md`**. Ce fichier combine des metadonnees YAML (frontmatter) et des instructions en Markdown qui enseignent a un agent IA comment accomplir une tache specifique.

Les skills peuvent aussi embarquer des scripts, des templates et des fichiers de reference.

**Origine** : Format cree par Anthropic pour Claude Code, puis publie comme standard ouvert. Aujourd'hui adopte par 30+ outils d'agents IA.

---

## Structure de fichiers

### Structure minimale

```
skill-name/
└── SKILL.md
```

### Structure complete

```
skill-name/
├── SKILL.md           # Requis : metadonnees + instructions
├── scripts/           # Optionnel : code executable
│   └── analyze.sh
├── references/        # Optionnel : documentation de reference
│   ├── REFERENCE.md
│   └── patterns.md
└── assets/            # Optionnel : templates, ressources
    └── template.erb
```

**Regle** : Le champ `name` du frontmatter **doit correspondre** au nom du dossier parent.
Exemple : `tdd-cycle/SKILL.md` → `name: tdd-cycle`

---

## Format du SKILL.md

```yaml
---
name: tdd-cycle
description: >-
  Guides Test-Driven Development workflow with Red-Green-Refactor cycle.
  Use when the user wants to implement a feature using TDD, write tests first,
  or mentions red-green-refactor.
license: MIT
compatibility: Ruby 3.3+, Rails 8.1+, RSpec
metadata:
  author: ThibautBaissac
  version: "1.0"
---

# TDD Cycle

## Instructions pour l'agent

[Contenu Markdown des instructions...]
```

---

## Champs du frontmatter

### Champs du standard de base (portables)

| Champ | Requis | Type | Contraintes | Description |
|-------|--------|------|-------------|-------------|
| `name` | **Oui** | String | 1-64 chars. Minuscules + tirets uniquement. Pas de tirets en debut/fin. Pas de doubles tirets (`--`). Doit correspondre au nom du dossier. | Identifiant unique de la skill |
| `description` | **Oui** | String | 1-1024 chars. Non vide. | Decrit ce que fait la skill ET quand l'utiliser. Inclure des mots-cles declencheurs. Ecrire a la troisieme personne. |
| `license` | Non | String | Court | Nom de licence ou reference a un fichier (`Apache-2.0`, `MIT`) |
| `compatibility` | Non | String | 1-500 chars | Prerequis : outils, versions, acces reseau (`Ruby 3.3+, Rails 8.1+`) |
| `metadata` | Non | Map (String → String) | Cles uniques | Proprietes supplementaires (`author`, `version`, etc.) |
| `allowed-tools` | Non | String (separe par espaces) | **Experimental** — support variable selon les outils | Outils pre-approuves pour la skill |

### Contraintes detaillees pour `name`

- Caracteres autorises : `a-z`, `0-9`, `-`
- Longueur : 1 a 64 caracteres
- Interdit : tirets en debut/fin, doubles tirets (`--`)
- Doit correspondre exactement au nom du dossier parent
- Pas de balises XML
- Mots reserves interdits : `anthropic`, `claude` (regles de la plateforme Claude)

### Contraintes pour `description`

- Ecrire a la **troisieme personne** : "Generates RSpec tests" (pas "I generate RSpec tests")
- Inclure **ce que fait** la skill ET **quand l'utiliser**
- Inclure des mots-cles specifiques pour aider l'agent a matcher les taches
- 1024 caracteres maximum

---

## Modele de chargement progressif

Les skills sont chargees en 3 niveaux pour optimiser le contexte :

| Niveau | Contenu charge | Quand | Budget tokens |
|--------|---------------|-------|---------------|
| **1. Metadonnees** | `name` + `description` du frontmatter | Au demarrage, pour TOUTES les skills disponibles | ~50-100 tokens / skill |
| **2. Instructions** | Corps Markdown complet du `SKILL.md` | Quand l'agent determine que la skill est pertinente | Recommande < 5 000 tokens (< 500 lignes) |
| **3. Ressources** | Fichiers dans `scripts/`, `references/`, `assets/` | A la demande, quand references par les instructions | Pas de limite (fichiers sur disque) |

**Fonctionnement de l'activation** :
1. L'agent lit les metadonnees de toutes les skills au demarrage
2. Quand une tache correspond a la description d'une skill, l'agent l'active
3. Le corps complet du `SKILL.md` est injecte dans la conversation
4. L'agent suit les instructions et charge les fichiers references au besoin

---

## Chemins de decouverte par outil

### Chemin universel recommande

```
.agents/skills/       # Projet — fonctionne avec la majorite des outils
~/.agents/skills/     # Global utilisateur
```

### Chemins par outil

| Outil | Chemin projet | Chemin global | Notes |
|-------|---------------|---------------|-------|
| **Claude Code** | `.claude/skills/` | `~/.claude/skills/` | Decouverte recursive dans les sous-dossiers |
| **Mistral Vibe** | `.vibe/skills/`, `.agents/skills/` | `~/.vibe/skills/` | Chemins custom via `skill_paths` dans `config.toml` |
| **GitHub Copilot** | `.github/skills/`, `.agents/skills/`, `.claude/skills/` | `~/.copilot/skills/`, `~/.agents/skills/` | Configurable via `chat.agentSkillsLocations` |
| **OpenAI Codex** | `.agents/skills/` (CWD, parents, racine repo) | `~/.agents/skills/` | Aussi : `/etc/codex/skills` (admin). Suit les symlinks |
| **Cursor** | `.agents/skills/`, `.cursor/skills/` | `~/.cursor/skills/` | Compat legacy : `.claude/skills/`, `.codex/skills/` |
| **Gemini CLI** | `.gemini/skills/`, `.agents/skills/` | `~/.gemini/skills/`, `~/.agents/skills/` | `.agents/skills/` prioritaire dans un meme niveau |
| **Roo Code** | `.roo/skills/`, `.agents/skills/` | `~/.roo/skills/`, `~/.agents/skills/` | Supporte aussi `skills-{mode}/` |
| **Goose** | — | `~/.config/goose/skills/` | Lit aussi `~/.claude/skills/` |

### Strategie pour un repo cross-compatible

```
mon-projet/
├── .agents/skills/          # Universel (Codex, Copilot, Cursor, Gemini, Vibe, Roo)
│   ├── tdd-cycle/
│   │   └── SKILL.md
│   └── rails-service-object/
│       └── SKILL.md
├── .claude/skills/          # Symlinks vers .agents/skills/ (ou copie)
│   ├── tdd-cycle -> ../../.agents/skills/tdd-cycle
│   └── rails-service-object -> ../../.agents/skills/rails-service-object
└── .vibe/skills/            # Symlinks vers .agents/skills/ (ou copie)
    ├── tdd-cycle -> ../../.agents/skills/tdd-cycle
    └── rails-service-object -> ../../.agents/skills/rails-service-object
```

**Alternative simple** : Placer les skills dans `.agents/skills/` uniquement. La majorite des outils modernes le supportent nativement.

---

## Extensions specifiques par outil

### Claude Code

Champs supplementaires dans le frontmatter :

| Champ | Type | Description |
|-------|------|-------------|
| `argument-hint` | String | Indice d'autocompletion (`[issue-number]`, `[filename]`) |
| `disable-model-invocation` | Boolean | `true` = seul l'utilisateur peut invoquer via `/name` |
| `user-invocable` | Boolean | `false` = cache du menu `/`, pour contexte de fond uniquement |
| `model` | String | Override du modele pour cette skill |
| `context` | String (`fork`) | Execution dans un sous-agent isole |
| `agent` | String | Type de sous-agent (`Explore`, `Plan`, `general-purpose`) |
| `hooks` | Object | Hooks de cycle de vie scopes a la skill |

Syntaxes specifiques dans le corps :
- `$ARGUMENTS`, `$ARGUMENTS[N]`, `$N` — substitution d'arguments
- `` !`commande` `` — injection de contexte dynamique (sortie shell)
- `${CLAUDE_SESSION_ID}` — variable de session

### Mistral Vibe

| Champ | Type | Description |
|-------|------|-------------|
| `allowed-tools` | Array YAML | Liste d'outils (`["read_file", "grep", "shell"]`) — pas un string separe par espaces |
| `user-invocable` | Boolean | Visibilite comme slash command |

Filtrage dans `config.toml` :
```toml
enabled_skills = ["tdd-*", "rails-*"]
disabled_skills = ["experimental-*"]
skill_paths = ["/path/to/custom/skills"]
```

### OpenAI Codex

Fichier supplementaire optionnel `agents/openai.yaml` :
```yaml
interface:
  display_name: "TDD Cycle"
  short_description: "Red-Green-Refactor workflow"
  icon_small: "./assets/icon.svg"
  brand_color: "#CC0000"
policy:
  allow_implicit_invocation: false
```

### Roo Code

Supporte des dossiers par mode d'agent :
```
.roo/skills-code/        # Skills pour le mode "code"
.roo/skills-architect/   # Skills pour le mode "architect"
.agents/skills/          # Skills universelles
```

---

## Regles de portabilite

Pour qu'une skill fonctionne sur **tous les outils** :

### A faire

1. **Utiliser uniquement les champs du standard de base** : `name`, `description`, `license`, `compatibility`, `metadata`
2. **Placer les skills dans `.agents/skills/`** — c'est le chemin le plus largement supporte
3. **Utiliser des slashes** (`/`) dans les chemins, meme sur Windows
4. **Utiliser des chemins relatifs** depuis la racine de la skill pour referencer les fichiers
5. **Ecrire la description a la troisieme personne** avec des mots-cles declencheurs
6. **Garder le `SKILL.md` sous 500 lignes** (< 5 000 tokens)
7. **Epingler les versions** des dependances dans les scripts (`npx eslint@9.0.0`)
8. **Indiquer les prerequis** dans le champ `compatibility`

### A eviter

1. **Ne pas utiliser les extensions specifiques** (`context: fork`, `hooks`, `model`) si la portabilite est importante
2. **Ne pas utiliser `allowed-tools`** avec des noms d'outils specifiques — les noms different entre les outils :
   | Operation | Claude Code | Mistral Vibe | Codex |
   |-----------|-------------|--------------|-------|
   | Lire un fichier | `Read` | `read_file` | `read_file` |
   | Ecrire un fichier | `Write` | `write_file` | `write_file` |
   | Modifier un fichier | `Edit` | `patch_file` | `patch` |
   | Executer un shell | `Bash` | `shell` | `shell` |
   | Rechercher | `Grep` | `grep` | `grep` |
3. **Ne pas creer de prompts interactifs** dans les scripts — les agents operent en mode non-interactif
4. **Ne pas creer de chaines de references profondes** — rester a un niveau depuis `SKILL.md`

### Compromis pour `allowed-tools`

Si vous devez utiliser `allowed-tools`, deux approches :

**Option A** : Omettre le champ — les outils ignorent les champs absents, et l'agent demandera simplement la permission
```yaml
---
name: tdd-cycle
description: Guides TDD workflow with Red-Green-Refactor cycle.
---
```

**Option B** : Utiliser le champ avec les noms les plus courants et accepter que certains outils ne les reconnaitront pas (ils seront simplement ignores)
```yaml
---
name: tdd-cycle
description: Guides TDD workflow with Red-Green-Refactor cycle.
allowed-tools: Read Write Edit Bash Grep
---
```

---

## Bonnes pratiques

### Redaction de la description

```yaml
# Bien — troisieme personne, mots-cles, quand l'utiliser
description: >-
  Generates RSpec model tests following TDD best practices. Use when creating
  new models, adding validations, associations, or scopes in a Rails application.

# Mal — premiere personne, vague, pas de declencheurs
description: I help you write tests for your Rails models.
```

### Concision des instructions

- Claude / Codestral / GPT sont deja intelligents. N'ajoutez que le contexte qu'ils n'ont **pas deja**.
- Challengez chaque paragraphe : "Est-ce que ca justifie son cout en tokens ?"
- Deplacez le contenu detaille dans `references/` — il sera charge a la demande.

### Convention de nommage

| Style | Exemple | Quand l'utiliser |
|-------|---------|------------------|
| Gerondif | `processing-pdfs` | Clarte maximale |
| Nom compose | `pdf-processing` | Standard |
| Action | `process-pdfs` | Imperatif |

**A eviter** : noms vagues comme `helper`, `utils`, `tools`, `misc`

### Taille des fichiers

| Element | Recommandation |
|---------|---------------|
| Corps du `SKILL.md` | < 500 lignes (< 5 000 tokens) |
| Champ `name` | Max 64 caracteres |
| Champ `description` | Max 1 024 caracteres |
| Champ `compatibility` | Max 500 caracteres |
| Fichiers de reference | Focuses et courts. Table des matieres si > 100 lignes |

---

## Scripts et ressources

### Regles pour les scripts embarques

Les scripts doivent etre concus pour un **usage agentique** (non-interactif) :

```bash
#!/bin/bash
# scripts/run_specs.sh

# Supporter --help
if [ "$1" = "--help" ]; then
  echo "Usage: run_specs.sh [--file PATH] [--format FORMAT]"
  echo ""
  echo "Flags:"
  echo "  --file PATH     Run specs for a specific file"
  echo "  --format FORMAT Output format: progress|documentation|json"
  echo "  --dry-run       Show what would be run without executing"
  exit 0
fi

# Jamais de prompt interactif
# Sortie structuree (JSON, CSV)
# Codes de sortie distincts par type d'erreur
# Sortie de taille previsible
# Idempotent : "creer si absent" plutot que "creer et echouer si doublon"
```

### Organisation des references

```
references/
├── REFERENCE.md          # Point d'entree principal
├── model-patterns.md     # Organise par domaine
├── controller-patterns.md
└── testing-patterns.md
```

- Chaines de references a **un seul niveau** de profondeur depuis `SKILL.md`
- Table des matieres pour les fichiers > 100 lignes
- Nommer par domaine, pas par numero (`patterns.md` > `doc1.md`)

---

## Outils adoptant le standard

31+ outils a ce jour (mars 2026) :

| Outil | Editeur | Decouverte `.agents/skills/` |
|-------|---------|------------------------------|
| Claude Code | Anthropic | Via `.claude/skills/` |
| Claude (claude.ai) | Anthropic | Via interface web |
| GitHub Copilot | GitHub/Microsoft | Oui |
| VS Code | Microsoft | Oui |
| OpenAI Codex | OpenAI | Oui |
| Cursor | Cursor Inc. | Oui |
| Gemini CLI | Google | Oui |
| Mistral Vibe | Mistral AI | Oui |
| Roo Code | Roo | Oui |
| Goose | Block | Via `~/.config/goose/skills/` |
| Amp | Sourcegraph | Oui |
| Junie | JetBrains | Oui |
| OpenHands | All Hands AI | Oui |
| TRAE | ByteDance | Oui |
| Databricks | Databricks | Oui |
| Spring AI | VMware | Oui |
| Laravel Boost | Laravel | Oui |
| Qodo | Qodo | Oui |
| Factory | Factory AI | Oui |

Et aussi : OpenCode, Letta, Piebald, Firebender, Command Code, Agentman, Emdash, VT Code, Ona, Autohand...

**Registre communautaire** : [skills.sh](https://skills.sh/) (par Vercel) — `npx skills add <package>`

---

## Validation

### Avec skills-ref (bibliotheque de reference Python)

```bash
# Installer
pip install skills-ref

# Valider une skill
skills-ref validate ./tdd-cycle

# Lire les proprietes en JSON
skills-ref read-properties ./tdd-cycle

# Generer le XML pour injection dans le system prompt
skills-ref to-prompt ./tdd-cycle ./rails-service-object
```

### Checklist manuelle

- [ ] Le dossier contient un `SKILL.md`
- [ ] Le `name` du frontmatter correspond au nom du dossier
- [ ] Le `name` est en minuscules avec tirets uniquement (1-64 chars)
- [ ] La `description` est non-vide (1-1024 chars)
- [ ] La `description` est a la troisieme personne avec des mots-cles declencheurs
- [ ] Le corps du `SKILL.md` fait moins de 500 lignes
- [ ] Les chemins de fichiers utilisent des slashes (`/`)
- [ ] Pas de champs specifiques a un outil si la portabilite est visee
- [ ] Les scripts supportent `--help` et n'ont pas de prompts interactifs
- [ ] Les fichiers de reference > 100 lignes ont une table des matieres

---

## Exemples

### Skill minimale portable

```
rails-service-object/
└── SKILL.md
```

```yaml
---
name: rails-service-object
description: >-
  Generates service objects following Rails conventions with callable interface,
  error handling, and RSpec tests. Use when extracting business logic from
  controllers or models, or when the user mentions service objects.
license: MIT
compatibility: Ruby 3.3+, Rails 8.1+, RSpec
metadata:
  author: ThibautBaissac
  version: "1.0"
---

# Rails Service Object Pattern

## Structure

Service objects follow the callable pattern with a `.call` class method:

[... instructions ...]
```

### Skill avec references et scripts

```
performance-optimization/
├── SKILL.md
├── scripts/
│   └── detect_n_plus_one.sh
└── references/
    ├── caching-strategies.md
    └── query-optimization.md
```

```yaml
---
name: performance-optimization
description: >-
  Analyzes and optimizes Rails application performance. Detects N+1 queries,
  implements caching strategies, and optimizes database queries. Use when the
  user reports slow pages, wants to improve performance, or mentions N+1.
license: MIT
compatibility: Ruby 3.3+, Rails 8.1+, bullet gem recommended
metadata:
  author: ThibautBaissac
  version: "1.0"
---

# Performance Optimization

## Workflow

1. Run `scripts/detect_n_plus_one.sh` to identify N+1 queries
2. See `references/query-optimization.md` for fix patterns
3. See `references/caching-strategies.md` for caching approaches

[... instructions ...]
```

---

## Sources

- [agentskills.io/specification](https://agentskills.io/specification) — Specification officielle
- [agentskills.io/what-are-skills](https://agentskills.io/what-are-skills) — Vue d'ensemble
- [agentskills.io/skill-creation/using-scripts](https://agentskills.io/skill-creation/using-scripts) — Guide scripts
- [github.com/agentskills/agentskills](https://github.com/agentskills/agentskills) — Depot du standard
- [github.com/anthropics/skills](https://github.com/anthropics/skills) — Exemples officiels
- [platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices](https://platform.claude.com/docs/en/agents-and-tools/agent-skills/best-practices) — Bonnes pratiques
- [code.claude.com/docs/en/skills](https://code.claude.com/docs/en/skills) — Claude Code
- [docs.mistral.ai/mistral-vibe/agents-skills](https://docs.mistral.ai/mistral-vibe/agents-skills) — Mistral Vibe
- [developers.openai.com/codex/skills/](https://developers.openai.com/codex/skills/) — OpenAI Codex
- [code.visualstudio.com/docs/copilot/customization/agent-skills](https://code.visualstudio.com/docs/copilot/customization/agent-skills) — VS Code / Copilot
- [cursor.com/docs/context/skills](https://cursor.com/docs/context/skills) — Cursor
- [geminicli.com/docs/cli/skills/](https://geminicli.com/docs/cli/skills/) — Gemini CLI
- [docs.roocode.com/features/skills](https://docs.roocode.com/features/skills) — Roo Code
- [skills.sh](https://skills.sh/) — Registre Vercel
- [github.com/skillmatic-ai/awesome-agent-skills](https://github.com/skillmatic-ai/awesome-agent-skills) — Liste curatee

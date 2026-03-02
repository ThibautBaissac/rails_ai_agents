Skill vs Agent : quand utiliser quoi ?

  La distinction fondamentale

  Skill = ce que l'agent sait (connaissances, instructions, patterns)
  Agent = qui fait le travail (worker autonome avec son propre contexte)

  Une skill est un manuel d'expertise. Un agent est un employé spécialisé.

  ---
  Matrice de décision

  ┌───────────────────────────────────────────────┬─────────────────────────────────────┐
  │                  Je veux...                   │               → Créer               │
  ├───────────────────────────────────────────────┼─────────────────────────────────────┤
  │ Enseigner des conventions de code             │ Skill                               │
  ├───────────────────────────────────────────────┼─────────────────────────────────────┤
  │ Partager un checklist de review entre projets │ Skill                               │
  ├───────────────────────────────────────────────┼─────────────────────────────────────┤
  │ Ajouter un savoir qui s'active                │ Skill (bonne description =          │
  │ automatiquement                               │ déclencheur)                        │
  ├───────────────────────────────────────────────┼─────────────────────────────────────┤
  │ Un slash command pour un workflow récurrent   │ Skill                               │
  ├───────────────────────────────────────────────┼─────────────────────────────────────┤
  │ Lancer des tests et rapporter les échecs      │ Agent                               │
  ├───────────────────────────────────────────────┼─────────────────────────────────────┤
  │ Explorer un codebase sans polluer le contexte │ Agent (type Explore)                │
  ├───────────────────────────────────────────────┼─────────────────────────────────────┤
  │ Router des tâches simples vers un modèle      │ Agent (model: haiku)                │
  │ moins cher                                    │                                     │
  ├───────────────────────────────────────────────┼─────────────────────────────────────┤
  │ Exécuter en parallèle sur 30 fichiers         │ Agents multiples                    │
  ├───────────────────────────────────────────────┼─────────────────────────────────────┤
  │ Restreindre les outils disponibles            │ Agent                               │
  │ (read-only)                                   │                                     │
  ├───────────────────────────────────────────────┼─────────────────────────────────────┤
  │ Accumuler de la mémoire entre sessions        │ Agent                               │
  └───────────────────────────────────────────────┴─────────────────────────────────────┘

  ---
  Les critères de choix

  ┌───────────────────┬──────────────────────────────┬─────────────────────────────────┐
  │      Critère      │            Skill             │              Agent              │
  ├───────────────────┼──────────────────────────────┼─────────────────────────────────┤
  │ Isolation du      │ Non — s'injecte dans la      │ Oui — contexte propre, ne       │
  │ contexte          │ conversation principale      │ pollue pas                      │
  ├───────────────────┼──────────────────────────────┼─────────────────────────────────┤
  │ Coût en tokens    │ Faible — chargement          │ Plus élevé — démarre un nouveau │
  │                   │ progressif                   │  contexte                       │
  ├───────────────────┼──────────────────────────────┼─────────────────────────────────┤
  │ Complexité        │ Faible — un fichier SKILL.md │ Plus élevée — system prompt,    │
  │                   │                              │ outils, modèle, permissions     │
  ├───────────────────┼──────────────────────────────┼─────────────────────────────────┤
  │ Portabilité       │ Haute — standard Agent       │ Faible — format spécifique à    │
  │                   │ Skills, 30+ outils           │ chaque outil                    │
  ├───────────────────┼──────────────────────────────┼─────────────────────────────────┤
  │ Restriction       │ Limitée (allowed-tools       │ Totale — contrôle fin des       │
  │ d'outils          │ expérimental)                │ permissions                     │
  ├───────────────────┼──────────────────────────────┼─────────────────────────────────┤
  │ Sortie            │ Reste dans le contexte       │ Reste dans le sous-agent, seul  │
  │ volumineuse       │ principal (le pollue)        │ un résumé remonte               │
  ├───────────────────┼──────────────────────────────┼─────────────────────────────────┤
  │ Réutilisabilité   │ Cross-projets, cross-outils  │ Souvent spécifique au projet    │
  └───────────────────┴──────────────────────────────┴─────────────────────────────────┘

  ---
  La progression naturelle

  Commencer simple et escalader quand nécessaire :

  1. Règle dans CLAUDE.md     → Convention simple ("toujours utiliser RSpec")
         ↓ quand c'est réutilisable et découvrable
  2. Skill                    → Expertise packagée (tdd-cycle, rails-service-object)
         ↓ quand la sortie pollue le contexte
  3. Skill + context: fork    → Skill exécutée dans un sous-agent isolé
         ↓ quand il faut des permissions custom, un modèle différent, de la mémoire
  4. Agent dédié              → Worker autonome avec config complète

  ---
  Le pont : context: fork (Claude Code)

  C'est le hybride entre skill et agent — une skill qui s'exécute dans un contexte isolé :

  ---
  name: deep-research
  description: Research a Rails topic thoroughly
  context: fork
  agent: Explore
  ---
  Research $ARGUMENTS thoroughly and return a summary...

  - Format = skill (portable, SKILL.md)
  - Exécution = agent (contexte isolé, pas de pollution)
  - Meilleur des deux mondes pour les tâches de recherche

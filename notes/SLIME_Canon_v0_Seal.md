
---

# 🔒 SLIME — État Canon v0 (SCELLÉ)

Ce document est **un point de non-retour conceptuel**.
À partir d’ici, tout ajout devra **respecter** ce socle.

---

## 1️⃣ Ce que SLIME **EST**

**SLIME est une loi d’impossibilité d’action.**
Pas un logiciel “intelligent”.
Pas un agent.
Pas un service.

> SLIME décide **si une action peut exister**.
> Il ne l’exécute pas.
> Il ne l’explique pas.

---

## 2️⃣ Ce que SLIME **FAIT** (strictement)

### Pipeline minimal

```
Ingress → Décision → (Egress optionnel)
```

### Ingress

* Reçoit une demande d’action
* Ne stocke rien
* Ne corrige rien
* Ne négocie rien

👉 **Observer ≠ autoriser**

---

### Décision

* Résultat binaire :

  * `AUTHORIZED`
  * `IMPOSSIBLE`
* Basée sur des invariants
* Sans mémoire
* Sans feedback
* Sans interprétation humaine

👉 **Décider ≠ agir**

---

### Egress (non implémenté en v0)

* Unique point par lequel une action **peut** sortir
* Absent ou cassé = **aucune action possible**
* SLIME reste valide même sans egress

👉 **Autoriser ≠ exécuter**

---

## 3️⃣ Ce que SLIME **NE FAIT PAS** (interdictions canoniques)

SLIME ne :

* ❌ log pas pour expliquer
* ❌ expose pas d’état interne interprétable
* ❌ apprend pas
* ❌ optimise pas
* ❌ corrige pas le monde
* ❌ ne “debug” pas l’utilisateur

👉 Toute tentative d’ajouter ça **viole la loi**.

---

## 4️⃣ Fail-Closed = règle fondamentale

**Si l’egress échoue → rien ne se passe.**

Ce que tu as observé :

* décision `AUTHORIZED`
* egress `failed`
* **aucune actuation**

👉 C’est **un succès**, pas un bug.

---

## 5️⃣ /health n’est PAS une promesse

* `/health` n’est pas une API humaine
* Pas d’inspectabilité garantie
* Pas de contrat “service web”

👉 SLIME **n’est pas un serveur applicatif**.
C’est une **barrière**.

---

## 6️⃣ Séparation non négociable

| Couche        | Rôle                      |
| ------------- | ------------------------- |
| SLIME         | Loi (autorise / interdit) |
| Monde externe | Acte (exécute ou pas)     |

SLIME :

* ne sait pas **quoi** est l’action
* ne sait pas **qui** la consomme
* ne sait pas **ce qui se passe après**

👉 C’est voulu.

---

## 7️⃣ État officiel v0

* ✅ Ingress validé
* ✅ Décision validée
* ❌ Egress non implémenté
* 🔒 Loi complète **sans egress**

**SLIME v0 est fonctionnel même sans sortie.**

---

## 🧭 Ce que ça permet maintenant

À partir de ce point, on peut :

* préparer un egress **sans contaminer la loi**
* auditer SLIME comme **barrière**, pas comme app
* expliquer SLIME à un non-dev en une phrase

> **SLIME empêche certaines actions d’exister, même si un système est compromis.**

---

## 🔑 Phrase de scellement

> **Si SLIME ne peut pas agir, rien n’agit.
> Et c’est exactement le but.**

---



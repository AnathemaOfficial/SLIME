
---

# 🧩 SLIME — Egress (Définition v0)

## 1) Rôle exact

**Egress = la seule sortie d’actuation.**
Pas un log. Pas un événement. Pas une “explication”.

> Egress transporte un *jeton d’effet* minimal, opaque, à destination d’un exécuteur externe.

---

## 2) Principe non négociable

**SLIME ne déclenche rien tout seul.**
Il ne “pousse” pas une action dans le monde.

Il fait seulement :

* **exposer** un effet autorisé
* via un canal binaire minimal
* consommé par un autre process (actuator)

👉 L’actuator est responsable de l’exécution physique (ou logicielle).

---

## 3) Topologie recommandée (la plus cohérente avec SLIME)

### Modèle “SLIME = serveur, Actuator = client”

* SLIME **crée** un socket Unix (listener).
* L’actuator **se connecte** au socket.
* Quand une action est AUTHORIZED, SLIME **écrit** 32 bytes.
* Si aucun actuator n’est connecté → **drop silencieux** ou **non-événement** (selon canon).

Pourquoi c’est le bon modèle :

* SLIME reste muet et stable
* l’actuator est isolable / remplaçable
* pas de dépendance réseau externe
* easy à sandboxer (permissions Unix)

---

## 4) Canal (support)

**Unix domain socket** local, path fixe.

* Canon (rappel) : `/run/slime/egress.sock`
* Test local : `/tmp/slime-egress.sock`

Propriétés :

* local-only
* permissions strictes (ex. `0660`)
* pas d’IP, pas d’Internet, pas de “remote control”

---

## 5) Payload (format)

**Payload fixe, binaire, non-verbosé.**
Idéalement **32 bytes** (ABI figée).

Exemple de convention (déjà dans ton canon SLIME v0) :

* `AuthorizedEffect = 32 bytes little-endian`

  * `u64 domain_id`
  * `u64 magnitude`
  * `u128 actuation_token` (opaque)

Règles :

* aucune string
* aucun JSON
* aucun reason_code
* aucune metadata
* aucune explication

---

## 6) Sémantique (comportement)

### Quand AUTHORIZED

* SLIME écrit **exactement 32 bytes** sur egress
* puis retourne une réponse HTTP minimale côté ingress (ok/authorized)

### Quand IMPOSSIBLE

* SLIME **n’écrit rien**
* “impossible” = **non-événement**

---

## 7) Fail-closed egress (invariant)

Si egress n’est pas disponible :

* socket absent
* write échoue
* actuator non connecté

Alors :

* **aucun effet ne sort**
* idéalement **aucun détail** n’est exposé
* SLIME reste “correct” : la loi est appliquée, mais rien n’advient

---

## 8) Ce que l’egress N’EST PAS

* ❌ une file de messages durable
* ❌ une queue Kafka / Redis
* ❌ un bus d’événements
* ❌ une API de contrôle
* ❌ un canal de debug
* ❌ un retour d’état

Egress = **impulsion**.

---

## 9) Qui consomme l’egress ?

Un process externe : **Actuator** (ou “Effect Runner”).

* Lit 32 bytes
* Traduction vers action concrète
* Applique des garde-fous de son côté (si voulu)
* Peut être remplacé / isolé / audité

SLIME n’a pas à “connaître” l’actuator.

---

# ✅ Résultat B (définition scellable)

**Egress = Unix socket local + payload binaire fixe (32 bytes) + non-événement si impossible.**

---


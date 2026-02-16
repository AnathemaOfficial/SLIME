systemd = le concierge de l’immeuble

slime.service = la fiche d’emploi du gardien

curl = quelqu’un qui sonne à la porte

socket = le câble entre la serrure et le moteur

actuator = le moteur qui ouvre la porte

                 (LOCALHOST ONLY)
Client / App  ── HTTP ──►  SLIME v0 (law-layer)
(curl, bot, service)      - écoute: 127.0.0.1:8080  (/action)
                           - dashboard: 127.0.0.1:8081 (read-only)
                           - décide: AUTHORIZED | IMPOSSIBLE
                           - ne fait AUCUN effet lui-même

                                   (ONE-WAY)
AUTHORIZED ───────────────────────────────────────────────► writes 32 bytes
IMPOSSIBLE ───────────────────────────────────────────────► writes nothing

                         Unix socket (local)
                /run/slime/egress.sock  (owned by actuator)
                perms: actuator:slime-actuator 0660

                           ▼
                    Actuator (external muscle)
                    - Unix socket SERVER
                    - reçoit 32 bytes
                    - exécute le “point d’effet”
                    - ne décide jamais
                    - ne renvoie aucun feedback à SLIME


1) Checklist “scellé” (tu peux cocher)

 slime.service canon : User=slime, Group=slime-actuator, ExecStart=/usr/local/bin/slime-runner, Restart=no

 Egress path unique : /run/slime/egress.sock (aucun /tmp, aucune env var)

 Boot fail-closed prouvé : sans socket → status=1/FAILURE

 ABI prouvée : 32 bytes vus au hexdump (tu l’as ✅)

 Ingress local : 127.0.0.1:8080 (LISTEN)

 Dashboard local : 127.0.0.1:8081 (si tu l’as activé)

 Actuator externe documenté (pas de code dans SLIME)
 
 


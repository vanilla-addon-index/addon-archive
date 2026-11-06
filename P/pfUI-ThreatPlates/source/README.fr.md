# pfUI-ThreatPlates

[English](README.md) | **Français**

Module "thirdparty" pour pfUI (Turtle WoW) qui affiche la menace directement sur les nameplates, en utilisant la même API serveur que TW Threatmeter.

## En bref
Sur Turtle WoW, le serveur calcule la menace de chaque joueur et la renvoie aux addons qui la demandent. pfUI-ThreatPlates pose cette information **sur les nameplates** : tu vois d'un coup d'œil, sur chaque mob, où tu en es par rapport au tank, sans ouvrir de fenêtre de menace.

Le principe, en quatre temps :
1. **Demande** : en combat et en groupe, l'addon interroge le serveur toutes les X secondes (`TWT_UDTSv4_TM`, la même requête que TWThreat).
2. **Réponse** : le serveur renvoie la menace de ta cible et celle des mobs que tu tankes.
3. **Partage** : l'addon relaie la liste de ta cible au groupe (canal `TWT`, format de TWThreat). Chaque joueur reçoit ainsi la menace des mobs que *les autres* ciblent.
4. **Affichage** : chaque nameplate est associée à son mob (par GUID, sinon par nom), puis reçoit une fine barre, un texte et, si tu le souhaites, une barre de vie colorée.

```
serveur ──TWTv4 / TMTv1──▶ toi ──TWTRelayV2 (groupe/raid)──▶ les autres joueurs
                            │                                   │
                            └──────▶ nameplates pfUI ◀──────────┘
```

## Installation
1. Installer **pfUI** (obligatoire).
2. Copier le dossier `pfUI-ThreatPlates` dans `Interface/AddOns/`. Avec le zip GitHub, renommer le dossier `pfUI-ThreatPlates-main` en `pfUI-ThreatPlates`.
3. Relancer le jeu ou taper `/reload`.

Compatible avec :
- **pfUI de brues-code + ClassicAPI** (recommandé) : nameplates suivies via `NAME_PLATE_UNIT_ADDED/REMOVED`, GUID via `UnitGUID`.
- **pfUI d'origine (shagu) + SuperWoW** : GUID via `GetName(1)` sur la nameplate.
- Sans aucun des deux : seule la nameplate de la cible est fiable.

TWThreat est facultatif. S'il est présent, les deux addons se partagent le travail sans doublon.

Réglages : `/pfui` → **Thirdparty** → **Threat Plates** (activation, rôle, intervalle, partage, position de la barre, seuils, couleurs).

## Fonctionnement
Toutes les X secondes en combat et en groupe, l'addon envoie la requête `TWT_UDTSv4_TM` au serveur (comme TWThreat en mode tank). Le serveur répond avec :
- la liste de menace de ta **cible** (`TWTv4=`) ;
- la liste de **tous les mobs que tu tankes**, avec le joueur suivant et son % (`TMTv1=`).

Affichage sur la nameplate : une fine barre de menace (par défaut juste **au-dessus** de la barre de vie, position et espacement réglables) + un texte :
| Situation | Affichage |
|---|---|
| Tu n'as pas l'aggro | ton % de menace par rapport au tank (vert → rouge) |
| Tu as l'aggro (rôle Auto/Tank) | joueur suivant + son % (rouge = il va te la prendre) |
| Tu as l'aggro (rôle DPS/Soigneur) | `AGGRO` |
| Rôle Tank, aggro perdue | nom du tank actuel + ton %, couleur "aggro perdue" |

### Couleur de la barre de vie (« Colorer la barre de vie selon l'aggro », activé par défaut)
| Rôle | Situation | Barre de vie |
|---|---|---|
| Tank (ou Auto quand tu tiens le mob) | tu tiens l'aggro, suivant sous le seuil | vert |
| | tu tiens l'aggro, suivant au-dessus du seuil | orange |
| Tank | aggro perdue | rouge |
| DPS / Soigneur (ou Auto sans aggro) | menace sous le seuil | couleur pfUI normale |
| | menace au-dessus du seuil | orange |
| | tu as l'aggro | rouge |

Seuil d'alerte réglable (80 % par défaut). La fine barre et le texte gardent le dégradé de %.

### Mobs sans donnée de menace (« Color Health Bar Without Threat Data (mob target) », activé par défaut)
Quand personne ne te donne la menace d'un mob, sa barre de vie est quand même colorée selon **qui le mob cible** (mobs hostiles en combat uniquement). La fine barre et le texte restent masqués, faute de chiffre à afficher.

| Rôle | Le mob te cible | Le mob cible quelqu'un d'autre |
|---|---|---|
| Tank | vert | rouge (mob perdu) |
| DPS / Soigneur / Auto | rouge | couleur pfUI normale |

Nécessite ClassicAPI (ou SuperWoW) pour lire la cible du mob sur toutes les nameplates ; sans eux, seule ta cible actuelle est couverte.

### Expérimental : scanner les autres mobs (désactivé par défaut, ClassicAPI uniquement)
Le serveur ne donne la menace que de ta cible : cette option **cible brièvement d'autres mobs** pour lire la leur. À chaque pas (« Scan: Seconds Between Two Mobs », 1 s par défaut), elle choisit **un** mob hostile, lui-même en combat, dont la dernière menace connue date de plus de « Scan: Refresh Threat Older Than (seconds) » (2 s par défaut), le cible via sa nameplate, envoie une requête, puis te rend ta cible précédente dès que la réponse arrive (environ 0,1-0,3 s, 0,7 s au maximum).

- **Seulement quand c'est utile :** en combat et en groupe. Un mob dont un équipier a partagé la menace (ou que tu as déjà lue) depuis moins que le seuil est ignoré, comme le mob que tu cibles déjà.
- **Les incantations ne gênent pas :** la cible d'un sort est fixée au début de l'incantation, changer de cible pendant ne la modifie pas.
- **Durée d'affichage :** une liste scannée reste affichée le seuil **+ 1 s** (3 s par défaut), pour que le chiffre soit encore là quand le prochain scan de ce mob revient. Elle n'est jamais partagée avec le groupe.
- **Beaucoup de mobs :** chacun est rafraîchi tous les N pas ; accélère le pas ou relève le seuil selon ton goût.

**Effets de bord, à lire :** chaque pas change deux fois ta cible, ce qui peut jouer le son de ciblage, faire clignoter le cadre de cible, déclencher les addons qui réagissent au changement de cible et, selon le client, interrompre l'attaque auto / tir auto ou perturber des macros. À tester sur un mannequin avant de t'y fier.

### Cache court à la perte de cible
Quand tu changes ou perds ta cible, la dernière menace connue de l'ancien mob reste affichée sur sa nameplate avant de disparaître, au lieu de s'effacer d'un coup. C'est l'option « Keep Threat After Target Loss (seconds, 0 = off) » (3 s par défaut) ; elle est distincte de « Query Interval (seconds) ». Avec le scan expérimental activé, elle est automatiquement au moins aussi longue qu'une liste scannée (seuil + 1 s), pour que la barre ne disparaisse pas avant que le scan la rafraîchisse.

## Partage dans le groupe (compatible TWThreat)
Option « Partager la menace avec le groupe » (activée par défaut). Le partage utilise **le canal et le format de relais de TWThreat** (préfixe `TWT`, version octo-addons 1.3.0-octo1 et suivantes) :
- **Envoi** : après chaque réponse du serveur, la liste de menace de ta cible part en `TWTRelayV2:<mob>#joueur:tank:menace:%:mêlée;…`, le message que TWThreat utilise pour son « Healer Master Target ». Si TWThreat relaie déjà cette réponse, rien n'est envoyé en double. Si un autre joueur vient de partager la même liste, l'envoi est sauté.
- **Réception** : les relais de **tout** joueur du groupe, qu'ils viennent de TWThreat ou de pfUI-ThreatPlates. Le mob est identifié par la cible de l'expéditeur (son GUID, vérifié par le nom).
- **Mode tank** : TWThreat n'a pas d'équivalent ; les tanks équipés de pfUI-ThreatPlates partagent leur liste en `PFTPTankV1:créature:guid:suivant:%;…` sur le même canal (TWThreat l'ignore).
- **Canal** : toujours `RAID` en raid et `PARTY` en groupe, choisi au moment de chaque envoi ; rien n'est envoyé hors groupe.
- **Avec TWThreat qui partage déjà** (`/twt share`, octo-addons 1.3.0-octo2 et suivantes) : pfUI-ThreatPlates n'envoie pas de relais en double, il se contente de lire ceux du groupe.
- **Sans TWThreat** : pfUI-ThreatPlates répond lui-même aux demandes `/twthmt` des soigneurs (`TWT_HMT` / `TWT_HMT_OK` / `TWT_HMT_REM`) et leur relaie la menace, même si le partage est désactivé. Avec TWThreat chargé, c'est lui qui s'en charge.

## Limites
- Le serveur ne renvoie le détail que pour **ta cible** + les mobs **que tu tankes**. Sans partage, un DPS ne voit donc sa menace que sur sa cible ; avec le partage, sur tout mob ciblé par un joueur qui relaie (pfUI-ThreatPlates, ou TWThreat quand un soigneur le lui a demandé).
- Un mob que personne ne relaie reste sans information. Les relais nécessitent ClassicAPI ou SuperWoW pour identifier le mob. Les données partagées ont jusqu'à ~1 s de retard (intervalle des requêtes).
- Sans ClassicAPI ni SuperWoW, seule la nameplate de la cible est fiable ; les mobs tankés sont associés par nom (seulement si le nom est unique).
- Pas d'envoi en solo (le serveur ne répond qu'en groupe/raid, comme TWThreat).
- Si TWThreat tourne aussi, les deux addons interrogent le serveur ; on peut augmenter l'intervalle dans les options.

## Dépannage
- **Rien ne s'affiche** : il faut être en groupe ou en raid et en combat ; vérifier que le module est activé dans les réglages.
- **Menace visible seulement sur ma cible** : normal sans partage. Activer « Partager la menace avec le groupe », et vérifier que les autres joueurs ont pfUI-ThreatPlates ou TWThreat.
- **Mauvais mob coloré** : installer ClassicAPI ou SuperWoW pour une association par GUID.
- **Trop de requêtes** : augmenter l'intervalle dans les options, surtout si TWThreat tourne aussi.

## Mises à jour
Les versions sont publiées sur ce dépôt ; remplacer le dossier de l'addon par la dernière version.

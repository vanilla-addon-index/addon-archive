# TWPulse

**Addon WoW Vanilla 1.12 / Turtle WoW**  
Displays a pulse animation for spells when their cooldown is finished. Allows visual tracking of ready spells and customization of animation size and position.  

---

## Fonctionnalités / Features

- Suivi automatique des cooldowns des sorts supérieurs à 1,7 seconde.  
  Automatic tracking of spell cooldowns longer than 1.7 seconds.  
- Animation de type **pulse** avec effet de zoom.  
  Pulse-style animation with zoom effect.  
- Affichage du **nom du sort** sous l’icône.  
  Displays the **spell name** below the icon.  
- Fenêtre **déplaçable et redimensionnable** via le menu d’options.  
  Movable and resizable frame via the options menu.  
- Possibilité de **verrouiller/déverrouiller** l’animation avec des commandes slash.  
  Ability to **lock/unlock** the animation with slash commands.  
- Interface d'options simple pour ajuster la taille des icônes et la visibilité.  
  Simple options interface to adjust icon size and visibility.  

---

## Illustration

<img src="https://raw.githubusercontent.com/FSuhas/TWPulse/main/animation.GIF" width="45%"> <img src="https://raw.githubusercontent.com/FSuhas/TWPulse/main/settings.PNG" width="45%">

---

## Commandes Slash / Slash Commands

- `/twp` – Ouvre/ferme le menu d’options.  
  Opens/closes the options menu.  

---

## Menu d’options / Options Menu

- **Lock Pulse Frame** – Active/désactive le verrouillage de la fenêtre.  
  Enables/disables frame locking.  
- **Icon Size** – Ajuste la taille des icônes et de l’animation.  
  Adjusts the icon and animation size.  
- Bouton **Fermer** – Ferme le menu d’options.  
  **Close** button – closes the options menu.  

💡 Le menu est **déplaçable** en cliquant-glissant avec le bouton gauche de la souris.  
💡 The menu is **movable** by clicking and dragging with the left mouse button.  

---

## Installation

1. Copier le dossier `TWPulse` dans le répertoire `Interface\AddOns\` de votre installation WoW.  
   Copy the `TWPulse` folder into your WoW `Interface\AddOns\` directory.  
2. Vérifier que le fichier `TWPulse.lua` et le XML associé sont présents.  
   Make sure `TWPulse.lua` and its XML file are present.  
3. Lancer WoW et activer l’addon dans l’écran de sélection des addons.  
   Launch WoW and enable the addon in the AddOns selection screen.  

---

## Personnalisation / Customization

- Modifier la taille des icônes dans le menu d’options.  
  Adjust icon size in the options menu.  
- Déplacer la fenêtre d’animation directement sur l’écran.  
  Move the animation frame directly on the screen.  
- Les icônes des sorts sont automatiquement créées et adaptées à la taille choisie.  
  Spell icons are automatically created and scaled to the chosen size.  
- Le nom du sort est affiché sous l’icône pour mieux identifier quel sort est prêt.  
  Spell name is displayed below the icon for better identification of ready spells.  

---

## Notes

- Compatible uniquement avec **WoW Vanilla 1.12** et **Turtle WoW**.  
  Compatible only with **WoW Vanilla 1.12** and **Turtle WoW**.  
- Ne modifie pas les fonctionnalités du jeu, uniquement l’affichage des cooldowns.  
  Does not modify game functionality, only cooldown display.  
- Les icônes sont générées dynamiquement en fonction des sorts suivis.  
  Icons are dynamically generated according to tracked spells.  


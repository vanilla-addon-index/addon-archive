# Threat

A World of Warcraft Vanilla (v1.1.12) Addon to simplify tanking.
Classes supported by addon:\
Warrior\
Paladin\
Druid

## Usage

Provide a single button to generate the maximum available threat on a given
single target. My keybindings have this on a easy-to-reach button, such as `E`.
Other frequently used abilities such as Shield Block or Bloodrage are not
included, since they have different intentions.

## Installation

Clone the repository into your `Addons` folder:

    cd <WOW_BASE_DIR>/Interface/Addons
    git clone https://github.com/Zedorff/Threat

Create a macro to call `Threat()` or `/threat`:

    /threat

    # or

    /script Threat();

## Commands

`Threat` can be enabled or disabled and its operation inspected:

    /threat             Cast "best" threat ability
    /threat debug       Toggle debug messages on/off
    /threat sunder      Stack 5 sunder always
    /threat shout       Always keep Battle Shount on yourself
    /threat wisdom      Always keep Judgement of Wisdom on target

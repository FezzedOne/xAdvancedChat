# xAdvancedChat

Replaces the lacklustre vanilla chat box with a new chat box that supports player portraits and more!
Brought to you with love by Degranon and ported to xSB-2 by FezzedOne.

# Functionality

Features of this mod:

 - Localisation: currently supports English and Russian languages
 - Two Discord-inspired modes: full and compact
 - Quick and easy DM tab
 - Collapsing of long messages
 - Ability to copy messages
 - Message channel filtration
 - Plugin system that allows modders to expand this mod's functionality even more! Plugins are cross-compatible with [Degranon's StarCustomChat](https://github.com/KrashV/StarCustomChat)

![Full avatar mode](https://i.imgur.com/yLO8qWg.png)
![Short mode with disabled commands](https://i.imgur.com/oXtXDp7.png)

# Prerequisites

- [xSB-2](https://github.com/FezzedOne/xSB-2) v2.3.7+.

# Controls

 - **Mousewheel**: scroll chat up / down
 - **Ctrl** + **Mousewheel**: change font size
 - **Shift** + **Mousewheel**: scroll up / down twice as fast
 - **Shift** + **Up**/**Down**: scroll through last sent messages
 - **P** (default, change in the Mod Binds dialogue): repeat last command

# Plugins

The base mod includes two sample plugins for proximity-based chat and OOC chat.
They are disabled by default and require patching the **/scripts/starcustomchat/enabledplugins.json** file. For example:

    [  {"op": "add", "path": "/-", "value": "oocchat" },   { "op": "add", "path": "/-", "value": "proximitychat" } ]

If you want to create your own plugins, have a look at the include samples in the repo:

## Proximity chat

You can specify the stagehand that would receive the message and then resend it to people around, or you can skip the stagehand and send the message around your character. 
![Proximity chat showcase](https://i.imgur.com/fbnNKF0.png)
*Obviously, only people with the mod installed will receive this message!*

## OOC chat

A simple tab that automatically adds double brackets around your message (`(( ))`). Also places OOC messages in a separate channel which you can turn off.
![OOC chat showcase](https://i.imgur.com/AeTFO7a.png)

# Contact the devs

If you have bug reports, suggestions or other ideas, you can contact:
- @degranon: On Discord (@degranon) or join [his Discord server](https://discord.gg/gnu8xRjS9p)
- @fezzedone: On Discord (@fezzedone) or join [his Discord server](https://discord.gg/S46Gk2t)

# xAdvancedChat

Replaces the lacklustre vanilla chat box with a new chat box that supports player portraits and more!
Created by Degranon, and improved and ported to xSB-2 by FezzedOne.

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

The base mod includes two plugins for proximity-based chat and OOC chat.
They are enabled by default in xAdvancedChat. To disable them, or enable your own plugins, make a patch file like this:

```json
[
    { "op": "remove", "path": "/", "find": "oocchat" },
    { "op": "remove", "path": "/", "find": "proximitychat" },
    { "op": "add", "path": "/-", "value": "customplugin" }
]
```

Note the xSB-2-specific `"find"` parameters. If you want to create your own plugins, have a look at the included plugins in the repo:

## Proximity chat

You can specify the stagehand that would receive the message and then resend it to people around it, or you can skip the stagehand and send the message around your character. Works with [StarCustomChat's](https://github.com/KrashV/StarCustomChat) proximity chat.

![Proximity chat showcase](https://i.imgur.com/fbnNKF0.png)
*Obviously, only people with the mod installed will receive this message!*

In xAdvancedChat, messages surrounded by triple parentheses or brackets (e.g., `((( OOC message! )))`) or by pipes (e.g., `|"Yelling!"|`) will be "split" from your message and sent to local chat. If the brackets or pipes are immediately preceded by an `@` (e.g., `@((( OOC message! )))` or `@|[Radio] "Radio message!"|`), that part of the message is sent in global/broadcast chat.

## OOC chat

A simple tab that automatically adds double brackets around your message (`(( ))`). Also places OOC messages in a separate channel which you can turn off. xAdvancedChat also adds a Rolls channel for dice rolls and other tabletop/mechanics stuff. Any messages posted in that channel will be surrounded by angled brackets (`<< >>`) and may turned off separately from regular OOC messages. Bracketed parts of messages are also automatically colour-coded appropriately, helpfully marking them as "OOC".

![OOC chat showcase](https://i.imgur.com/AeTFO7a.png)

# Redistribution and modification

This mod is under the MIT licence. You can modify the mod however you like, but make sure to credit FezzedOne and Degranon!

# Contact the devs

If you have bug reports, suggestions or other ideas, you can contact:
- @degranon: On Discord (@degranon) or join [his Discord server](https://discord.gg/gnu8xRjS9p)
- @fezzedone: On Discord (@fezzedone) or join [his Discord server](https://discord.gg/S46Gk2t)

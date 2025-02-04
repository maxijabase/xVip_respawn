# xVip - Respawn Plugin

A customizable respawn plugin for xVip players in Team Fortress 2. This plugin allows VIP players to respawn either instantly or by pressing the "Call Medic!" button (E key by default).

## Features

- Two respawn modes for VIP players:
  - Press E to respawn (Pressing E Mode)
  - Instant respawn after death (Always Instant Mode)
- Customizable respawn preferences saved per player
- HUD messages indicating respawn availability

## Requirements

- SourceMod
- Team Fortress 2 dedicated server
- [xVip](https://github.com/maxijabase/xVip)

## Configuration

### ConVars

- `vip_respawn_enabled` - Enable/disable the plugin (Default: 1)
- `vip_respawn_version` - Plugin version (Do not modify)

### Commands

- `sm_respawnmode` - Opens the respawn mode selection menu

### Permissions

Players must have VIP status through the xVip system to use the respawn features.

## Usage

VIP players can:
1. Type `!respawnmode` in chat to open the respawn mode selection menu
2. Choose between two modes:
   - Pressing E: Respawn by pressing the "Call Medic!" button after death
   - Always Instant: Automatically respawn shortly after death

## Credits

- Original author: Mathx
- Modified by: ampere
- Part of the xVip plugin

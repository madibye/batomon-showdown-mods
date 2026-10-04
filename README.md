# Batomon Showdown Mod Repository

Hello! This repository currently contains a mod loader for Batomon Showdown and various compatible mods. If you'd like your mod added here, please feel free to contact me on Discord and let me know. I'm also active in the [Batomon Showdown Discord server](https://discord.gg/kyArnasVTU)'s #modding channel, where I'd recommend sharing about development of mods and such. My only rule at the moment is that I will not be accepting AI generated or vibecoded mods onto this repo.

This repo currently includes the following:

- Batomon Showdown Mod Loader, mostly by [@EmoUsedHM01](https://github.com/EmoUsedHM01) with some tweaks by [@madibye](https://github.com/madibye)
- BatopediaChecker, by [@EmoUsedHM01](https://github.com/EmoUsedHM01)
- LeaderboardMod, by [@EmoUsedHM01](https://github.com/EmoUsedHM01)
- KeybindsMod, by [@madibye](https://github.com/madibye)

# Batomon Showdown Mod Loader

## Install

Extract the loader ZIP into the game folder beside `batomon_showdown.exe` and `batomon_showdown.pck`. The resulting layout is:

```text
batomon_showdown.exe
batomon_showdown.pck
override.cfg
Mods/
  mod_loader.gd
  README.md
  YourMod/
    mod_main.gd
```

If you already have an `override.cfg`, preserve its other settings and add this entry to its `[autoload]` section (create that section if absent):

```ini
[autoload]
ModLoader="*res://Mods/mod_loader.gd"
```

Start the game normally. No personal paths, installer, custom launcher or game-archive patch are required. The game folder must be writable for log files.

## Mod format

Each loose mod goes in `Mods/<mod_name>/mod_main.gd` and extends `Node`. The loader instantiates entry scripts during its own `_init`, then adds them to the tree during its `_ready`.

Optional mod entry callbacks:

```gdscript
func mod_init():
	# Early setup. The mod instance exists, but it is not in the scene tree yet.
	# Use this for pure data setup or other work that must happen before the main scene loads.

func mod_ready():
	# Runtime setup after the loader adds the mod node to the tree.
	# Use this for tree access, signals, input, UI patches, and /root autoload lookups.

func mod_bootstrap():
	# Legacy runtime hook. Still called after mod_ready() for existing mods.

func make_custom_settings_menu_entries() -> Array[Control]:
  # Use to return Control nodes to put in the settings menu.
```

A mod script's native `_init()` runs when the loader instantiates it, and native `_ready()` runs when the loader adds it to the tree. If a mod also calls bootstrap in `_ready()`, its bootstrap should guard against repeated initialization.

PCK and ZIP resource packs are supported in Mods and directly inside each mod folder. Packed entry scripts use `res://mods/<archive_basename>/mod_main.gd`. Packs are mounted before the main scene loads, in sorted order within each folder. Loose entries take precedence over packed entries with the same name. Resource-only packs do not need an entry script.

Distribution ZIPs containing a top-level Mods folder should be extracted into the game folder, rather than placed inside Mods as resource packs.

## Paths and logging

The portable autoload uses `res://Mods/mod_loader.gd`. The loader locates the external, writable Mods directory with `OS.get_executable_path().get_base_dir().path_join("Mods")`, so moving the installation or launching from a different working directory needs no configuration changes. Game resources continue to use `res://` paths.

On each launch, the loader clears existing `.log` files recursively under Mods before loading any mods; symbolic links are skipped. It writes a timestamped session header to `Mods/mod_loader.log` and appends that launch's messages. Other files are untouched.

To disable a mod, close the game and move its folder outside Mods. To disable the loader, remove its autoload entry from override.cfg.

Validated with the installed Godot 4.7 game build from a separate installation directory and a different working directory. Future game builds may require compatibility updates. This package contains the loader only, with no mods, game files, saves or logs.

## Mod identity and configurable settings (loader 1.1)

The loader adds **Settings > Mods** to the native settings menu. Select a mod with the Mod row's arrows, then edit its settings below. Only mods declaring settings appear in this picker. The selected mod's ID, version and optional author appear beneath it; its description is available as a tooltip.

Add an optional `mod.json` next to a mod's entry script:

```json
{
  "id": "example.my_mod",
  "name": "My Mod",
  "version": "1.0.0",
  "author": "Your name",
  "description": "What this mod does.",
  "settings": [
    {"key": "enabled", "label": "Enabled", "type": "bool", "default": true},
    {"key": "style", "label": "Style", "type": "enum", "options": ["Small", "Large"], "default": "Small"},
    {"key": "count", "label": "Count", "type": "int", "min": 1, "max": 10, "step": 1, "default": 3},
    {"key": "scale", "label": "Scale", "type": "float", "min": 0.5, "max": 2.0, "step": 0.1, "default": 1.0},
    {"key": "caption", "label": "Caption", "type": "string", "default": "Hello"}
  ]
}
```

Use a unique stable ID; changing it creates a separate settings namespace.
Packed mods can provide `res://mods/<archive_basename>/mod.json`; an external manifest takes precedence. Legacy mods still load with their folder/archive name as ID and name, version `Unknown`, and no configurable settings. Invalid manifests block startup. Duplicate IDs also block startup instead of using a fallback ID. Invalid setting definitions and duplicate keys are skipped.

Supported types: `bool`, `enum`, `int`, `float`, `string`. Numeric bounds default to 0 and 100, and step to 1; step must be positive. Each setting needs a valid `default`; `label` and `description` are optional. String edits save on Enter or focus loss. Other edits save immediately. Large schemas scroll within the page.

Runtime API, available once the loader has entered the tree:

```gdscript
var loader = get_node("/root/ModLoader")
var mods = loader.get_mods() # Detached metadata dictionaries; true filters to configurable mods.
var enabled = loader.get_config("example.my_mod", "enabled", true)
var error = loader.set_config("example.my_mod", "enabled", false)
loader.config_changed.connect(func(mod_id, key, value):
    if mod_id == "example.my_mod":
        print(key, " changed to ", value)
)
```

Settings live in `user://mod_settings.cfg`, separate from game settings and save data. They persist across restarts and mod updates. Missing/invalid stored values use the declared defaults. `set_config` validates values, returns a Godot error code, and emits `config_changed` only after a successful save. Failed saves restore the previous in-memory value and display an error in the menu. The settings file is never removed by log cleanup.

The native Game/System pages, Done/close behavior and controller tab cycling are inherited from the installed game. Future changes to the game's settings script or scene structure may require a loader compatibility update.

## Required dependencies (loader 1.2)

Declare required mods using their exact, case-sensitive manifest IDs:

```json
{
  "id": "example.my_mod",
  "name": "My Mod",
  "version": "1.0.0",
  "dependencies": ["batopedia_checker", "example.shared_library"]
}
```

The optional `dependencies` field is an array of non-empty ID strings. An absent or empty list means no dependencies. For legacy mods without a manifest, use the folder/archive name. This checks installed presence, not version ranges or successful execution, and does not change mod load order.

The loader checks all dependencies before instantiating any mod entry scripts or calling hooks. Missing dependencies, invalid manifests/dependency declarations, and duplicate IDs block startup. The error screen lists affected mods and missing IDs, pauses the game, and offers an **Exit** button. Install the required mods or remove the affected mods and restart. Details also appear in `Mods/mod_loader.log`. Packs must still be mounted first to discover packed manifests.


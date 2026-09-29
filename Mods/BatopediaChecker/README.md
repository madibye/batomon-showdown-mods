# BatopediaChecker 1.1.0

Shows earned Batopedia completion icons on Batomon cards using the game's original artwork and saved achievement data.

- Team and bench: top right, beside the level label.
- Shop: top left, including shiny offers. Icons move below existing level indicators when needed; the shiny label stays on the right.
- Inspection and hover panels: between the name and rarity. Icons shrink to fit a narrow header; exceptionally crowded headers omit them rather than overlap text.
- Order: trophy (`won`), medal (`lv3`), rainbow star (`shiny`). Only earned marks appear.

Evolved and shiny forms use the same base-species lookup as the Batopedia. Empty slots, item cards, locked slots and concealed monsters do not display marks. Changes to card contents and profile achievements are reflected automatically. Overlays do not receive mouse or controller input.

## Installed location

`C:\Games\Batomon Showdown\Mods\BatopediaChecker\mod_main.gd`

Start or restart the game normally. The existing `Mods/mod_loader.gd` loads this loose script automatically. No PCK or ZIP is needed in the Mods folder.

To uninstall, close the game and remove the `Mods/BatopediaChecker` folder, or move it outside `Mods`. No save-file cleanup is required. Renaming the folder inside Mods will not disable it.

## Compatibility and validation

Built against this installed Batomon Showdown build (Godot 4.7, build 5b4e0cb0f). Requires the existing local mod loader. Future game changes to card scripts or profile fields may require an update.

Passed 49 runtime checks with the game's actual card scenes in an isolated test profile, including all eight achievement combinations, empty/item card reuse, evolution, shiny instances, shiny shop alignment, profile replacement, locked/unknown cards, duplicate initialization, input passthrough and layout bounds. Visually checked rendered cards; see `preview.png`. A complete interactive run was not played during validation.

The mod reads completion progress only; it does not grant achievements, modify gameplay, or save profile data. No game assets are bundled: textures load from the installed game.

Editable source: `Mods_src/BatopediaChecker/mod_main.gd`.

## Settings

With the updated ModLoader, open Settings > Mods and select Batopedia Checker.
Tooltip Icons, Team View Icons (including bench), and Shop Icons each have an
independent On/Off toggle. All default to On. Changes apply immediately to
existing cards and persist across game restarts. The manifest is `mod.json`;
distribute it alongside `mod_main.gd`. Mod ID: `batopedia_checker`.

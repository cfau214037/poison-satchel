# Poison Satchel

<img src="PoisonSatchel-icon.png" alt="Emerald poison flask in a rogue's leather satchel" width="128">

Poison Satchel helps rogues in **World of Warcraft Forever** restock and apply poisons. At a poison vendor, choose a recipe and how many times to craft it. The manager compares the ingredients with what's in your bags and shows how much the missing supplies will cost.

## Getting started

1. Copy the [PoisonSatchel](PoisonSatchel/) folder into `_forever_/Interface/AddOns/`. The file `PoisonSatchel_Forever.toc` should sit directly inside `AddOns/PoisonSatchel/`.
2. Enable **Poison Satchel** in the character selection AddOns list. Open your **Poisons** profession once in game so the manager can read your learned recipes.
3. Visit a poison supplier, choose a poison and enter a craft quantity. Buy the missing ingredients, then click **Prepare craft**. Confirm with **Create** in the Poisons window.

The manager shows the highest learned rank of each poison by default. Enable **Show all learned ranks** to prepare a lower rank.

## Poison action bar

The bar has one slot each for Instant, Deadly, Wound, Crippling, and Mind-numbing Poison. A colored icon shows the highest rank in your bags and how many you have of that rank. A gray icon means you have none of that poison. Click a stocked poison, then select the weapon to coat.

Click the **Poisons crafting icon** at the end of the bar to open the profession. Right-drag that icon to move the bar. Its position is saved per character.

## Minimap and settings

| Control | Action |
| --- | --- |
| Left-click the minimap icon | Open the poison manager. |
| Right-click the minimap icon | Open the manager, toggle the poison bar, or jump to addon settings. |
| Drag the minimap icon | Move it around the minimap. |
| Type `/poisonsatchel` or `/venom` | Open the poison manager. |

All three preferences are under **Settings → AddOns → Poison Satchel**. Action bar visibility changes take effect after combat if you toggle the bar during a fight.

## Publishing a release

Set the version in `PoisonSatchel/PoisonSatchel_Forever.toc` and commit the changes. Tag that commit with the matching version (for example, `v0.3.8`) and push the tag to GitHub. The release workflow checks the tag against the TOC, packages the addon and license, and attaches the ZIP to a GitHub Release.

For CurseForge, upload the attached `PoisonSatchel-vX.Y.Z.zip` from the release. To build the same file locally, run `./scripts/Build-Addon.ps1` in PowerShell 7. The ZIP is written to `dist/`.

## License

[MIT](LICENSE)

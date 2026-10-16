# Inventory Archivist — Forever

**Version:** 0.1.2j-alpha (community test release)  
**Client:** WoW Forever 1.60.1 (Interface 16001)

Inventory Archivist is a community-made addon for tracking character inventories, viewing account-wide item snapshots through its Vault, and customizing bag positions in WoW Forever.

## Install

1. Exit the game.
2. Extract the ZIP into your WoW Forever `Interface/AddOns/` directory.
3. Confirm the result is `Interface/AddOns/InventoryArchivist_Forever/InventoryArchivist_Forever.toc` (not a nested duplicate folder).
4. Launch the game and enable **Inventory Archivist - Forever** if needed.
5. Type `/ia` to open the Vault; `/ia status` shows diagnostics.

## Features

- Locally recorded character inventory and bank snapshots, separated by realm.
- Read-only Account Vault for viewing tracked items across characters.
- Bag and bank inventory markers.
- Custom bag positioning with independent combined/separate layouts, reset controls, and saved coordinates.
- New-install defaults: positioning enabled, locked, and controls always visible. Existing settings are retained on update.

## Alpha feedback

Please share: (1) what happened, (2) exact steps to reproduce, (3) Lua errors if any, (4) screenshot if helpful, and (5) whether `/reload` changes the behavior. Particularly useful: combined/separate bag switching, keyring/reagent behavior, bank markers, and realm isolation.

Known minor visual quirk: when dragging a bag with other bags natively stacked against it, an attached bag can briefly follow and snap back to its saved position. This does not normally change saved positions.

## Data and updates

The addon stores snapshots and preferences locally using WoW SavedVariables (`InventoryArchivistForeverDB`). Back up the relevant SavedVariables files before major testing. Installing a new ZIP normally preserves existing saved data.

This addon does not move, delete, sell, or modify inventory items. This is an independent community project and is not affiliated with Blizzard Entertainment or the WoW Forever team.

## License

The project's original source code is intended to be distributed under the MIT License. **Before redistributing this ZIP, place your completed `LICENSE` file inside the `InventoryArchivist_Forever` folder.** The `LICENSE` file is intentionally not included in this package because the copyright-holder details were not supplied for packaging. Blizzard trademarks, game assets, and any third-party components remain subject to their respective owners' terms.

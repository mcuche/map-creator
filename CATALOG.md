# Cast & Props Catalog

The application creates an editable catalog in its user-data folder on first run. Use **OPEN FOLDER** in the Cast & Props panel to find `catalog.json` and its `images` directory, then use **RELOAD** after editing.

The file uses strict UTF-8 JSON:

```json
{
  "version": 1,
  "groups": [
    { "id": "cast", "name": "CAST" }
  ],
  "entries": [
    { "id": "knight", "name": "Knight", "group_id": "cast", "footprint": [1, 1], "image": "images/knight.png" }
  ]
}
```

- IDs use lowercase letters, numbers, hyphens, and underscores and must be unique.
- Group and entry array order controls display order.
- Group and entry names must not be empty; duplicate display names are allowed.
- Footprint dimensions are whole numbers from 1 through 100.
- Images must be PNG files inside the catalog folder, at most 20 MiB and 4096×4096 pixels.
- The catalog supports at most 100 groups and 500 entries and may be empty.
- Unknown fields, missing groups, unsafe paths, or invalid images reject the entire reload. The previous valid catalog remains active.

Existing pieces on a battle map keep the identity, name, footprint, and image path captured when they were placed. Removing or editing a catalog entry does not change those fields on existing pieces. Saving embeds each used PNG once, reducing embedded copies larger than 2 MiB with nearest-neighbor scaling while leaving catalog PNGs unchanged. Embedded images are limited to 2 MiB each and 32 MiB per map. A map opened from the new format uses its embedded images even if catalog entries or PNG files have been removed. Older maps still use image paths until saved again. If an older map's image is already missing and has no cached copy, saving reports an error because the image cannot be embedded.

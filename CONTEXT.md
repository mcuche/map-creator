# Battle Map Creator

Language for a desktop editor that prepares fantasy tabletop battle maps by arranging pieces over a landscape.

## Language

**Cast & Props Catalog**:
The complete user-controlled collection of characters, creatures, props, and scenery available for placement. Starter contents are ordinary catalog contents and may be changed or removed by the user.
_Avoid_: Built-in assets, asset library

**Group**:
A user-defined, ordered collection within the Cast & Props Catalog. A group may be empty, renamed, created, or removed independently of its contents.
_Avoid_: Fixed category

**Catalog Entry**:
A reusable character, creature, prop, or scenery definition available from the Cast & Props Catalog. Removing an entry prevents new placement but does not alter pieces already placed on a battle map.
_Avoid_: Built-in asset, catalog item

**Placed Piece**:
An occurrence of a Catalog Entry on a battle map. It retains its identity, name, and footprint when placed. New map files embed its image so the saved appearance survives catalog changes; older files still use a live image path. A missing image does not remove the piece.
_Avoid_: Catalog Entry, object

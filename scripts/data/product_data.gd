class_name ProductData
extends Resource
## A sellable medical diagnostics product. One .tres per product lives in res://data/products/.

@export var id: StringName
@export var display_name := ""
## Short code drawn on placeholder boxes (shelves, inventory).
@export var short_code := ""
@export_multiline var description := ""
## What the Supplier Depot charges per unit.
@export var wholesale_cost := 0
## Base selling price per unit (before reputation / in-person bonuses).
@export var retail_price := 0
## XP earned per unit sold.
@export var xp_reward := 10
## Reputation (%) earned per deal for this product.
@export var reputation_reward := 1
## Player level required before leads ask for it / the depot stocks it.
@export var unlock_level := 1
## Upper bound for how many units a single lead orders.
@export var max_order_qty := 3
@export var color := Color.WHITE
## Optional icon. When null, UI draws a colored placeholder box with short_code.
@export var icon: Texture2D

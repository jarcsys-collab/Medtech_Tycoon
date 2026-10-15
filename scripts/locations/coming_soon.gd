extends LocationBase
## Placeholder for map places without a playable scene yet (Medtycoonv1 "SCENE COMING SOON").

@onready var place_label: Label = %PlaceLabel


func setup(data: LocationData, player: Player) -> void:
	super.setup(data, player)
	if data:
		place_label.text = "%s · %s" % [data.display_name, data.district]

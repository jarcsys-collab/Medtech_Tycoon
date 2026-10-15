class_name ChoiceDialog
extends Control
## Modal dialog driven by UIEvents.ask(title, body, options). Used by customers, shelves, bed, finance.

@onready var title_label: Label = %Title
@onready var body_label: RichTextLabel = %Body
@onready var buttons: VBoxContainer = %Buttons
@onready var panel: PanelContainer = $Center/Panel


func _ready() -> void:
	hide()
	UIEvents.choice_requested.connect(open)


func open(title: String, body: String, options: Array) -> void:
	title_label.text = title
	body_label.text = body
	UIFactory.clear(buttons)
	for opt in options:
		var b := UIFactory.button(opt.get("label", "OK"), _choose.bind(opt.get("action", Callable())),
			opt.get("disabled", false), opt.get("primary", false))
		b.custom_minimum_size.y = 40
		buttons.add_child(b)
	UIAnim.pop_in(self, panel, 0.92)


func close() -> void:
	UIAnim.fade_out(self)


## Responsive: on narrow portrait screens the dialog uses the screen width instead of 460 px.
func apply_layout(portrait: bool) -> void:
	if portrait:
		LayoutSwap.apply(panel, {"custom_minimum_size": Vector2(minf(460.0, get_viewport_rect().size.x - 20.0), 0)})
	else:
		LayoutSwap.restore(panel)


func _choose(action: Callable) -> void:
	close()
	if action.is_valid():
		# Deferred: the action may reopen this dialog, which frees the button being pressed.
		action.call_deferred()

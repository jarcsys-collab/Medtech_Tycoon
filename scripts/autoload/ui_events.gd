extends Node
## Decoupled UI requests. World objects (shelves, customers, bed) ask for dialogs/toasts here
## instead of reaching into the UI scene tree.

signal toast_requested(text: String)
## options: Array of { "label": String, "action": Callable, "disabled": bool, "primary": bool }
signal choice_requested(title: String, body: String, options: Array)


func toast(text: String) -> void:
	toast_requested.emit(text)


func ask(title: String, body: String, options: Array) -> void:
	choice_requested.emit(title, body, options)


## Helper for building dialog options.
func option(label: String, action: Callable = Callable(), disabled := false, primary := false) -> Dictionary:
	return {"label": label, "action": action, "disabled": disabled, "primary": primary}

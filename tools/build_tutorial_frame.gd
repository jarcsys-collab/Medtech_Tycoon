extends SceneTree
## Builds the pixel-art tutorial frame textures from the Sales Simulator v3 dialog box.
##   godot --headless -s tools/build_tutorial_frame.gd -- <path/to/ui/dialog-box.png> <out_dir>
## Source: Sales simulator_.zip -> assets/ui/dialog-box.png (2027x501). Outputs, at 1/5 scale:
##   tutorial_frame.png  card frame for a 9-slice StyleBoxTexture: left border + a clean middle strip +
##                       right border (drops the portrait slot and the small square near the bottom right)
##   tutorial_slot.png   the portrait slot frame on its own
## Source geometry (px): outer edge 0-16, teal line 17-27, fill from 28; slot spans x 40-440, y 40-460.

const SCALE := 0.2
const LEFT_BORDER := Rect2i(0, 0, 40, 501)
const MIDDLE := Rect2i(460, 0, 560, 501)
const RIGHT_BORDER := Rect2i(1960, 0, 67, 501)
const SLOT := Rect2i(40, 40, 400, 420)


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("usage: -- <dialog-box.png> <out_dir>")
		quit(1)
		return
	var src := Image.load_from_file(args[0])
	if src == null or src.get_size() != Vector2i(2027, 501):
		push_error("expected the 2027x501 dialog-box.png")
		quit(1)
		return
	src.convert(Image.FORMAT_RGBA8)
	var w := LEFT_BORDER.size.x + MIDDLE.size.x + RIGHT_BORDER.size.x
	var frame := Image.create_empty(w, src.get_height(), false, Image.FORMAT_RGBA8)
	frame.blit_rect(src, LEFT_BORDER, Vector2i.ZERO)
	frame.blit_rect(src, MIDDLE, Vector2i(LEFT_BORDER.size.x, 0))
	frame.blit_rect(src, RIGHT_BORDER, Vector2i(LEFT_BORDER.size.x + MIDDLE.size.x, 0))
	_save(frame, args[1].path_join("tutorial_frame.png"))
	_save(src.get_region(SLOT), args[1].path_join("tutorial_slot.png"))
	quit(0)


func _save(img: Image, path: String) -> void:
	img.resize(roundi(img.get_width() * SCALE), roundi(img.get_height() * SCALE), Image.INTERPOLATE_LANCZOS)
	img.save_png(path)
	print("wrote %s %s" % [path, img.get_size()])

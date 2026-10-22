class_name SaveMigrator
extends RefCounted
## Save-file parsing, version upgrades and validation. Pure data in, pure data out (no autoloads,
## no file access), so tests can exercise it directly.
##
## A save file is {"version": int, "saved_at": String, "state": Dictionary}; "state" is
## GameState.to_dict(). To change the format:
##   1. bump SaveSystem.SAVE_VERSION to N,
##   2. add a step for N-1 to SaveSystem.MIGRATIONS (state of version N-1 in, state of version N out),
##   3. add a fixture of the old format under tests/fixtures/ and a test that loads it.
## Never edit a step that has shipped; add a new one instead.
##
## Validation never invents progress: a field with the wrong type is dropped (GameState.from_dict
## then uses its default) and malformed list entries are skipped, each with a warning.

enum Status { OK, CORRUPT, UNSUPPORTED }

## Saves written before the "version" key existed are treated as this version.
const LEGACY_VERSION := 1

const INT_FIELDS := ["day", "minutes", "cash", "reputation", "xp", "revenue_total", "expenses_total",
	"tutorial_step", "tutorial_version", "next_id"]
const NON_NEGATIVE_FIELDS := ["minutes", "xp", "revenue_total", "expenses_total", "tutorial_step"]
const LEAD_REQUIRED := {"id": TYPE_INT, "name": TYPE_STRING, "business": TYPE_STRING,
	"product_id": TYPE_STRING, "qty": TYPE_INT}
const DEAL_REQUIRED := {"day": TYPE_INT, "customer": TYPE_STRING, "product_id": TYPE_STRING,
	"qty": TYPE_INT, "amount": TYPE_INT}


## Parses save-file text and upgrades it to `current_version`.
## Returns {status: Status, version: int (as found in the file), state: Dictionary, warnings: Array[String], error: String}.
static func parse(text: String, current_version: int, migrations: Dictionary) -> Dictionary:
	var json := JSON.new()
	if json.parse(text) != OK:
		return _fail(Status.CORRUPT, "not valid JSON (line %d: %s)" % [json.get_error_line(), json.get_error_message()])
	var data = json.data
	if typeof(data) != TYPE_DICTIONARY:
		return _fail(Status.CORRUPT, "top level is not an object")
	if typeof(data.get("state")) != TYPE_DICTIONARY:
		return _fail(Status.CORRUPT, "missing \"state\" object")
	var version := LEGACY_VERSION
	if data.has("version"):
		var v = _as_int(data.version)
		if v == null or v < LEGACY_VERSION:
			return _fail(Status.CORRUPT, "invalid version %s" % str(data.version))
		version = v
	if version > current_version:
		var newer := _fail(Status.UNSUPPORTED, "save version %d is newer than this game (%d)" % [version, current_version])
		newer.version = version
		return newer
	var upgraded := migrate(data.state, version, current_version, migrations)
	if upgraded.status != Status.OK:
		upgraded.version = version
		return upgraded
	var warnings: Array[String] = []
	var state := sanitize_state(upgraded.state, warnings)
	return {"status": Status.OK, "version": version, "state": state, "warnings": warnings, "error": ""}


## Runs migration steps from_version -> to_version in order. Each step receives a deep copy.
static func migrate(state: Dictionary, from_version: int, to_version: int, migrations: Dictionary) -> Dictionary:
	var out := state.duplicate(true)
	for v in range(from_version, to_version):
		if not migrations.has(v):
			return _fail(Status.UNSUPPORTED, "no upgrade step from save version %d" % v)
		var next = (migrations[v] as Callable).call(out.duplicate(true))
		if typeof(next) != TYPE_DICTIONARY:
			return _fail(Status.CORRUPT, "upgrade step from version %d failed" % v)
		out = next
	return {"status": Status.OK, "state": out, "warnings": [], "error": ""}


## Returns a copy of `state` whose known fields have the types GameState.from_dict expects.
static func sanitize_state(state: Dictionary, warnings: Array[String]) -> Dictionary:
	var out := state.duplicate(true)
	for key in INT_FIELDS:
		if not out.has(key):
			continue
		var n = _as_int(out[key])
		if n == null:
			warnings.append("%s: not a number, using default" % key)
			out.erase(key)
		elif key in NON_NEGATIVE_FIELDS and n < 0:
			warnings.append("%s: negative, using default" % key)
			out.erase(key)
		else:
			out[key] = n
	if out.has("day") and out.day < 1:
		warnings.append("day: below 1, using default")
		out.erase("day")
	if out.has("reputation"):
		out.reputation = clampi(out.reputation, 0, 100)
	if out.has("tutorial_done") and typeof(out.tutorial_done) != TYPE_BOOL:
		warnings.append("tutorial_done: not true/false, using default")
		out.erase("tutorial_done")
	if out.has("location_id") and typeof(out.location_id) != TYPE_STRING:
		warnings.append("location_id: not text, using default")
		out.erase("location_id")
	if out.has("inventory"):
		out.inventory = _clean_inventory(out.inventory, warnings)
	for key in ["leads", "prospects"]:
		if out.has(key):
			out[key] = _clean_list(key, out[key], LEAD_REQUIRED, _fix_lead, warnings)
	if out.has("deals"):
		out.deals = _clean_list("deals", out.deals, DEAL_REQUIRED, _fix_deal, warnings)
	for key in ["customers", "completed_tasks"]:
		if out.has(key):
			out[key] = _clean_strings(key, out[key], warnings)
	# New leads get ids from next_id; keep it above every saved id so ids never collide.
	var max_id := 0
	for key in ["leads", "prospects"]:
		for l in out.get(key, []):
			max_id = maxi(max_id, l.id)
	if max_id > 0 and int(out.get("next_id", 1)) <= max_id:
		if out.has("next_id"):
			warnings.append("next_id: raised above the highest saved lead id")
		out.next_id = max_id + 1
	return out


## JSON numbers arrive as floats. Accepts whole numbers only; anything else returns null.
static func _as_int(v: Variant) -> Variant:
	match typeof(v):
		TYPE_INT:
			return v
		TYPE_FLOAT:
			if is_finite(v) and v == floorf(v) and absf(v) < 9.0e15:
				return int(v)
	return null


static func _clean_inventory(raw: Variant, warnings: Array[String]) -> Dictionary:
	if typeof(raw) != TYPE_DICTIONARY:
		warnings.append("inventory: not an object, using default")
		return {}
	var out := {}
	for k in raw:
		var n = _as_int(raw[k])
		if n == null or n < 0:
			warnings.append("inventory.%s: invalid amount, skipped" % str(k))
		elif n > 0:
			out[str(k)] = n
	return out


static func _clean_list(key: String, raw: Variant, required: Dictionary, fix: Callable, warnings: Array[String]) -> Array:
	if typeof(raw) != TYPE_ARRAY:
		warnings.append("%s: not a list, using default" % key)
		return []
	var out := []
	for i in raw.size():
		var e = raw[i]
		if typeof(e) != TYPE_DICTIONARY:
			warnings.append("%s[%d]: not an object, skipped" % [key, i])
			continue
		var bad := ""
		for field in required:
			if not e.has(field):
				bad = "missing %s" % field
			elif required[field] == TYPE_INT:
				var n = _as_int(e[field])
				if n == null:
					bad = "%s is not a number" % field
				else:
					e[field] = n
			elif typeof(e[field]) != required[field]:
				bad = "%s has the wrong type" % field
			if bad != "":
				break
		if bad != "":
			warnings.append("%s[%d]: %s, skipped" % [key, i, bad])
			continue
		out.append(fix.call(e))
	return out


static func _fix_lead(l: Dictionary) -> Dictionary:
	l.qty = maxi(1, l.qty)
	for flag in ["met", "sold"]:
		if typeof(l.get(flag)) != TYPE_BOOL:
			l[flag] = false
	if typeof(l.get("source")) != TYPE_STRING:
		l.source = "phone"
	if typeof(l.get("tint")) != TYPE_STRING or not Color.html_is_valid(l.tint):
		l.tint = "ffffffff"
	return l


static func _fix_deal(d: Dictionary) -> Dictionary:
	if typeof(d.get("in_person")) != TYPE_BOOL:
		d.in_person = false
	return d


static func _clean_strings(key: String, raw: Variant, warnings: Array[String]) -> Array:
	if typeof(raw) != TYPE_ARRAY:
		warnings.append("%s: not a list, using default" % key)
		return []
	var out := []
	for e in raw:
		if typeof(e) == TYPE_STRING:
			out.append(e)
		else:
			warnings.append("%s: skipped a non-text entry" % key)
	return out


static func _fail(status: Status, error: String) -> Dictionary:
	return {"status": status, "version": 0, "state": {}, "warnings": [], "error": error}

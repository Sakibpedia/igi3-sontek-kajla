@tool
extends RefCounted
## The logic of the GenMagic plugin that needs neither the editor nor the network:
## building requests, reading responses, formatting prices, naming files and turning
## errors into plain words. Everything here is a static function, so it can be unit
## tested headless (see test/gd/run_tests.gd) and reused by the dock and the client.
##
## Use it with a preload, not a global class: const Core = preload("core.gd")

const VERSION := "1.0.0"
## Sent as X-GenMagic-Client on every request, so the account owner can tell
## plugin usage apart from other API usage.
const CLIENT_HEADER := "godot-plugin/" + VERSION

const DEFAULT_BASE_URL := "https://genmagic.co"
const UTM := "utm_source=godot&utm_medium=integration&utm_campaign=godot-asset-store"
const KEY_URL := "https://genmagic.co/get-api-key?" + UTM
const PRICING_URL := "https://genmagic.co/pricing?" + UTM
const MODELS_URL := "https://genmagic.co/models?" + UTM
const PRIVACY_URL := "https://genmagic.co/legal/privacy"

## The key lives in the per-user Editor Settings (never in the project, so it is never committed).
const SETTING_API_KEY := "genmagic/api_key"
const ENV_API_KEY := "GENMAGIC_API_KEY"
## Optional. Points the plugin at another GenMagic address (a staging server, or a local stand-in
## while testing). Only https, or http on this computer, is accepted, so the key can never be sent
## in the clear to another machine.
const ENV_BASE_URL := "GENMAGIC_BASE_URL"

## Everything the plugin generates is saved under this folder of the project.
const OUTPUT_ROOT := "res://genmagic"

enum Mode { IMAGE, SPEECH, MUSIC }

const IMAGE_SIZES := [
	{"value": "1024x1024", "label": "Square, 1024 x 1024"},
	{"value": "1792x1024", "label": "Wide, 1792 x 1024"},
	{"value": "1024x1792", "label": "Tall, 1024 x 1792"},
]
const DEFAULT_IMAGE_SIZE := "1024x1024"

const MAX_PROMPT_CHARS := 4000
const MAX_SPEECH_CHARS := 4096
## A reference image is sent inside the request as a data URL, so keep it modest.
const MAX_REFERENCE_BYTES := 4 * 1024 * 1024
const MAX_RESPONSE_BYTES := 128 * 1024 * 1024

const IMAGE_TIMEOUT_SECONDS := 150.0
const AUDIO_TIMEOUT_SECONDS := 240.0
const LOOKUP_TIMEOUT_SECONDS := 30.0
const DOWNLOAD_TIMEOUT_SECONDS := 120.0


# ----------------------------------------------------------------------------------------
# Modes
# ----------------------------------------------------------------------------------------

static func mode_kind(mode: int) -> String:
	match mode:
		Mode.SPEECH:
			return "speech"
		Mode.MUSIC:
			return "music"
		_:
			return "image"


static func mode_folder(mode: int) -> String:
	match mode:
		Mode.SPEECH:
			return "speech"
		Mode.MUSIC:
			return "music"
		_:
			return "images"


static func mode_label(mode: int) -> String:
	match mode:
		Mode.SPEECH:
			return "Speech"
		Mode.MUSIC:
			return "Music"
		_:
			return "Image"


# ----------------------------------------------------------------------------------------
# URLs and headers
# ----------------------------------------------------------------------------------------

## A base URL with no trailing slash. Anything that is not http or https falls back to the default.
static func normalize_base_url(url: String) -> String:
	var u := url.strip_edges()
	while u.ends_with("/"):
		u = u.substr(0, u.length() - 1)
	if not (u.begins_with("https://") or u.begins_with("http://")) or u.length() < 10:
		return DEFAULT_BASE_URL
	return u


## The base URL to use: GENMAGIC_BASE_URL when it is https or loopback http, else genmagic.co.
static func base_url_from_environment() -> String:
	var raw := OS.get_environment(ENV_BASE_URL).strip_edges()
	if raw.is_empty():
		return DEFAULT_BASE_URL
	var normalized := normalize_base_url(raw)
	if normalized == DEFAULT_BASE_URL and not raw.begins_with(DEFAULT_BASE_URL):
		return DEFAULT_BASE_URL # not a usable address
	var p := parse_url(normalized)
	if not bool(p["valid"]):
		return DEFAULT_BASE_URL
	if p["scheme"] == "https" or is_loopback_host(str(p["host"])):
		return normalized
	return DEFAULT_BASE_URL


static func join_url(base_url: String, path: String) -> String:
	return normalize_base_url(base_url) + (path if path.begins_with("/") else "/" + path)


## Splits an http(s) URL into scheme, host, port and the rest. Returns an empty host when it
## is not a usable URL. No credentials in the authority are accepted.
static func parse_url(url: String) -> Dictionary:
	var out := {"scheme": "", "host": "", "port": 0, "rest": "", "valid": false}
	var u := url.strip_edges()
	var scheme := ""
	if u.begins_with("https://"):
		scheme = "https"
	elif u.begins_with("http://"):
		scheme = "http"
	else:
		return out
	var after := u.substr(scheme.length() + 3)
	var cut := after.length()
	for ch in ["/", "?", "#"]:
		var i := after.find(ch)
		if i != -1 and i < cut:
			cut = i
	var authority := after.substr(0, cut)
	var rest := after.substr(cut)
	if authority.is_empty() or authority.contains("@") or authority.contains(" "):
		return out
	var host := authority
	var port := 443 if scheme == "https" else 80
	if authority.begins_with("["):
		return out # IPv6 literals are not used by GenMagic or its media hosts
	var colon := authority.rfind(":")
	if colon != -1:
		host = authority.substr(0, colon)
		var port_text := authority.substr(colon + 1)
		if not port_text.is_valid_int():
			return out
		port = port_text.to_int()
	if host.is_empty():
		return out
	out["scheme"] = scheme
	out["host"] = host.to_lower()
	out["port"] = port
	out["rest"] = rest
	out["valid"] = true
	return out


static func is_loopback_host(host: String) -> bool:
	return host == "localhost" or host == "127.0.0.1"


## True when the URL points at this computer, over http or https. Used by the checks that run
## the plugin against a local mock server; no setting in the plugin points anywhere else.
static func is_loopback_url(url: String) -> bool:
	var p := parse_url(url)
	return bool(p["valid"]) and is_loopback_host(str(p["host"]))


## A generated image is downloaded from the URL the API returned. It must be https (or a
## loopback address while testing locally). The API key is never sent to this host.
static func is_safe_media_url(url: String, allow_loopback_http: bool = false) -> bool:
	var p := parse_url(url)
	if not bool(p["valid"]):
		return false
	if p["scheme"] == "https":
		return true
	return allow_loopback_http and is_loopback_host(str(p["host"]))


## Request headers. The Authorization header is added only when there is a key, so the public
## model list can be read without one.
static func build_headers(api_key: String, json_body: bool, accept: String = "application/json") -> PackedStringArray:
	var h := PackedStringArray()
	h.append("Accept: " + accept)
	h.append("X-GenMagic-Client: " + CLIENT_HEADER)
	if json_body:
		h.append("Content-Type: application/json")
	var key := api_key.strip_edges()
	if not key.is_empty():
		h.append("Authorization: Bearer " + key)
	return h


# ----------------------------------------------------------------------------------------
# Requests
# ----------------------------------------------------------------------------------------

## The problem with the user's input, in words, or an empty string when it is fine.
static func validate_input(mode: int, text: String) -> String:
	var t := text.strip_edges()
	if t.is_empty():
		match mode:
			Mode.SPEECH:
				return "Type the line of dialogue to speak."
			Mode.MUSIC:
				return "Describe the track you want: genre, mood, instruments, tempo."
			_:
				return "Describe the image you want."
	var limit := MAX_SPEECH_CHARS if mode == Mode.SPEECH else MAX_PROMPT_CHARS
	if t.length() > limit:
		return "That is %d characters long. The limit is %d. Shorten it and try again." % [t.length(), limit]
	return ""


## Builds {"path", "body"} for a generation. params: prompt, model (optional, "" means the
## recommended default), size and reference (image only), voice (speech only).
static func build_request(mode: int, params: Dictionary) -> Dictionary:
	var text := str(params.get("prompt", "")).strip_edges()
	var model := str(params.get("model", "")).strip_edges()
	match mode:
		Mode.SPEECH:
			var body := {"input": text}
			var voice := str(params.get("voice", "")).strip_edges()
			if not voice.is_empty():
				body["voice"] = voice
			if not model.is_empty():
				body["model"] = model
			return {"path": "/api/v1/audio/speech", "body": body}
		Mode.MUSIC:
			var body := {"prompt": text}
			if not model.is_empty():
				body["model"] = model
			return {"path": "/api/v1/audio/music", "body": body}
		_:
			var size := str(params.get("size", DEFAULT_IMAGE_SIZE))
			if not image_size_values().has(size):
				size = DEFAULT_IMAGE_SIZE
			var body := {"prompt": text, "size": size}
			if not model.is_empty():
				body["model"] = model
			var reference := str(params.get("reference", "")).strip_edges()
			if not reference.is_empty():
				body["image"] = reference
			return {"path": "/api/v1/images/generations", "body": body}


## Turns what the user typed as the reference image into what the API takes: an https address
## is passed through, a file of the project (res://...) is read and sent as a data URL.
## Returns {"ok": bool, "value": String, "error": String}; an empty text is fine (no reference).
static func resolve_reference(text: String) -> Dictionary:
	var t := text.strip_edges()
	if t.is_empty():
		return {"ok": true, "value": "", "error": ""}
	if t.begins_with("https://"):
		if not is_safe_media_url(t):
			return {"ok": false, "value": "", "error": "That reference image address is not valid."}
		return {"ok": true, "value": t, "error": ""}
	if t.begins_with("http://"):
		return {"ok": false, "value": "", "error": "Use an https address, or pick an image file from your project."}
	if not (t.begins_with("res://") or t.begins_with("user://")):
		return {"ok": false, "value": "", "error": "Pick an image file from your project (res://...) or paste an https address."}
	if not FileAccess.file_exists(t):
		return {"ok": false, "value": "", "error": "The reference image %s was not found." % t}
	var bytes := FileAccess.get_file_as_bytes(t)
	if bytes.size() > MAX_REFERENCE_BYTES:
		return {"ok": false, "value": "", "error": "The reference image is larger than %d MB. Use a smaller one." % (MAX_REFERENCE_BYTES / (1024 * 1024))}
	var data_url := reference_data_url(bytes)
	if data_url.is_empty():
		return {"ok": false, "value": "", "error": "The reference image must be a PNG, JPG or WebP file."}
	return {"ok": true, "value": data_url, "error": ""}


static func image_size_values() -> Array:
	var out: Array = []
	for s in IMAGE_SIZES:
		out.append(s["value"])
	return out


static func timeout_for(mode: int) -> float:
	return IMAGE_TIMEOUT_SECONDS if mode == Mode.IMAGE else AUDIO_TIMEOUT_SECONDS


## "data:image/png;base64,..." for a reference image, or "" when the format is unsupported.
static func reference_data_url(bytes: PackedByteArray) -> String:
	var ext := sniff_image_ext(bytes)
	var mime := ""
	match ext:
		"png":
			mime = "image/png"
		"jpg":
			mime = "image/jpeg"
		"webp":
			mime = "image/webp"
		_:
			return ""
	return "data:%s;base64,%s" % [mime, Marshalls.raw_to_base64(bytes)]


# ----------------------------------------------------------------------------------------
# Responses
# ----------------------------------------------------------------------------------------

## Parses JSON without printing an engine error when the text is not JSON (an HTML error page,
## for example). Returns null when it cannot be parsed.
static func parse_json(text: String) -> Variant:
	if text.strip_edges().is_empty():
		return null
	var j := JSON.new()
	if j.parse(text) != OK:
		return null
	return j.data


## {"url": String, "bytes": PackedByteArray, "error": String} from an images response. The
## API returns a hosted url by default; base64 is handled too.
static func parse_image_response(payload: Variant) -> Dictionary:
	var out := {"url": "", "bytes": PackedByteArray(), "error": ""}
	if typeof(payload) != TYPE_DICTIONARY:
		out["error"] = "GenMagic answered, but the answer was not an image response."
		return out
	var data: Variant = (payload as Dictionary).get("data")
	if typeof(data) != TYPE_ARRAY or (data as Array).is_empty() or typeof((data as Array)[0]) != TYPE_DICTIONARY:
		out["error"] = "GenMagic answered without an image. Try again, or pick another model."
		return out
	var first: Dictionary = (data as Array)[0]
	var url := str(first.get("url", "")).strip_edges()
	if not url.is_empty():
		out["url"] = url
		return out
	var b64 := str(first.get("b64_json", "")).strip_edges()
	if not b64.is_empty():
		var raw := Marshalls.base64_to_raw(b64)
		if raw.size() > 0:
			out["bytes"] = raw
			return out
	out["error"] = "GenMagic answered without an image. Try again, or pick another model."
	return out


## {"error": bool, "code": String, "message": String, "type": String} from an error body.
static func parse_error_body(text: String) -> Dictionary:
	var out := {"code": "", "message": "", "type": ""}
	var payload: Variant = parse_json(text)
	if typeof(payload) == TYPE_DICTIONARY:
		var err: Variant = (payload as Dictionary).get("error")
		if typeof(err) == TYPE_DICTIONARY:
			out["code"] = str((err as Dictionary).get("code", ""))
			out["message"] = str((err as Dictionary).get("message", ""))
			out["type"] = str((err as Dictionary).get("type", ""))
		elif typeof(err) == TYPE_STRING:
			out["message"] = str(err)
	return out


## Reads a header from the "Name: value" lines HTTPRequest returns, ignoring case.
static func header_value(headers: PackedStringArray, header_name: String) -> String:
	var prefix := header_name.to_lower() + ":"
	for line in headers:
		var l: String = line
		if l.to_lower().begins_with(prefix):
			return l.substr(prefix.length()).strip_edges()
	return ""


static func _number_or_unknown(text: String) -> float:
	if text.is_valid_float():
		var v := text.to_float()
		if v >= 0.0 and not is_nan(v) and not is_inf(v):
			return v
	return -1.0


## What a call cost and what is left, from the response headers. Unknown values are -1.0.
static func parse_metering(headers: PackedStringArray) -> Dictionary:
	return {
		"cost_cents": _number_or_unknown(header_value(headers, "X-Cost-Cents")),
		"balance_cents": _number_or_unknown(header_value(headers, "X-Credits-Remaining")),
		"media_url": header_value(headers, "X-Media-Url"),
	}


## {"ok": bool, "balance_cents": float, "spent_cents": float} from GET /api/v1/usage.
static func parse_usage(payload: Variant) -> Dictionary:
	var out := {"ok": false, "balance_cents": -1.0, "spent_cents": -1.0}
	if typeof(payload) != TYPE_DICTIONARY:
		return out
	var d: Dictionary = payload
	if d.has("balance_cents") and (typeof(d["balance_cents"]) == TYPE_FLOAT or typeof(d["balance_cents"]) == TYPE_INT):
		out["balance_cents"] = float(d["balance_cents"])
		out["ok"] = true
	if d.has("spent_cents") and (typeof(d["spent_cents"]) == TYPE_FLOAT or typeof(d["spent_cents"]) == TYPE_INT):
		out["spent_cents"] = float(d["spent_cents"])
	return out


## The models for one mode from GET /api/v1/models, in the order the API returned them
## (newest first). Each: {"id", "name", "price_usd" (-1.0 if unknown), "unit"}.
static func parse_models(payload: Variant, mode: int) -> Array:
	var out: Array = []
	if typeof(payload) != TYPE_DICTIONARY:
		return out
	var items: Variant = (payload as Dictionary).get("data")
	if typeof(items) != TYPE_ARRAY:
		return out
	for item in items:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var m: Dictionary = item
		var id := str(m.get("id", "")).strip_edges()
		if id.is_empty():
			continue
		var category := str(m.get("category", ""))
		var kind := str(m.get("audio_kind", ""))
		if mode == Mode.IMAGE and category != "image":
			continue
		if mode == Mode.SPEECH and not (category == "audio" and kind == "speech"):
			continue
		if mode == Mode.MUSIC and not (category == "audio" and kind == "music"):
			continue
		var price := -1.0
		var unit := ""
		var pricing: Variant = m.get("pricing")
		if typeof(pricing) == TYPE_DICTIONARY:
			var p: Dictionary = pricing
			var est: Variant = p.get("est_per_generation_usd")
			if typeof(est) == TYPE_FLOAT or typeof(est) == TYPE_INT:
				price = float(est)
			unit = str(p.get("unit", ""))
		var name := str(m.get("name", "")).strip_edges()
		out.append({"id": id, "name": id if name.is_empty() else name, "price_usd": price, "unit": unit})
	return out


# ----------------------------------------------------------------------------------------
# Money
# ----------------------------------------------------------------------------------------

## A price in US dollars with as many decimals as it needs: $12.50, $0.195, $0.0045.
static func format_usd(value: float) -> String:
	if is_nan(value) or is_inf(value) or value < 0.0:
		return "price unknown"
	if value == 0.0:
		return "$0.00"
	if value < 0.0001:
		return "under $0.0001"
	if value >= 1.0:
		return "$%.2f" % value
	var s := "%.4f" % value
	var dot := s.find(".")
	while s.ends_with("0") and s.length() - dot - 1 > 2:
		s = s.substr(0, s.length() - 1)
	return "$" + s


## Cents (the API reports cost and balance in US cents, possibly fractional) as dollars.
static func format_cents(cents: float) -> String:
	if cents < 0.0:
		return "unknown"
	return format_usd(cents / 100.0)


## A balance always shows two decimals: $4.21.
static func format_balance(cents: float) -> String:
	if cents < 0.0:
		return "unknown"
	return "$%.2f" % (cents / 100.0)


## "about $0.195 per image", "about $0.0045 per minute".
static func price_phrase(model: Dictionary) -> String:
	var price := float(model.get("price_usd", -1.0))
	if price < 0.0:
		return "price not listed"
	var unit := str(model.get("unit", ""))
	var per := "generation"
	match unit:
		"image":
			per = "image"
		"minute":
			per = "minute"
		"second":
			per = "second"
		"song":
			per = "song"
	return "about %s per %s" % [format_usd(price), per]


## The line shown in the model dropdown.
static func model_label(model: Dictionary) -> String:
	return "%s (%s)" % [model.get("name", model.get("id", "")), format_usd(float(model.get("price_usd", -1.0)))]


## "Cost $0.042. Balance left $4.21." with whatever the headers gave.
static func cost_line(cost_cents: float, balance_cents: float) -> String:
	var parts: Array[String] = []
	if cost_cents >= 0.0:
		parts.append("Cost %s." % format_cents(cost_cents))
	if balance_cents >= 0.0:
		parts.append("Balance left %s." % format_balance(balance_cents))
	if parts.is_empty():
		return "The cost was not reported. Check your balance."
	return " ".join(parts)


# ----------------------------------------------------------------------------------------
# Errors
# ----------------------------------------------------------------------------------------

## Replaces the key with *** wherever it appears, so a key can never end up in a message.
static func redact(text: String, api_key: String) -> String:
	var key := api_key.strip_edges()
	if key.length() < 6:
		return text
	return text.replace(key, "***")


## A key shown as "gm_a...9f2c" so the user can recognise it without exposing it.
static func mask_key(api_key: String) -> String:
	var k := api_key.strip_edges()
	if k.is_empty():
		return ""
	if k.length() <= 8:
		return "..." + k.substr(maxi(k.length() - 2, 0))
	return k.substr(0, 3) + "..." + k.substr(k.length() - 4)


## An API error in plain words with the next step. status is the HTTP status (0 when the call
## never got one), code and message come from the error body.
static func error_message(status: int, code: String, message: String) -> String:
	if code == "missing_api_key":
		return "Add your GenMagic API key first. Create one at %s and paste it above." % KEY_URL
	if code == "email_verification_required":
		return "Verify the email address of your GenMagic account first (https://genmagic.co/verify-email), then try again."
	var detail := message.strip_edges()
	match status:
		401:
			return "GenMagic did not accept the API key. Check that it was pasted whole, or create a new one at %s." % KEY_URL
		402:
			return "Your GenMagic balance is too low for this generation. Add credit at %s and try again." % PRICING_URL
		429:
			return "GenMagic is limiting how fast this key can be used. Wait a minute and try again."
		400, 422:
			if detail.is_empty():
				return "GenMagic could not use this request. Change the prompt or the model and try again."
			return "GenMagic could not use this request: %s" % detail
		404:
			return "That model is not available any more. Refresh the model list and pick another."
		503:
			return "This part of GenMagic is temporarily unavailable. Try again in a moment."
	if status >= 300 and status < 400:
		return "GenMagic answered with a redirect (status %d), which the plugin does not follow with your key. Update the plugin." % status
	if status >= 500:
		return "GenMagic had a problem on its side (status %d). Try again in a moment." % status
	if detail.is_empty():
		return "GenMagic answered with status %d." % status
	return "GenMagic answered with status %d: %s" % [status, detail]


## A failed connection (HTTPRequest.Result) in plain words.
static func transport_error_message(result: int) -> String:
	match result:
		HTTPRequest.RESULT_CANT_RESOLVE:
			return "Could not find the GenMagic server. Check your internet connection."
		HTTPRequest.RESULT_CANT_CONNECT, HTTPRequest.RESULT_CONNECTION_ERROR, HTTPRequest.RESULT_NO_RESPONSE:
			return "Could not reach GenMagic. Check your internet connection and try again."
		HTTPRequest.RESULT_TLS_HANDSHAKE_ERROR:
			return "The secure connection to GenMagic failed. Check the date and time of this computer and any proxy or firewall."
		HTTPRequest.RESULT_TIMEOUT:
			return "GenMagic took too long to answer. A busy model can be slow: try again, or pick another model."
		HTTPRequest.RESULT_BODY_SIZE_LIMIT_EXCEEDED:
			return "The answer from GenMagic was larger than the plugin accepts."
		HTTPRequest.RESULT_REDIRECT_LIMIT_REACHED:
			return "GenMagic sent the plugin in circles (too many redirects)."
		_:
			return "The request to GenMagic failed (network error %d). Try again." % result


# ----------------------------------------------------------------------------------------
# Files
# ----------------------------------------------------------------------------------------

## A lowercase file-name stem from a prompt: letters, digits and single hyphens, at most
## max_words words and max_len characters. Empty when nothing usable is left.
static func slugify(text: String, max_len: int = 40, max_words: int = 6) -> String:
	var s := text.to_lower()
	var out := ""
	for i in s.length():
		var c := s.unicode_at(i)
		var is_digit := c >= 48 and c <= 57
		var is_letter := c >= 97 and c <= 122
		out += char(c) if (is_digit or is_letter) else "-"
	var words: Array[String] = []
	for w in out.split("-", false):
		if words.size() >= max_words:
			break
		words.append(w)
	var joined := "-".join(words)
	if joined.length() > max_len:
		joined = joined.substr(0, max_len)
		while joined.ends_with("-"):
			joined = joined.substr(0, joined.length() - 1)
	return joined


## "20261101-101530" from a Time.get_datetime_dict_from_system() dictionary.
static func timestamp_stamp(dt: Dictionary) -> String:
	return "%04d%02d%02d-%02d%02d%02d" % [
		int(dt.get("year", 1970)), int(dt.get("month", 1)), int(dt.get("day", 1)),
		int(dt.get("hour", 0)), int(dt.get("minute", 0)), int(dt.get("second", 0)),
	]


## The folder for a mode: res://genmagic/images, res://genmagic/speech, res://genmagic/music.
static func output_dir(mode: int) -> String:
	return OUTPUT_ROOT + "/" + mode_folder(mode)


## A readable file name: the first words of the prompt plus the time, e.g.
## "castle-in-the-clouds-20261101-101530.png". Falls back to the kind ("image") when the prompt
## has no usable letters.
static func build_file_name(mode: int, prompt: String, ext: String, stamp: String) -> String:
	var slug := slugify(prompt)
	if slug.is_empty():
		slug = mode_kind(mode)
	return "%s-%s.%s" % [slug, stamp, ext]


## Adds -2, -3 ... before the extension until the path is free.
static func unique_path(path: String) -> String:
	if not FileAccess.file_exists(path):
		return path
	var base := path.get_basename()
	var ext := path.get_extension()
	var n := 2
	while FileAccess.file_exists("%s-%d.%s" % [base, n, ext]):
		n += 1
	return "%s-%d.%s" % [base, n, ext]


## Only paths inside res://genmagic/ are ever written.
static func is_safe_output_path(path: String) -> bool:
	if not path.begins_with(OUTPUT_ROOT + "/"):
		return false
	var tail := path.substr(OUTPUT_ROOT.length() + 1)
	return not (tail.is_empty() or tail.contains("..") or tail.contains("\\") or tail.contains("//") or tail.ends_with("/"))


## Writes the bytes into the project. Returns OK or an Error code.
static func save_bytes(path: String, bytes: PackedByteArray) -> int:
	if not is_safe_output_path(path):
		return ERR_UNAUTHORIZED
	var dir := path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir):
		var made := DirAccess.make_dir_recursive_absolute(dir)
		if made != OK and not DirAccess.dir_exists_absolute(dir):
			return made
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return FileAccess.get_open_error()
	f.store_buffer(bytes)
	f.close()
	return OK


## Why a save failed, in words.
static func save_error_message(err: int, path: String) -> String:
	if err == ERR_UNAUTHORIZED:
		return "The plugin only saves inside res://genmagic/."
	return "The result could not be saved to %s (%s). Check that the project folder is writable." % [path, error_string(err)]


# ----------------------------------------------------------------------------------------
# Formats
# ----------------------------------------------------------------------------------------

static func _starts_with(bytes: PackedByteArray, signature: Array) -> bool:
	if bytes.size() < signature.size():
		return false
	for i in signature.size():
		if bytes[i] != int(signature[i]):
			return false
	return true


## "png", "jpg", "webp", or "" when the bytes are not an image the plugin knows.
static func sniff_image_ext(bytes: PackedByteArray) -> String:
	if _starts_with(bytes, [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]):
		return "png"
	if _starts_with(bytes, [0xFF, 0xD8, 0xFF]):
		return "jpg"
	if bytes.size() >= 12 and _starts_with(bytes, [0x52, 0x49, 0x46, 0x46]) and bytes.slice(8, 12).get_string_from_ascii() == "WEBP":
		return "webp"
	return ""


## "mp3", "wav", "ogg" or "flac" from the first bytes, else from the Content-Type, else "mp3".
static func sniff_audio_ext(bytes: PackedByteArray, content_type: String = "") -> String:
	if _starts_with(bytes, [0x49, 0x44, 0x33]): # ID3 tag
		return "mp3"
	if bytes.size() >= 2 and bytes[0] == 0xFF and (bytes[1] & 0xE0) == 0xE0:
		return "mp3"
	if bytes.size() >= 12 and _starts_with(bytes, [0x52, 0x49, 0x46, 0x46]) and bytes.slice(8, 12).get_string_from_ascii() == "WAVE":
		return "wav"
	if _starts_with(bytes, [0x4F, 0x67, 0x67, 0x53]):
		return "ogg"
	if _starts_with(bytes, [0x66, 0x4C, 0x61, 0x43]):
		return "flac"
	var ct := content_type.to_lower()
	if ct.contains("wav"):
		return "wav"
	if ct.contains("ogg"):
		return "ogg"
	if ct.contains("flac"):
		return "flac"
	return "mp3"


## A note to show when the saved audio is in a format Godot cannot import, else "".
static func audio_format_note(ext: String) -> String:
	if ext == "flac":
		return "This file is FLAC, which Godot does not import. Convert it to WAV, OGG or MP3 before using it."
	return ""


## Reads a PCM WAV file: {"ok", "channels", "rate", "bits", "data", "error"}. Only 16-bit PCM
## with one or two channels is accepted, which is what the dock needs to preview a clip.
static func parse_wav(bytes: PackedByteArray) -> Dictionary:
	var out := {"ok": false, "channels": 0, "rate": 0, "bits": 0, "data": PackedByteArray(), "error": ""}
	if bytes.size() < 44 or bytes.slice(0, 4).get_string_from_ascii() != "RIFF" or bytes.slice(8, 12).get_string_from_ascii() != "WAVE":
		out["error"] = "Not a WAV file."
		return out
	var pos := 12
	var format := 0
	var have_fmt := false
	while pos + 8 <= bytes.size():
		var chunk := bytes.slice(pos, pos + 4).get_string_from_ascii()
		var size := bytes.decode_u32(pos + 4)
		var body := pos + 8
		if chunk == "fmt " and body + 16 <= bytes.size():
			format = bytes.decode_u16(body)
			out["channels"] = bytes.decode_u16(body + 2)
			out["rate"] = bytes.decode_u32(body + 4)
			out["bits"] = bytes.decode_u16(body + 14)
			have_fmt = true
		elif chunk == "data":
			if not have_fmt:
				out["error"] = "The WAV data came before its format."
				return out
			var end := bytes.size()
			if size != 0xFFFFFFFF and size != 0 and body + size <= bytes.size():
				end = body + size
			out["data"] = bytes.slice(body, end)
			break
		pos = body + size + (size & 1)
		if size == 0xFFFFFFFF:
			break
	if not have_fmt or (out["data"] as PackedByteArray).is_empty():
		out["error"] = "The WAV file has no audio data."
		return out
	if not (format == 1 or format == 0xFFFE) or int(out["bits"]) != 16:
		out["error"] = "Only 16-bit PCM WAV can be previewed here. The file is saved and can still be imported."
		return out
	if int(out["channels"]) < 1 or int(out["channels"]) > 2:
		out["error"] = "Only mono and stereo WAV can be previewed here."
		return out
	out["ok"] = true
	return out

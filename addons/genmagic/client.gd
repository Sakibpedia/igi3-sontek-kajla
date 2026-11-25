@tool
extends Node
## Talks to the GenMagic API (https://genmagic.co/openapi.json) with Godot's HTTPRequest.
##
## One request at a time. Every method is a coroutine (use await) that always returns a
## Dictionary and never throws:
##   success: {"ok": true, ...}
##   failure: {"ok": false, "error": "<plain words>", "status": int, "code": String}
##
## The API key is held in memory only. It is sent in the Authorization header to the GenMagic
## host and nowhere else: never in a URL, never in a request body, never to the host a
## generated image is downloaded from, and redirects are not followed with it.

const Core = preload("core.gd")

## Progress for the dock: what is happening now, and which step of how many.
signal stage_changed(text: String, step: int, steps: int)

## One request in flight. Each has its own completion signal, so requests that overlap (the
## dock loads the model list and the balance at the same time) can never receive each other's answer.
class Pending:
	extends RefCounted
	signal done(result: Array)
	var http: HTTPRequest = null
	var cancellable: bool = false
	var finished: bool = false

	func finish(result: Array) -> void:
		if finished:
			return
		finished = true
		done.emit(result)

var base_url: String = Core.base_url_from_environment()
var api_key: String = ""
## True while a generation is running (model and balance lookups do not count).
var busy: bool = false

var _pending: Array[Pending] = []
var _closing: bool = false


## Stops the generation that is running: the request to GenMagic or the image download.
func cancel() -> void:
	for p in _pending.duplicate():
		if p.cancellable:
			_abort(p)


## Stops everything in flight and refuses new requests. Called when the node leaves the tree,
## so no request outlives the editor session or the plugin.
func cancel_all() -> void:
	_closing = true
	for p in _pending.duplicate():
		_abort(p)


func _abort(p: Pending) -> void:
	if p.http != null and is_instance_valid(p.http):
		p.http.cancel_request()
	p.finish([-1, 0, PackedStringArray(), PackedByteArray()])


func _exit_tree() -> void:
	cancel_all()


func _fail(status: int, code: String, message: String) -> Dictionary:
	return {"ok": false, "status": status, "code": code, "error": Core.redact(message, api_key)}


## One HTTP round trip. Returns {"result", "status", "headers", "body", "cancelled"}.
func _send(url: String, method: int, headers: PackedStringArray, body: String, timeout: float, max_redirects: int, cancellable: bool) -> Dictionary:
	var cancelled := {"result": -1, "status": 0, "headers": PackedStringArray(), "body": PackedByteArray(), "cancelled": true}
	if _closing:
		return cancelled
	var http := HTTPRequest.new()
	http.timeout = timeout
	http.body_size_limit = Core.MAX_RESPONSE_BYTES
	http.max_redirects = max_redirects
	add_child(http)
	var pending := Pending.new()
	pending.http = http
	pending.cancellable = cancellable
	_pending.append(pending)
	http.request_completed.connect(func(result: int, code: int, hdrs: PackedStringArray, payload: PackedByteArray) -> void:
		pending.finish([result, code, hdrs, payload])
	)
	var err := http.request(url, headers, method, body)
	if err != OK:
		_pending.erase(pending)
		http.queue_free()
		return {"result": HTTPRequest.RESULT_CANT_CONNECT, "status": 0, "headers": PackedStringArray(), "body": PackedByteArray(), "cancelled": false}
	var r: Array = await pending.done
	_pending.erase(pending)
	http.queue_free()
	if int(r[0]) == -1:
		return cancelled
	return {"result": int(r[0]), "status": int(r[1]), "headers": r[2], "body": r[3], "cancelled": false}


## A call to the GenMagic API. Returns {"ok": true, "status", "headers", "body"} or a failure.
func _api(method: int, path: String, body: Variant, with_key: bool, accept: String, timeout: float, cancellable: bool = false) -> Dictionary:
	if with_key and api_key.strip_edges().is_empty():
		return _fail(0, "missing_api_key", Core.error_message(0, "missing_api_key", ""))
	var json_body := typeof(body) == TYPE_DICTIONARY
	var headers := Core.build_headers(api_key if with_key else "", json_body, accept)
	var payload := JSON.stringify(body) if json_body else ""
	var r := await _send(Core.join_url(base_url, path), method, headers, payload, timeout, 0, cancellable)
	if bool(r["cancelled"]):
		return _fail(0, "cancelled", "Cancelled.")
	if int(r["result"]) != HTTPRequest.RESULT_SUCCESS:
		return _fail(0, "network_error", Core.transport_error_message(int(r["result"])))
	var status: int = r["status"]
	if status < 200 or status >= 300:
		var info := Core.parse_error_body((r["body"] as PackedByteArray).get_string_from_utf8())
		return _fail(status, str(info["code"]), Core.error_message(status, str(info["code"]), str(info["message"])))
	return {"ok": true, "status": status, "headers": r["headers"], "body": r["body"]}


## The public model list for a category ("image" or "audio"). No key is sent, so a wrong key
## cannot break it. Returns {"ok": true, "payload": Variant}.
func fetch_models(category: String) -> Dictionary:
	var r := await _api(HTTPClient.METHOD_GET, "/api/v1/models?category=" + category.uri_encode(), null, false, "application/json", Core.LOOKUP_TIMEOUT_SECONDS)
	if not bool(r["ok"]):
		return r
	var payload: Variant = Core.parse_json((r["body"] as PackedByteArray).get_string_from_utf8())
	if typeof(payload) != TYPE_DICTIONARY:
		return _fail(int(r["status"]), "bad_response", "GenMagic answered, but the model list could not be read.")
	return {"ok": true, "payload": payload}


## The account balance. Returns {"ok": true, "balance_cents": float, "spent_cents": float}.
func fetch_usage() -> Dictionary:
	var r := await _api(HTTPClient.METHOD_GET, "/api/v1/usage", null, true, "application/json", Core.LOOKUP_TIMEOUT_SECONDS)
	if not bool(r["ok"]):
		return r
	var usage := Core.parse_usage(Core.parse_json((r["body"] as PackedByteArray).get_string_from_utf8()))
	if not bool(usage["ok"]):
		return _fail(int(r["status"]), "bad_response", "GenMagic answered, but the balance could not be read.")
	return {"ok": true, "balance_cents": usage["balance_cents"], "spent_cents": usage["spent_cents"]}


## Makes one image, speech clip or music track. params: prompt, model, size, reference, voice.
## Returns {"ok": true, "bytes", "ext", "cost_cents", "balance_cents", "media_url", "mode",
## "model"} or a failure.
func generate(mode: int, params: Dictionary) -> Dictionary:
	if busy:
		return _fail(0, "busy", "A generation is already running.")
	busy = true
	var result := await _generate(mode, params)
	busy = false
	return result


func _generate(mode: int, params: Dictionary) -> Dictionary:
	var problem := Core.validate_input(mode, str(params.get("prompt", "")))
	if not problem.is_empty():
		return _fail(0, "invalid_input", problem)
	if api_key.strip_edges().is_empty():
		return _fail(0, "missing_api_key", Core.error_message(0, "missing_api_key", ""))

	var request := Core.build_request(mode, params)
	var is_image := mode == Core.Mode.IMAGE
	var steps := 3 if is_image else 2
	stage_changed.emit("Sending your request to GenMagic. Making it can take a while.", 1, steps)
	var accept := "application/json" if is_image else "audio/*, application/json"
	var r := await _api(HTTPClient.METHOD_POST, str(request["path"]), request["body"], true, accept, Core.timeout_for(mode), true)
	if not bool(r["ok"]):
		return r

	var metering := Core.parse_metering(r["headers"])
	var out := {
		"ok": true,
		"mode": mode,
		"model": str((request["body"] as Dictionary).get("model", "")),
		"cost_cents": float(metering["cost_cents"]),
		"balance_cents": float(metering["balance_cents"]),
		"media_url": str(metering["media_url"]),
		"bytes": PackedByteArray(),
		"ext": "",
	}

	if not is_image:
		var audio: PackedByteArray = r["body"]
		if audio.is_empty():
			return _fail(int(r["status"]), "empty_response", "GenMagic answered without any audio. Try again, or pick another model.")
		var content_type := Core.header_value(r["headers"], "Content-Type")
		out["bytes"] = audio
		out["ext"] = Core.sniff_audio_ext(audio, content_type)
		return out

	var parsed := Core.parse_image_response(Core.parse_json((r["body"] as PackedByteArray).get_string_from_utf8()))
	if not str(parsed["error"]).is_empty():
		return _fail(int(r["status"]), "bad_response", str(parsed["error"]))
	var image_bytes: PackedByteArray = parsed["bytes"]
	var url := str(parsed["url"])
	if image_bytes.is_empty():
		stage_changed.emit("Downloading the finished image.", 2, steps)
		var d := await _download(url)
		if not bool(d["ok"]):
			# The image was made (and billed): keep the address so the user can still get it.
			d["error"] = "%s Your image was made, and you can still open it at %s" % [d["error"], url]
			d["cost_cents"] = out["cost_cents"]
			d["balance_cents"] = out["balance_cents"]
			return d
		image_bytes = d["bytes"]
		out["media_url"] = url
	var ext := Core.sniff_image_ext(image_bytes)
	if ext.is_empty():
		return _fail(int(r["status"]), "bad_image", "GenMagic returned a file that is not a PNG, JPG or WebP image.")
	out["bytes"] = image_bytes
	out["ext"] = ext
	return out


## Downloads a finished image. The API key is not sent.
func _download(url: String) -> Dictionary:
	if not Core.is_safe_media_url(url, Core.is_loopback_url(base_url)):
		return _fail(0, "unsafe_url", "GenMagic returned an image address the plugin will not open (it is not https).")
	var headers := PackedStringArray(["Accept: image/*", "X-GenMagic-Client: " + Core.CLIENT_HEADER])
	var r := await _send(url, HTTPClient.METHOD_GET, headers, "", Core.DOWNLOAD_TIMEOUT_SECONDS, 4, true)
	if bool(r["cancelled"]):
		return _fail(0, "cancelled", "Cancelled.")
	if int(r["result"]) != HTTPRequest.RESULT_SUCCESS:
		return _fail(0, "network_error", Core.transport_error_message(int(r["result"])))
	if int(r["status"]) < 200 or int(r["status"]) >= 300:
		return _fail(int(r["status"]), "download_failed", "The image could not be downloaded (status %d)." % int(r["status"]))
	var bytes: PackedByteArray = r["body"]
	if bytes.is_empty():
		return _fail(int(r["status"]), "download_failed", "The image download was empty.")
	return {"ok": true, "bytes": bytes}

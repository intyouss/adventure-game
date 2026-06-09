# NetworkManager - HTTP + WebSocket communication
class_name NetworkManager
extends Node

const BASE_URL: String = "http://localhost:8080"
const WS_URL: String = "ws://localhost:8080/ws/battle"

var access_token: String = ""
var refresh_token: String = ""

var _ws: WebSocketPeer
var _ws_connected: bool = false

signal token_expired
signal ws_message_received(type: String, payload: Dictionary)
signal ws_connected
signal ws_disconnected
signal auto_login_success

func _ready() -> void:
	_load_tokens()
	_try_auto_login()

func _process(_delta: float) -> void:
	if _ws == null:
		return
	var state := _ws.get_ready_state()
	if state == WebSocketPeer.STATE_OPEN:
		if not _ws_connected:
			_ws_connected = true
			ws_connected.emit()
			Log.info("Network", "WebSocket connected")
		_ws.poll()
		while _ws.get_available_packet_count() > 0:
			var packet := _ws.get_packet()
			var text := packet.get_string_from_utf8()
			var json: Variant = JSON.parse_string(text)
			if json and json is Dictionary:
				ws_message_received.emit(json.get("type", ""), json.get("payload", {}))
	elif state == WebSocketPeer.STATE_CLOSED:
		if _ws_connected:
			_ws_connected = false
			ws_disconnected.emit()
			Log.warn("Network", "WebSocket disconnected")

# ── Auth ──────────────────────────────────────────────

func _try_auto_login() -> void:
	if refresh_token == "":
		Log.info("Network", "No refresh token, skip auto-login")
		return
	Log.info("Network", "Attempting auto-login with refresh token")
	var ok: bool = await _silent_refresh()
	if ok:
		Log.info("Network", "Auto-login success")
		auto_login_success.emit()
	else:
		Log.warn("Network", "Auto-login failed")

func _silent_refresh() -> bool:
	var http := HTTPRequest.new()
	add_child(http)
	http.request(BASE_URL + "/api/auth/refresh", ["Content-Type: application/json"], HTTPClient.METHOD_POST,
		JSON.stringify({"refresh_token": refresh_token}))
	var result: Array = await http.request_completed
	http.queue_free()
	var response_code: int = result[1]
	if response_code != 200:
		Log.warn("Network", "Silent refresh failed", {"status": response_code})
		return false
	var json: Variant = JSON.parse_string(result[3].get_string_from_utf8())
	if json and json is Dictionary and json.code == 0:
		access_token = json.data.access_token
		refresh_token = json.data.refresh_token
		_save_tokens()
		return true
	Log.warn("Network", "Silent refresh response invalid")
	return false

func _load_tokens() -> void:
	var f := FileAccess.open("user://tokens.dat", FileAccess.READ)
	if f:
		var data: Variant = JSON.parse_string(f.get_as_text())
		if data and data is Dictionary:
			access_token = data.get("access", "")
			refresh_token = data.get("refresh", "")
		f.close()
		Log.info("Network", "Tokens loaded from disk")

func _save_tokens() -> void:
	var f := FileAccess.open("user://tokens.dat", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"access": access_token, "refresh": refresh_token}))
		f.close()

func save_tokens(p_access: String, p_refresh: String) -> void:
	access_token = p_access
	refresh_token = p_refresh
	_save_tokens()
	Log.info("Network", "Tokens saved")

func clear_tokens() -> void:
	access_token = ""
	refresh_token = ""
	_save_tokens()
	Log.info("Network", "Tokens cleared")

# ── HTTP Request ──────────────────────────────────────

func request(method: String, path: String, body: Dictionary = {}) -> Dictionary:
	var http_method: HTTPClient.Method
	match method:
		"GET": http_method = HTTPClient.METHOD_GET
		"POST": http_method = HTTPClient.METHOD_POST
		"PUT": http_method = HTTPClient.METHOD_PUT
		"DELETE": http_method = HTTPClient.METHOD_DELETE
		_: http_method = HTTPClient.METHOD_GET

	var headers: PackedStringArray = ["Content-Type: application/json"]
	if access_token != "":
		headers.append("Authorization: Bearer " + access_token)

	Log.debug("Network", ">> Request", {"method": method, "path": path, "has_body": not body.is_empty()})

	var http := HTTPRequest.new()
	add_child(http)
	var err: int = http.request(BASE_URL + path, headers, http_method, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		Log.error("Network", "Request creation failed", {"error": err, "method": method, "path": path})
		return {"code": -1, "msg": "request failed"}

	var result: Array = await http.request_completed
	http.queue_free()

	var response_code: int = result[1]
	var response_body: String = result[3].get_string_from_utf8()

	Log.debug("Network", "<< Response", {"method": method, "path": path, "status": response_code})

	if response_code == 401 and path != "/api/auth/refresh":
		Log.info("Network", "Token expired, refreshing...", {"path": path})
		await _refresh_token()
		return await request(method, path, body)

	var json: Variant = JSON.parse_string(response_body)
	if json and json is Dictionary:
		return json
	Log.error("Network", "JSON parse error", {"path": path, "status": response_code})
	return {"code": -1, "msg": "parse error"}

func _refresh_token() -> void:
	var http := HTTPRequest.new()
	add_child(http)
	http.request(BASE_URL + "/api/auth/refresh", ["Content-Type: application/json"], HTTPClient.METHOD_POST,
		JSON.stringify({"refresh_token": refresh_token}))
	var result: Array = await http.request_completed
	http.queue_free()
	var json: Variant = JSON.parse_string(result[3].get_string_from_utf8())
	if json and json is Dictionary and json.code == 0:
		access_token = json.data.access_token
		refresh_token = json.data.refresh_token
		_save_tokens()
		Log.info("Network", "Token refreshed")
	else:
		Log.warn("Network", "Token refresh failed")
		token_expired.emit()

# ── WebSocket ─────────────────────────────────────────

func connect_ws() -> void:
	if _ws != null:
		disconnect_ws()
	_ws = WebSocketPeer.new()
	var url: String = WS_URL + "?token=" + access_token
	_ws.connect_to_url(url)
	Log.info("Network", "Connecting WebSocket", {"url": WS_URL})

func disconnect_ws() -> void:
	if _ws == null:
		return
	if _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.close()
	_ws_connected = false
	_ws = null
	Log.info("Network", "WebSocket disconnected")

func send_ws_message(type: String, payload: Dictionary) -> void:
	if _ws == null or _ws.get_ready_state() != WebSocketPeer.STATE_OPEN:
		Log.warn("Network", "Cannot send WS message, not connected", {"type": type})
		return
	var msg: String = JSON.stringify({"type": type, "payload": payload})
	_ws.send_text(msg)
	Log.debug("Network", "WS >> Message sent", {"type": type})

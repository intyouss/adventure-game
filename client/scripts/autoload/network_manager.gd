extends Node

const BASE_URL = "http://localhost:8080"
const WS_URL = "ws://localhost:8080/ws/battle"

var access_token: String = ""
var refresh_token: String = ""
var _ws: WebSocketPeer
var _ws_connected: bool = false

signal token_expired
signal ws_message_received(type: String, payload: Dictionary)
signal ws_connected
signal ws_disconnected
signal auto_login_success

func _ready():
	_load_tokens()
	_try_auto_login()

func _process(_delta):
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_ws.poll()
		while _ws.get_available_packet_count() > 0:
			var packet = _ws.get_packet()
			var text = packet.get_string_from_utf8()
			var json = JSON.parse_string(text)
			if json:
				ws_message_received.emit(json.get("type", ""), json.get("payload", {}))

func _try_auto_login():
	if refresh_token:
		var ok = await _silent_refresh()
		if ok:
			auto_login_success.emit()

func _silent_refresh() -> bool:
	var http = HTTPRequest.new()
	add_child(http)
	http.request(BASE_URL + "/api/auth/refresh", ["Content-Type: application/json"], HTTPClient.METHOD_POST,
		JSON.stringify({"refresh_token": refresh_token}))
	var result = await http.request_completed
	http.queue_free()

	var json = JSON.parse_string(result[3].get_string_from_utf8())
	if json and json.code == 0:
		access_token = json.data.access_token
		refresh_token = json.data.refresh_token
		_save_tokens()
		return true
	return false

func _load_tokens():
	var f = FileAccess.open("user://tokens.json", FileAccess.READ)
	if f:
		var data = JSON.parse_string(f.get_as_text())
		if data:
			access_token = data.get("access_token", "")
			refresh_token = data.get("refresh_token", "")
		f.close()

func _save_tokens():
	var f = FileAccess.open("user://tokens.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"access_token": access_token, "refresh_token": refresh_token}))
		f.close()

func request(method: String, path: String, body: Dictionary = {}) -> Dictionary:
	var http = HTTPRequest.new()
	add_child(http)

	var headers = [
		"Content-Type: application/json"
	]
	if access_token:
		headers.append("Authorization: Bearer " + access_token)

	var err = http.request(BASE_URL + path, headers, method, JSON.stringify(body))
	if err != OK:
		http.queue_free()
		return {"code": -1, "msg": "request failed"}

	var result = await http.request_completed
	http.queue_free()

	var response_code = result[1]
	var response_body = result[3].get_string_from_utf8()

	if response_code == 401 and path != "/api/auth/refresh":
		await _refresh_token()
		return await request(method, path, body)

	var json = JSON.parse_string(response_body)
	if json:
		return json
	return {"code": -1, "msg": "parse error"}

func _refresh_token():
	var http = HTTPRequest.new()
	add_child(http)
	http.request(BASE_URL + "/api/auth/refresh", ["Content-Type: application/json"], HTTPClient.METHOD_POST,
		JSON.stringify({"refresh_token": refresh_token}))
	var result = await http.request_completed
	http.queue_free()

	var json = JSON.parse_string(result[3].get_string_from_utf8())
	if json and json.code == 0:
		access_token = json.data.access_token
		refresh_token = json.data.refresh_token
		_save_tokens()
	else:
		token_expired.emit()

func connect_ws():
	_ws = WebSocketPeer.new()
	_ws.connect_to_url(WS_URL + "?token=" + access_token)

func send_ws_message(type: String, payload: Dictionary):
	if _ws and _ws.get_ready_state() == WebSocketPeer.STATE_OPEN:
		var msg = JSON.stringify({"type": type, "payload": payload})
		_ws.send_text(msg)

func clear_tokens():
	access_token = ""
	refresh_token = ""
	_save_tokens()

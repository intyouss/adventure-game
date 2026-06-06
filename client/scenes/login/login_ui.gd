extends Control

@onready var phone_input = $VBox/PhoneInput
@onready var code_input = $VBox/CodeInput
@onready var password_input = $VBox/PasswordInput
@onready var send_code_btn = $VBox/SendCodeBtn
@onready var login_btn = $VBox/LoginBtn
@onready var register_btn = $VBox/RegisterBtn
@onready var status_label = $StatusLabel

var _mode: String = "login"  # login or register
var _code_sent: bool = false

func _ready():
	send_code_btn.pressed.connect(_on_send_code)
	login_btn.pressed.connect(_on_login)
	register_btn.pressed.connect(_on_toggle_mode)

func _on_send_code():
	var phone = phone_input.text.strip_edges()
	if phone.length() < 11:
		status_label.text = "请输入有效手机号"
		return
	var res = await NetworkManager.request("POST", "/api/auth/send_code", {"target": phone, "type": "phone"})
	if res.code == 0:
		_code_sent = true
		status_label.text = "验证码已发送"
	else:
		status_label.text = res.msg

func _on_login():
	var phone = phone_input.text.strip_edges()
	var password = password_input.text
	if _mode == "register":
		var code = code_input.text
		var res = await NetworkManager.request("POST", "/api/auth/register", {"target": phone, "type": "phone", "code": code, "password": password})
		if res.code == 0:
			NetworkManager.access_token = res.data.access_token
			NetworkManager.refresh_token = res.data.refresh_token
			NetworkManager._save_tokens()
			EventBus.login_success.emit()
		else:
			status_label.text = res.msg
	else:
		var res = await NetworkManager.request("POST", "/api/auth/login", {"target": phone, "password": password})
		if res.code == 0:
			NetworkManager.access_token = res.data.access_token
			NetworkManager.refresh_token = res.data.refresh_token
			NetworkManager._save_tokens()
			EventBus.login_success.emit()
		else:
			status_label.text = res.msg

func _on_toggle_mode():
	_mode = "register" if _mode == "login" else "login"
	code_input.visible = _mode == "register"
	send_code_btn.visible = _mode == "register"
	register_btn.text = "切换到登录" if _mode == "register" else "切换到注册"
	login_btn.text = "注册" if _mode == "register" else "登录"

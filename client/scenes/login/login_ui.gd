extends Control

@onready var phone_input = $VBox/PhoneInput
@onready var email_input = $VBox/EmailInput
@onready var nickname_input = $VBox/NicknameInput
@onready var code_input = $VBox/CodeInput
@onready var password_input = $VBox/PasswordInput
@onready var send_code_btn = $VBox/SendCodeBtn
@onready var login_btn = $VBox/LoginBtn
@onready var register_btn = $VBox/RegisterBtn
@onready var status_label = $StatusLabel
@onready var tab_phone = $VBox/TabPhone
@onready var tab_email = $VBox/TabEmail

var _mode: String = "login"  # login or register
var _contact_type: String = "phone"  # phone or email
var _code_cooldown: float = 0.0
const CODE_COOLDOWN_SEC = 60.0

func _ready():
	tab_phone.pressed.connect(func(): _switch_contact("phone"))
	tab_email.pressed.connect(func(): _switch_contact("email"))
	send_code_btn.pressed.connect(_on_send_code)
	login_btn.pressed.connect(_on_login)
	register_btn.pressed.connect(_on_toggle_mode)
	_switch_contact("phone")

func _switch_contact(type: String):
	_contact_type = type
	phone_input.visible = type == "phone"
	email_input.visible = type == "email"
	tab_phone.modulate = Color.WHITE if type == "phone" else Color.GRAY
	tab_email.modulate = Color.WHITE if type == "email" else Color.GRAY

func _on_send_code():
	if _code_cooldown > 0:
		status_label.text = "请等待 %.0f 秒后再发送" % _code_cooldown
		return
	var target: String
	var body: Dictionary
	if _contact_type == "phone":
		target = phone_input.text.strip_edges()
		if target.length() < 11:
			status_label.text = "请输入有效手机号"
			return
		body = {"phone": target}
	else:
		target = email_input.text.strip_edges()
		if not "@" in target or target.length() < 5:
			status_label.text = "请输入有效邮箱"
			return
		body = {"email": target}
	var res = await NetworkManager.request("POST", "/api/auth/send_code", body)
	if res.code == 0:
		_code_cooldown = CODE_COOLDOWN_SEC
		status_label.text = "验证码已发送"
	else:
		status_label.text = res.msg

func _on_login():
	var contact = phone_input.text.strip_edges() if _contact_type == "phone" else email_input.text.strip_edges()
	var password = password_input.text
	if _mode == "register":
		var code = code_input.text
		var nickname = nickname_input.text.strip_edges()
		if nickname == "":
			nickname = "冒险者"
		var body = {"code": code, "password": password, "nickname": nickname}
		if _contact_type == "phone":
			body["phone"] = contact
		else:
			body["email"] = contact
		var res = await NetworkManager.request("POST", "/api/auth/register", body)
		if res.code == 0:
			NetworkManager.access_token = res.data.access_token
			NetworkManager.refresh_token = res.data.refresh_token
			NetworkManager._save_tokens()
			EventBus.login_success.emit()
		else:
			status_label.text = res.msg
	else:
		var res = await NetworkManager.request("POST", "/api/auth/login", {"account": contact, "password": password})
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
	nickname_input.visible = _mode == "register"
	send_code_btn.visible = _mode == "register"
	register_btn.text = "切换到登录" if _mode == "register" else "切换到注册"
	login_btn.text = "注册" if _mode == "register" else "登录"

func _process(delta: float):
	if _code_cooldown > 0:
		_code_cooldown -= delta
		if _code_cooldown <= 0:
			_code_cooldown = 0
			send_code_btn.text = "发送验证码"
			send_code_btn.disabled = false
		else:
			send_code_btn.text = "%.0f秒后重发" % _code_cooldown
			send_code_btn.disabled = true

# LoginUI - Login & registration screen
class_name LoginUI
extends Control

@onready var phone_input: LineEdit = $VBox/PhoneInput
@onready var email_input: LineEdit = $VBox/EmailInput
@onready var account_input: LineEdit = $VBox/AccountInput
@onready var nickname_input: LineEdit = $VBox/NicknameInput
@onready var code_input: LineEdit = $VBox/CodeRow/CodeInput
@onready var password_input: LineEdit = $VBox/PasswordInput
@onready var send_code_btn: Button = $VBox/CodeRow/SendCodeBtn
@onready var login_btn: Button = $VBox/LoginBtn
@onready var register_btn: Button = $VBox/RegisterBtn
@onready var status_label: Label = $StatusLabel
@onready var tab_phone: Button = $VBox/TabHBox/TabPhone
@onready var tab_email: Button = $VBox/TabHBox/TabEmail
@onready var tab_account: Button = $VBox/TabHBox/TabAccount

var _mode: String = "login"  # "login" or "register"
var _contact_type: String = "phone"  # "phone", "email", or "account"
var _code_cooldown: float = 0.0
const CODE_COOLDOWN_SEC: float = 60.0

func _ready() -> void:
	tab_phone.pressed.connect(func() -> void: _switch_contact("phone"))
	tab_email.pressed.connect(func() -> void: _switch_contact("email"))
	tab_account.pressed.connect(func() -> void: _switch_contact("account"))
	send_code_btn.pressed.connect(_on_send_code)
	login_btn.pressed.connect(_on_login)
	register_btn.pressed.connect(_on_toggle_mode)
	_switch_contact("phone")
	NetworkManager.auto_login_success.connect(_on_auto_login)
	Log.info("LoginUI", "Login screen ready")

func _switch_contact(type: String) -> void:
	_contact_type = type
	var is_code_mode: bool = type == "phone" or type == "email"
	var is_account_mode: bool = type == "account"
	phone_input.visible = type == "phone"
	email_input.visible = type == "email"
	account_input.visible = is_account_mode
	code_input.visible = is_code_mode
	send_code_btn.visible = is_code_mode
	password_input.visible = is_account_mode
	tab_phone.modulate = Color.WHITE if type == "phone" else Color.GRAY
	tab_email.modulate = Color.WHITE if type == "email" else Color.GRAY
	tab_account.modulate = Color.WHITE if is_account_mode else Color.GRAY
	# Show/hide the CodeRow container
	var code_row: Node = get_node_or_null("VBox/CodeRow")
	if code_row:
		code_row.visible = is_code_mode
	Log.debug("LoginUI", "Contact type switched", {"type": type})

func _on_send_code() -> void:
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
	Log.info("LoginUI", "Sending verification code", {"type": _contact_type, "target": target})
	var res: Dictionary = await NetworkManager.request("POST", "/api/auth/send_code", body)
	if res.code == 0:
		_code_cooldown = CODE_COOLDOWN_SEC
		status_label.text = "验证码已发送，测试阶段固定验证码 000000"
		Log.info("LoginUI", "Verification code sent", {"target": target})
	else:
		status_label.text = res.msg
		Log.warn("LoginUI", "Send code failed", {"msg": res.msg})

func _on_login() -> void:
	var contact: String
	if _contact_type == "phone":
		contact = phone_input.text.strip_edges()
	elif _contact_type == "email":
		contact = email_input.text.strip_edges()
	else:
		contact = account_input.text.strip_edges()

	var password: String = password_input.text
	if _mode == "register":
		var code: String = code_input.text
		var nickname: String = nickname_input.text.strip_edges()
		if nickname == "":
			nickname = "冒险者"
		var body: Dictionary = {"code": code, "password": password, "nickname": nickname}
		if _contact_type == "phone":
			body["phone"] = contact
		else:
			body["email"] = contact
		Log.info("LoginUI", "Registering", {"type": _contact_type, "nickname": nickname})
		var res: Dictionary = await NetworkManager.request("POST", "/api/auth/register", body)
		if res.code == 0:
			NetworkManager.save_tokens(res.data.access_token, res.data.refresh_token)
			status_label.text = "注册成功！欢迎来到冒险大作战！"
			Log.info("LoginUI", "Register success", {"nickname": nickname})
			await _transition_to_game()
		else:
			status_label.text = res.msg
			Log.warn("LoginUI", "Register failed", {"msg": res.msg})
	else:
		var code: String = code_input.text.strip_edges()
		var login_body: Dictionary = {"account": contact}
		if _contact_type == "account":
			login_body["password"] = password
		else:
			login_body["code"] = code
		Log.info("LoginUI", "Logging in", {"type": _contact_type})
		var res: Dictionary = await NetworkManager.request("POST", "/api/auth/login", login_body)
		if res.code == 0:
			NetworkManager.save_tokens(res.data.access_token, res.data.refresh_token)
			status_label.text = "登录成功，正在进入游戏..."
			Log.info("LoginUI", "Login success")
			await _transition_to_game()
		else:
			status_label.text = res.msg
			Log.warn("LoginUI", "Login failed", {"msg": res.msg})

func _on_toggle_mode() -> void:
	_mode = "register" if _mode == "login" else "login"
	nickname_input.visible = _mode == "register"
	# In register mode, always show code row; in login mode, depends on contact type
	if _mode == "register":
		send_code_btn.visible = true
		var code_row: Node = get_node_or_null("VBox/CodeRow")
		if code_row:
			code_row.visible = true
	tab_account.visible = _mode == "login"
	if _mode == "register" and _contact_type == "account":
		_switch_contact("phone")
	register_btn.text = "切换到登录" if _mode == "register" else "切换到注册"
	login_btn.text = "注册" if _mode == "register" else "登录"
	Log.debug("LoginUI", "Mode toggled", {"mode": _mode})

func _on_auto_login() -> void:
	status_label.text = "自动登录成功，进入游戏..."
	Log.info("LoginUI", "Auto-login success")
	await _transition_to_game()

func _transition_to_game() -> void:
	await get_tree().create_timer(0.8).timeout
	EventBus.login_success.emit()
	get_tree().change_scene_to_file("res://scenes/main/main_scene.tscn")

func _process(delta: float) -> void:
	if _code_cooldown > 0:
		_code_cooldown -= delta
		if _code_cooldown <= 0:
			_code_cooldown = 0
			send_code_btn.text = "发送验证码"
			send_code_btn.disabled = false
		else:
			send_code_btn.text = "%.0f秒后重发" % _code_cooldown
			send_code_btn.disabled = true

extends Control

@onready var phone_input = $VBox/PhoneInput
@onready var email_input = $VBox/EmailInput
@onready var account_input = $VBox/AccountInput
@onready var nickname_input = $VBox/NicknameInput
@onready var code_input = $VBox/CodeInput
@onready var password_input = $VBox/PasswordInput
@onready var send_code_btn = $VBox/SendCodeBtn
@onready var login_btn = $VBox/LoginBtn
@onready var register_btn = $VBox/RegisterBtn
@onready var status_label = $StatusLabel
@onready var tab_phone = $VBox/TabPhone
@onready var tab_email = $VBox/TabEmail
@onready var tab_account = $VBox/TabAccount

var _mode: String = "login"  # login or register
var _contact_type: String = "phone"  # phone, email, or account
var _code_cooldown: float = 0.0
const CODE_COOLDOWN_SEC = 60.0

func _ready():
	tab_phone.pressed.connect(func(): _switch_contact("phone"))
	tab_email.pressed.connect(func(): _switch_contact("email"))
	tab_account.pressed.connect(func(): _switch_contact("account"))
	send_code_btn.pressed.connect(_on_send_code)
	login_btn.pressed.connect(_on_login)
	register_btn.pressed.connect(_on_toggle_mode)
	_switch_contact("phone")
	# 监听自动登录成功（refresh token 有效时跳过登录页）
	NetworkManager.auto_login_success.connect(_on_auto_login)

func _switch_contact(type: String):
	print("[UI] switch_contact type=", type)
	_contact_type = type
	var is_code_mode = type == "phone" or type == "email"
	var is_account_mode = type == "account"
	phone_input.visible = type == "phone"
	email_input.visible = type == "email"
	account_input.visible = is_account_mode
	code_input.visible = is_code_mode
	send_code_btn.visible = is_code_mode
	password_input.visible = is_account_mode
	tab_phone.modulate = Color.WHITE if type == "phone" else Color.GRAY
	tab_email.modulate = Color.WHITE if type == "email" else Color.GRAY
	tab_account.modulate = Color.WHITE if is_account_mode else Color.GRAY

func _on_send_code():
	print("[UI] send_code type=", _contact_type)
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
		status_label.text = "验证码已发送，测试阶段固定验证码: 000000"
	else:
		status_label.text = res.msg

func _on_login():
	print("[UI] login mode=", _mode, " type=", _contact_type)
	var contact: String
	if _contact_type == "phone":
		contact = phone_input.text.strip_edges()
	elif _contact_type == "email":
		contact = email_input.text.strip_edges()
	else:
		contact = account_input.text.strip_edges()
	
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
			status_label.text = "注册成功！欢迎来到冒险大作战！"
			await _transition_to_game()
		else:
			status_label.text = res.msg
	else:
		var code = code_input.text.strip_edges()
		var login_body = {"account": contact}
		if _contact_type == "account":
			# Branch 3: Account + Password login — no code field
			login_body["password"] = password
		else:
			# Branch 1 & 2: Phone/Email + Code login — no password field
			login_body["code"] = code
		var res = await NetworkManager.request("POST", "/api/auth/login", login_body)
		if res.code == 0:
			NetworkManager.access_token = res.data.access_token
			NetworkManager.refresh_token = res.data.refresh_token
			NetworkManager._save_tokens()
			status_label.text = "登录成功，正在进入游戏..."
			await _transition_to_game()
		else:
			status_label.text = res.msg

func _on_toggle_mode():
	print("[UI] toggle_mode new=", "register" if _mode == "login" else "login")
	_mode = "register" if _mode == "login" else "login"
	code_input.visible = true
	nickname_input.visible = _mode == "register"
	send_code_btn.visible = _mode == "register"
	# In register mode, hide account tab (register always uses phone/email + code)
	tab_account.visible = _mode == "login"
	if _mode == "register" and _contact_type == "account":
		_switch_contact("phone")
	register_btn.text = "切换到登录" if _mode == "register" else "切换到注册"
	login_btn.text = "注册" if _mode == "register" else "登录"

func _on_auto_login():
	print("[UI] auto_login")
	status_label.text = "自动登录成功，进入游戏..."
	await _transition_to_game()

func _transition_to_game():
	# 短暂延迟让用户看到成功提示
	await get_tree().create_timer(0.8).timeout
	EventBus.login_success.emit()
	get_tree().change_scene_to_file("res://scenes/main/main_scene.tscn")



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

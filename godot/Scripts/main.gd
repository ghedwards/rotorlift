extends Control

const Model = preload("res://Scripts/flight_model.gd")
const View = preload("res://Scripts/flight_view.gd")
const Hud = preload("res://Scripts/flight_hud.gd")
const MONO = preload("res://Assets/Fonts/IBMPlexMono-Regular.ttf")
const DISPLAY = preload("res://Assets/Fonts/BarlowCondensed-SemiBold.ttf")
const SANS = preload("res://Assets/Fonts/DMSans.ttf")
const ORANGE := Color("f28a50")
var missions: Array = []
var mission_index := 0
var flight: FlightModel
var view: FlightView
var hud: FlightHud
var overlay_kicker: Label
var result_summary: Label
var manual_open := false
var manual_was_playing := false
var overlay_tween: Tween
var winch_button: Button
var pause_button: Button
var radio_message: Label
var radio_bubble: Control
var assist_checks: Array[CheckButton] = []
var settings_panel: PopupPanel
var settings_was_playing := false
var assist_flags := [false,true,false]
var mission_picker: OptionButton
var overlay: PanelContainer
var overlay_title: Label
var overlay_copy: Label
var resume_button: Button
var next_button: Button
var muted := true
var sound_button: Button
var completed: Array = []
var held := {"left": false, "right": false, "up": false, "down": false}
var touch_actions: Dictionary = {}
var control_buttons: Dictionary = {}
var audio: AudioStreamPlayer
var last_status := FlightModel.Status.READY

func _ready() -> void:
	missions = JSON.parse_string(FileAccess.get_file_as_string("res://Assets/missions.json"))
	var progress := ConfigFile.new()
	if progress.load("user://progress.cfg") == OK:
		completed = progress.get_value("missions", "completed", [])
	var settings := ConfigFile.new()
	if settings.load("user://assists.cfg")==OK:
		for i in 3:
			assist_flags[i]=bool(settings.get_value("assists",str(i),assist_flags[i]))
	get_tree().quit_on_go_back = false
	_update_display_scale()
	get_window().size_changed.connect(_update_display_scale)
	_setup_actions()
	_setup_theme()
	_build_ui()
	_select_mission(0)
	get_window().focus_exited.connect(_lose_focus)

func _update_display_scale() -> void:
	var dimensions := get_window().size
	if dimensions.x <= 0 or dimensions.y <= 0:
		return
	# A landscape phone needs usable touch targets, not a letterboxed desktop UI.
	var phone_layout := OS.has_feature("mobile") or dimensions.y < 600
	var logical_width := 1200 if phone_layout and dimensions.x > dimensions.y else 1440
	var logical_size := Vector2i(logical_width,roundi(float(logical_width)*dimensions.y/dimensions.x))
	if get_window().content_scale_size != logical_size:
		get_window().content_scale_size = logical_size

func _setup_actions() -> void:
	var keys := {"left": [KEY_A, KEY_LEFT], "right": [KEY_D, KEY_RIGHT], "up": [KEY_W, KEY_UP], "down": [KEY_S, KEY_DOWN], "winch": [KEY_SPACE, KEY_E], "pause": [KEY_P, KEY_ESCAPE], "restart": [KEY_R], "fullscreen": [KEY_F11]}
	for action: String in keys:
		var name := "flight_" + action
		InputMap.add_action(name)
		for key: int in keys[action]:
			var event := InputEventKey.new()
			event.physical_keycode = key
			InputMap.action_add_event(name, event)

func _style(background: Color, border: Color, padding := 14.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(3)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func _setup_theme() -> void:
	var theme_resource := Theme.new()
	theme_resource.default_font = SANS
	theme_resource.default_font_size = 14
	theme_resource.set_color("font_color", "Label", Color("eceee5"))
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var background := Color("303829") if state == "hover" else Color("3b4431") if state == "pressed" else Color("242b20")
		var border := ORANGE if state == "focus" else Color("7a8561") if state == "hover" else Color("4a543d")
		for type_name in ["Button", "OptionButton"]:
			theme_resource.set_stylebox(state, type_name, _style(background, border))
			theme_resource.set_color("font_color", type_name, Color("e9e8d1"))
			theme_resource.set_color("font_hover_color", type_name, Color("fff3dc"))
			theme_resource.set_color("font_pressed_color", type_name, Color("f6bd84"))
			theme_resource.set_color("icon_normal_color", type_name, Color("d9ddc0"))
	var popup := _style(Color("1b231c"), Color("46513b"), 10)
	theme_resource.set_stylebox("panel", "PopupMenu", popup)
	theme_resource.set_font("font", "PopupMenu", SANS)
	theme_resource.set_font_size("font_size", "PopupMenu", 14)
	theme = theme_resource

func _icon(name: String) -> Texture2D:
	return load("res://Assets/Icons/%s.svg" % name)

func _flat(button: Button) -> Button:
	for state in ["normal", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, _style(Color(0,0,0,0), Color(0,0,0,0), 12))
	button.add_theme_stylebox_override("hover", _style(Color(0.86,0.91,0.73,0.05),Color(0,0,0,0),12))
	button.add_theme_stylebox_override("pressed", _style(Color(0.86,0.91,0.73,0.09),Color(0,0,0,0),12))
	button.add_theme_color_override("font_color",Color("9da58e"))
	return button

func _primary(button: Button) -> Button:
	for state in ["normal", "hover", "pressed", "focus"]:
		var background := ORANGE.lightened(0.08) if state == "hover" else ORANGE.darkened(0.12) if state == "pressed" else ORANGE
		button.add_theme_stylebox_override(state,_style(background,Color("d47842")))
		button.add_theme_color_override("font_" + (state + "_" if state != "normal" else "") + "color",Color("22291f"))
	button.add_theme_color_override("icon_normal_color",Color("263022"))
	button.add_theme_color_override("icon_hover_color",Color("263022"))
	return button

func _mono_label(text: String, font_size := 9) -> Label:
	var label := _label(text,maxi(12,font_size))
	label.add_theme_font_override("font",MONO)
	label.add_theme_color_override("font_color",Color("bdc6ad"))
	return label

func _margin(left: int, top: int, right: int, bottom: int) -> MarginContainer:
	var margin := MarginContainer.new()
	for pair in [["left",left],["top",top],["right",right],["bottom",bottom]]:
		margin.add_theme_constant_override("margin_"+pair[0],pair[1])
	return margin

func _label(text: String, font_size := 17) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	return label

func _button(text: String, callback: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.focus_mode = Control.FOCUS_NONE
	button.pressed.connect(callback)
	return button

func _build_ui() -> void:
	var layout := VBoxContainer.new()
	layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layout.add_theme_constant_override("separation", 0)
	add_child(layout)
	var scene := Control.new()
	scene.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scene.custom_minimum_size.y = 240
	layout.add_child(scene)
	view = View.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.add_child(view)
	hud = Hud.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.add_child(hud)
	_build_overlay(scene)
	_build_flight_deck(layout)
	_build_settings()
	audio = AudioStreamPlayer.new()
	add_child(audio)

func _build_overlay(scene: Control) -> void:
	overlay = PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_theme_stylebox_override("panel",_style(Color(0.04,0.08,0.07,0.88),Color(0,0,0,0),0))
	scene.add_child(overlay)
	var frame := VBoxContainer.new()
	overlay.add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.add_child(scroll)
	var center := CenterContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(center)
	var dialog := VBoxContainer.new()
	dialog.add_theme_constant_override("separation",16)
	dialog.custom_minimum_size.x = 480
	center.add_child(dialog)
	overlay_kicker = _mono_label("TAKE A BREATHER, PILOT.",10)
	overlay_kicker.add_theme_color_override("font_color",ORANGE)
	overlay_kicker.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog.add_child(overlay_kicker)
	overlay_title = _label("",56)
	overlay_title.add_theme_font_override("font",DISPLAY)
	overlay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog.add_child(overlay_title)
	overlay_copy = _label("",14)
	overlay_copy.add_theme_color_override("font_color",Color("b7c0ab"))
	overlay_copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	overlay_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_copy.custom_minimum_size.x = 480
	dialog.add_child(overlay_copy)
	result_summary = _mono_label("",11)
	result_summary.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dialog.add_child(result_summary)
	resume_button = _primary(_button("Resume flight   [P]",_pause))
	resume_button.icon = _icon("play")
	resume_button.add_theme_constant_override("icon_max_width",16)
	resume_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	resume_button.custom_minimum_size = Vector2(260,64)
	frame.add_child(resume_button)
	next_button = _primary(_button("Next operation",func(): _select_mission((mission_index+1)%missions.size())))
	next_button.icon = _icon("right")
	next_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	next_button.custom_minimum_size = Vector2(230,46)
	dialog.add_child(next_button)
	var restart := _flat(_button("Restart mission",func(): _select_mission(mission_index)))
	restart.icon = _icon("restart")
	restart.add_theme_constant_override("icon_max_width",15)
	restart.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dialog.add_child(restart)

func _build_flight_deck(layout: VBoxContainer) -> void:
	var panel := PanelContainer.new()
	var deck_style := _style(Color("1e251c"),Color("343d2c"),0)
	deck_style.set_corner_radius_all(0)
	deck_style.set_border_width_all(0)
	deck_style.border_width_top = 1
	panel.add_theme_stylebox_override("panel",deck_style)
	layout.add_child(panel)
	deck_style.content_margin_top = 0
	deck_style.content_margin_bottom = 0
	var margin := _margin(32,24,32,24)
	panel.add_child(margin)
	var controls := HBoxContainer.new()
	controls.add_theme_constant_override("separation",32)
	var deck := VBoxContainer.new()
	deck.add_theme_constant_override("separation",12)
	margin.add_child(deck)
	deck.add_child(controls)
	radio_bubble = Control.new()
	radio_bubble.custom_minimum_size.y = 52
	radio_bubble.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	radio_bubble.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bubble_panel := PanelContainer.new()
	bubble_panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bubble_style := _style(Color("192c28"),Color.TRANSPARENT,14)
	bubble_style.set_corner_radius_all(12)
	bubble_style.set_border_width_all(0)
	bubble_panel.add_theme_stylebox_override("panel",bubble_style)
	radio_bubble.add_child(bubble_panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	bubble_panel.add_child(scroll)
	radio_message = _label("",16)
	radio_message.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	radio_message.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	radio_message.add_theme_color_override("font_color",Color("eeedcf"))
	scroll.add_child(radio_message)
	var tail := TextureRect.new()
	tail.texture = load("res://Assets/Art/radio-bubble-tail.svg")
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	tail.position = Vector2(18,-1)
	tail.size = Vector2(18,12)
	radio_bubble.add_child(tail)
	# Steering and altitude sit at opposite thumb positions; utility controls stay central.
	var steering := HBoxContainer.new()
	steering.add_theme_constant_override("separation",24)
	controls.add_child(steering)
	for definition: Array in [["left","A","left"],["right","D","right"]]:
		steering.add_child(_flight_button(definition[0],definition[1],definition[2],Vector2(100,100)))
	var center := HBoxContainer.new()
	center.alignment = BoxContainer.ALIGNMENT_CENTER
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	center.add_theme_constant_override("separation",12)
	controls.add_child(center)
	controls.move_child(center,1)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.alignment = BoxContainer.ALIGNMENT_BEGIN
	var brand := VBoxContainer.new()
	brand.alignment = BoxContainer.ALIGNMENT_CENTER
	brand.add_theme_constant_override("separation",0)
	center.add_child(brand)
	var wordmark := _label("AIRLIFT.",52)
	wordmark.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	wordmark.add_theme_font_override("font",DISPLAY)
	brand.add_child(wordmark)
	var utilities := HBoxContainer.new()
	utilities.alignment = BoxContainer.ALIGNMENT_CENTER
	utilities.add_theme_constant_override("separation",4)
	brand.add_child(utilities)
	for definition: Array in [["info","Flight manual (pauses flight)"],["settings","Settings"],["expand","Fullscreen (F11)"],["pause","Start / pause / resume (P)"]]:
		var callback := _show_manual if definition[0]=="info" else _show_settings if definition[0]=="settings" else _pause if definition[0]=="pause" else _toggle_fullscreen
		var button := _button("",callback)
		button.icon = _icon(definition[0])
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.expand_icon = true
		for state in ["normal","hover","pressed","focus","disabled"]:
			button.add_theme_stylebox_override(state,_style(Color.TRANSPARENT,Color.TRANSPARENT,12))
		button.add_theme_color_override("icon_normal_color",Color("dce4cd"))
		button.add_theme_color_override("icon_hover_color",Color("ffffff"))
		button.add_theme_color_override("icon_pressed_color",ORANGE)
		button.add_theme_constant_override("icon_max_width",26)
		button.custom_minimum_size = Vector2(64,64)
		button.tooltip_text = definition[1]
		utilities.add_child(button)
		if definition[0]=="pause":
			pause_button = button
	center.add_child(radio_bubble)
	winch_button = _button("DEPLOY WINCH",func(): flight.toggle_winch())
	winch_button.icon = null
	winch_button.add_theme_constant_override("icon_max_width",24)
	winch_button.add_theme_font_size_override("font_size",18)
	winch_button.custom_minimum_size = Vector2(224,100)
	_touch_style(winch_button,true)
	for text_state in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:
		winch_button.add_theme_color_override(text_state,Color("e2e8cf"))
	var winch_hint := _label("SPACE",14)
	winch_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	winch_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	winch_hint.add_theme_color_override("font_color",Color("a8b69c"))
	winch_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	winch_hint.offset_left = 12
	winch_hint.offset_right = -8
	winch_hint.offset_top = -25
	winch_hint.offset_bottom = -5
	winch_button.add_child(winch_hint)
	winch_button.tooltip_text = "Rescue / interact (Space)"
	controls.add_child(winch_button)
	var altitude := HBoxContainer.new()
	altitude.add_theme_constant_override("separation",24)
	controls.add_child(altitude)
	for definition: Array in [["down","S","down"],["up","W","up"]]:
		var button := _flight_button(definition[0],definition[1],definition[2],Vector2(100,100))
		button.tooltip_text = "Hold to descend" if definition[0]=="down" else "Hold to climb"
		altitude.add_child(button)

func _build_settings() -> void:
	settings_panel = PopupPanel.new()
	settings_panel.add_theme_stylebox_override("panel",_style(Color("1b231c"),Color("56664b"),24))
	add_child(settings_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",8)
	settings_panel.add_child(content)
	content.add_child(_label("Flight settings",24))
	mission_picker = OptionButton.new()
	mission_picker.custom_minimum_size = Vector2(400,48)
	for operation: Dictionary in missions:
		mission_picker.add_item("%s / %s" % [operation.id,operation.name])
	mission_picker.item_selected.connect(func(index: int):
		settings_was_playing = false
		_select_mission(index))
	content.add_child(mission_picker)
	sound_button = _button("Sound: off",_toggle_sound)
	sound_button.custom_minimum_size.y = 48
	sound_button.icon = _icon("muted")
	content.add_child(sound_button)
	for i in 3:
		var check := CheckButton.new()
		check.text = ["Altitude hold","Ground tether","Auto-hoist"][i]
		check.custom_minimum_size.y = 48
		check.button_pressed = assist_flags[i]
		check.pressed.connect(_toggle_assist.bind(i))
		assist_checks.append(check)
		content.add_child(check)
	var restart := _button("Restart mission",func():
		settings_was_playing = false
		_select_mission(mission_index)
		settings_panel.hide())
	restart.custom_minimum_size.y = 48
	content.add_child(restart)
	var close := _primary(_button("Done",func(): settings_panel.hide()))
	close.custom_minimum_size.y = 48
	content.add_child(close)
	settings_panel.popup_hide.connect(func():
		_clear_controls()
		if settings_was_playing and flight.status == FlightModel.Status.PAUSED:
			flight.toggle_pause()
		_refresh())

func _show_settings() -> void:
	settings_was_playing = flight.status == FlightModel.Status.PLAYING
	if settings_was_playing:
		flight.toggle_pause()
	_clear_controls()
	settings_panel.popup_centered()
	_refresh()

func _touch_style(button: Button, accent := false) -> void:
	button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = true
	button.add_theme_constant_override("h_separation",12)
	button.add_theme_constant_override("icon_max_width",28)
	for state in ["normal","hover","pressed","disabled","focus"]:
		var background := Color("35473b") if accent else Color("29372e")
		if state == "pressed":
			background = Color("54664b")
		elif state == "hover":
			background = background.lightened(0.08)
		var style := _style(background,Color("8caa76") if accent else Color("52634d"),12)
		style.content_margin_top = 12
		style.content_margin_bottom = 12
		style.set_corner_radius_all(10)
		button.add_theme_stylebox_override(state,style)
	button.add_theme_color_override("font_color",Color("f0f0df"))
	button.add_theme_color_override("icon_normal_color",Color("e2e8cf"))

func _flight_button(action: String, text: String, icon_name: String, minimum: Vector2) -> Button:
	var button := Button.new()
	button.text = ""
	button.tooltip_text = text
	var key_hint := _label(text,14)
	key_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	key_hint.add_theme_color_override("font_color",Color("a8b69c"))
	key_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	key_hint.position = Vector2(-24,-25)
	key_hint.size = Vector2(16,20)
	button.add_child(key_hint)
	button.icon = _icon(icon_name)
	button.add_theme_constant_override("icon_max_width",28)
	button.add_theme_font_override("font",MONO)
	button.add_theme_font_size_override("font_size",18)
	button.focus_mode = Control.FOCUS_NONE
	button.custom_minimum_size = minimum
	button.button_down.connect(func(): held[action] = true)
	button.button_up.connect(func(): held[action] = false)
	_touch_style(button)
	control_buttons[action] = button
	return button

func _toggle_assist(index: int) -> void:
	assist_flags[index]=not assist_flags[index]
	assist_checks[index].set_pressed_no_signal(assist_flags[index])
	if flight!=null:
		flight.set_assists(assist_flags[0],assist_flags[1],assist_flags[2])
	var settings := ConfigFile.new()
	for i in 3:
		settings.set_value("assists",str(i),assist_flags[i])
	settings.save("user://assists.cfg")

func _select_mission(index: int) -> void:
	mission_index = index
	manual_open = false
	mission_picker.select(index)
	flight = Model.new(missions[index])
	flight.set_assists(assist_flags[0],assist_flags[1],assist_flags[2])
	flight.cue.connect(_play_cue)
	view.flight = flight
	hud.flight = flight
	view.camera_x = 0
	view.backdrop = load("res://Assets/" + String(missions[index].image).get_file())
	last_status = FlightModel.Status.READY
	_clear_controls()
	_refresh()

func _process(dt: float) -> void:
	if flight == null:
		return
	var steer := float(_control("right")) - float(_control("left"))
	if not manual_open and not settings_panel.visible:
		flight.step(minf(dt, 0.04), steer, _control("up"), _control("down"))
	if flight.status == FlightModel.Status.COMPLETE and last_status != flight.status:
		var id: String = flight.mission.id
		if not completed.has(id):
			completed.append(id)
			var progress := ConfigFile.new()
			progress.set_value("missions", "completed", completed)
			var error := progress.save("user://progress.cfg")
			if error != OK:
				push_warning("Could not save mission progress: %s" % error_string(error))
	last_status = flight.status
	_refresh()

func _control(action: String) -> bool:
	return bool(held[action]) or Input.is_action_pressed("flight_" + action) or touch_actions.values().has(action)

func _input(event: InputEvent) -> void:
	if manual_open or settings_panel.visible:
		return
	# Track each finger independently so throttle and steering work together.
	if event is InputEventScreenTouch:
		if event.pressed:
			for action: String in control_buttons:
				if not control_buttons[action].disabled and control_buttons[action].get_global_rect().has_point(event.position):
					touch_actions[event.index] = action
		else:
			touch_actions.erase(event.index)
	elif event is InputEventScreenDrag:
		touch_actions.erase(event.index)
		for action: String in control_buttons:
			if not control_buttons[action].disabled and control_buttons[action].get_global_rect().has_point(event.position):
				touch_actions[event.index] = action

func _unhandled_key_input(event: InputEvent) -> void:
	if settings_panel.visible:
		return
	if manual_open:
		if event.is_action_pressed("flight_pause"):
			_pause()
		return
	if event.is_echo():
		return
	if event.is_action_pressed("flight_winch"):
		flight.toggle_winch()
	elif event.is_action_pressed("flight_pause"):
		_pause()
	elif event.is_action_pressed("flight_restart"):
		_select_mission(mission_index)
	elif event.is_action_pressed("flight_fullscreen"):
		_toggle_fullscreen()

func _clear_controls() -> void:
	for action: String in held:
		held[action] = false
	touch_actions.clear()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and flight != null:
		_clear_controls()
		if settings_panel != null and settings_panel.visible:
			settings_panel.hide()
		elif flight.status != FlightModel.Status.READY or manual_open:
			_pause()
	elif what == NOTIFICATION_APPLICATION_PAUSED:
		_lose_focus()

func _lose_focus() -> void:
	_clear_controls()
	if flight != null and flight.status == FlightModel.Status.PLAYING:
		flight.toggle_pause()

func _show_manual() -> void:
	if manual_open:
		_pause()
		return
	manual_was_playing = flight.status == FlightModel.Status.PLAYING
	if manual_was_playing:
		flight.toggle_pause()
	manual_open = true
	_clear_controls()
	_refresh()

func _pause() -> void:
	if manual_open:
		manual_open = false
		if manual_was_playing and flight.status == FlightModel.Status.PAUSED:
			flight.toggle_pause()
	elif flight.status == FlightModel.Status.READY:
		flight.step(0,0,true)
	else:
		flight.toggle_pause()
	_clear_controls()

func _refresh() -> void:
	radio_message.text = flight.message
	radio_message.tooltip_text = flight.message
	radio_bubble.custom_minimum_size.y = clampf(radio_message.get_minimum_size().y+20,52,100)
	winch_button.text = "DEPLOY WINCH" if flight.winch == FlightModel.Winch.STOWED else "HOIST PATIENT" if flight.winch == FlightModel.Winch.READY_TO_HOIST else "CANCEL PICKUP" if flight.winch == FlightModel.Winch.LOWERING else "RETRIEVING..."
	if flight.crew_index>=0:
		winch_button.text="HELP / BOARD"
	elif flight.can_disembark():
		winch_button.text="SEND RESCUER"
	winch_button.disabled = flight.status not in [FlightModel.Status.READY, FlightModel.Status.PLAYING] or manual_open
	pause_button.icon = _icon("play") if flight.status in [FlightModel.Status.READY,FlightModel.Status.PAUSED] else _icon("pause")
	for action: String in control_buttons:
		control_buttons[action].set_pressed_no_signal(_control(action))
		control_buttons[action].disabled=flight.crew_index>=0 and action in ["up","down"]
	var show_overlay := not settings_panel.visible and (manual_open or flight.status in [FlightModel.Status.PAUSED,FlightModel.Status.FAILED,FlightModel.Status.COMPLETE])
	if show_overlay and not overlay.visible:
		overlay.modulate.a = 0
		if overlay_tween:
			overlay_tween.kill()
		overlay_tween = create_tween()
		overlay_tween.tween_property(overlay,"modulate:a",1.0,0.18)
	overlay.visible = show_overlay
	resume_button.visible = manual_open or flight.status == FlightModel.Status.PAUSED
	resume_button.text = "Ready to fly" if manual_open else "Resume flight   [P]"
	next_button.visible = not manual_open and flight.status == FlightModel.Status.COMPLETE
	result_summary.visible = not manual_open and flight.status in [FlightModel.Status.COMPLETE,FlightModel.Status.FAILED]
	if show_overlay:
		if manual_open:
			overlay_kicker.text = "A LITTLE COURAGE. A LOT OF LIFT."
			overlay_title.text = "Be their lifeline."
			overlay_copy.text = "A / D: accelerate or brake. W / S: climb or descend.\nSettings: altitude hold, ground tether and auto-hoist are independent.\n\nWINCH: Space lowers the rescue crew. Keep the hook in the circle while it fills.\nWith tether on, the ground end anchors; excess tension or slack releases it.\nSpace hoists the loaded stretcher, unless auto-hoist is enabled.\n\nLANDING: land at a green LZ, then Space to control the rescuer.\nA / D to walk. Space near the survivor to help; return and Space to board.\n\nBring everyone home to the base helipad. Land at base to refuel."
		else:
			overlay_kicker.text = "TAKE A BREATHER, PILOT." if flight.status == FlightModel.Status.PAUSED else "MISSION ACCOMPLISHED" if flight.status == FlightModel.Status.COMPLETE else "MISSION INCOMPLETE"
			overlay_title.text = "Holding position." if flight.status == FlightModel.Status.PAUSED else "Everyone. Home safe." if flight.status == FlightModel.Status.COMPLETE else "A second chance to fly."
			overlay_copy.text = "Your mission will be right here." if flight.status == FlightModel.Status.PAUSED else flight.message
			result_summary.text = "%d / %d  SURVIVORS     %02d:%02d  FLIGHT TIME" % [flight.rescued,flight.targets.size(),int(flight.elapsed)/60,int(flight.elapsed)%60]

func _toggle_fullscreen() -> void:
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _toggle_sound() -> void:
	muted = not muted
	sound_button.text = "Sound: off" if muted else "Sound: on"
	sound_button.icon = _icon("muted") if muted else _icon("sound")
	sound_button.tooltip_text = "Enable game sound" if muted else "Mute game sound"
	if not muted:
		_play_cue("winch")

func _play_cue(kind: String) -> void:
	if muted:
		return
	var rate := 22050
	var duration := 0.4 if kind == "complete" else 0.16
	var count := int(rate * duration)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var frequency := 220.0 if kind == "damage" else 660.0 if kind == "rescue" else 880.0 if kind == "complete" else 440.0
	for i in count:
		var t := float(i) / rate
		var envelope := sin(PI * i / count) * 0.2
		bytes.encode_s16(i * 2, int(sin(TAU * frequency * t) * envelope * 32767))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	audio.stream = stream
	audio.play()

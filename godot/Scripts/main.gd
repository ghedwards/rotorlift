extends Control

const Model = preload("res://Scripts/flight_model.gd")
const View = preload("res://Scripts/flight_view.gd")
const Hud = preload("res://Scripts/flight_hud.gd")
const TouchControls = preload("res://Scripts/flight_controls.gd")
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
var assist_checks: Array[CheckButton] = []
var settings_panel: PanelContainer
var settings_was_playing := false
var assist_flags := [true,true,false]
var mission_picker: OptionButton
var overlay: PanelContainer
var overlay_title: Label
var overlay_copy: Label
var resume_button: Button
var next_button: Button
var muted := true
var sound_button: Button
var touch_controls: FlightControls
var menu_button: Button
var menu_panel: PanelContainer
var menu_resume: Button
var menu_was_playing := false
var dialog_scrim: ColorRect
var overlay_card: PanelContainer
var overlay_restart: Button
var settings_scroll: ScrollContainer
var menu_scroll: ScrollContainer
var completed: Array = []
var held := {"left": false, "right": false, "up": false, "down": false}
var audio: AudioStreamPlayer
var last_status := FlightModel.Status.READY
var rotation_overlay: PanelContainer
var portrait_blocked := false
var portrait_was_playing := false

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
	_update_display_scale()
	get_window().focus_exited.connect(_lose_focus)

func _update_display_scale() -> void:
	var dimensions := get_window().size
	if dimensions.x <= 0 or dimensions.y <= 0:
		return
	# A landscape phone needs usable touch targets, not a letterboxed desktop UI.
	var phone_layout := OS.has_feature("mobile") or dimensions.y < 600
	var logical_width := 720 if dimensions.x < dimensions.y else 1200 if phone_layout else 1440
	var logical_size := Vector2i(logical_width,roundi(float(logical_width)*dimensions.y/dimensions.x))
	if get_window().content_scale_size != logical_size:
		get_window().content_scale_size = logical_size
	_set_portrait_blocked(dimensions.x < dimensions.y)

func _set_portrait_blocked(blocked: bool) -> void:
	if rotation_overlay != null:
		rotation_overlay.visible = blocked
	if blocked == portrait_blocked:
		return
	portrait_blocked = blocked
	_clear_controls()
	if flight == null:
		return
	if blocked:
		if menu_panel.visible:
			menu_panel.hide()
		if settings_panel.visible:
			settings_panel.hide()
		portrait_was_playing = flight.status == FlightModel.Status.PLAYING
		if portrait_was_playing:
			flight.toggle_pause()
	else:
		if portrait_was_playing and flight.status == FlightModel.Status.PAUSED and not manual_open:
			flight.toggle_pause()
		portrait_was_playing = false

func _build_rotation_prompt() -> void:
	rotation_overlay = PanelContainer.new()
	rotation_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rotation_overlay.add_theme_stylebox_override("panel",_style(Color("192c28"),Color.TRANSPARENT,32))
	rotation_overlay.visible = portrait_blocked
	add_child(rotation_overlay)
	var center := CenterContainer.new()
	rotation_overlay.add_child(center)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",24)
	content.custom_minimum_size.x = 560
	center.add_child(content)
	var title := _label("Turn your phone\nsideways to fly.",48)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	content.add_child(title)
	var copy := _label("Landscape gives both thumbs room\nto steer, climb and work the winch.\n\nYour flight is paused while you rotate.",26)
	copy.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	copy.add_theme_color_override("font_color",Color("bbc6b0"))
	content.add_child(copy)

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

func _dialog_style() -> StyleBoxFlat:
	var panel := _style(Color("192c28"),Color("43594d"),24)
	panel.set_corner_radius_all(16)
	panel.content_margin_top = 24
	panel.content_margin_bottom = 24
	panel.shadow_color = Color(0.01,0.04,0.03,0.4)
	panel.shadow_size = 16
	panel.shadow_offset = Vector2(0,6)
	return panel

func _dialog_button(text: String, callback: Callable, icon_name := "", primary := false) -> Button:
	var button := _button(text,callback)
	button.custom_minimum_size.y = 64
	button.add_theme_font_size_override("font_size",22)
	button.add_theme_constant_override("h_separation",16)
	button.add_theme_constant_override("icon_max_width",24)
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER if primary else HORIZONTAL_ALIGNMENT_LEFT
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.expand_icon = true
	if not icon_name.is_empty():
		button.icon = _icon(icon_name)
	for state in ["normal","hover","pressed","focus","disabled"]:
		var background := ORANGE if primary else Color("233b32")
		if state=="hover": background = background.lightened(0.06)
		if state=="pressed": background = background.lightened(0.11) if not primary else background.darkened(0.1)
		var style := _style(background,ORANGE if state=="focus" else Color.TRANSPARENT,18)
		style.set_corner_radius_all(9)
		button.add_theme_stylebox_override(state,style)
		var color := Color("192c28") if primary else Color("eeedcf")
		button.add_theme_color_override("font_"+(state+"_" if state!="normal" else "")+"color",color)
		if state in ["normal","hover","pressed","disabled"]:
			button.add_theme_color_override("icon_"+state+"_color",color)
	return button

func _dialog_header(content: VBoxContainer, title: String, close: Callable) -> void:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation",16)
	content.add_child(header)
	var heading := _label(title,32)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(heading)
	var dismiss := _flat(_button("×",close))
	dismiss.add_theme_font_size_override("font_size",32)
	dismiss.custom_minimum_size = Vector2(48,48)
	header.add_child(dismiss)

func _fit_popup(panel: PanelContainer, preferred: Vector2i, edge := 32.0) -> void:
	var viewport_size := get_viewport_rect().size
	var available := viewport_size-Vector2.ONE*edge*2
	panel.size = Vector2(minf(preferred.x,available.x),minf(preferred.y,available.y))
	panel.position = (viewport_size-panel.size)/2
	panel.show()

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
	var scene := Control.new()
	scene.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(scene)
	view = View.new()
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.add_child(view)
	hud = Hud.new()
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scene.add_child(hud)
	_build_touch_controls()
	dialog_scrim = ColorRect.new()
	dialog_scrim.color = Color(0.025,0.06,0.05,0.62)
	dialog_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dialog_scrim.visible = false
	add_child(dialog_scrim)
	dialog_scrim.gui_input.connect(func(event: InputEvent):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			if settings_panel.visible: settings_panel.hide()
			elif menu_panel.visible: menu_panel.hide())
	_build_settings()
	_build_menu()
	_build_overlay(scene)
	audio = AudioStreamPlayer.new()
	add_child(audio)
	_build_rotation_prompt()

func _build_overlay(_scene: Control) -> void:
	overlay = PanelContainer.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var scrim := _style(Color(0.025,0.06,0.05,0.62),Color.TRANSPARENT,32)
	scrim.set_border_width_all(0)
	scrim.content_margin_top = 32
	scrim.content_margin_bottom = 32
	overlay.add_theme_stylebox_override("panel",scrim)
	add_child(overlay)
	var center := CenterContainer.new()
	overlay.add_child(center)
	overlay_card = PanelContainer.new()
	overlay_card.add_theme_stylebox_override("panel",_dialog_style())
	center.add_child(overlay_card)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",16)
	overlay_card.add_child(content)
	overlay_kicker = _mono_label("",14)
	overlay_kicker.add_theme_color_override("font_color",Color("a9c894"))
	content.add_child(overlay_kicker)
	overlay_title = _label("",32)
	content.add_child(overlay_title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.custom_minimum_size.y = 40
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	overlay_copy = _label("",21)
	overlay_copy.add_theme_color_override("font_color",Color("bbc6b0"))
	overlay_copy.add_theme_constant_override("line_spacing",5)
	overlay_copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	overlay_copy.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(overlay_copy)
	result_summary = _mono_label("",17)
	content.add_child(result_summary)
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_END
	actions.add_theme_constant_override("separation",12)
	content.add_child(actions)
	overlay_restart = _dialog_button("Restart",func(): _select_mission(mission_index),"restart")
	actions.add_child(overlay_restart)
	next_button = _dialog_button("Next mission",func(): _select_mission((mission_index+1)%missions.size()),"right",true)
	actions.add_child(next_button)
	resume_button = _dialog_button("Resume flight",_pause,"play",true)
	actions.add_child(resume_button)

func _build_touch_controls() -> void:
	touch_controls = TouchControls.new()
	touch_controls.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	touch_controls.winch_pressed.connect(func(): flight.toggle_winch())
	add_child(touch_controls)
	menu_button = _flat(_button("",_show_menu))
	menu_button.icon = _icon("menu")
	menu_button.expand_icon = true
	menu_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	menu_button.add_theme_constant_override("icon_max_width",32)
	menu_button.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	menu_button.offset_left = -106
	menu_button.offset_right = -30
	menu_button.offset_top = 24
	menu_button.offset_bottom = 104
	menu_button.tooltip_text = "Flight menu / pause"
	add_child(menu_button)

func _build_menu() -> void:
	menu_panel = PanelContainer.new()
	menu_panel.visible = false
	menu_panel.add_theme_stylebox_override("panel",_dialog_style())
	menu_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(menu_panel)
	menu_scroll = ScrollContainer.new()
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_panel.add_child(menu_scroll)
	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation",12)
	menu_scroll.add_child(content)
	_dialog_header(content,"Flight menu",func(): menu_panel.hide())
	var subtitle := _label("Flight pauses while this menu is open.",18)
	subtitle.add_theme_color_override("font_color",Color("bbc6b0"))
	content.add_child(subtitle)
	menu_resume = _dialog_button("Resume flight",func():
		menu_was_playing = false
		menu_panel.hide()
		if flight.status in [FlightModel.Status.READY,FlightModel.Status.PAUSED]:
			_pause(),"play",true)
	menu_resume.custom_minimum_size.y = 70
	content.add_child(menu_resume)
	for definition in [["settings","Settings"],["info","Flight manual"],["expand","Fullscreen"]]:
		var action: String = definition[0]
		content.add_child(_dialog_button(definition[1],func(): _menu_action(action),action))
	menu_panel.visibility_changed.connect(func():
		if menu_panel.visible: return
		_clear_controls()
		if menu_was_playing and flight.status == FlightModel.Status.PAUSED:
			flight.toggle_pause()
		menu_was_playing = false
		_refresh())

func _show_menu() -> void:
	menu_was_playing = flight.status == FlightModel.Status.PLAYING
	if menu_was_playing:
		flight.toggle_pause()
	_clear_controls()
	menu_resume.text = "Start flight" if flight.status == FlightModel.Status.READY else "Resume flight" if flight.status == FlightModel.Status.PAUSED else "Back to mission"
	menu_scroll.scroll_vertical = 0
	_fit_popup(menu_panel,Vector2i(540,464))
	_refresh()

func _menu_action(action: String) -> void:
	if action == "expand":
		_toggle_fullscreen()
		return
	var resume_after := menu_was_playing
	menu_was_playing = false
	menu_panel.hide()
	if action == "settings":
		_show_settings()
		settings_was_playing = resume_after
	else:
		_show_manual()
		manual_was_playing = resume_after

func _settings_toggle(title: String, active: bool, callback: Callable) -> CheckButton:
	var check := CheckButton.new()
	check.text = title
	check.custom_minimum_size.y = 64
	check.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	check.add_theme_font_size_override("font_size",22)
	for state in ["normal","hover","pressed","hover_pressed","focus","disabled"]:
		check.add_theme_color_override("font_"+(state+"_" if state!="normal" else "")+"color",Color("eeedcf"))
		var style := _style(Color("2b4539") if state in ["hover","hover_pressed"] else Color("233b32"),Color.TRANSPARENT,14)
		style.set_corner_radius_all(9)
		check.add_theme_stylebox_override(state,style)
	for icon_name in ["checked","checked_disabled","unchecked","unchecked_disabled"]:
		check.add_theme_icon_override(icon_name,load("res://Assets/Icons/toggle-%s.svg" % ("on" if icon_name.begins_with("checked") else "off")))
	check.button_pressed = active
	check.pressed.connect(callback)
	return check

func _settings_group(parent: VBoxContainer, control: Control, description: String) -> void:
	var group := VBoxContainer.new()
	group.add_theme_constant_override("separation",4)
	parent.add_child(group)
	group.add_child(control)
	var inset := _margin(14,0,14,0)
	group.add_child(inset)
	var copy := _label(description,16)
	copy.add_theme_color_override("font_color",Color("bbc6b0"))
	copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	inset.add_child(copy)

func _build_settings() -> void:
	settings_panel = PanelContainer.new()
	settings_panel.visible = false
	settings_panel.add_theme_stylebox_override("panel",_dialog_style())
	settings_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(settings_panel)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation",16)
	settings_panel.add_child(content)
	_dialog_header(content,"Settings",func(): settings_panel.hide())
	settings_scroll = ScrollContainer.new()
	settings_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	settings_scroll.custom_minimum_size.y = 100
	settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(settings_scroll)
	var columns := HBoxContainer.new()
	columns.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	columns.add_theme_constant_override("separation",28)
	settings_scroll.add_child(columns)
	var operation := VBoxContainer.new()
	operation.custom_minimum_size.x = 310
	operation.add_theme_constant_override("separation",8)
	columns.add_child(operation)
	var mission_label := _label("OPERATION",16)
	mission_label.add_theme_color_override("font_color",Color("bbc6b0"))
	operation.add_child(mission_label)
	mission_picker = OptionButton.new()
	mission_picker.custom_minimum_size = Vector2(310,64)
	mission_picker.add_theme_font_size_override("font_size",22)
	for mission: Dictionary in missions:
		mission_picker.add_item("%s  ·  %s" % [mission.id,mission.name])
	var popup := mission_picker.get_popup()
	popup.add_theme_stylebox_override("panel",_dialog_style())
	popup.add_theme_font_size_override("font_size",22)
	popup.add_theme_constant_override("v_separation",24)
	mission_picker.item_selected.connect(func(index: int):
		settings_was_playing = false
		_select_mission(index))
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style := _style(Color("233b32"),Color("43594d"),14)
		style.set_corner_radius_all(9)
		mission_picker.add_theme_stylebox_override(state,style)
	mission_picker.add_theme_icon_override("arrow",_icon("down"))
	_settings_group(operation,mission_picker,"Choose a rescue mission.")
	sound_button = _settings_toggle("Sound",not muted,_toggle_sound)
	_settings_group(operation,sound_button,"Winch and rescue sounds.")
	var restart := _dialog_button("Restart mission",func():
		settings_was_playing = false
		_select_mission(mission_index)
		settings_panel.hide())
	for state in ["normal","hover","pressed","focus","disabled"]:
		var style: StyleBoxFlat = restart.get_theme_stylebox(state).duplicate()
		style.content_margin_left = 14
		style.content_margin_right = 14
		restart.add_theme_stylebox_override(state,style)
	_settings_group(operation,restart,"Reset your current mission.")
	var assists := VBoxContainer.new()
	assists.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	assists.add_theme_constant_override("separation",8)
	columns.add_child(assists)
	var assists_title := _label("FLIGHT ASSISTS",16)
	assists_title.add_theme_color_override("font_color",Color("bbc6b0"))
	assists.add_child(assists_title)
	var descriptions := ["Keep height when the stick is released.","Anchor the line during survivor loading.","Lift automatically once loading finishes."]
	for i in 3:
		var check := _settings_toggle(["Altitude hold","Ground tether","Auto-hoist"][i],assist_flags[i],_toggle_assist.bind(i))
		assist_checks.append(check)
		_settings_group(assists,check,descriptions[i])
	var done := _dialog_button("Back to flight",func(): settings_panel.hide(),"play",true)
	done.size_flags_horizontal = Control.SIZE_SHRINK_END
	done.custom_minimum_size.x = 240
	content.add_child(done)
	settings_panel.visibility_changed.connect(func():
		if settings_panel.visible: return
		_clear_controls()
		if settings_was_playing and flight.status == FlightModel.Status.PAUSED:
			flight.toggle_pause()
		_refresh())

func _show_settings() -> void:
	settings_was_playing = flight.status == FlightModel.Status.PLAYING
	if settings_was_playing:
		flight.toggle_pause()
	_clear_controls()
	settings_scroll.scroll_vertical = 0
	_fit_popup(settings_panel,Vector2i(940,536),20)
	_refresh()

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
	view.reset_camera()
	view.backdrop = load("res://Assets/" + String(missions[index].image).get_file())
	last_status = FlightModel.Status.READY
	_clear_controls()
	_refresh()

func _process(dt: float) -> void:
	if flight == null:
		return
	var steer := clampf(float(_control("right"))-float(_control("left"))+touch_controls.stick.x,-1,1)
	var vertical := -1.0 if _control("up") else 1.0 if _control("down") else touch_controls.stick.y
	if not portrait_blocked and not manual_open and not settings_panel.visible and not menu_panel.visible:
		flight.step(minf(dt,0.04),steer,_control("up"),_control("down"),vertical)
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
	return not portrait_blocked and (bool(held[action]) or Input.is_action_pressed("flight_" + action))

func _unhandled_key_input(event: InputEvent) -> void:
	if portrait_blocked:
		return
	if menu_panel.visible:
		if event.is_action_pressed("flight_pause"):
			menu_panel.hide()
		return
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
	if touch_controls != null:
		touch_controls.reset()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and flight != null:
		_clear_controls()
		if menu_panel != null and menu_panel.visible:
			menu_panel.hide()
		elif settings_panel != null and settings_panel.visible:
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
	if portrait_blocked:
		return
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
	if dialog_scrim != null:
		dialog_scrim.visible = settings_panel.visible or menu_panel.visible
	var can_control := not portrait_blocked and not manual_open and not settings_panel.visible and not menu_panel.visible and flight.status in [FlightModel.Status.READY,FlightModel.Status.PLAYING]
	touch_controls.set_enabled(can_control)
	touch_controls.visible = can_control
	touch_controls.vertical_enabled = flight.crew_index < 0
	touch_controls.winch_active = flight.winch != FlightModel.Winch.STOWED or flight.crew_index >= 0
	touch_controls.winch_icon = _icon("up") if flight.winch in [FlightModel.Winch.READY_TO_HOIST,FlightModel.Winch.RETRIEVING] else _icon("rescue-cross")
	touch_controls.winch_description = "Help / board" if flight.crew_index >= 0 else "Send rescuer" if flight.can_disembark() else "Hoist patient" if flight.winch == FlightModel.Winch.READY_TO_HOIST else "Cancel pickup" if flight.winch == FlightModel.Winch.LOWERING else "Deploy winch"
	touch_controls.rescue_progress = -1
	touch_controls.rescue_remaining = -1
	if flight.crew_index >= 0 and flight.crew_state == 1:
		touch_controls.rescue_progress = clampf(flight.crew_progress/3,0,1)
		touch_controls.rescue_remaining = maxf(0,3-flight.crew_progress)
	elif flight.contact >= 0 and flight.attached < 0 and flight.winch in [FlightModel.Winch.LOWERING,FlightModel.Winch.READY_TO_HOIST]:
		var duration := flight.pickup_duration(flight.contact)
		touch_controls.rescue_progress = 1 if flight.winch == FlightModel.Winch.READY_TO_HOIST else clampf(flight.pickup_progress/duration,0,1)
		touch_controls.rescue_remaining = 0 if flight.winch == FlightModel.Winch.READY_TO_HOIST else maxf(0,duration-flight.pickup_progress)
	touch_controls.queue_redraw()
	menu_button.disabled = portrait_blocked or manual_open or settings_panel.visible
	var show_overlay := not settings_panel.visible and not menu_panel.visible and (manual_open or flight.status in [FlightModel.Status.PAUSED,FlightModel.Status.FAILED,FlightModel.Status.COMPLETE])
	if show_overlay and not overlay.visible:
		overlay.modulate.a = 0
		if overlay_tween:
			overlay_tween.kill()
		overlay_tween = create_tween()
		overlay_tween.tween_property(overlay,"modulate:a",1.0,0.18)
	overlay.visible = show_overlay
	resume_button.visible = manual_open or flight.status == FlightModel.Status.PAUSED
	resume_button.text = "Back to flight" if manual_open else "Resume flight"
	overlay_restart.visible = not manual_open
	next_button.visible = not manual_open and flight.status == FlightModel.Status.COMPLETE
	result_summary.visible = not manual_open and flight.status in [FlightModel.Status.COMPLETE,FlightModel.Status.FAILED]
	if show_overlay:
		var available := get_viewport_rect().size-Vector2(64,64)
		overlay_card.custom_minimum_size = Vector2(minf(900 if manual_open else 720,available.x),minf(520 if manual_open else 340,available.y))
		if manual_open:
			overlay_kicker.text = "PILOT GUIDE"
			overlay_title.text = "Flight manual"
			overlay_copy.text = "FLY\nUse the left joystick to steer and climb. Small movements give finer control. Release to coast; push the opposite way to brake. Keyboard: WASD / arrows.\n\nRESCUE\nTap the rescue cross to lower the crew. Keep the hook in the survivor circle until the countdown finishes, then tap the up arrow to hoist. Excess line tension or slack cancels loading.\n\nLAND\nLand at a field pad and tap the cross to send the rescuer. Use the stick to walk; tap beside the survivor to help, then return to the helicopter and tap to board.\n\nRETURN HOME\nBring everyone to the base helipad. Land to refuel. Flight assists and sound are in Menu → Settings."
		else:
			overlay_kicker.text = String(flight.mission.name).to_upper()
			overlay_title.text = "Flight paused" if flight.status == FlightModel.Status.PAUSED else "Mission complete" if flight.status == FlightModel.Status.COMPLETE else "Mission ended"
			overlay_copy.text = "Your crew and helicopter are safe here. Continue whenever you are ready." if flight.status == FlightModel.Status.PAUSED else flight.message
			result_summary.text = "%d / %d rescued     %02d:%02d flight time" % [flight.rescued,flight.targets.size(),int(flight.elapsed)/60,int(flight.elapsed)%60]

func _toggle_fullscreen() -> void:
	var fullscreen := DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if fullscreen else DisplayServer.WINDOW_MODE_FULLSCREEN)

func _toggle_sound() -> void:
	muted = not muted
	sound_button.set_pressed_no_signal(not muted)
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

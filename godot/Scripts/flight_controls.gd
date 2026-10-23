class_name FlightControls
extends Control
## Independent thumb ownership, with mouse support for the desktop preview.
signal winch_pressed

const DEAD_ZONE := 0.14
const STICK_RADIUS := 92.0
const TRAVEL := 54.0
const WINCH_RADIUS := 57.0
const MOUSE_POINTER := -100
const EMULATED_DEVICE := -1
var stick := Vector2.ZERO
var thumb := Vector2.ZERO
var joystick_pointer := -1
var winch_pointer := -1
var enabled := true
var vertical_enabled := true
var winch_active := false
var winch_icon: Texture2D = preload("res://Assets/Icons/rescue-cross.svg")
var winch_description := "Deploy winch / Space"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func joystick_center() -> Vector2:
	return Vector2(132,size.y-132)

func winch_center() -> Vector2:
	return Vector2(size.x-116,size.y-132)

func reset() -> void:
	stick = Vector2.ZERO
	thumb = Vector2.ZERO
	joystick_pointer = -1
	winch_pointer = -1
	queue_redraw()

func set_enabled(value: bool) -> void:
	if enabled and not value:
		reset()
	enabled = value

func _move_stick(point: Vector2) -> void:
	thumb = ((point-joystick_center())/TRAVEL).limit_length()
	var strength := thumb.length()
	stick = Vector2.ZERO
	if strength > DEAD_ZONE:
		var direction := thumb
		if absf(direction.x) < absf(direction.y)*0.18:
			direction.x = 0
		elif absf(direction.y) < absf(direction.x)*0.18:
			direction.y = 0
		stick = direction.normalized() * clampf((strength-DEAD_ZONE)/(1-DEAD_ZONE),0,1)
	if not vertical_enabled:
		stick.y = 0
	queue_redraw()

func _press(pointer: int, point: Vector2) -> bool:
	if joystick_pointer == -1 and point.distance_to(joystick_center()) <= STICK_RADIUS+10:
		joystick_pointer = pointer
		_move_stick(point)
		return true
	if winch_pointer == -1 and point.distance_to(winch_center()) <= WINCH_RADIUS+8:
		winch_pointer = pointer
		winch_pressed.emit()
		queue_redraw()
		return true
	return false

func _release(pointer: int) -> bool:
	if pointer == joystick_pointer:
		joystick_pointer = -1
		stick = Vector2.ZERO
		thumb = Vector2.ZERO
		queue_redraw()
		return true
	if pointer == winch_pointer:
		winch_pointer = -1
		queue_redraw()
		return true
	return false

func handle_event(event: InputEvent) -> bool:
	if not enabled or event.device == EMULATED_DEVICE:
		return false
	if event is InputEventScreenTouch:
		return _press(event.index,event.position) if event.pressed else _release(event.index)
	if event is InputEventScreenDrag and event.index == joystick_pointer:
		_move_stick(event.position)
		return true
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		return _press(MOUSE_POINTER,event.position) if event.pressed else _release(MOUSE_POINTER)
	if event is InputEventMouseMotion and joystick_pointer == MOUSE_POINTER:
		_move_stick(event.position)
		return true
	return false

func _input(event: InputEvent) -> void:
	if handle_event(event):
		get_viewport().set_input_as_handled()

func _draw() -> void:
	var cream := Color("eeedcf")
	var center := joystick_center()
	draw_circle(center,STICK_RADIUS,Color(0.07,0.14,0.12,0.26))
	draw_arc(center,STICK_RADIUS,0,TAU,80,Color(0.93,0.93,0.81,0.35),2,true)
	draw_arc(center,TRAVEL,0,TAU,64,Color(0.93,0.93,0.81,0.12),1,true)
	for direction in [Vector2.LEFT,Vector2.RIGHT,Vector2.UP,Vector2.DOWN]:
		if vertical_enabled or direction.y == 0:
			draw_line(center+direction*74,center+direction*82,Color(0.93,0.93,0.81,0.4),2,true)
	var puck := center+thumb*TRAVEL
	draw_circle(puck,35,Color(0.93,0.93,0.81,0.21 if joystick_pointer == -1 else 0.36))
	draw_arc(puck,35,0,TAU,64,Color(0.93,0.93,0.81,0.55),2,true)
	draw_circle(puck,5,Color(0.93,0.93,0.81,0.65))
	var button := winch_center()
	var active := winch_pointer != -1
	var tint := Color("f28a50") if winch_active else cream
	draw_circle(button,WINCH_RADIUS,Color(0.07,0.14,0.12,0.46 if active else 0.28))
	draw_arc(button,WINCH_RADIUS,0,TAU,80,Color(tint,0.75 if active else 0.5),2,true)
	if winch_active:
		draw_arc(button,WINCH_RADIUS-6,-PI*0.75,PI*0.75,64,Color(tint,0.6),2,true)
	var icon_color := Color.WHITE if winch_icon.resource_path.ends_with("rescue-cross.svg") else tint
	draw_texture_rect(winch_icon,Rect2(button-Vector2.ONE*27,Vector2.ONE*54),false,Color(icon_color,0.95))

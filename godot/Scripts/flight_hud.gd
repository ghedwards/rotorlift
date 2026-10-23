class_name FlightHud
extends Control
## Original HTML instruments, typography, spacing and route map in Godot Canvas.

const MONO = preload("res://Assets/Fonts/IBMPlexMono-Regular.ttf")
const DISPLAY = preload("res://Assets/Fonts/BarlowCondensed-SemiBold.ttf")
const SANS = preload("res://Assets/Fonts/DMSans.ttf")
const CREAM := Color("eeedcf")
const MUTED := Color("bbc6b0")
const ORANGE := Color("f28a50")
var flight: FlightModel
var icons: Dictionary = {}
var upper_shade: GradientTexture2D
var lower_shade: GradientTexture2D

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	upper_shade = _gradient(0.42,0.0)
	lower_shade = _gradient(0.0,0.75)
	for name in ["person", "fuel", "shield", "wind", "radio"]:
		icons[name] = load("res://Assets/Icons/%s.svg" % name)

func _gradient(start: float, finish: float) -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.colors = PackedColorArray([Color(0.04,0.09,0.08,start),Color(0.04,0.09,0.08,finish)])
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.width = 4
	texture.height = 256
	texture.fill_from = Vector2.ZERO
	texture.fill_to = Vector2(0,1)
	return texture

func _process(_dt: float) -> void:
	queue_redraw()

func _text(p: Vector2, value: String, font_size := 12, color := CREAM, font: Font = SANS) -> void:
	font_size=maxi(14,font_size)
	draw_string(font, p + Vector2(0, 1), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(0.04,0.1,0.09,0.45))
	draw_string(font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

func _icon(name: String, p: Vector2, side := 21.0, color := CREAM) -> void:
	draw_texture_rect(icons[name], Rect2(p, Vector2.ONE * side), false, color)

func _draw() -> void:
	if flight == null:
		return
	# Transparent shading leaves the landscape visible while protecting legibility.
	draw_texture_rect(upper_shade,Rect2(0,0,size.x,170),false)
	_draw_top_panel()
	_draw_tension()
	_draw_route()
	for corner in [Vector2(8,8),Vector2(size.x-8,8),Vector2(8,size.y-8),Vector2(size.x-8,size.y-8)]:
		var direction := Vector2(1 if corner.x<20 else -1,1 if corner.y<20 else -1)
		draw_line(corner,corner+Vector2(10*direction.x,0),Color(0.92,0.94,0.84,0.75),1)
		draw_line(corner,corner+Vector2(0,10*direction.y),Color(0.92,0.94,0.84,0.75),1)

func _draw_top_panel() -> void:
	# One shared panel and baseline grid for every top-level instrument.
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("192c28")
	panel.border_color = Color("43564a")
	panel.set_border_width_all(1)
	panel.set_corner_radius_all(8)
	draw_style_box(panel,Rect2(18,12,size.x-36,104))
	var status: String = ["Awaiting takeoff","Live operation","Operation paused","Mission complete","Signal lost"][flight.status]
	var lamp := Color("cee3a8") if flight.status == FlightModel.Status.PLAYING else ORANGE
	draw_circle(Vector2(38,32),3,lamp)
	_text(Vector2(51,39),status,18,CREAM)
	var location := "%s / %s" % [flight.mission.name,String(flight.mission.region).capitalize()]
	var location_width := SANS.get_string_size(location,HORIZONTAL_ALIGNMENT_LEFT,-1,18).x
	_text(Vector2(size.x-332-location_width,39),location,18,CREAM)
	draw_line(Vector2(34,50),Vector2(size.x-332,50),Color("43564a"),1)
	var column_width := (size.x-376)/7.0
	var values := ["%02d / %02d" % [flight.rescued,flight.targets.size()],"%d%%" % ceili(flight.fuel),"", "%d ft" % maxi(0,int((flight.ground(flight.position.x)-flight.position.y-48)*0.7)),"%d kts" % int(absf(flight.velocity.x)*0.3),"%02d:%02d" % [int(flight.elapsed)/60,int(flight.elapsed)%60],"%s %02d kts" % ["→" if flight.wind_knots()>=0 else "←",int(absf(flight.wind_knots()))]]
	for i in 7:
		var x := 38+column_width*i
		_text(Vector2(x,72),["Rescued","Fuel","Airframe","Altitude","Speed","Flight time","Wind"][i],16,MUTED)
		if i>0:
			draw_line(Vector2(x-16,64),Vector2(x-16,102),Color("43564a"),1)
		if i==2:
			for segment in 3:
				draw_style_box(_integrity_segment(segment<flight.health),Rect2(x+segment*26,85,20,14))
		else:
			_text(Vector2(x,101),values[i],22,ORANGE if i==1 and flight.fuel<20 else CREAM)

func _integrity_segment(active: bool) -> StyleBoxFlat:
	var segment := StyleBoxFlat.new()
	segment.bg_color = CREAM if active else Color("43564a")
	segment.set_corner_radius_all(2)
	return segment

func _draw_tension() -> void:
	if flight.cable <= 0 and flight.overload_warning <= 0:
		return
	var origin := Vector2(size.x-191,152)
	var ratio := clampf(flight.tether_tension/FlightModel.TETHER_LIMIT,0,1)
	var broken := flight.overload_warning > 0
	if broken:
		ratio = 1
	var color := Color("ef7967") if broken or ratio >= 0.85 else ORANGE if ratio >= 0.6 else Color("a9d9aa")
	draw_rect(Rect2(origin-Vector2(12,16),Vector2(175,112)),Color(0.05,0.10,0.09,0.78))
	_text(origin,"LINE TENSION",9,CREAM)
	_text(origin+Vector2(0,24),"%d%%" % roundi(ratio*100),19,color,DISPLAY)
	_text(origin+Vector2(82,22),"LIMIT",8,MUTED)
	var bar := Rect2(origin+Vector2(0,34),Vector2(126,9))
	draw_rect(bar,Color(0.8,0.9,0.8,0.12))
	draw_rect(Rect2(bar.position,Vector2(bar.size.x*ratio,bar.size.y)),color)
	draw_line(bar.position+Vector2(126,-3),bar.end+Vector2(0,3),Color("ef7967"),2,true)
	var label := "DISCONNECTED" if broken else "EASE OFF" if ratio>=0.85 else "TAUT" if ratio>=0.6 else "TETHERED" if flight.contact>=0 else "TETHER OFF" if not flight.ground_tether else "FREE LINE"
	_text(origin+Vector2(0,63),label,9,color)
	_text(origin+Vector2(0,78),"100% = RELEASE",8,MUTED)

func _draw_route() -> void:
	draw_line(Vector2(size.x-312,24),Vector2(size.x-312,104),Color("43564a"),1)
	var origin := Vector2(size.x-288,39)
	_text(origin,"Mission route",16,MUTED)
	_text(origin+Vector2(206,0),"%s / 03" % flight.mission.id,14,MUTED)
	var route := PackedVector2Array()
	for p: Dictionary in flight.mission.terrain:
		route.append(origin+Vector2(float(p.x)/float(flight.mission.width)*260,22+(float(p.y)-470)/8))
	var fill := route.duplicate()
	fill.append(origin+Vector2(260,65))
	fill.append(origin+Vector2(0,65))
	draw_colored_polygon(fill,Color(0.8,0.86,0.79,0.07))
	draw_polyline(route,Color(0.8,0.86,0.79,0.55),1,true)
	draw_line(origin+Vector2(0,65),origin+Vector2(260,65),Color("43564a"),1)
	var base := origin+Vector2(245.0/float(flight.mission.width)*260,22+(flight.ground(245)-470)/8)
	draw_rect(Rect2(base-Vector2(3,3),Vector2(6,6)),CREAM)
	for i in flight.targets.size():
		var target: Dictionary = flight.mission.targets[i]
		var marker := origin+Vector2(float(target.x)/float(flight.mission.width)*260,22+(float(target.y)-470)/8)
		draw_circle(marker,3,Color("a7bd90") if flight.targets[i]==FlightModel.Survivor.RESCUED else ORANGE)
	var plane := origin+Vector2(flight.position.x/float(flight.mission.width)*260,clampf(22+(flight.position.y-470)/8,14,60))
	draw_colored_polygon(PackedVector2Array([plane+Vector2(-4,0),plane+Vector2(0,-6),plane+Vector2(4,0)]),ORANGE)

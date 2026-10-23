class_name FlightModel
extends RefCounted
## Deterministic simulation shared by the game and headless mission tests.

signal cue(kind: String)

enum Status { READY, PLAYING, PAUSED, COMPLETE, FAILED }
enum Winch { STOWED, LOWERING, RETRIEVING, READY_TO_HOIST }
enum Survivor { WAITING, ATTACHED, RESCUED }

var altitude_assist := false
var ground_tether := true
var auto_hoist := false
var altitude_hold_y := 305.0
var crew_index := -1
var crew_x := 0.0
var crew_state := 0 # 0 walking, 1 helping, 2 escorting
var crew_progress := 0.0

var mission: Dictionary
var status: Status = Status.READY
var winch: Winch = Winch.STOWED
var targets: Array[int] = []
var position := Vector2(510, 305)
var velocity := Vector2.ZERO
var facing := 1
var fuel := 100.0
var health := 3
var rescued := 0
var elapsed := 0.0
var clock := 0.0
var cable := 0.0
var attached := -1
const PICKUP_TIME := 3.0
var contact := -1
var pickup_progress := 0.0
var contact_cable := 0.0
const HOOK_RADIUS := 6.0
const WINCH_MOUNT := Vector2(4,-34)
const MAX_CABLE := 412.0
const PICKUP_RADIUS := 32.0
var contact_anchor := Vector2.ZERO
var tether_tension := 0.0
const TETHER_LIMIT := 180.0
var overload_warning := 0.0
var swing := 0.0
var swing_speed := 0.0
var obstacles: Array[Dictionary] = []
var trees: Array[Dictionary] = []
var birds: Array[Dictionary] = []
var invincible := 0.0
var message := "Rescue crew ready. You are cleared for takeoff."

func _init(operation: Dictionary) -> void:
	mission = operation
	for target in mission.targets:
		targets.append(Survivor.WAITING)
	message = mission.description
	_build_world()
	for i in 5:
		birds.append({"dead": false, "position": Vector2.ZERO, "velocity": Vector2.ZERO, "age": 0.0, "grounded": false})

func pickup_duration(index: int) -> float:
	var target: Dictionary = mission.targets[index]
	if target.has("pickup_seconds"):
		return maxf(PICKUP_TIME, float(target.pickup_seconds))
	var duration := PICKUP_TIME
	if float(mission.wind) >= 15:
		duration += 1 # Exposed site: additional time securing the patient.
	for hazard: Dictionary in mission.hazards:
		var distance := absf(float(hazard.x) - float(target.x))
		if hazard.type == "tower":
			distance = minf(distance, absf(wire_points(hazard)[-1].x - float(target.x)))
		if distance < 200:
			duration += 1 # Nearby obstacles require a more careful loading procedure.
			break
	return duration

func pickup_center(index: int) -> Vector2:
	var target: Dictionary = mission.targets[index]
	return Vector2(float(target.x),float(target.y)-38)

func hook_in_pickup_zone(index: int, hook: Vector2) -> bool:
	var edge_tolerance := 6.0 if contact == index else 0.0
	return hook.distance_to(pickup_center(index)) <= PICKUP_RADIUS + HOOK_RADIUS + edge_tolerance

func tether_force() -> Vector2:
	tether_tension = 0.0
	if not ground_tether or contact < 0 or winch not in [Winch.LOWERING,Winch.READY_TO_HOIST]:
		return Vector2.ZERO
	var away := winch_origin() - contact_anchor
	var extension := away.length() - contact_cable
	if extension <= 0:
		return Vector2.ZERO # A slack rope cannot push or hold altitude.
	var direction := away.normalized()
	tether_tension = maxf(0,extension * 8 + velocity.dot(direction) * 1.8)
	return -direction * minf(tether_tension,140)

func pickup_candidate(hook: Vector2) -> int:
	for i in targets.size():
		if mission.targets[i].get("mode", "winch") != "landing" and (targets[i] == Survivor.WAITING or contact == i) and hook_in_pickup_zone(i,hook):
			return i
	return -1

func winch_points() -> PackedVector2Array:
	var origin := winch_origin()
	var hook := hook_position()
	if not (ground_tether and contact>=0):
		return PackedVector2Array([origin,hook])
	var distance := origin.distance_to(hook)
	var bow := minf(45,sqrt(maxf(0,cable*cable-distance*distance))*0.45)
	var points := PackedVector2Array()
	for i in 13:
		var t := i/12.0
		points.append(origin.lerp(hook,t)+Vector2(bow*4*t*(1-t),0))
	return points

func rig_position() -> Vector2:
	var hook := hook_position()
	# Crew can stand on the rescue ledge while the hook is in the body-sized zone.
	# Other terrain, cliffs and obstacles still collide normally.
	var candidate := pickup_candidate(hook) if winch in [Winch.LOWERING,Winch.READY_TO_HOIST] else -1
	if candidate >= 0:
		hook.y = float(mission.targets[candidate].y)-35 if ground_tether and contact>=0 else minf(hook.y,float(mission.targets[candidate].y)-35)
	return hook

func ground(x: float) -> float:
	var points: Array = mission.terrain
	for i in range(1, points.size()):
		if x <= float(points[i].x):
			var a: Dictionary = points[i - 1]
			var b: Dictionary = points[i]
			return lerpf(float(a.y), float(b.y), clampf((x - float(a.x)) / (float(b.x) - float(a.x)), 0, 1))
	return float(points.back().y)

func set_assists(altitude: bool, tether: bool, hoist: bool) -> void:
	if altitude != altitude_assist:
		altitude_hold_y = position.y
	altitude_assist = altitude
	if tether != ground_tether:
		var hook := hook_position()
		if ground_tether:
			_release_anchor()
		ground_tether = tether
		if contact >= 0:
			contact_anchor = hook
			contact_cable = cable
		tether_tension = 0
	auto_hoist = hoist

func _release_anchor() -> void:
	if not ground_tether or contact < 0:
		return
	var offset := contact_anchor - winch_origin()
	cable = offset.length()
	swing = atan2(offset.x,offset.y)
	swing_speed = 0

func landing_site() -> int:
	for i in targets.size():
		var target: Dictionary = mission.targets[i]
		if target.get("mode", "winch") == "landing" and absf(position.x-float(target.landing_x)) < 32:
			return i
	return -1

func can_disembark() -> bool:
	var site := landing_site()
	return site >= 0 and targets[site]==Survivor.WAITING and winch==Winch.STOWED and position.y>=ground(position.x)-58 and velocity.length()<10

func _crew_action() -> void:
	var target: Dictionary = mission.targets[crew_index]
	if absf(crew_x-position.x) < 28 and crew_state!=1:
		if crew_state==2:
			targets[crew_index]=Survivor.RESCUED
			rescued+=1
			cue.emit("rescue")
		crew_index=-1
		crew_state=0
		message="Crew aboard. Return to base." if rescued==targets.size() else "Crew aboard. Flight controls restored."
	elif absf(crew_x-float(target.x)) < 20 and crew_state==0:
		crew_state=1
		crew_progress=0
		message="Helping the survivor. Stay still for three seconds."

func _step_crew(dt: float, steer: float) -> void:
	velocity=Vector2.ZERO
	var target: Dictionary = mission.targets[crew_index]
	if crew_state==1 and steer!=0:
		crew_state=0
		crew_progress=0
	if crew_state==1:
		crew_progress+=dt
		if crew_progress>=3:
			crew_state=2
			targets[crew_index]=Survivor.ATTACHED
			message="Survivor ready. Walk back to the helicopter; SPACE to board."
	else:
		crew_x=clampf(crew_x+steer*(55 if crew_state==2 else 90)*dt,float(target.landing_x)-40,float(target.x)+40)
		message="A / D: escort survivor back. SPACE near helicopter: board." if crew_state==2 else "A / D: walk to survivor. SPACE nearby: help."

func toggle_pause() -> void:
	if status == Status.PLAYING:
		status = Status.PAUSED
	elif status == Status.PAUSED:
		status = Status.PLAYING

func toggle_winch() -> void:
	if status == Status.READY:
		status = Status.PLAYING
	if status != Status.PLAYING:
		return
	if crew_index>=0:
		_crew_action()
		return
	if can_disembark():
		crew_index=landing_site()
		crew_x=position.x+20
		crew_state=0
		crew_progress=0
		velocity=Vector2.ZERO
		message="Rescuer controls: A / D to walk, SPACE to help or board."
		return
	if winch == Winch.STOWED:
		pickup_progress = 0
		contact = -1
		winch = Winch.LOWERING
		message = "Rescuer and stretcher deployed. Lower them to the survivor and hold steady."
	elif winch == Winch.READY_TO_HOIST:
		_release_anchor()
		contact = -1
		winch = Winch.RETRIEVING
		message = "Hoisting rescuer and patient. Keep the stretcher clear of hazards."
	elif attached == -1:
		_release_anchor()
		contact = -1
		pickup_progress = 0
		winch = Winch.RETRIEVING if winch == Winch.LOWERING else Winch.LOWERING
	cue.emit("winch")

func hit(reason: String) -> void:
	if invincible > 0 or status != Status.PLAYING:
		return
	health -= 1
	invincible = 2.7
	message = reason
	cue.emit("damage")
	if health <= 0:
		status = Status.FAILED
		message = "Critical airframe damage. Regroup and try again."


func wind_knots() -> float:
	return float(mission.wind) * (0.75 + 0.25 * sin(clock * 0.23)) * cos(clock * 0.045)

func winch_origin() -> Vector2:
	return position+(WINCH_MOUNT*Vector2(facing,1)).rotated(velocity.x*0.00045)

func hook_position() -> Vector2:
	if ground_tether and contact >= 0:
		return contact_anchor
	return winch_origin() + Vector2(sin(swing), cos(swing)) * cable

func bird_position(i: int) -> Vector2:
	if birds[i].dead:
		return birds[i].position
	return Vector2(1500 + i * 26 + sin(clock * 0.15) * 170, 200 + i % 3 * 17 + sin(clock + i) * 6)

func tree_polygon(x: float, bottom: float, height: float) -> PackedVector2Array:
	var points := PackedVector2Array([Vector2(x, bottom - height)])
	for side in [-1, 1]:
		var branch := PackedVector2Array()
		for j in range(1, 7):
			var t := j / 7.0
			var width := height * t * (0.27 + 0.035 * sin(x + j * 7 + side))
			branch.append(Vector2(x + side * width * 0.45, bottom - height + height * (t - 0.09)))
			branch.append(Vector2(x + side * width, bottom - height + height * t))
		if side == 1:
			branch.reverse()
		points.append_array(branch)
	return points

func wire_points(hazard: Dictionary) -> PackedVector2Array:
	var x := float(hazard.x)
	var top := ground(x) - float(hazard.height)
	var end_x := x + 340
	# Keep the grounded support out of the existing rescue clearing.
	for target: Dictionary in mission.targets:
		if absf(end_x - float(target.x)) < 110:
			end_x = float(target.x) - 110
	var end_top := minf(top + 23, ground(end_x) - 80)
	var points := PackedVector2Array()
	for j in 33:
		var t := j / 32.0
		points.append(Vector2(lerpf(x, end_x, t), lerpf(top, end_top, t) + 25 + 140 * t * (1 - t)))
	return points

func strip(a: Vector2, b: Vector2, radius: float) -> PackedVector2Array:
	var normal := (b - a).normalized().orthogonal() * radius
	if a == b:
		normal = Vector2(radius, 0)
	return PackedVector2Array([a + normal, b + normal, b - normal, a - normal])

func _obstacle(poly: PackedVector2Array, kind: String) -> void:
	var bounds := Rect2(poly[0], Vector2.ZERO)
	for point in poly:
		bounds = bounds.expand(point)
	obstacles.append({"poly": poly, "bounds": bounds, "kind": kind})

func _build_world() -> void:
	for i in 90:
		var x := i * 59 + fposmod(sin(i * 127.1 + 311.7) * 43758.5453, 1) * 30
		if x < 450 or x > float(mission.width):
			continue
		var clear := true
		for target: Dictionary in mission.targets:
			if absf(float(target.x) - x) < 110 or (target.get("mode", "winch")=="landing" and x>float(target.landing_x)-210 and x<float(target.x)+90):
				clear = false
		if clear:
			trees.append({"x": x, "height": 22 + fposmod(sin((i + 30) * 127.1 + 311.7) * 43758.5453, 1) * 51})
	for hazard: Dictionary in mission.hazards:
		var x := float(hazard.x)
		var bottom := ground(x)
		var top := bottom - float(hazard.height)
		if hazard.type == "tree":
			trees.append(hazard)
		elif hazard.type == "tower":
			var wire := wire_points(hazard)
			for anchor in [wire[0], wire[-1]]:
				_obstacle(strip(anchor - Vector2(0, 25), Vector2(anchor.x, ground(anchor.x)), 18), "tower")
				_obstacle(strip(anchor - Vector2(25, 0), anchor + Vector2(25, 0), 3), "tower")
			for j in range(1, wire.size()):
				_obstacle(strip(wire[j - 1], wire[j], 2), "power line")
		else:
			_obstacle(strip(Vector2(x, top), Vector2(x, bottom), 42), "fire")
	for tree in trees:
		var x := float(tree.x)
		_obstacle(tree_polygon(x, ground(x), float(tree.height)), "tree")
		_obstacle(strip(Vector2(x, ground(x) - float(tree.height) * 0.5), Vector2(x, ground(x)), 3), "tree")
	for i in range(1, mission.terrain.size()):
		var a: Dictionary = mission.terrain[i - 1]
		var b: Dictionary = mission.terrain[i]
		_obstacle(PackedVector2Array([Vector2(a.x,a.y),Vector2(b.x,b.y),Vector2(b.x,1000),Vector2(a.x,1000)]), "terrain")

func collision(poly: PackedVector2Array, allow_landing := false) -> String:
	var bounds := Rect2(poly[0], Vector2.ZERO)
	for point in poly:
		bounds = bounds.expand(point)
	for obstacle in obstacles:
		if allow_landing and obstacle.kind == "terrain":
			continue
		if bounds.intersects(obstacle.bounds) and not Geometry2D.intersect_polygons(poly, obstacle.poly).is_empty():
			return obstacle.kind
	return ""

func _update_birds(dt: float) -> void:
	for bird in birds:
		if not bird.dead:
			continue
		bird.age += dt
		if bird.grounded:
			continue
		bird.velocity += Vector2(wind_knots() * 0.5, 280) * dt
		bird.position += bird.velocity * dt
		if bird.position.y >= ground(bird.position.x) - 3:
			bird.position.y = ground(bird.position.x) - 3
			bird.grounded = true
			bird.velocity = Vector2.ZERO

func _rotor_bird_contacts() -> void:
	# Swept blade envelopes match the rendered main rotor and spinning tail rotor.
	var tail := PackedVector2Array()
	for i in 24:
		tail.append(Vector2(-155,-29) + Vector2.from_angle(TAU * i / 24) * 26)
	for rotor: PackedVector2Array in [strip(Vector2(-154,-70),Vector2(140,-70),5), tail]:
		for j in rotor.size():
			rotor[j] = (rotor[j] * Vector2(facing,1)).rotated(velocity.x * 0.00045) + position
		for i in birds.size():
			if birds[i].dead:
				continue
			var point := bird_position(i)
			var touching := Geometry2D.is_point_in_polygon(point, rotor)
			for j in rotor.size():
				if Geometry2D.get_closest_point_to_segment(point,rotor[j],rotor[(j+1)%rotor.size()]).distance_to(point) < 8:
					touching = true
			if touching:
				birds[i].position = point
				birds[i].velocity = Vector2(velocity.x * 0.3 + facing * 25, 20)
				birds[i].dead = true
				hit("Bird strike on rotor. Watch the flock.")

func _disconnect_load(reason: String) -> void:
	_release_anchor()
	if attached >= 0:
		targets[attached] = Survivor.WAITING
	attached = -1
	contact = -1
	pickup_progress = 0
	winch = Winch.RETRIEVING
	message = reason + " Line retracting; survivor remains at the beacon."

func step(dt: float, steer: float = 0, throttle: bool = false, descend: bool = false) -> void:
	if status == Status.READY and (steer != 0 or throttle or descend):
		status = Status.PLAYING
	if status == Status.PAUSED:
		return
	if status != Status.PLAYING:
		clock += dt
		return
	var remaining := dt
	while remaining > 0 and status == Status.PLAYING:
		var tick := minf(remaining, 1.0 / 120)
		_tick(tick, steer, throttle, descend)
		remaining -= tick

func _tick(dt: float, steer: float, throttle: bool, descend: bool) -> void:
	clock += dt
	_update_birds(dt)
	overload_warning = maxf(0,overload_warning-dt)
	elapsed += dt
	invincible = maxf(0, invincible - dt)
	fuel = maxf(0, fuel - dt * (0.42 if throttle else 0.2))
	if crew_index>=0:
		_step_crew(dt,steer)
		if fuel<=0:
			status=Status.FAILED
			message="Fuel depleted. Restart the mission."
		return
	if auto_hoist and winch==Winch.READY_TO_HOIST:
		toggle_winch()
	var loaded := attached >= 0
	var acceleration := steer * (320 if steer * velocity.x < 0 else 100) + wind_knots() * 0.65
	velocity.x = clampf(velocity.x + acceleration * dt, -280, 280)
	if absf(velocity.x) > 15:
		facing = 1 if velocity.x > 0 else -1
	if altitude_assist and not throttle and not descend:
		velocity.y += clampf((altitude_hold_y-position.y)*6-velocity.y*4,-160,160)*dt
	else:
		altitude_hold_y=position.y
		velocity.y += ((-125.0 if loaded else -230.0) if throttle else 160.0 if descend else 47.0)*dt
		velocity.y *= exp(-0.9*dt)
	velocity.y = clampf(velocity.y, -85 if loaded else -155, 130)
	var tether := tether_force()
	if tether_tension >= TETHER_LIMIT:
		overload_warning = 1.5
		_disconnect_load("Line tension limit exceeded.")
		cue.emit("winch")
		tether = Vector2.ZERO
	velocity += tether * dt
	var previous := position
	position += velocity * dt
	position.x = clampf(position.x, 190, float(mission.width) - 190)
	position.y = clampf(position.y, 110, 715)
	if position.y <= 110:
		velocity.y = maxf(0, velocity.y)
	var at_base := position.x > 190 and position.x < 320
	var landing := (at_base or landing_site()>=0) and velocity.y < 80 and absf(velocity.x) < 35 and cable == 0
	if landing and position.y + 56 >= ground(position.x):
		position.y = ground(position.x) - 56
		velocity.y = 0
		velocity.x *= exp(-8 * dt)
		if at_base:
			fuel = minf(100, fuel + 4 * dt)
		elif can_disembark():
			message="Landing zone reached. SPACE to control the rescuer."
		if at_base and rescued == targets.size():
			status = Status.COMPLETE
			message = "Everyone home safe. Outstanding work, Rescue One."
			cue.emit("complete")
	var shapes := [
		PackedVector2Array([Vector2(-64,-32),Vector2(30,-43),Vector2(83,0),Vector2(83,28),Vector2(-58,30)]),
		strip(Vector2(-55,0),Vector2(-167,-25),12),
		strip(Vector2(-155,-63),Vector2(-155,-4),9),
		strip(Vector2(-154,-70),Vector2(140,-70),5),
		strip(Vector2(-68,48),Vector2(92,44),4)]
	for shape: PackedVector2Array in shapes:
		for j in shape.size():
			shape[j] = (shape[j] * Vector2(facing,1)).rotated(velocity.x * 0.00045) + position
		var obstacle := collision(shape, landing)
		if obstacle != "":
			hit("Airframe contact with %s. Climb clear." % obstacle)
			position = previous
			velocity = Vector2(-velocity.x * 0.35, -65)
			break
	_rotor_bird_contacts()
	# The grounded anchor and airborne pendulum are mutually exclusive.
	if not (ground_tether and contact>=0):
		var length := maxf(cable,30)
		swing_speed += (-450/length*sin(swing)+(wind_knots()*(2.8 if loaded else 0.4)-acceleration)/length*cos(swing)-swing_speed*(0.65 if loaded else 2.5))*dt
		swing=clampf(swing+swing_speed*dt,-0.85,0.85)
	elif contact_cable-(winch_origin()).distance_to(contact_anchor)>45:
		_disconnect_load("Too much slack. Pickup contact lost.")
	if winch in [Winch.LOWERING, Winch.READY_TO_HOIST]:
		# Contact locks the spool; helicopter movement never pays out extra cable.
		cable = contact_cable if contact >= 0 else minf(MAX_CABLE, cable + dt * 115)
	elif winch == Winch.RETRIEVING:
		cable = maxf(0, cable - dt * (62 if loaded else 105))
	var hook := hook_position()
	if cable > 2:
		var rig := rig_position()
		var obstruction := ""
		# Check the whole rig so harmless ground contact cannot mask a fire/wire hit.
		var rig_shapes := [strip(hook,rig,2),strip(hook-Vector2(0,5),hook+Vector2(0,5),6),strip(rig+Vector2(0,8),rig+Vector2(0,32),30)]
		var points := winch_points()
		for i in range(1,points.size()):
			rig_shapes.append(strip(points[i-1],points[i],2))
		for shape: PackedVector2Array in rig_shapes:
			var touched := collision(shape)
			if touched != "":
				obstruction = touched
				if touched != "terrain":
					break
		if obstruction != "":
			if obstruction == "terrain":
				_disconnect_load("Ground contact — winch returning.")
			else:
				hit("Winch / load contact with %s." % obstruction)
				_disconnect_load("Contact with %s." % obstruction)
			cable = maxf(0, cable - 8)
	if winch in [Winch.LOWERING, Winch.READY_TO_HOIST]:
		if contact < 0:
			for i in targets.size():
				var target: Dictionary = mission.targets[i]
				if target.get("mode", "winch") != "landing" and targets[i] == Survivor.WAITING and hook_in_pickup_zone(i,hook):
					pickup_progress = 0
					contact = i
					contact_cable = cable
					contact_anchor = hook
					break
		if contact >= 0:
			var target: Dictionary = mission.targets[contact]
			if not hook_in_pickup_zone(contact,hook):
				_disconnect_load("Pickup contact lost.")
			elif winch == Winch.READY_TO_HOIST:
				message = "Patient secured. Press SPACE to hoist the stretcher."
			else:
				pickup_progress += dt
				message = "Loading %s: keep the hook inside the pickup zone." % target.name
				if pickup_progress >= pickup_duration(contact):
					pickup_progress = 0
					attached = contact
					targets[attached] = Survivor.ATTACHED
					winch = Winch.READY_TO_HOIST
					message = "Patient secured. Press SPACE to hoist the stretcher."
					cue.emit("winch")
	if winch == Winch.RETRIEVING and cable == 0:
		winch = Winch.STOWED
		swing = 0
		swing_speed = 0
		if attached >= 0:
			targets[attached] = Survivor.RESCUED
			rescued += 1
			attached = -1
			message = "Everyone aboard. Return left and land on the base helipad." if rescued == targets.size() else "Survivor secured. Follow the next orange beacon."
			cue.emit("rescue")
	if fuel <= 0:
		status = Status.FAILED
		message = "Fuel depleted. Land at base to refuel on your next flight."

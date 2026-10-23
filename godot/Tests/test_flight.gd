extends SceneTree

const Model = preload("res://Scripts/flight_model.gd")
const DT := 1.0 / 60
var failures := 0

func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)

func pilot(flight: FlightModel, x: float, y: float) -> void:
	var desired := clampf((x - flight.position.x) * 1.5, -220, 220)
	var delta := desired - flight.velocity.x
	var steering := 1.0 if delta > 1.8 else -1.0 if delta < -1.8 else 0.0
	var vertical := clampf((y - flight.position.y) * 1.6,-100,85) - flight.velocity.y
	flight.step(DT,steering,vertical < -3,vertical > 3)

func move_to(flight: FlightModel, x: float, y: float) -> void:
	for i in 6000:
		pilot(flight,x,y)
		if flight.can_disembark() and y>=flight.ground(x)-56:
			break
		if flight.status == FlightModel.Status.FAILED:
			break
		if flight.position.distance_to(Vector2(x,y)) < 3 and flight.velocity.length() < 6:
			break

func _initialize() -> void:
	var missions: Array = JSON.parse_string(FileAccess.get_file_as_string("res://Assets/missions.json"))
	for mission: Dictionary in missions:
		var flight := Model.new(mission)
		for i in mission.targets.size():
			if mission.targets[i].get("mode","winch")=="landing":
				var target: Dictionary=mission.targets[i]
				move_to(flight,flight.position.x,110)
				move_to(flight,float(target.landing_x),110)
				move_to(flight,float(target.landing_x),float(target.y)-50)
				flight.toggle_winch()
				check(flight.crew_index==i,"Landing must allow crew disembarkation")
				for j in 600:
					flight.step(DT,1)
					if absf(flight.crew_x-float(target.x))<10: break
				flight.toggle_winch()
				for j in 190: flight.step(DT)
				check(flight.crew_state==2,"Ground survivor must be ready to escort")
				for j in 600:
					flight.step(DT,-1)
					if absf(flight.crew_x-flight.position.x)<10: break
				flight.toggle_winch()
				check(flight.rescued==i+1 and flight.crew_index==-1,"Ground survivor and rescuer must board")
				continue
			move_to(flight,flight.position.x,110)
			move_to(flight,float(mission.targets[i].x),110)
			var hover_y := float(mission.targets[i].y) - 230
			move_to(flight,float(mission.targets[i].x),hover_y)
			flight.toggle_winch()
			for j in 1200:
				if flight.winch == FlightModel.Winch.READY_TO_HOIST:
					flight.toggle_winch()
				pilot(flight,float(mission.targets[i].x),hover_y)
				if flight.rescued > i or flight.status == FlightModel.Status.FAILED:
					break
			check(flight.rescued == i + 1, "%s: survivor %s was not rescued: %s" % [mission.name, i, flight.message])
		move_to(flight,flight.position.x,110)
		move_to(flight,245,110)
		move_to(flight,245,flight.ground(245)-50)
		check(flight.status == FlightModel.Status.COMPLETE, "%s: flight did not finish (health %s, fuel %s)" % [mission.name, flight.health, flight.fuel])
		print("%s: rescued %d, health %d, fuel %.1f, status %d" % [mission.name, flight.rescued, flight.health, flight.fuel, flight.status])
	var paused := Model.new(missions[0])
	paused.step(DT, 1)
	paused.toggle_pause()
	var before := paused.position
	var before_fuel := paused.fuel
	paused.step(5, 1, true)
	check(paused.position == before and paused.fuel == before_fuel, "Paused flight advanced")
	paused.toggle_pause()
	paused.hit("test")
	paused.hit("test")
	check(paused.health == 2, "Damage cooldown did not protect the airframe")
	paused.invincible = 0
	paused.hit("test")
	paused.invincible = 0
	paused.hit("test")
	check(paused.status == FlightModel.Status.FAILED, "Critical damage did not fail the mission")
	var empty := Model.new(missions[0])
	empty.fuel = 0.001
	empty.step(1, 0, true)
	check(empty.status == FlightModel.Status.FAILED, "Empty fuel did not fail the mission")
	print("Flight checks: %d failures" % failures)
	quit(1 if failures else 0)

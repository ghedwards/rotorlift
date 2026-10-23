extends SceneTree
const Model = preload("res://Scripts/flight_model.gd")
const DT := 1.0 / 60
var failures := 0

func check(ok: bool, description: String) -> void:
	if not ok:
		failures += 1
		push_error(description)

func make_flight() -> FlightModel:
	var mission := {"description":"Test", "width":3000,"wind":0,"terrain":[{"x":0,"y":700},{"x":3000,"y":700}],"targets":[{"x":1100,"y":700,"name":"Test"}],"hazards":[]}
	var f := Model.new(mission)
	f.status = FlightModel.Status.PLAYING
	f.position = Vector2(1100,450)
	return f

func advance(f: FlightModel, seconds: float, steer := 0.0, up := false, down := false) -> void:
	for i in int(seconds / DT):
		f.step(DT,steer,up,down)

func hold_height(f: FlightModel, seconds: float, height: float) -> void:
	for i in int(seconds / DT):
		var desired := clampf((height-f.position.y)*1.6,-50,50)
		f.step(DT,0,f.velocity.y>desired+1)

func contact_flight() -> FlightModel:
	var f := make_flight()
	f.toggle_winch()
	for i in 240:
		hold_height(f,DT,450)
		if f.contact >= 0:
			break
	return f

func _initialize() -> void:
	var f := make_flight()
	f.cable = 0
	advance(f,0.5,1)
	var speed := f.velocity.x
	advance(f,0.5,1)
	check(f.velocity.x > speed + 40,"Holding direction must build speed")
	speed = f.velocity.x
	advance(f,0.2)
	check(absf(f.velocity.x-speed)<0.01,"Release must coast")
	advance(f,0.2,-1)
	check(f.velocity.x < speed-50,"Opposite direction must brake")
	f = make_flight()
	f.mission.wind = 20
	f.toggle_winch()
	advance(f,0.5)
	check(f.velocity.x>4,"Wind must push without steering")
	f = contact_flight()
	check(f.contact==0,"Hook should contact survivor")
	var length := f.cable
	hold_height(f,1,450)
	check(f.attached==-1 and f.cable==length,"Contact must stop extension and wait three seconds")
	f.velocity.x=30
	f.step(DT)
	check(f.pickup_progress>1,"Motion inside pickup zone must not reset loading")
	for offset in [-90,90]:
		f=contact_flight()
		f.position.y+=offset
		f.step(DT)
		check(f.contact==-1 and f.winch==FlightModel.Winch.RETRIEVING,"Vertical contact loss must retract")
	# Real detach/redeploy cycle: progress from the first attempt cannot carry over.
	for offset in [-90,90]:
		f=contact_flight()
		hold_height(f,1.2,450)
		check(f.pickup_progress>1,"First attachment must accumulate progress")
		var locked_length := f.cable
		f.position.y+=offset
		f.step(DT)
		check(f.pickup_progress==0 and f.attached==-1,"Detachment must discard all pickup progress")
		var released_length := f.cable
		f.step(DT)
		check(f.cable<released_length,"Released spool must retract")
		hold_height(f,3,450)
		check(f.winch==FlightModel.Winch.STOWED,"Cancelled line must finish retracting")
		f.toggle_winch()
		for j in 240:
			hold_height(f,DT,450)
			if f.contact>=0: break
		check(f.contact==0 and f.pickup_progress<0.1,"Reattachment starts a new countdown")
		locked_length=f.cable
		hold_height(f,2.8,450)
		check(f.attached==-1 and f.cable==locked_length,"Reattachment must hold fixed length for the full countdown: %s, contact %s, progress %s" % [f.message,f.contact,f.pickup_progress])
		hold_height(f,0.3,450)
		check(f.attached==0,"Fresh uninterrupted hold should complete pickup")
	f=contact_flight()
	hold_height(f,3.1,450)
	check(f.attached==0,"Steady three-second hold attaches survivor")
	f.toggle_winch()
	var loaded := f
	var unloaded := make_flight()
	unloaded.position=loaded.position
	unloaded.toggle_winch()
	advance(loaded,0.4,1,true)
	advance(unloaded,0.4,1,true)
	check(absf(loaded.velocity.y)<absf(unloaded.velocity.y),"Suspended load must slow climb")
	check(absf(loaded.swing)>0.01,"Load must sway with acceleration")
	# Every pickup, including subsequent survivors, starts a fresh timer.
	f=make_flight()
	f.pickup_progress=2.0
	f.toggle_winch()
	check(f.pickup_progress==0,"New deployment must clear previous pickup progress")
	f.pickup_progress=2.0
	f.cable=160
	for i in 120:
		hold_height(f,DT,450)
		if f.contact>=0: break
	check(f.contact==0 and f.pickup_progress<0.1 and f.attached==-1,"New contact must not reuse previous survivor timer")
	hold_height(f,2.8,450)
	check(f.attached==-1,"Subsequent survivor must wait full three seconds")
	hold_height(f,0.3,450)
	check(f.attached==0,"Subsequent survivor attaches after full hold")
	for state in [FlightModel.Winch.STOWED,FlightModel.Winch.LOWERING,FlightModel.Winch.RETRIEVING]:
		f=make_flight()
		f.winch=state
		f.cable=100 if state!=FlightModel.Winch.STOWED else 0
		advance(f,0.3)
		check(f.velocity.y>10 and f.position.y>451,"No altitude hold in winch state %s" % state)
	# Loading completion must wait for a separate hoist command.
	f=contact_flight()
	hold_height(f,3.1,450)
	check(f.winch==FlightModel.Winch.READY_TO_HOIST and f.rescued==0,"Loading must wait for manual hoist")
	var ready_length := f.cable
	hold_height(f,0.4,450)
	check(f.cable==ready_length and f.winch==FlightModel.Winch.READY_TO_HOIST,"No automatic hoisting after loading")
	f.toggle_winch()
	hold_height(f,0.4,450)
	check(f.winch==FlightModel.Winch.RETRIEVING and f.cable<ready_length,"Hoist command must lift stretcher")
	hold_height(f,5,450)
	check(f.rescued==1 and f.winch==FlightModel.Winch.STOWED,"Patient counted only when stretcher arrives aboard")
	f=make_flight()
	check(f.pickup_duration(0)==3,"Clear pickup must take three seconds")
	f.mission.wind=20
	check(f.pickup_duration(0)==4,"Exposed pickup must take longer")
	f.mission.hazards.append({"type":"fire","x":1200,"height":100})
	check(f.pickup_duration(0)==5,"Exposed hazardous pickup must take five seconds")
	# Angled pickups use the actual hook, with no helicopter-centering requirement.
	f=make_flight()
	f.position=Vector2(1040,450)
	f.cable=260
	f.swing=asin((1100-f.winch_origin().x)/f.cable)
	f.winch=FlightModel.Winch.LOWERING
	f.step(DT)
	check(f.contact==0,"Angled hook inside the circle must start loading")
	var pickup_center := f.pickup_center(0)
	check(f.hook_in_pickup_zone(0,pickup_center+Vector2(37,0)),"Hook edge overlap should count")
	check(not f.hook_in_pickup_zone(0,pickup_center+Vector2(45,0)),"Hook wholly outside circle must not count")
	f=contact_flight()
	f.position+=Vector2(10,-8)
	var tension := f.tether_force()
	check(tension.x<0 and tension.y>0,"Taut ground tether must resist drifting and climbing away")
	f.position.y+=20
	check(f.tether_force()==Vector2.ZERO,"Slack tether must not provide altitude assist")
	f=contact_flight()
	f.position.y-=25
	f.step(DT)
	check(f.overload_warning>0 and f.contact==-1 and f.pickup_progress==0 and f.winch==FlightModel.Winch.RETRIEVING,"Exceeding tension limit must release and reset loading")
	# All eight combinations remain independent.
	for altitude in [false,true]:
		for tether in [false,true]:
			for auto in [false,true]:
				f=make_flight()
				f.set_assists(altitude,tether,auto)
				f.toggle_winch()
				for j in 240:
					hold_height(f,DT,450)
					if f.contact>=0: break
				hold_height(f,3.2,450)
				check(f.attached==0,"Every assist combination must support loading")
				check(f.winch==(FlightModel.Winch.RETRIEVING if auto else FlightModel.Winch.READY_TO_HOIST),"Auto-hoist must be independent of altitude and tether")
	f=make_flight()
	f.set_assists(true,false,false)
	advance(f,0.5)
	check(absf(f.position.y-450)<0.1,"Altitude assist must hold current height")
	f.set_assists(false,false,false)
	advance(f,0.5)
	check(f.position.y>453,"Turning altitude assist off restores descent")
	f=contact_flight()
	var anchor := f.hook_position()
	f.position+=Vector2(10,-5)
	f.step(DT)
	check(f.hook_position()==anchor,"Grounded hook must stay at its anchor while helicopter moves")
	f.winch=FlightModel.Winch.READY_TO_HOIST
	f.toggle_winch()
	check(f.hook_position().distance_to(anchor)<0.01,"Hoisting must release anchor without hook teleportation")
	f=contact_flight()
	anchor=f.hook_position()
	f.set_assists(false,false,false)
	check(f.hook_position().distance_to(anchor)<0.01,"Disabling tether must preserve hook position")
	f.position.x+=10
	check(f.hook_position().distance_to(anchor)>9,"Tether off must let the hook move freely")
	# Ground controls require a landing and return to flight only after boarding.
	f=make_flight()
	f.mission.targets[0].mode="landing"
	f.mission.targets[0].landing_x=960
	f.position=Vector2(960,600)
	check(not f.can_disembark(),"Airborne crew must not disembark")
	f.position.y=644
	check(f.can_disembark(),"Landed crew should be able to disembark")
	f.toggle_winch()
	var parked := f.position
	advance(f,0.5,1,true)
	check(f.position==parked and f.crew_x>parked.x+20,"Ground movement must control rescuer, not helicopter")
	f.crew_x=1100
	f.toggle_winch()
	advance(f,1)
	check(f.crew_state==1 and f.crew_progress>0.9,"Ground help must take time")
	f.step(DT,1)
	check(f.crew_state==0 and f.crew_progress==0,"Moving interrupts ground help")
	f.toggle_winch()
	advance(f,3.1)
	check(f.crew_state==2 and f.rescued==0,"Helping must not count as rescued until boarding")
	f.toggle_pause()
	var crew_before := f.crew_x
	advance(f,0.5,-1)
	check(f.crew_x==crew_before,"Paused ground rescuer must not move")
	f.toggle_pause()
	f.crew_x=f.position.x+10
	f.toggle_winch()
	check(f.rescued==1 and f.crew_index==-1,"Both ground crew and survivor must board")
	f.obstacles.clear()
	advance(f,0.2,0,true)
	check(f.position.y<parked.y,"Boarding must restore helicopter controls")
	# Each component can independently hit each obstacle type, including fire.
	for kind in ["tree","tower","power line","terrain","fire"]:
		for component in ["airframe","line","hook","person"]:
			f=make_flight()
			f.obstacles.clear()
			f.cable=120
			f.winch=FlightModel.Winch.RETRIEVING
			var center := f.position
			if component=="line": center+=Vector2(0,85)
			if component=="hook": center=f.hook_position()+Vector2(5,0)
			if component=="person":
				f.attached=0
				f.targets[0]=FlightModel.Survivor.ATTACHED
				center=f.hook_position()+Vector2(0,24)
			f._obstacle(f.strip(center-Vector2(0,3),center+Vector2(0,3),3),kind)
			f.step(DT)
			var expected_health := 3 if kind=="terrain" and component!="airframe" else 2
			check(f.health==expected_health,"%s contact with %s has incorrect damage" % [component,kind])
			if component!="airframe":
				check(f.attached==-1 and f.winch==FlightModel.Winch.RETRIEVING,"Load collision must disconnect/retract")
	f=make_flight()
	f.position=Vector2(1100,450)
	f.cable=210
	f.winch=FlightModel.Winch.LOWERING
	f.position.x=1300
	f.obstacles.assign(f.obstacles.filter(func(obstacle: Dictionary) -> bool: return obstacle.kind=="terrain"))
	advance(f,0.5)
	check(f.health==3 and f.winch==FlightModel.Winch.RETRIEVING,"Ground must retract winch without damage")
	# Ground on the cable must not hide a simultaneous fire contact on the load.
	f=make_flight()
	f.obstacles.clear()
	f.cable=120
	f.winch=FlightModel.Winch.RETRIEVING
	var cable_point := f.position+Vector2(0,85)
	var load_point := f.hook_position()+Vector2(0,24)
	f._obstacle(f.strip(cable_point-Vector2(0,3),cable_point+Vector2(0,3),3),"terrain")
	f._obstacle(f.strip(load_point-Vector2(0,3),load_point+Vector2(0,3),3),"fire")
	f.step(DT)
	check(f.health==2,"Fire damage must take priority over ground retraction")
	for component in ["body","line","hook","person","main rotor","tail rotor"]:
		f=make_flight()
		f.obstacles.clear()
		var point := f.bird_position(0)
		f.position=point
		if component=="main rotor": f.position=point+Vector2(0,70)
		if component=="tail rotor": f.position=point+Vector2(155,29)
		if component in ["line","hook","person"]:
			f.cable=40
			f.winch=FlightModel.Winch.RETRIEVING
			f.position=point-Vector2(0,60 if component=="line" else 83 if component=="hook" else 105)
			if component=="person":
				f.attached=0
				f.targets[0]=FlightModel.Survivor.ATTACHED
		f.step(DT)
		var rotor: bool = component.ends_with("rotor")
		check(f.birds[0].dead==rotor,"Only rotors should kill birds: %s" % component)
		check(f.health==(2 if rotor else 3),"Only rotor bird strikes should damage helicopter: %s" % component)
		if rotor:
			var struck_at := f.bird_position(0)
			f.toggle_pause()
			advance(f,0.2)
			check(f.bird_position(0)==struck_at,"Paused birds must not fall")
			f.toggle_pause()
			f.position=Vector2(1100,450)
			advance(f,0.3)
			check(f.bird_position(0).y>struck_at.y+10,"Struck bird must fall")
			# Isolate the fallen bird from the remaining live flock.
			for i in range(1,f.birds.size()):
				f.birds[i].dead=true
			f.invincible=0
			f.position=f.bird_position(0)+Vector2(0,70)
			f.velocity=Vector2.ZERO
			f.step(DT)
			check(f.health==2,"Dead birds must not cause repeat damage")
	print("Rescue and hazard checks: %d failures" % failures)
	quit(1 if failures else 0)

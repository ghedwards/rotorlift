# Rotorlift — Godot edition

Built for **Godot 4.7.2 stable**, using typed GDScript and the Compatibility renderer. The standard Godot editor is sufficient; .NET is not required.

## Play

1. Import `project.godot` in Godot 4.7.2.
2. Press **F6** to play the main scene, or **F5** to run the project.
3. Choose Pine Ridge, Storm Coast, or Ember Valley from the mission selector in Settings.

Hold a direction to build speed, release to coast, and press the opposite direction to brake. Wind pushes the helicopter even without steering. Each mission has five winch rescues and one landing rescue, for six survivors total. The routes extend 1,800 world units beyond the original maps (about 35–38% longer). Landing rescues occupy their own far-end clearings, separated from every winch pickup.

The **Settings** cog independently controls **Altitude hold**, **Ground tether**, and **Auto-hoist**. Choices persist across missions and restarts. Defaults preserve manual altitude and manual hoisting, with the ground tether enabled. Altitude hold maintains height when vertical controls are released; W/S still override it.

For a winch rescue, Space lowers a rescue specialist and stretcher from the hoist above the open side door. The rescuer waits in the doorway while aboard; the cable mount follows the aircraft facing and bank. A pickup circle appears as the hook approaches. Any hook overlap starts loading; a faint outer rim provides a small tolerance against boundary jitter. With the tether off, keep the swinging hook inside the circle for the full loading period. With the tether on, the hook anchors at contact, the cable length locks, and a slack rope visibly bows. A taut rope resists climbing or drifting away. The right-side tension meter releases the line at 100%; descending enough to leave excessive slack also cancels the attempt. The anchor releases smoothly when hoisting or disabling the tether. The ground tether itself provides no altitude hold.

Loading takes three seconds at a clear site, plus one second for strong wind (mission wind at least 15 knots) and one for a hazard within 200 world units. A mission can explicitly set `pickup_seconds` per survivor (minimum three). Every cancelled attempt clears all progress. Once the patient is ready, press Space to hoist, or enable Auto-hoist. The stretcher sways with acceleration and wind, retracts more slowly, and reduces climb performance.

The home base has a permanent concrete helipad, hangar, fuel point, and lighting. Remote landing zones are rough clearings with temporary fabric markers, flags, and clear approach labels.

For a landing rescue, land gently in the marked **FIELD LANDING** clearing and press Space to send the rescuer out. A/D now move the rescuer. Press Space near the survivor and stay still for three seconds to help them, then escort them back. Press Space near the helicopter to board both people and restore flight controls. Moving during treatment resets that attempt. The helicopter stays parked while the crew is outside; Space near the aircraft also lets the rescuer board without a patient if you need to cancel the ground excursion.

Birds only strike the main or tail rotors, then tumble and fade. Trees, power lines, and fire damage the helicopter or winch assembly. Ground contact with the line, hook, rescuer, or stretcher cancels the winch attempt and retracts without damage; helicopter terrain collisions still cause damage. A load collision returns the survivor to their beacon for another try. Once all six survivors are aboard, return left and land gently on the base helipad. Landing at base replenishes fuel. Completed missions are saved in Godot's user-data directory.

| Action | Keyboard |
| --- | --- |
| Steer | A / D or Left / Right |
| Climb | Hold W or Up |
| Descend | Hold S or Down |
| Winch / ground rescue interaction | Space or E |
| Pause / resume | P or Escape |
| Restart | R |
| Fullscreen | F11 or utility icon |

On-screen controls also accept mouse and touch input. The initial layout is intended for desktop and landscape screens; portrait mobile layout and device testing are follow-up work. Sound is muted initially; enable it in the header for winch, rescue, damage, and completion cues.

## Verify

With `godot` pointing to the Godot 4.7.2 executable:

```sh
godot --headless --path . --editor --import --quit
godot --headless --path . --script Tests/test_flight.gd
godot --headless --path . --script Tests/test_rescue.gd
godot --headless --path . --script Tests/test_scene.gd
```

The headless checks fly all three missions, rescue every survivor, return to base, and check pause, damage cooldown, critical damage, and fuel depletion.

## Export to a browser

Install the matching **4.7.2 export templates** using **Editor → Manage Export Templates**. The `Web` preset uses a single thread, so it does not require cross-origin isolation headers.

```sh
mkdir -p builds/web
godot --headless --path . --export-release Web builds/web/index.html
python3 -m http.server 8080 --directory builds/web
```

Open `http://localhost:8080`. Serve the whole export directory; opening the HTML directly with `file://` is unsupported. Use HTTPS in production and gzip/Brotli for the `.wasm` and `.pck` files.

## Structure

- `Scripts/flight_model.gd`: simulation, winch, collisions, fuel, mission outcomes.
- `Scripts/flight_view.gd`: terrain, hazards, helicopter, survivor and cable rendering.
- `Scripts/main.gd`: input, HUD, menus, fullscreen, audio cues and saved progress.
- `Assets/missions.json`: mission definitions ported from the original TypeScript game.
- `Assets/*.png`: original backdrop artwork.
- `Tests/test_flight.gd`: deterministic mission checks.

The visual system follows the original HTML game: bundled Barlow Condensed, DM Sans and IBM Plex Mono fonts; orange rescue livery; fuel and integrity meters; radio, altitude, speed and route overlays; a compact flight deck; and pause, result and manual screens. Fonts are bundled under their accompanying SIL Open Font Licenses in `Assets/Fonts/`.

The three original missions now include landing rescues alongside momentum flight, physical wind, timed winch pickups, suspended-load collisions, and independent difficulty assists. Continuous rotor audio, a dedicated mission-briefing screen, portrait mobile layout and device testing remain follow-up work.

## Character animation

Survivors wave in staggered twelve-frame cycles with idle breaks. The rescuer runs when alone, walks while escorting, idles when stopped, and works during treatment. Escort characters follow the travel direction; stride phase advances with distance, and animation pauses with the simulation. The doorway and winch crew use idle/working poses. Editable SVG atlases live in `Assets/Art/Characters/`; regenerate them with `python3 Tools/generate_character_animation.py`. Run `godot --headless --path . --script Tests/test_animation.gd` to check state tracking.

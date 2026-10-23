# Static artwork

These SVGs are original Rotorlift artwork, initially extracted from the former drawing commands in `Scripts/flight_view.gd`. Edit the SVG files directly to change the illustrations; no runtime SVG generation is used.

- `survivor-wave-0.svg`, `survivor-wave-1.svg`: waving survivor poses, feet at `(0, 0)`.
- `rescuer.svg`, `rescuer-working.svg`: helmeted crew poses with visible harnesses, feet at `(0, 0)`.
- `stretcher-patient.svg`: horizontal patient aligned to the rescue rig.
- `helicopter-body.svg`: refined curved silhouette, cockpit glazing and open cabin; static airframe, open door, cockpit, landing skids and winch mount. Local origin `(0, 0)` is the helicopter's simulation position; the SVG viewBox is `-190 -80 290 135`.
- `helicopter-body-flash.svg`: matching damage-flash variant (main fuselage paint only).
- `field-landing-pad.svg`: temporary landing mat and rough clearing, with local ground origin and viewBox `-100 -6 200 24`.
- `rescue-base.svg`: hangar, antenna, helipad and fuel point. Origin is the ground baseline; viewBox `0 -132 470 164`.

Godot imports these as textures. The rotor animation, crew, wind sock, winch and hook remain dynamic. Trees and powerlines still use the shared model geometry so their artwork matches collision shapes. Terrain, fire, smoke, pickup rings and HUD meters remain procedural because they change with the simulation.

The existing alpine, coastal and wildfire backdrops are already external PNG assets. External UI icon sources and their license are documented in `../Icons/SOURCES.md`.

The current animated characters use seven twelve-frame atlases in `Characters/`. The previous standalone poses remain as editable references. Atlas cells are 50 × 50 world units, rasterized at 3× resolution. See `Tools/generate_character_animation.py` for the reproducible animation source.

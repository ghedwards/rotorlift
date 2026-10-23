import type { Hazard, Mission } from "./scenarios";

export type GameStatus = "ready" | "playing" | "paused" | "complete" | "failed";
export type Control = "left" | "right" | "throttle" | "descend";
export type TargetStatus = "waiting" | "attached" | "rescued";
export type Snapshot = {
  missionId: string;
  status: GameStatus;
  fuel: number;
  health: number;
  rescued: number;
  elapsed: number;
  altitude: number;
  speed: number;
  x: number;
  winch: "stowed" | "lowering" | "retrieving";
  message: string;
  targetStates: TargetStatus[];
  controls: Record<Control, boolean>;
};

export const INITIAL_SNAPSHOT: Snapshot = {
  missionId: "01",
  status: "ready",
  fuel: 100,
  health: 3,
  rescued: 0,
  elapsed: 0,
  altitude: 230,
  speed: 0,
  x: 510,
  winch: "stowed",
  message: "Three hikers need a way home. You are cleared for takeoff.",
  targetStates: ["waiting", "waiting", "waiting"],
  controls: { left: false, right: false, throttle: false, descend: false },
};

const HEIGHT = 760;
const clamp = (n: number, min: number, max: number) =>
  Math.max(min, Math.min(max, n));
const noise = (seed: number) => {
  const n = Math.sin(seed * 127.1 + 311.7) * 43758.5453;
  return n - Math.floor(n);
};

export class RescueGame {
  private canvas: HTMLCanvasElement;
  private ctx: CanvasRenderingContext2D;
  private mission: Mission;
  private onUpdate: (snapshot: Snapshot) => void;
  private onSound: (type: "rescue" | "damage" | "complete" | "winch") => void;
  private observer: ResizeObserver;
  private frame = 0;
  private lastTime = 0;
  private lastPublish = 0;
  private width = 1680;
  private camera = 0;
  private background = new Image();
  private backgroundReady = false;
  private clock = 0;
  private invincible = 0;
  private x = 510;
  private y = 305;
  private vx = 0;
  private vy = 0;
  private facing = 1;
  private cable = 0;
  private attached = -1;
  private state: Snapshot;
  private activeKeys = new Set<string>();

  constructor(
    canvas: HTMLCanvasElement,
    mission: Mission,
    onUpdate: (snapshot: Snapshot) => void,
    onSound: (type: "rescue" | "damage" | "complete" | "winch") => void,
  ) {
    this.canvas = canvas;
    this.ctx = canvas.getContext("2d")!;
    this.mission = mission;
    this.onUpdate = onUpdate;
    this.onSound = onSound;
    this.state = {
      ...INITIAL_SNAPSHOT,
      missionId: mission.id,
      controls: { ...INITIAL_SNAPSHOT.controls },
      targetStates: mission.targets.map(() => "waiting"),
      message:
        mission.theme === "coast"
          ? "The crew is stranded along the coast. Watch those crosswinds."
          : mission.theme === "fire"
            ? "The fire crew needs an exit. Keep clear of the updrafts."
            : INITIAL_SNAPSHOT.message,
    };
    this.background.onload = () => {
      this.backgroundReady = true;
    };
    this.background.src = mission.image;
    this.observer = new ResizeObserver(() => this.resize());
    this.observer.observe(canvas);
    this.resize();
    window.addEventListener("keydown", this.keyDown);
    window.addEventListener("keyup", this.keyUp);
    window.addEventListener("blur", this.blur);
    this.publish();
    this.frame = requestAnimationFrame(this.tick);
  }

  private resize() {
    const { width, height } = this.canvas.getBoundingClientRect();
    if (!width || !height) return;
    const dpr = Math.min(window.devicePixelRatio || 1, 2);
    this.canvas.width = Math.round(width * dpr);
    this.canvas.height = Math.round(height * dpr);
    this.width = (HEIGHT * width) / height;
  }

  start() {
    if (this.state.status !== "ready") return;
    this.state.status = "playing";
    this.state.message =
      "Head right to the orange beacon. Hover above the survivor and deploy your winch.";
    this.publish();
  }

  setControl(control: Control, pressed: boolean) {
    if (
      pressed &&
      this.state.status !== "ready" &&
      this.state.status !== "playing"
    )
      return;
    if (pressed && this.state.status === "ready") this.start();
    this.state.controls[control] = pressed;
    this.publish();
  }

  toggleWinch() {
    if (this.state.status === "ready") this.start();
    if (this.state.status !== "playing") return;
    if (this.state.winch === "stowed") {
      this.state.winch = "lowering";
      this.state.message =
        "Winch deployed. Hover directly over a survivor. Flight assist is holding your altitude.";
    } else if (this.attached === -1) {
      this.state.winch =
        this.state.winch === "lowering" ? "retrieving" : "lowering";
    }
    this.onSound("winch");
    this.publish();
  }

  pause() {
    if (this.state.status !== "playing") return;
    this.state.status = "paused";
    this.clearControls();
    this.publish();
  }

  resume() {
    if (this.state.status !== "paused") return;
    this.state.status = "playing";
    this.publish();
  }

  togglePause() {
    if (this.state.status === "paused") this.resume();
    else this.pause();
  }

  private blur = () => {
    this.clearControls();
    this.pause();
  };

  private controlForCode(code: string): Control | undefined {
    if (code === "ArrowLeft" || code === "KeyA") return "left";
    if (code === "ArrowRight" || code === "KeyD") return "right";
    if (code === "ArrowUp" || code === "KeyW") return "throttle";
    if (code === "ArrowDown" || code === "KeyS") return "descend";
  }

  private keyDown = (event: KeyboardEvent) => {
    if (document.querySelector("dialog[open]")) return;
    if (
      event.target instanceof HTMLInputElement ||
      event.target instanceof HTMLTextAreaElement
    )
      return;
    if (
      event.code === "Space" &&
      (event.target instanceof HTMLButtonElement ||
        event.target instanceof HTMLAnchorElement)
    )
      return;
    const control = this.controlForCode(event.code);
    if (control || event.code === "Space") event.preventDefault();
    if (this.activeKeys.has(event.code)) return;
    this.activeKeys.add(event.code);
    if (control) this.setControl(control, true);
    if (event.code === "Space" || event.code === "KeyE") this.toggleWinch();
    if (event.code === "KeyP" || event.code === "Escape") this.togglePause();
  };

  private keyUp = (event: KeyboardEvent) => {
    this.activeKeys.delete(event.code);
    const control = this.controlForCode(event.code);
    if (control) this.setControl(control, false);
  };

  private clearControls() {
    this.activeKeys.clear();
    this.state.controls = {
      left: false,
      right: false,
      throttle: false,
      descend: false,
    };
  }

  private ground(x: number) {
    const terrain = this.mission.terrain;
    for (let i = 1; i < terrain.length; i++) {
      if (x <= terrain[i].x) {
        const a = terrain[i - 1];
        const b = terrain[i];
        return a.y + (b.y - a.y) * clamp((x - a.x) / (b.x - a.x), 0, 1);
      }
    }
    return terrain[terrain.length - 1].y;
  }

  private tick = (time: number) => {
    const dt = this.lastTime
      ? Math.min((time - this.lastTime) / 1000, 0.04)
      : 0;
    this.lastTime = time;
    if (this.state.status !== "paused") this.clock += dt;
    if (this.state.status === "playing") this.update(dt);
    const targetCamera = clamp(
      this.x - this.width * 0.37,
      0,
      Math.max(0, this.mission.width - this.width),
    );
    this.camera += (targetCamera - this.camera) * Math.min(1, dt * 3.4);
    this.draw();
    if (time - this.lastPublish > 90) {
      this.publish();
      this.lastPublish = time;
    }
    this.frame = requestAnimationFrame(this.tick);
  };

  private update(dt: number) {
    if (this.state.status !== "playing") return;
    const { controls } = this.state;
    this.state.elapsed += dt;
    this.invincible = Math.max(0, this.invincible - dt);
    this.state.fuel = Math.max(
      0,
      this.state.fuel - dt * (controls.throttle ? 0.42 : 0.2),
    );
    const steer = Number(controls.right) - Number(controls.left);
    const assisting = this.state.winch !== "stowed";
    const wind = Math.sin(this.clock * 0.6) * this.mission.wind;
    this.vx += (steer * 240 + wind) * dt;
    this.vx *= Math.exp(-(assisting && !steer ? 3 : 1.15) * dt);
    this.vx = clamp(this.vx, -220, 220);
    if (Math.abs(this.vx) > 15) this.facing = this.vx > 0 ? 1 : -1;
    if (assisting && !controls.throttle && !controls.descend) {
      this.vy *= Math.exp(-5 * dt);
    } else {
      this.vy += (controls.throttle ? -230 : controls.descend ? 160 : 47) * dt;
      this.vy *= Math.exp(-0.9 * dt);
    }
    this.vy = clamp(this.vy, -155, 130);
    this.x = clamp(this.x + this.vx * dt, 105, this.mission.width - 105);
    this.y = clamp(this.y + this.vy * dt, 145, 715);
    if (this.y <= 145) this.vy = Math.max(0, this.vy);
    const floor = this.ground(this.x);
    const overBase = this.x > 90 && this.x < 420;
    if (this.y + 48 >= floor - 7) {
      if (overBase && this.vy < 115 && Math.abs(this.vx) < 90) {
        this.y = floor - 56;
        this.vy = 0;
        this.vx *= 0.94;
        this.state.fuel = Math.min(100, this.state.fuel + 4 * dt);
        if (this.state.rescued === this.mission.targets.length) this.complete();
      } else {
        this.hit("Terrain contact. Gain altitude and keep clear of the ridge.");
        this.y = floor - 80;
        this.vy = -80;
      }
    }
    for (const hazard of this.mission.hazards) {
      const bottom = this.ground(hazard.x);
      const radius =
        hazard.type === "tree" ? 24 : hazard.type === "fire" ? 36 : 16;
      if (
        Math.abs(this.x - hazard.x) < radius + 48 &&
        this.y + 30 > bottom - hazard.height &&
        this.y - 30 < bottom
      ) {
        this.hit(
          hazard.type === "fire"
            ? "Heat damage. Climb above the flames."
            : "Obstacle contact. Watch your airframe.",
        );
        this.vx = this.x < hazard.x ? -85 : 85;
        this.vy = -90;
      }
      if (
        hazard.type === "tower" &&
        this.x > hazard.x + 35 &&
        this.x < hazard.x + 340
      ) {
        const t = (this.x - hazard.x) / 340;
        const top = bottom - hazard.height;
        const wireY =
          (top + 27) * (1 - t) ** 2 +
          2 * (top + 90) * t * (1 - t) +
          (top + 50) * t ** 2;
        if (Math.abs(this.y - wireY) < 32) {
          this.hit("Power line contact. Climb above the cables.");
          this.vy = -85;
        }
      }
    }
    if (this.state.status !== "playing") return;
    if (this.state.winch === "lowering") {
      const availableCable = clamp(this.ground(this.x) - this.y - 48, 12, 335);
      this.cable = Math.min(availableCable, this.cable + dt * 115);
      const hookY = this.y + 43 + this.cable;
      for (let i = 0; i < this.mission.targets.length; i++) {
        const target = this.mission.targets[i];
        if (this.state.targetStates[i] !== "waiting") continue;
        const distance = Math.abs(this.x - target.x);
        if (distance < 75) {
          if (this.cable >= 334 && hookY < target.y - 40) {
            this.state.message =
              "Winch at full reach. Retract it and descend closer to the survivor.";
          } else if (this.y >= target.y - 90) {
            this.state.message =
              "A little more lift, pilot. Climb to a safe hover above the survivor.";
          } else if (hookY >= target.y - 40 && Math.abs(this.vx) >= 115) {
            this.state.message =
              "Ease off steering. Let the winch settle above the survivor.";
          }
        }
        if (
          distance < 48 &&
          hookY >= target.y - 40 &&
          this.y < target.y - 90 &&
          Math.abs(this.vx) < 115
        ) {
          this.attached = i;
          this.cable = clamp(target.y - this.y - 80, 12, 335);
          this.state.targetStates[i] = "attached";
          this.state.winch = "retrieving";
          this.state.message = `${target.name} is on the line. Hold steady while the winch reels in.`;
          this.onSound("winch");
          break;
        }
      }
    } else if (this.state.winch === "retrieving") {
      this.cable = Math.max(0, this.cable - dt * 105);
      if (this.cable === 0) {
        this.state.winch = "stowed";
        if (this.attached !== -1) {
          this.state.targetStates[this.attached] = "rescued";
          this.state.rescued++;
          this.attached = -1;
          this.onSound("rescue");
          this.state.message =
            this.state.rescued === this.mission.targets.length
              ? "Everyone is on board. Return to the base on your left and land on the helipad."
              : `Survivor secured. ${this.mission.targets.length - this.state.rescued} more to bring home. Follow the next beacon.`;
        }
      }
    }
    if (this.state.fuel === 0) {
      this.state.status = "failed";
      this.state.message =
        "Fuel depleted. Return to the helipad to refuel on your next flight.";
      this.clearControls();
    }
  }

  private hit(message: string) {
    if (this.invincible > 0 || this.state.status !== "playing") return;
    this.state.health--;
    this.invincible = 2.7;
    this.state.message = message;
    this.onSound("damage");
    if (this.state.health <= 0) {
      this.state.status = "failed";
      this.state.message =
        "Your aircraft sustained critical damage. Regroup and try a different approach.";
      this.clearControls();
    }
  }

  private complete() {
    this.state.status = "complete";
    this.state.message =
      "All survivors home safe. Outstanding work, Rescue One.";
    this.clearControls();
    this.onSound("complete");
    this.publish();
  }

  private publish() {
    this.onUpdate({
      ...this.state,
      controls: { ...this.state.controls },
      targetStates: [...this.state.targetStates],
      altitude: Math.max(
        0,
        Math.round((this.ground(this.x) - this.y - 48) * 0.7),
      ),
      speed: Math.round(Math.abs(this.vx) * 0.3),
      x: this.x,
    });
  }

  private polygon(points: number[][], fill: string, stroke?: string) {
    const ctx = this.ctx;
    ctx.beginPath();
    points.forEach(([x, y], i) => (i ? ctx.lineTo(x, y) : ctx.moveTo(x, y)));
    ctx.closePath();
    ctx.fillStyle = fill;
    ctx.fill();
    if (stroke) {
      ctx.strokeStyle = stroke;
      ctx.stroke();
    }
  }

  private draw() {
    const ctx = this.ctx;
    const scale = this.canvas.height / HEIGHT;
    ctx.setTransform(scale, 0, 0, scale, 0, 0);
    ctx.clearRect(0, 0, this.width, HEIGHT);
    this.drawBackground();
    this.drawDistantTrees();
    ctx.save();
    ctx.translate(-this.camera, 0);
    this.drawTerrain();
    this.drawBase();
    for (const hazard of this.mission.hazards) {
      if (
        hazard.x > this.camera - 200 &&
        hazard.x < this.camera + this.width + 200
      )
        this.drawHazard(hazard);
    }
    this.drawTargets();
    this.drawBirds();
    const groundY = this.ground(this.x);
    ctx.fillStyle = "rgba(4, 15, 16, 0.22)";
    ctx.beginPath();
    ctx.ellipse(
      this.x,
      groundY - 3,
      85 + (groundY - this.y) * 0.08,
      9,
      0,
      0,
      Math.PI * 2,
    );
    ctx.fill();
    this.drawCable();
    ctx.save();
    const idleBob =
      this.state.status === "ready" ? Math.sin(this.clock * 1.6) * 3 : 0;
    ctx.translate(this.x, this.y + idleBob);
    ctx.scale(this.facing * 1.15, 1.15);
    ctx.rotate(clamp(this.vx / 1600, -0.13, 0.13) * this.facing);
    if (this.invincible > 0 && Math.floor(this.clock * 9) % 2 === 0)
      ctx.globalAlpha = 0.45;
    this.drawHelicopter();
    ctx.restore();
    ctx.restore();
    this.drawAtmosphere();
    const vignette = ctx.createLinearGradient(0, 0, 0, HEIGHT);
    vignette.addColorStop(0, "rgba(10, 22, 24, 0.50)");
    vignette.addColorStop(0.27, "rgba(0,0,0,0)");
    vignette.addColorStop(0.75, "rgba(0,0,0,0)");
    vignette.addColorStop(1, "rgba(7,16,17,0.55)");
    ctx.fillStyle = vignette;
    ctx.fillRect(0, 0, this.width, HEIGHT);
  }

  private drawBackground() {
    const ctx = this.ctx;
    const sky = ctx.createLinearGradient(0, 0, 0, HEIGHT);
    sky.addColorStop(0, this.mission.theme === "fire" ? "#aa9a72" : "#d2d5cb");
    sky.addColorStop(1, "#4b6870");
    ctx.fillStyle = sky;
    ctx.fillRect(0, 0, this.width, HEIGHT);
    if (this.backgroundReady) {
      const imageRatio =
        this.background.naturalWidth / this.background.naturalHeight;
      const drawWidth = Math.max(this.width * 1.16, HEIGHT * imageRatio);
      const drawHeight = drawWidth / imageRatio;
      const travel =
        this.camera /
        (this.mission.width - Math.min(this.width, this.mission.width - 1));
      const offset = -(drawWidth - this.width) * clamp(travel, 0, 1);
      ctx.drawImage(
        this.background,
        offset,
        (HEIGHT - drawHeight) * 0.48,
        drawWidth,
        drawHeight,
      );
      ctx.fillStyle =
        this.mission.theme === "fire"
          ? "rgba(49,35,19,0.13)"
          : "rgba(28,58,61,0.08)";
      ctx.fillRect(0, 0, this.width, HEIGHT);
    }
    const sun = ctx.createRadialGradient(
      this.width * 0.83,
      70,
      0,
      this.width * 0.83,
      70,
      280,
    );
    sun.addColorStop(0, "rgba(255,239,189,0.10)");
    sun.addColorStop(1, "rgba(255,239,189,0)");
    ctx.fillStyle = sun;
    ctx.fillRect(0, 0, this.width, HEIGHT);
  }

  private drawDistantTrees() {
    const ctx = this.ctx;
    ctx.save();
    ctx.translate((-this.camera * 0.45) % 110, 0);
    for (let i = -2; i < this.width / 45 + 5; i++) {
      const x = i * 45;
      const y = 720 + Math.sin(i * 0.3) * 27;
      const height = 65 + noise(i + 7) * 90;
      this.tree(x, y, height, "#16383b", 0.47);
    }
    ctx.restore();
  }

  private drawTerrain() {
    const ctx = this.ctx;
    const points = this.mission.terrain;
    const isFire = this.mission.theme === "fire";
    const top = isFire
      ? "#4b5037"
      : this.mission.theme === "coast"
        ? "#465a54"
        : "#425b4b";
    const face = isFire ? "#303b32" : "#293e3d";
    this.polygon(
      [
        [0, HEIGHT + 160],
        ...points.map((p) => [p.x, p.y + 16]),
        [this.mission.width, HEIGHT + 160],
      ],
      face,
    );
    for (let i = 0; i < points.length - 1; i++) {
      const a = points[i];
      const b = points[i + 1];
      if (b.x < this.camera - 200 || a.x > this.camera + this.width + 200)
        continue;
      const mid = a.x + (b.x - a.x) * 0.55;
      this.polygon(
        [
          [a.x, a.y + 15],
          [b.x, b.y + 15],
          [mid, 830],
        ],
        i % 2 ? "#314745" : "#243b3c",
      );
      this.polygon(
        [
          [a.x + 5, a.y + 22],
          [mid - 18, a.y + 115],
          [a.x + 40, 830],
        ],
        "rgba(12,29,31,0.25)",
      );
      this.polygon(
        [
          [a.x, a.y],
          [b.x, b.y],
          [b.x + 15, b.y + 19],
          [a.x + 15, a.y + 19],
        ],
        top,
      );
      ctx.beginPath();
      ctx.moveTo(a.x, a.y);
      ctx.lineTo(b.x, b.y);
      ctx.strokeStyle = isFire ? "#737451" : "#6f8063";
      ctx.lineWidth = 2;
      ctx.stroke();
      for (let j = 0; j < Math.floor((b.x - a.x) / 26); j++) {
        const x = a.x + j * 26 + 8;
        const y = this.ground(x);
        ctx.strokeStyle = "rgba(160,172,117,0.38)";
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(x, y);
        ctx.lineTo(x - 2, y - 4 - noise(x) * 7);
        ctx.moveTo(x + 2, y);
        ctx.lineTo(x + 5, y - 5);
        ctx.stroke();
      }
    }
    if (this.mission.theme === "coast") {
      const water = ctx.createLinearGradient(0, 714, 0, HEIGHT);
      water.addColorStop(0, "rgba(79,127,132,0.85)");
      water.addColorStop(1, "#24494f");
      ctx.fillStyle = water;
      ctx.fillRect(0, 724, this.mission.width, 100);
      for (let i = 0; i < 40; i++) {
        const x = i * 145 + Math.sin(this.clock + i) * 12;
        ctx.strokeStyle = "rgba(201,223,210,0.3)";
        ctx.beginPath();
        ctx.moveTo(x, 733 + (i % 3) * 9);
        ctx.lineTo(x + 65, 733 + (i % 3) * 9);
        ctx.stroke();
      }
    }
    for (let i = 0; i < 90; i++) {
      const x = i * 59 + noise(i) * 30;
      if (x < this.camera - 100 || x > this.camera + this.width + 100) continue;
      if (x < 450 || this.mission.targets.some((t) => Math.abs(t.x - x) < 110))
        continue;
      const h = 22 + noise(i + 30) * 51;
      this.tree(x, this.ground(x) + 20, h, "#203e38", 1);
    }
  }

  private tree(x: number, y: number, height: number, color: string, alpha = 1) {
    const ctx = this.ctx;
    ctx.save();
    ctx.globalAlpha = alpha;
    ctx.fillStyle = "#34463a";
    ctx.fillRect(
      x - height * 0.025,
      y - height * 0.42,
      height * 0.05,
      height * 0.42,
    );
    for (let i = 0; i < 4; i++) {
      const top = y - height + height * i * 0.16;
      const w = height * (0.15 + i * 0.034);
      const bottom = top + height * 0.43;
      this.polygon(
        [
          [x, top],
          [x - w, bottom],
          [x + w, bottom],
        ],
        color,
      );
      this.polygon(
        [
          [x, top],
          [x + w, bottom],
          [x + 1, bottom - 5],
        ],
        "rgba(4,21,24,0.19)",
      );
    }
    ctx.restore();
  }

  private drawBase() {
    const ctx = this.ctx;
    const y = 646;
    this.polygon(
      [
        [110, y],
        [355, y],
        [384, y + 18],
        [135, y + 18],
      ],
      "#75817a",
    );
    this.polygon(
      [
        [135, y + 18],
        [384, y + 18],
        [384, y + 27],
        [135, y + 27],
      ],
      "#394d48",
    );
    ctx.save();
    ctx.translate(247, y + 7);
    ctx.scale(1, 0.22);
    ctx.strokeStyle = "#e4deba";
    ctx.lineWidth = 7;
    ctx.beginPath();
    ctx.arc(0, 0, 78, 0, Math.PI * 2);
    ctx.stroke();
    ctx.font = "bold 77px Arial";
    ctx.textAlign = "center";
    ctx.fillStyle = "#e4deba";
    ctx.fillText("H", 0, 26);
    ctx.restore();
    for (const x of [120, 355]) {
      ctx.fillStyle = "#263a34";
      ctx.fillRect(x, 623, 5, 24);
      ctx.fillStyle = `rgba(255,151,73,${0.65 + Math.sin(this.clock * 3) * 0.25})`;
      ctx.fillRect(x - 2, 620, 9, 6);
    }
    ctx.fillStyle = "rgba(227,237,217,0.65)";
    ctx.font = "600 12px monospace";
    ctx.textAlign = "center";
    ctx.fillText("RESCUE BASE", 245, 694);
    // The windsock provides a readable wind cue without adding another HUD panel.
    ctx.fillStyle = "#8c9a89";
    ctx.fillRect(411, 557, 3, 93);
    this.polygon(
      [
        [414, 558],
        [461, 568 + Math.sin(this.clock * 2) * 3],
        [460, 583 + Math.sin(this.clock * 2) * 3],
        [414, 577],
      ],
      "#db743d",
    );
    this.polygon(
      [
        [428, 561],
        [437, 563],
        [436, 581],
        [427, 579],
      ],
      "#dfd3b7",
    );
  }

  private drawHazard(hazard: Hazard) {
    const ctx = this.ctx;
    const y = this.ground(hazard.x);
    if (hazard.type === "tree") {
      this.tree(
        hazard.x,
        y,
        hazard.height,
        this.mission.theme === "fire" ? "#343d2d" : "#193c35",
      );
    } else if (hazard.type === "tower") {
      const top = y - hazard.height;
      ctx.strokeStyle = "#334a48";
      ctx.lineWidth = 5;
      ctx.beginPath();
      ctx.moveTo(hazard.x - 26, y);
      ctx.lineTo(hazard.x - 8, top);
      ctx.lineTo(hazard.x + 8, top);
      ctx.lineTo(hazard.x + 26, y);
      ctx.stroke();
      ctx.lineWidth = 2;
      for (let i = 0; i < 6; i++) {
        const yy = top + (i * hazard.height) / 6;
        const half = 8 + i * 3;
        ctx.beginPath();
        ctx.moveTo(hazard.x - half, yy);
        ctx.lineTo(hazard.x + half + 3, yy + hazard.height / 6);
        ctx.moveTo(hazard.x + half, yy);
        ctx.lineTo(hazard.x - half - 3, yy + hazard.height / 6);
        ctx.stroke();
      }
      ctx.fillStyle = "#405954";
      ctx.fillRect(hazard.x - 40, top + 24, 80, 7);
      ctx.fillStyle = Math.sin(this.clock * 4) > 0 ? "#ee6c3d" : "#653f31";
      ctx.beginPath();
      ctx.arc(hazard.x, top - 5, 4, 0, Math.PI * 2);
      ctx.fill();
      ctx.strokeStyle = "rgba(36,57,53,0.6)";
      ctx.lineWidth = 1.3;
      for (const offset of [-28, 28]) {
        ctx.beginPath();
        ctx.moveTo(hazard.x + offset, top + 27);
        ctx.quadraticCurveTo(
          hazard.x + 170,
          top + 90,
          hazard.x + 340,
          top + 50,
        );
        ctx.stroke();
      }
    } else {
      for (let i = 0; i < 8; i++) {
        const x = hazard.x - 55 + i * 15;
        const h =
          hazard.height *
          (0.45 + Math.sin(this.clock * 5 + i * 1.4) * 0.15 + noise(i) * 0.35);
        const flame = ctx.createLinearGradient(x, y - h, x, y);
        flame.addColorStop(0, "rgba(245,171,72,0.05)");
        flame.addColorStop(0.35, "rgba(234,124,41,0.75)");
        flame.addColorStop(1, "#d25a25");
        ctx.fillStyle = flame;
        ctx.beginPath();
        ctx.moveTo(x - 15, y);
        ctx.quadraticCurveTo(
          x - 20,
          y - h * 0.4,
          x + Math.sin(this.clock * 3 + i) * 15,
          y - h,
        );
        ctx.quadraticCurveTo(x + 34, y - h * 0.3, x + 19, y);
        ctx.fill();
      }
    }
  }

  private drawTargets() {
    const ctx = this.ctx;
    this.mission.targets.forEach((target, i) => {
      if (this.state.targetStates[i] !== "waiting") return;
      const x = target.x;
      const y = target.y;
      const pulse = (this.clock * 0.55 + i * 0.3) % 1;
      ctx.strokeStyle = `rgba(247,125,68,${0.45 * (1 - pulse)})`;
      ctx.lineWidth = 2;
      ctx.beginPath();
      ctx.ellipse(x, y - 3, 22 + pulse * 46, 5 + pulse * 11, 0, 0, Math.PI * 2);
      ctx.stroke();
      for (let j = 0; j < 8; j++) {
        const progress = (this.clock * 0.15 + j / 8) % 1;
        const smokeX = x + 39 + Math.sin(progress * 8 + j) * 9 + progress * 22;
        const smokeY = y - 5 - progress * 145;
        ctx.fillStyle = `rgba(239,125,63,${0.17 * (1 - progress)})`;
        ctx.beginPath();
        ctx.arc(smokeX, smokeY, 5 + progress * 18, 0, Math.PI * 2);
        ctx.fill();
      }
      ctx.fillStyle = "#ee8a50";
      ctx.beginPath();
      ctx.arc(x + 39, y - 7, 4, 0, Math.PI * 2);
      ctx.fill();
      this.drawPerson(x, y - 3, true);
      const markerY = y - 136 + Math.sin(this.clock * 2 + i) * 3;
      ctx.save();
      ctx.translate(x, markerY);
      ctx.fillStyle = "#f27a42";
      ctx.beginPath();
      ctx.roundRect(-22, -24, 44, 36, 3);
      ctx.fill();
      this.polygon(
        [
          [-6, 12],
          [6, 12],
          [0, 19],
        ],
        "#f27a42",
      );
      ctx.fillStyle = "#182725";
      ctx.font = "bold 17px monospace";
      ctx.textAlign = "center";
      ctx.fillText(`0${i + 1}`, 0, 0);
      ctx.setLineDash([3, 5]);
      ctx.strokeStyle = "rgba(246,154,96,0.5)";
      ctx.lineWidth = 1;
      ctx.beginPath();
      ctx.moveTo(0, 26);
      ctx.lineTo(0, 82);
      ctx.stroke();
      ctx.restore();
    });
  }

  private drawPerson(x: number, y: number, waving: boolean) {
    const ctx = this.ctx;
    ctx.save();
    ctx.translate(x, y);
    ctx.strokeStyle = "#223330";
    ctx.lineCap = "round";
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.moveTo(-3, -14);
    ctx.lineTo(-5, 0);
    ctx.moveTo(3, -14);
    ctx.lineTo(6, 0);
    ctx.stroke();
    ctx.fillStyle = "#e5b78b";
    ctx.beginPath();
    ctx.arc(0, -38, 5, 0, Math.PI * 2);
    ctx.fill();
    ctx.fillStyle = "#ef9450";
    ctx.beginPath();
    ctx.roundRect(-7, -31, 14, 20, 4);
    ctx.fill();
    ctx.strokeStyle = "#ef9450";
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(-5, -27);
    ctx.lineTo(-13, -21);
    ctx.moveTo(5, -27);
    ctx.lineTo(13, waving ? -39 + Math.sin(this.clock * 4) * 4 : -19);
    ctx.stroke();
    ctx.restore();
  }

  private drawCable() {
    if (this.cable <= 0) return;
    const ctx = this.ctx;
    const startY = this.y + 40;
    const sway =
      Math.sin(this.clock * 2.3) * Math.min(this.cable * 0.035, 7) -
      this.vx * 0.035;
    ctx.strokeStyle = "#d4ccb0";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(this.x, startY);
    ctx.quadraticCurveTo(
      this.x + sway * 0.5,
      startY + this.cable * 0.5,
      this.x + sway,
      startY + this.cable,
    );
    ctx.stroke();
    ctx.strokeStyle = "#e69d55";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.arc(
      this.x + sway + 3,
      startY + this.cable + 3,
      6,
      -Math.PI * 0.5,
      Math.PI,
    );
    ctx.stroke();
    if (this.attached !== -1)
      this.drawPerson(this.x + sway, startY + this.cable + 40, false);
  }

  private drawHelicopter() {
    const ctx = this.ctx;
    // Layered facets give the helicopter volume while preserving its readable side profile.
    this.polygon(
      [
        [-47, -13],
        [-160, -30],
        [-167, -20],
        [-52, 13],
      ],
      "#d46932",
    );
    this.polygon(
      [
        [-52, 7],
        [-167, -20],
        [-161, -13],
        [-51, 19],
      ],
      "#8d4b2d",
    );
    this.polygon(
      [
        [-155, -22],
        [-157, -63],
        [-146, -63],
        [-129, -17],
      ],
      "#e17c3b",
    );
    this.polygon(
      [
        [-159, -19],
        [-184, -10],
        [-133, -10],
        [-125, -17],
      ],
      "#294447",
    );
    ctx.save();
    ctx.translate(-155, -29);
    ctx.rotate(this.clock * 33);
    ctx.fillStyle = "#b9c7ba";
    ctx.fillRect(-2, -25, 4, 50);
    ctx.fillRect(-25, -2, 50, 4);
    ctx.fillStyle = "#304f4c";
    ctx.beginPath();
    ctx.arc(0, 0, 5, 0, Math.PI * 2);
    ctx.fill();
    ctx.restore();
    ctx.strokeStyle = "#263d3b";
    ctx.lineWidth = 5;
    ctx.beginPath();
    ctx.moveTo(-30, 20);
    ctx.lineTo(-40, 45);
    ctx.moveTo(43, 20);
    ctx.lineTo(55, 45);
    ctx.stroke();
    ctx.strokeStyle = "#b0b7a7";
    ctx.lineWidth = 4;
    ctx.beginPath();
    ctx.moveTo(-68, 42);
    ctx.quadraticCurveTo(-69, 47, -60, 48);
    ctx.lineTo(78, 48);
    ctx.quadraticCurveTo(89, 47, 92, 39);
    ctx.stroke();
    ctx.strokeStyle = "#263b37";
    ctx.lineWidth = 2;
    ctx.beginPath();
    ctx.moveTo(-58, 50);
    ctx.lineTo(77, 50);
    ctx.stroke();
    this.polygon(
      [
        [-62, -19],
        [-43, -34],
        [27, -35],
        [58, -23],
        [79, -5],
        [83, 12],
        [67, 28],
        [-28, 30],
        [-56, 18],
        [-64, -2],
      ],
      "#ed7d3c",
    );
    this.polygon(
      [
        [-56, 12],
        [-26, 22],
        [69, 19],
        [82, 11],
        [66, 29],
        [-28, 31],
        [-56, 19],
      ],
      "#ba582e",
    );
    this.polygon(
      [
        [-47, -30],
        [-28, -43],
        [21, -43],
        [42, -33],
      ],
      "#e39356",
    );
    this.polygon(
      [
        [-28, -43],
        [-15, -49],
        [13, -48],
        [21, -43],
      ],
      "#495247",
    );
    this.polygon(
      [
        [-64, -5],
        [-58, -22],
        [-46, -31],
        [-44, 10],
        [-56, 15],
      ],
      "#d56b35",
    );
    this.polygon(
      [
        [15, -31],
        [36, -30],
        [59, -19],
        [73, -4],
        [75, 8],
        [15, 7],
      ],
      "#24454b",
    );
    this.polygon(
      [
        [18, -29],
        [32, -28],
        [42, 5],
        [18, 5],
      ],
      "#75908b",
    );
    this.polygon(
      [
        [39, -27],
        [57, -17],
        [68, -5],
        [71, 5],
        [47, 5],
      ],
      "#4f7274",
    );
    this.polygon(
      [
        [40, -26],
        [57, -17],
        [64, -10],
        [44, -16],
      ],
      "rgba(202,225,201,0.24)",
    );
    ctx.strokeStyle = "#a14f2c";
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.roundRect(-34, -27, 43, 49, 3);
    ctx.stroke();
    this.polygon(
      [
        [-30, -24],
        [4, -24],
        [4, -2],
        [-30, -2],
      ],
      "#345254",
    );
    this.polygon(
      [
        [-28, -23],
        [-18, -23],
        [-8, -4],
        [-28, -4],
      ],
      "rgba(160,194,177,0.3)",
    );
    ctx.fillStyle = "#f4dfb5";
    ctx.fillRect(-21, 3, 7, 18);
    ctx.fillRect(-26, 8, 17, 7);
    ctx.fillStyle = "#753f28";
    ctx.fillRect(-1, 2, 6, 2);
    ctx.fillStyle = "#efd7ab";
    ctx.font = "bold 8px monospace";
    ctx.textAlign = "left";
    ctx.fillText("RESCUE", 23, 19);
    ctx.fillStyle = "#203b3d";
    ctx.fillRect(-32, -40, 12, 7);
    ctx.fillRect(-9, -41, 12, 7);
    ctx.fillStyle = "#afb5a0";
    ctx.fillRect(-10, -67, 6, 21);
    ctx.fillStyle = "#304742";
    ctx.fillRect(-16, -68, 20, 5);
    ctx.fillStyle = "rgba(39,62,57,0.13)";
    ctx.beginPath();
    ctx.ellipse(-7, -70, 143, 7, 0, 0, Math.PI * 2);
    ctx.fill();
    const rotorLength = 115 + Math.abs(Math.sin(this.clock * 42)) * 32;
    ctx.strokeStyle = "rgba(40,56,49,0.75)";
    ctx.lineWidth = 3;
    ctx.beginPath();
    ctx.moveTo(-7 - rotorLength, -70 - Math.sin(this.clock * 28) * 2);
    ctx.lineTo(-7 + rotorLength, -70 + Math.sin(this.clock * 28) * 2);
    ctx.stroke();
    ctx.strokeStyle = "rgba(222,221,191,0.48)";
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.moveTo(-140, -73);
    ctx.lineTo(130, -68);
    ctx.stroke();
    ctx.fillStyle = Math.sin(this.clock * 5) > 0.5 ? "#f2a674" : "#a64e2d";
    ctx.beginPath();
    ctx.arc(-146, -61, 2.5, 0, Math.PI * 2);
    ctx.fill();
    ctx.strokeStyle = "#54604e";
    ctx.lineWidth = 1.5;
    ctx.beginPath();
    ctx.moveTo(60, -22);
    ctx.lineTo(68, -43);
    ctx.stroke();
  }

  private drawBirds() {
    const ctx = this.ctx;
    ctx.strokeStyle = "rgba(37,62,58,0.6)";
    ctx.lineWidth = 1.8;
    for (let i = 0; i < 5; i++) {
      const x = 1500 + i * 26 + Math.sin(this.clock * 0.15) * 170;
      const y = 200 + (i % 3) * 17 + Math.sin(this.clock + i) * 6;
      const flap = Math.sin(this.clock * 4 + i) * 6;
      ctx.beginPath();
      ctx.moveTo(x - 8, y - flap);
      ctx.quadraticCurveTo(x - 4, y - 3, x, y);
      ctx.quadraticCurveTo(x + 4, y - 3, x + 8, y - flap);
      ctx.stroke();
    }
  }

  private drawAtmosphere() {
    const ctx = this.ctx;
    for (let i = 0; i < 6; i++) {
      const x =
        ((i * 390 + this.clock * (4 + i) - this.camera * 0.12) %
          (this.width + 600)) -
        200;
      const y = 500 + (i % 3) * 55;
      const fog = ctx.createRadialGradient(x, y, 0, x, y, 240);
      fog.addColorStop(
        0,
        this.mission.theme === "fire"
          ? "rgba(170,156,113,0.06)"
          : "rgba(203,220,204,0.07)",
      );
      fog.addColorStop(1, "rgba(180,200,183,0)");
      ctx.fillStyle = fog;
      ctx.save();
      ctx.translate(0, y);
      ctx.scale(1, 0.23);
      ctx.translate(0, -y);
      ctx.fillRect(x - 240, y - 240, 480, 480);
      ctx.restore();
    }
    if (this.mission.theme === "fire") {
      for (let i = 0; i < 32; i++) {
        const x =
          (noise(i) * this.width + this.clock * (4 + noise(i + 5) * 12)) %
          this.width;
        const y =
          HEIGHT - ((this.clock * (12 + noise(i) * 20) + i * 37) % HEIGHT);
        ctx.fillStyle = `rgba(248,175,89,${0.15 + noise(i + 8) * 0.4})`;
        ctx.fillRect(x, y, 1.5, 3);
      }
    }
  }

  destroy() {
    cancelAnimationFrame(this.frame);
    this.observer.disconnect();
    window.removeEventListener("keydown", this.keyDown);
    window.removeEventListener("keyup", this.keyUp);
    window.removeEventListener("blur", this.blur);
  }
}

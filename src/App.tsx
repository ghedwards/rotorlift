import {
  useEffect,
  useRef,
  useState,
  type ReactNode,
  type SVGProps,
  type PointerEvent as ReactPointerEvent,
  type KeyboardEvent as ReactKeyboardEvent,
} from "react";
import { FlightAudio } from "./game/audio";
import {
  INITIAL_SNAPSHOT,
  RescueGame,
  type Control,
  type GameStatus,
  type Snapshot,
} from "./game/engine";
import { MISSIONS } from "./game/scenarios";

type IconName =
  | "helicopter"
  | "arrow-left"
  | "arrow-right"
  | "arrow-up"
  | "arrow-down"
  | "arrow-up-right"
  | "person"
  | "fuel"
  | "shield"
  | "pause"
  | "play"
  | "sound"
  | "muted"
  | "close"
  | "restart"
  | "expand"
  | "winch"
  | "wind"
  | "radio"
  | "book"
  | "check"
  | "mountain"
  | "keyboard"
  | "crosshair";

const iconPaths: Record<IconName, ReactNode> = {
  helicopter: (
    <>
      <path d="M3 3h14M10 3v5M4 9H2l-1-3M3 9l5 4M8 9h7a5 5 0 0 1 5 5v2H9l-3-5 2-2ZM14 9v5h6M10 16v4m7-4v4M6 20h15" />
    </>
  ),
  "arrow-left": <path d="m14 6-6 6 6 6M8 12h12" />,
  "arrow-right": <path d="m10 6 6 6-6 6M4 12h12" />,
  "arrow-up": <path d="m6 10 6-6 6 6M12 4v16" />,
  "arrow-down": <path d="m6 14 6 6 6-6M12 4v16" />,
  "arrow-up-right": <path d="M6 18 18 6M6 6h12v12" />,
  person: (
    <>
      <circle cx="12" cy="5" r="2.5" />
      <path d="M7 20v-6H5V9h14v5h-2v6M10 20v-5h4v5" />
    </>
  ),
  fuel: (
    <>
      <path d="M4 21V4h10v17M2 21h14M6 7h6v5H6ZM14 12h3v5a2 2 0 0 0 4 0V8l-3-3M19 6v4h2" />
    </>
  ),
  shield: <path d="m12 3 8 3v6c0 5-8 9-8 9s-8-4-8-9V6l8-3ZM9 12l2 2 4-4" />,
  pause: <path d="M8 5v14M16 5v14" strokeWidth="3" />,
  play: <path d="m8 4 12 8-12 8V4Z" />,
  sound: (
    <>
      <path d="M11 4 6 8H3v8h3l5 4V4ZM15 8a6 6 0 0 1 0 8M18 5a10 10 0 0 1 0 14" />
    </>
  ),
  muted: (
    <>
      <path d="M11 4 6 8H3v8h3l5 4V4ZM16 9l6 6m0-6-6 6" />
    </>
  ),
  close: <path d="m6 6 12 12M6 18 18 6" />,
  restart: <path d="M3 10a9 9 0 1 1 1 7M3 4v6h6" />,
  expand: <path d="M8 3H3v5m13-5h5v5M3 16v5h5m13-5v5h-5" />,
  winch: <path d="M6 3h12M12 3v11a4 4 0 1 1-4 4M8 13l4 3 4-3" />,
  wind: <path d="M3 8h12a3 3 0 1 0-3-3M2 12h17a3 3 0 1 1-3 3M5 16h4" />,
  radio: <path d="M4 9v6m4-10v14m4-17v20m4-17v14m4-10v6" />,
  book: (
    <path d="M12 5C8 2 3 3 3 3v16s5-1 9 2c4-3 9-2 9-2V3s-5-1-9 2Zm0 0v16" />
  ),
  check: <path d="m5 12 4 4L19 6" />,
  mountain: <path d="m2 20 8-15 5 9 3-5 5 11H2ZM7 11l3 2 3-2" />,
  keyboard: (
    <>
      <rect x="2" y="5" width="20" height="14" rx="2" />
      <path d="M6 9h.01M10 9h.01M14 9h.01M18 9h.01M6 12h.01M10 12h.01M14 12h.01M18 12h.01M7 16h10" />
    </>
  ),
  crosshair: (
    <>
      <circle cx="12" cy="12" r="7" />
      <path d="M12 2v5m0 10v5M2 12h5m10 0h5" />
    </>
  ),
};

function Icon({
  name,
  ...props
}: SVGProps<SVGSVGElement> & { name: IconName }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="none"
      stroke="currentColor"
      strokeWidth="1.6"
      strokeLinecap="round"
      strokeLinejoin="round"
      aria-hidden="true"
      {...props}
    >
      {iconPaths[name]}
    </svg>
  );
}

function formatTime(seconds: number) {
  return `${Math.floor(seconds / 60)
    .toString()
    .padStart(2, "0")}:${Math.floor(seconds % 60)
    .toString()
    .padStart(2, "0")}`;
}

function Dialog({
  children,
  label,
  onClose,
  wide = false,
}: {
  children: ReactNode;
  label: string;
  onClose: () => void;
  wide?: boolean;
}) {
  const ref = useRef<HTMLDialogElement>(null);
  useEffect(() => {
    ref.current?.showModal();
    const previous = document.body.style.overflow;
    document.body.style.overflow = "hidden";
    return () => {
      document.body.style.overflow = previous;
    };
  }, []);
  return (
    <dialog
      ref={ref}
      className={`dialog ${wide ? "dialog-wide" : ""}`}
      aria-label={label}
      onCancel={(event) => {
        event.preventDefault();
        onClose();
      }}
      onClick={(event) => {
        if (event.target === event.currentTarget) onClose();
      }}
    >
      <button
        className="icon-button dialog-close"
        onClick={onClose}
        aria-label="Close dialog"
      >
        <Icon name="close" />
      </button>
      {children}
    </dialog>
  );
}

export default function App() {
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const stationRef = useRef<HTMLElement>(null);
  const gameRef = useRef<RescueGame | null>(null);
  const audioRef = useRef<FlightAudio | null>(null);
  const previousStatus = useRef<GameStatus>("ready");
  const [snapshot, setSnapshot] = useState<Snapshot>(INITIAL_SNAPSHOT);
  const [missionIndex, setMissionIndex] = useState(0);
  const [runId, setRunId] = useState(0);
  const [overlay, setOverlay] = useState<"missions" | "manual" | null>(null);
  const [sound, setSound] = useState(false);
  const [fullscreen, setFullscreen] = useState(false);
  const [completed, setCompleted] = useState<string[]>(() => {
    try {
      const stored: unknown = JSON.parse(
        localStorage.getItem("airlift-completed") || "[]",
      );
      return Array.isArray(stored)
        ? stored.filter((id): id is string => typeof id === "string")
        : [];
    } catch {
      return [];
    }
  });
  const mission = MISSIONS[missionIndex];
  const disabled =
    snapshot.status === "paused" ||
    snapshot.status === "failed" ||
    snapshot.status === "complete";

  useEffect(() => {
    audioRef.current = new FlightAudio();
    return () => {
      audioRef.current?.destroy();
      audioRef.current = null;
    };
  }, []);

  useEffect(() => {
    if (!canvasRef.current) return;
    const game = new RescueGame(
      canvasRef.current,
      MISSIONS[missionIndex],
      setSnapshot,
      (type) => audioRef.current?.cue(type),
    );
    gameRef.current = game;
    return () => {
      game.destroy();
      gameRef.current = null;
    };
  }, [missionIndex, runId]);

  useEffect(() => {
    if (
      snapshot.status === "complete" &&
      snapshot.missionId === mission.id &&
      !completed.includes(mission.id)
    ) {
      const next = [...completed, mission.id];
      setCompleted(next);
      try {
        localStorage.setItem("airlift-completed", JSON.stringify(next));
      } catch {
        /* Progress is optional in private browsing. */
      }
    }
  }, [snapshot.status, snapshot.missionId, mission.id, completed]);

  useEffect(() => {
    const onFullscreen = () => setFullscreen(!!document.fullscreenElement);
    document.addEventListener("fullscreenchange", onFullscreen);
    return () => document.removeEventListener("fullscreenchange", onFullscreen);
  }, []);

  function openOverlay(kind: "missions" | "manual") {
    previousStatus.current = snapshot.status;
    gameRef.current?.pause();
    setOverlay(kind);
  }

  function closeOverlay() {
    setOverlay(null);
    if (previousStatus.current === "playing") gameRef.current?.resume();
  }

  function selectMission(index: number) {
    setSnapshot({ ...INITIAL_SNAPSHOT, missionId: MISSIONS[index].id });
    setMissionIndex(index);
    setRunId((id) => id + 1);
    setOverlay(null);
  }

  async function toggleSound() {
    try {
      setSound((await audioRef.current?.toggle()) ?? false);
    } catch {
      setSound(false);
    }
  }

  async function toggleFullscreen() {
    try {
      if (document.fullscreenElement) await document.exitFullscreen();
      else await stationRef.current?.requestFullscreen();
    } catch {
      /* The game remains playable when fullscreen is unavailable. */
    }
  }

  function holdProps(control: Control) {
    return {
      onPointerDown: (event: ReactPointerEvent<HTMLButtonElement>) => {
        event.preventDefault();
        event.currentTarget.setPointerCapture(event.pointerId);
        gameRef.current?.setControl(control, true);
      },
      onPointerUp: () => gameRef.current?.setControl(control, false),
      onPointerCancel: () => gameRef.current?.setControl(control, false),
      onLostPointerCapture: () => gameRef.current?.setControl(control, false),
      onKeyDown: (event: ReactKeyboardEvent<HTMLButtonElement>) => {
        if (event.code === "Space" || event.code === "Enter") {
          event.preventDefault();
          event.stopPropagation();
          gameRef.current?.setControl(control, true);
        }
      },
      onKeyUp: (event: ReactKeyboardEvent<HTMLButtonElement>) => {
        if (event.code === "Space" || event.code === "Enter") {
          event.preventDefault();
          event.stopPropagation();
          gameRef.current?.setControl(control, false);
        }
      },
    };
  }

  return (
    <div className="app-shell">
      <header className="site-header">
        <div className="header-inner">
          <a className="brand" href="#flight-station" aria-label="Airlift home">
            <span className="brand-symbol">
              <Icon name="helicopter" />
            </span>
            <span className="brand-word">
              AIRLIFT<span className="brand-period">.</span>
              <span className="brand-subtitle">SEARCH & RESCUE</span>
            </span>
          </a>
          <nav className="main-nav" aria-label="Main navigation">
            <button
              className={!overlay ? "nav-link active" : "nav-link"}
              onClick={() => {
                closeOverlay();
                stationRef.current?.scrollIntoView({
                  behavior: "smooth",
                  block: "center",
                });
              }}
            >
              Play
              <span className="nav-active-dot" />
            </button>
            <button
              className={
                overlay === "missions" ? "nav-link active" : "nav-link"
              }
              onClick={() => openOverlay("missions")}
            >
              Missions<span className="nav-count">03</span>
            </button>
            <button
              className={overlay === "manual" ? "nav-link active" : "nav-link"}
              onClick={() => openOverlay("manual")}
            >
              Flight manual
              <Icon name="arrow-up-right" />
            </button>
          </nav>
          <div className="header-right">
            <span className="online-status">
              <span />
              ALL SYSTEMS GO
            </span>
            <span className="header-divider" />
            <button
              className={`icon-button sound-button ${sound ? "is-on" : ""}`}
              onClick={toggleSound}
              aria-label={sound ? "Mute game sound" : "Enable game sound"}
              title={sound ? "Sound on" : "Sound off"}
            >
              <Icon name={sound ? "sound" : "muted"} />
            </button>
            <div className="pilot-profile">
              <span className="pilot-avatar">P1</span>
              <span>PILOT 01</span>
            </div>
          </div>
        </div>
      </header>

      <main className="main-content">
        <section className="mission-heading" aria-label="Current mission">
          <div>
            <p className="eyebrow">
              <span className="orange-dash" />A LITTLE COURAGE. A LOT OF LIFT.
            </p>
            <h1>
              Bring them home<span>.</span>
            </h1>
          </div>
          <button
            className="mission-switcher"
            onClick={() => openOverlay("missions")}
            aria-label="Choose a rescue mission"
          >
            <span className="mission-number">
              {mission.id}
              <span> / 03</span>
            </span>
            <span className="mission-switcher-text">
              <span>CURRENT OPERATION</span>
              <strong>{mission.name}</strong>
            </span>
            <Icon name="arrow-right" />
          </button>
        </section>

        <section
          className={`flight-station ${fullscreen ? "is-fullscreen" : ""}`}
          id="flight-station"
          ref={stationRef}
          aria-label="Helicopter rescue game"
        >
          <div className="game-viewport">
            <canvas
              ref={canvasRef}
              className="game-canvas"
              aria-label={`A side-scrolling helicopter rescue mission in ${mission.name}. Use A and D to steer, hold W to climb, and press Space to deploy the winch.`}
            />
            <div className="scene-topline">
              <span
                className={`live-status ${snapshot.status === "playing" ? "is-live" : ""}`}
              >
                <span />
                {snapshot.status === "ready"
                  ? "AWAITING TAKEOFF"
                  : snapshot.status === "paused"
                    ? "OPERATION PAUSED"
                    : snapshot.status === "complete"
                      ? "MISSION COMPLETE"
                      : snapshot.status === "failed"
                        ? "SIGNAL LOST"
                        : "LIVE OPERATION"}
              </span>
              <span className="scene-region">
                {mission.region}
                <span className="scene-region-divider">/</span>06:42 AM
              </span>
            </div>
            <div className="hud-top">
              <div className="hud-readouts">
                <div className="hud-stat rescue-stat">
                  <Icon name="person" />
                  <div>
                    <span className="hud-label">RESCUED</span>
                    <strong>
                      {String(snapshot.rescued).padStart(2, "0")}
                      <span> / 03</span>
                    </strong>
                  </div>
                </div>
                <span className="hud-divider" />
                <div className="hud-stat fuel-stat">
                  <Icon name="fuel" />
                  <div>
                    <span className="hud-label">
                      FUEL <span>{Math.ceil(snapshot.fuel)}%</span>
                    </span>
                    <div
                      className={`fuel-meter ${snapshot.fuel < 20 ? "fuel-low" : ""}`}
                    >
                      {Array.from({ length: 10 }, (_, i) => (
                        <i
                          key={i}
                          className={snapshot.fuel > i * 10 ? "filled" : ""}
                        />
                      ))}
                    </div>
                  </div>
                </div>
                <span className="hud-divider airframe-divider" />
                <div className="hud-stat airframe-stat">
                  <Icon name="shield" />
                  <div>
                    <span className="hud-label">AIRFRAME</span>
                    <div
                      className="airframe-meter"
                      role="meter"
                      aria-label="Aircraft integrity"
                      aria-valuemin={0}
                      aria-valuemax={3}
                      aria-valuenow={snapshot.health}
                    >
                      {[0, 1, 2].map((i) => (
                        <i
                          className={i < snapshot.health ? "filled" : ""}
                          key={i}
                        />
                      ))}
                    </div>
                  </div>
                </div>
              </div>
              <div className="hud-right">
                <div className="flight-time">
                  <span className="hud-label">FLIGHT TIME</span>
                  <strong>{formatTime(snapshot.elapsed)}</strong>
                </div>
                <button
                  className="scene-button pause-button"
                  onClick={() => {
                    if (snapshot.status === "ready") gameRef.current?.start();
                    else gameRef.current?.togglePause();
                  }}
                  aria-label={
                    snapshot.status === "paused"
                      ? "Resume flight"
                      : snapshot.status === "ready"
                        ? "Start mission"
                        : "Pause flight"
                  }
                  title="Pause / resume (P)"
                >
                  <Icon
                    name={
                      snapshot.status === "paused" ||
                      snapshot.status === "ready"
                        ? "play"
                        : "pause"
                    }
                  />
                </button>
              </div>
            </div>
            <div className="wind-readout">
              <Icon name="wind" />
              <span>{String(mission.wind).padStart(2, "0")} KTS</span>
              <Icon name="arrow-right" />
            </div>
            <div className="hud-bottom">
              <div className="radio-message">
                <span className="radio-symbol">
                  <Icon name="radio" />
                </span>
                <div>
                  <span className="radio-label">
                    COMMS <span>/</span> RESCUE ONE
                  </span>
                  <p
                    key={snapshot.message}
                    role="status"
                    aria-live="polite"
                    aria-atomic="true"
                  >
                    {snapshot.message}
                  </p>
                </div>
              </div>
              <div className="mini-instruments">
                <div>
                  <span>ALT</span>
                  <strong>
                    {String(snapshot.altitude).padStart(3, "0")}
                    <small> FT</small>
                  </strong>
                </div>
                <span className="instrument-divider" />
                <div>
                  <span>SPD</span>
                  <strong>
                    {String(snapshot.speed).padStart(2, "0")}
                    <small> KTS</small>
                  </strong>
                </div>
              </div>
              <div className="route-map" aria-label="Mission route">
                <div className="route-label">
                  <span>MISSION ROUTE</span>
                  <span>{mission.id} / 03</span>
                </div>
                <svg viewBox="0 0 190 34" aria-hidden="true">
                  <path
                    d="M4 25 17 25 30 30 43 28 57 18 70 18 82 26 98 24 111 13 128 13 141 25 152 19 164 8 181 8 188 22"
                    fill="none"
                    stroke="rgba(204,219,202,.4)"
                    strokeWidth="1"
                  />
                  <line
                    x1="4"
                    y1="31"
                    x2="188"
                    y2="31"
                    stroke="rgba(204,219,202,.15)"
                  />
                  <rect x="5" y="20" width="5" height="5" fill="#e9e5ce" />
                  {mission.targets.map((target, i) => (
                    <circle
                      key={i}
                      cx={4 + (target.x / mission.width) * 180}
                      cy="13"
                      r="3"
                      fill={
                        snapshot.targetStates[i] === "rescued"
                          ? "#a7bd90"
                          : "#ee8851"
                      }
                    />
                  ))}
                  <path
                    d="m-4 0 4-6 4 6Z"
                    fill="#f58b51"
                    transform={`translate(${4 + (snapshot.x / mission.width) * 180} 7)`}
                  />
                </svg>
              </div>
            </div>
            {snapshot.status === "ready" && (
              <div className="takeoff-tip">
                <span className="tip-line" />
                <Icon name="arrow-up" />
                <span>HOLD THROTTLE TO TAKE FLIGHT</span>
              </div>
            )}
            {snapshot.status === "paused" && !overlay && (
              <div className="game-overlay pause-overlay">
                <span className="overlay-kicker">TAKE A BREATHER, PILOT.</span>
                <h2>Holding position.</h2>
                <p>Your mission will be right here.</p>
                <button
                  className="primary-button"
                  onClick={() => gameRef.current?.resume()}
                >
                  <Icon name="play" />
                  Resume flight<span className="button-key">P</span>
                </button>
                <button
                  className="text-button"
                  onClick={() => setRunId((id) => id + 1)}
                >
                  Restart mission
                  <Icon name="restart" />
                </button>
              </div>
            )}
            {(snapshot.status === "complete" ||
              snapshot.status === "failed") && (
              <div className="game-overlay result-overlay">
                <span
                  className={`result-symbol ${snapshot.status === "failed" ? "failed-symbol" : ""}`}
                >
                  <Icon
                    name={
                      snapshot.status === "complete" ? "check" : "helicopter"
                    }
                  />
                </span>
                <span className="overlay-kicker">
                  {snapshot.status === "complete"
                    ? "MISSION ACCOMPLISHED"
                    : "MISSION INCOMPLETE"}
                </span>
                <h2>
                  {snapshot.status === "complete"
                    ? "Everyone. Home safe."
                    : "A second chance to fly."}
                </h2>
                <p>{snapshot.message}</p>
                <div className="result-summary">
                  <span>
                    <strong>{snapshot.rescued}/3</strong> SURVIVORS
                  </span>
                  <span>
                    <strong>{formatTime(snapshot.elapsed)}</strong> FLIGHT TIME
                  </span>
                </div>
                <button
                  className="primary-button"
                  onClick={() =>
                    snapshot.status === "complete"
                      ? selectMission((missionIndex + 1) % MISSIONS.length)
                      : setRunId((id) => id + 1)
                  }
                >
                  {snapshot.status === "complete"
                    ? "Next operation"
                    : "Try again"}
                  <Icon name="arrow-right" />
                </button>
                <button
                  className="text-button"
                  onClick={() => openOverlay("missions")}
                >
                  Choose a mission
                  <Icon name="mountain" />
                </button>
              </div>
            )}
            <span className="viewport-corner corner-tl" />
            <span className="viewport-corner corner-tr" />
            <span className="viewport-corner corner-bl" />
            <span className="viewport-corner corner-br" />
          </div>
          <div className="flight-controls">
            <div className="flight-deck-label">
              <Icon name="keyboard" />
              <div>
                <span>FLIGHT DECK</span>
                <small>Steady hands. Safe landings.</small>
              </div>
            </div>
            <div className="control-group steering-controls">
              <span className="control-caption">STEER</span>
              <div className="steering-buttons">
                <button
                  className={`key-button ${snapshot.controls.left ? "pressed" : ""}`}
                  disabled={disabled}
                  aria-label="Fly left (A or Left Arrow)"
                  {...holdProps("left")}
                >
                  <Icon name="arrow-left" />
                  <span>A</span>
                </button>
                <button
                  className={`key-button ${snapshot.controls.right ? "pressed" : ""}`}
                  disabled={disabled}
                  aria-label="Fly right (D or Right Arrow)"
                  {...holdProps("right")}
                >
                  <Icon name="arrow-right" />
                  <span>D</span>
                </button>
              </div>
            </div>
            <div className="control-group throttle-controls">
              <span className="control-caption">HOLD TO CLIMB</span>
              <button
                className={`throttle-button ${snapshot.controls.throttle ? "pressed" : ""}`}
                disabled={disabled}
                aria-label="Throttle: hold to climb (W or Up Arrow)"
                {...holdProps("throttle")}
              >
                <Icon name="arrow-up" />
                <span>THROTTLE</span>
                <kbd>W</kbd>
              </button>
            </div>
            <div className="control-group winch-controls">
              <span className="control-caption">
                {snapshot.winch === "lowering"
                  ? "FLIGHT ASSIST ACTIVE"
                  : snapshot.winch === "retrieving"
                    ? "BRINGING THEM UP"
                    : "TOGGLE TO RESCUE"}
              </span>
              <button
                className={`winch-button ${snapshot.winch !== "stowed" ? "winch-active" : ""}`}
                disabled={disabled}
                onClick={() => gameRef.current?.toggleWinch()}
                aria-label="Toggle rescue winch (Space or E)"
                aria-pressed={snapshot.winch !== "stowed"}
              >
                <Icon name="winch" />
                <span>
                  {snapshot.winch === "lowering"
                    ? "RETRACT WINCH"
                    : snapshot.winch === "retrieving"
                      ? "RETRIEVING"
                      : "DEPLOY WINCH"}
                </span>
                <kbd>SPACE</kbd>
              </button>
            </div>
            <div className="deck-actions">
              <button
                className="icon-button"
                onClick={() => setRunId((id) => id + 1)}
                aria-label="Restart mission"
                title="Restart mission"
              >
                <Icon name="restart" />
              </button>
              <button
                className="icon-button fullscreen-button"
                onClick={toggleFullscreen}
                aria-label={fullscreen ? "Exit fullscreen" : "Enter fullscreen"}
                title="Fullscreen"
              >
                <Icon name="expand" />
              </button>
            </div>
          </div>
          <div className="station-statusbar">
            <span>
              <span className="status-led" />
              {snapshot.status === "ready"
                ? "READY WHEN YOU ARE"
                : snapshot.status === "playing"
                  ? "YOU HAVE THE CONTROLS"
                  : snapshot.status === "paused"
                    ? "FLIGHT ON HOLD"
                    : snapshot.status === "complete"
                      ? "EVERY LIFE COUNTS"
                      : "REGROUP. REFOCUS. RESCUE."}
            </span>
            <span className="statusbar-tip">
              {snapshot.winch !== "stowed"
                ? "Hover assist engaged. Move over a survivor to attach the cable."
                : "Release throttle to descend. Hover over a beacon, then lower your winch."}
            </span>
            <button onClick={() => openOverlay("manual")}>
              CONTROL GUIDE
              <Icon name="arrow-up-right" />
            </button>
          </div>
        </section>
        <section className="mission-brief" aria-label="Mission objective">
          <div className="objective-icon">
            <Icon name="crosshair" />
          </div>
          <div className="objective-copy">
            <span className="eyebrow">THE OBJECTIVE</span>
            <h2>No one gets left behind.</h2>
            <p>
              Find the stranded survivors. Winch them to safety. Bring everyone
              back to base.
            </p>
          </div>
          <button
            className="briefing-link"
            onClick={() => openOverlay("manual")}
          >
            First time in the cockpit?
            <span>
              Read the flight manual
              <Icon name="arrow-up-right" />
            </span>
          </button>
        </section>
      </main>
      <footer className="site-footer">
        <span>
          AIRLIFT<span className="footer-slash">/</span>MADE FOR THE MISSION.
        </span>
        <span>
          A STEADY HAND CAN CHANGE EVERYTHING.
          <span className="footer-cross">+</span>
        </span>
      </footer>
      {overlay === "missions" && (
        <Dialog label="Choose your rescue mission" onClose={closeOverlay} wide>
          <p className="eyebrow">
            <span className="orange-dash" />
            OPERATIONS CENTER
          </p>
          <h2 className="dialog-title">Different terrain. Same purpose.</h2>
          <p className="dialog-description">
            Choose your next operation. Every mission is ready to fly.
          </p>
          <div className="mission-list">
            {MISSIONS.map((item, index) => (
              <button
                key={item.id}
                className={`mission-option ${index === missionIndex ? "selected" : ""}`}
                onClick={() => selectMission(index)}
              >
                <span
                  className="mission-thumbnail"
                  style={{ backgroundImage: `url(${item.image})` }}
                >
                  <span>{item.id}</span>
                </span>
                <span className="mission-option-copy">
                  <span className="mission-option-meta">
                    {item.region}
                    <span>{item.difficulty}</span>
                  </span>
                  <strong>{item.name}</strong>
                  <span className="mission-option-description">
                    {item.description}
                  </span>
                  <span className="mission-conditions">
                    <Icon name="wind" />
                    {item.conditions}
                  </span>
                </span>
                <span className="mission-option-arrow">
                  {completed.includes(item.id) ? (
                    <Icon name="check" />
                  ) : (
                    <Icon name="arrow-up-right" />
                  )}
                </span>
              </button>
            ))}
          </div>
          <p className="dialog-footnote">
            <Icon name="shield" />
            Progress saves on this device. All three operations are unlocked.
          </p>
        </Dialog>
      )}
      {overlay === "manual" && (
        <Dialog label="Helicopter flight manual" onClose={closeOverlay}>
          <p className="eyebrow">
            <span className="orange-dash" />
            PILOT FIELD GUIDE / 001
          </p>
          <h2 className="dialog-title">A little lift goes a long way.</h2>
          <p className="dialog-description">
            Your aircraft is ready. Here's how to bring everyone home.
          </p>
          <div className="manual-controls">
            <div>
              <span className="manual-keys">
                <kbd>A</kbd>
                <kbd>D</kbd>
              </span>
              <div>
                <strong>Find your direction.</strong>
                <p>Hold A / D or the left / right arrows to steer.</p>
              </div>
            </div>
            <div>
              <span className="manual-keys">
                <kbd>W</kbd>
                <Icon name="arrow-up" />
              </span>
              <div>
                <strong>Give it some lift.</strong>
                <p>
                  Hold W or the up arrow to climb. Release to descend. S or the
                  down arrow descends faster.
                </p>
              </div>
            </div>
            <div>
              <span className="manual-keys">
                <kbd className="wide-key">SPACE</kbd>
              </span>
              <div>
                <strong>Be their lifeline.</strong>
                <p>
                  Hover directly above an orange beacon and press Space or E.
                  The winch catches and retrieves survivors automatically.
                </p>
              </div>
            </div>
          </div>
          <div className="manual-tip">
            <Icon name="shield" />
            <p>
              <strong>Slow is smooth. Smooth is safe.</strong>The winch holds
              your altitude while deployed. Avoid trees, towers, and fire. Land
              on the base helipad to refuel. Rescue all three people and return
              to base to finish.
            </p>
          </div>
          <div className="manual-footer">
            <span>
              <kbd>P</kbd> PAUSE / RESUME
            </span>
            <button className="primary-button" onClick={closeOverlay}>
              Ready to fly
              <Icon name="arrow-right" />
            </button>
          </div>
        </Dialog>
      )}
    </div>
  );
}

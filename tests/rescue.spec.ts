import { expect, test } from "@playwright/test";

test("keyboard flight, automatic rescue, pause, and restart work", async ({
  page,
}) => {
  const errors: string[] = [];
  page.on("pageerror", (error) => errors.push(error.message));
  await page.goto("/");
  await expect(page.locator(".live-status")).toHaveText("AWAITING TAKEOFF");
  await page.keyboard.press("Space");
  await expect(page.locator(".live-status")).toHaveText("LIVE OPERATION");
  await expect(page.locator(".winch-button")).toContainText("RETRACT WINCH");
  await page.keyboard.down("KeyD");
  await expect
    .poll(
      async () => {
        const transform = await page
          .locator(".route-map path")
          .last()
          .getAttribute("transform");
        const mapX = Number(transform!.match(/translate\(([\d.]+)/)![1]);
        return ((mapX - 4) / 180) * 4800;
      },
      { timeout: 12000, intervals: [50] },
    )
    .toBeGreaterThan(1120);
  await page.keyboard.up("KeyD");
  await expect(page.locator(".rescue-stat strong")).toContainText("01", {
    timeout: 9000,
  });
  await page.keyboard.press("KeyP");
  await expect(
    page.getByRole("heading", { name: "Holding position." }),
  ).toBeVisible();
  const time = await page.locator(".flight-time strong").textContent();
  await page.waitForTimeout(1100);
  await expect(page.locator(".flight-time strong")).toHaveText(time!);
  await page.getByRole("button", { name: "Resume flight" }).last().click();
  await expect(page.locator(".live-status")).toHaveText("LIVE OPERATION");
  await page
    .getByRole("button", { name: "Restart mission", exact: true })
    .click();
  await expect(page.locator(".live-status")).toHaveText("AWAITING TAKEOFF");
  await expect(page.locator(".rescue-stat strong")).toContainText("00");
  expect(errors).toEqual([]);
});

test("mission selection, manual, and sound controls work", async ({ page }) => {
  await page.goto("/");
  await page.getByRole("button", { name: "Missions" }).click();
  await expect(page.getByRole("dialog")).toBeVisible();
  await expect(page.locator(".mission-option")).toHaveCount(3);
  await page.locator(".mission-option").nth(1).click();
  await expect(page.locator(".mission-switcher-text strong")).toHaveText(
    "Storm Coast",
  );
  await expect(page.locator("dialog")).toHaveCount(0);
  await page.getByRole("button", { name: "CONTROL GUIDE" }).click();
  await expect(page.getByRole("dialog")).toContainText("Be their lifeline.");
  await page.keyboard.press("Escape");
  await expect(page.locator("dialog")).toHaveCount(0);
  await expect(page.locator(".live-status")).toHaveText("AWAITING TAKEOFF");
  await page.getByRole("button", { name: "Enable game sound" }).click();
  await expect(
    page.getByRole("button", { name: "Mute game sound" }),
  ).toBeVisible();
  await page.getByRole("button", { name: "Mute game sound" }).click();
  await expect(
    page.getByRole("button", { name: "Enable game sound" }),
  ).toBeVisible();
});

test("a complete flight shows results, saves progress, and advances the mission", async ({
  page,
}) => {
  test.setTimeout(90000);
  await page.clock.install({ time: new Date("2026-04-01T06:42:00") });
  await page.goto("/");
  await page.clock.pauseAt(new Date("2026-04-01T06:43:00"));
  const position = async () => {
    const transform = await page
      .locator(".route-map path")
      .last()
      .getAttribute("transform");
    return (
      ((Number(transform!.match(/translate\(([\d.]+)/)![1]) - 4) / 180) * 4800
    );
  };

  await page.keyboard.press("Space");
  for (const [index, x] of [1210, 2530, 3840].entries()) {
    if (index > 0) await page.keyboard.press("Space");
    await page.keyboard.down("KeyD");
    for (let i = 0; i < 80 && (await position()) < x - 90; i++) {
      await page.clock.runFor(200);
    }
    await page.keyboard.up("KeyD");
    for (let i = 0; i < 30; i++) {
      await page.clock.runFor(200);
      if (
        (await page.locator(".rescue-stat strong").innerText()).startsWith(
          String(index + 1).padStart(2, "0"),
        )
      )
        break;
    }
    await expect(page.locator(".rescue-stat strong")).toContainText(
      String(index + 1).padStart(2, "0"),
    );
  }

  await page.keyboard.press("Space");
  await page.keyboard.down("KeyW");
  await page.clock.runFor(1500);
  await page.keyboard.up("KeyW");
  await page.keyboard.down("KeyA");
  for (let i = 0; i < 150 && (await position()) > 320; i++) {
    await page.clock.runFor(200);
  }
  await page.keyboard.up("KeyA");
  await page.clock.runFor(1500);
  await page.keyboard.press("Space");
  await page.clock.runFor(17000);

  await expect(
    page.getByRole("heading", { name: "Everyone. Home safe." }),
  ).toBeVisible();
  expect(
    await page.evaluate(() =>
      JSON.parse(localStorage.getItem("airlift-completed") || "[]"),
    ),
  ).toContain("01");
  await page.getByRole("button", { name: "Next operation" }).click();
  await expect(page.locator(".mission-switcher-text strong")).toHaveText(
    "Storm Coast",
  );
  expect(
    await page.evaluate(() =>
      JSON.parse(localStorage.getItem("airlift-completed") || "[]"),
    ),
  ).toEqual(["01"]);
});

test("touch flight controls and phone layout work", async ({ browser }) => {
  const context = await browser.newContext({
    viewport: { width: 390, height: 844 },
    isMobile: true,
    hasTouch: true,
  });
  const page = await context.newPage();
  await page.goto("http://localhost:5173");
  expect(
    await page.evaluate(
      () => document.documentElement.scrollWidth <= innerWidth,
    ),
  ).toBe(true);
  const throttle = page.getByRole("button", {
    name: "Throttle: hold to climb (W or Up Arrow)",
    exact: true,
  });
  const bounds = await throttle.boundingBox();
  const touch = await context.newCDPSession(page);
  await touch.send("Input.dispatchTouchEvent", {
    type: "touchStart",
    touchPoints: [
      { x: bounds!.x + bounds!.width / 2, y: bounds!.y + bounds!.height / 2 },
    ],
  });
  await expect(page.locator(".live-status")).toHaveText("LIVE OPERATION");
  await expect(throttle).toHaveClass(/pressed/);
  await touch.send("Input.dispatchTouchEvent", {
    type: "touchEnd",
    touchPoints: [],
  });
  await expect(throttle).not.toHaveClass(/pressed/);
  await page
    .getByRole("button", { name: "Toggle rescue winch (Space or E)" })
    .tap();
  await expect(page.locator(".winch-button")).toContainText("RETRACT WINCH");
  await context.close();
});

for (let missionIndex = 0; missionIndex < 3; missionIndex++) {
  test(`mission ${missionIndex + 1} can rescue all survivors and return home`, async ({
    page,
  }) => {
    await page.goto("/");
    const result = await page.evaluate(async (index) => {
      const enginePath = "/src/game/engine.ts";
      const scenariosPath = "/src/game/scenarios.ts";
      const { RescueGame } = await import(enginePath);
      const { MISSIONS } = await import(scenariosPath);
      const canvas = document.createElement("canvas");
      canvas.style.cssText =
        "width:1200px;height:500px;position:absolute;top:0;visibility:hidden";
      document.body.append(canvas);
      const mission = MISSIONS[index];
      const game = new RescueGame(
        canvas,
        mission,
        () => {},
        () => {},
      );
      cancelAnimationFrame(game.frame);
      const dt = 1 / 60;
      const step = () => {
        game.clock += dt;
        game.update(dt);
      };
      const moveTo = (x: number) => {
        for (let i = 0; i < 5000; i++) {
          const error = x - game.x;
          const projected = error - game.vx * 0.36;
          game.setControl("right", projected > 9);
          game.setControl("left", projected < -9);
          step();
          if (Math.abs(error) < 16 && Math.abs(game.vx) < 12) break;
        }
        game.setControl("right", false);
        game.setControl("left", false);
      };
      game.toggleWinch();
      for (let i = 0; i < mission.targets.length; i++) {
        if (game.state.winch === "stowed") game.toggleWinch();
        moveTo(mission.targets[i].x);
        for (let j = 0; j < 600 && game.state.rescued <= i; j++) step();
        if (game.state.winch === "stowed") game.toggleWinch();
      }
      moveTo(245);
      if (game.state.winch === "lowering") game.toggleWinch();
      for (let i = 0; i < 2000 && game.state.status === "playing"; i++) step();
      const result = {
        status: game.state.status,
        rescued: game.state.rescued,
        health: game.state.health,
        fuel: game.state.fuel,
        x: game.x,
        y: game.y,
      };
      game.destroy();
      canvas.remove();
      return result;
    }, missionIndex);
    expect(result.rescued, JSON.stringify(result)).toBe(3);
    expect(result.status, JSON.stringify(result)).toBe("complete");
    expect(result.health).toBeGreaterThan(0);
  });
}

test("obstacle collisions cause damage, cooldown, and mission failure", async ({
  page,
}) => {
  await page.goto("/");
  const result = await page.evaluate(async () => {
    const enginePath = "/src/game/engine.ts";
    const scenariosPath = "/src/game/scenarios.ts";
    const { RescueGame } = await import(enginePath);
    const { MISSIONS } = await import(scenariosPath);
    const canvas = document.createElement("canvas");
    document.body.append(canvas);
    const game = new RescueGame(
      canvas,
      MISSIONS[0],
      () => {},
      () => {},
    );
    cancelAnimationFrame(game.frame);
    game.start();
    const obstacle = MISSIONS[0].hazards[0];
    game.x = obstacle.x;
    game.y = game.ground(obstacle.x) - obstacle.height + 10;
    game.update(1 / 60);
    const afterFirstHit = game.state.health;
    game.update(1 / 60);
    const duringCooldown = game.state.health;
    game.invincible = 0;
    game.hit("Obstacle contact");
    game.invincible = 0;
    game.hit("Obstacle contact");
    const status = game.state.status;
    game.destroy();
    canvas.remove();
    return { afterFirstHit, duringCooldown, status };
  });
  expect(result).toEqual({
    afterFirstHit: 2,
    duringCooldown: 2,
    status: "failed",
  });
});

export type TerrainPoint = { x: number; y: number };
export type RescueTarget = { x: number; y: number; name: string };
export type Hazard = {
  type: "tree" | "tower" | "fire";
  x: number;
  height: number;
};

export type Mission = {
  id: string;
  name: string;
  region: string;
  description: string;
  difficulty: string;
  conditions: string;
  wind: number;
  image: string;
  theme: "alpine" | "coast" | "fire";
  width: number;
  terrain: TerrainPoint[];
  targets: RescueTarget[];
  hazards: Hazard[];
};

export const MISSIONS: Mission[] = [
  {
    id: "01",
    name: "Pine Ridge",
    region: "NORTH CASCADES",
    description: "Three hikers. A remote mountain ridge. Be their way home.",
    difficulty: "ROOKIE",
    conditions: "Light winds",
    wind: 6,
    image: "/images/alpine-backdrop.png",
    theme: "alpine",
    width: 4800,
    terrain: [
      { x: 0, y: 650 },
      { x: 420, y: 650 },
      { x: 620, y: 720 },
      { x: 850, y: 690 },
      { x: 1040, y: 565 },
      { x: 1360, y: 565 },
      { x: 1530, y: 700 },
      { x: 1770, y: 695 },
      { x: 1900, y: 590 },
      { x: 2140, y: 635 },
      { x: 2370, y: 520 },
      { x: 2690, y: 520 },
      { x: 2900, y: 700 },
      { x: 3190, y: 665 },
      { x: 3400, y: 570 },
      { x: 3670, y: 470 },
      { x: 4020, y: 470 },
      { x: 4240, y: 640 },
      { x: 4500, y: 690 },
      { x: 4800, y: 650 },
    ],
    targets: [
      { x: 1210, y: 565, name: "Alex" },
      { x: 2530, y: 520, name: "Morgan" },
      { x: 3840, y: 470, name: "Sam" },
    ],
    hazards: [
      { type: "tree", x: 760, height: 125 },
      { type: "tree", x: 1550, height: 180 },
      { type: "tree", x: 1710, height: 140 },
      { type: "tower", x: 2090, height: 235 },
      { type: "tree", x: 2900, height: 190 },
      { type: "tree", x: 3100, height: 145 },
      { type: "tower", x: 3480, height: 180 },
      { type: "tree", x: 4310, height: 190 },
    ],
  },
  {
    id: "02",
    name: "Storm Coast",
    region: "PACIFIC NORTHWEST",
    description:
      "A rising tide and an unforgiving coast. Find the missing crew.",
    difficulty: "SKILLED",
    conditions: "Strong crosswinds",
    wind: 23,
    image: "/images/coastal-backdrop.png",
    theme: "coast",
    width: 5000,
    terrain: [
      { x: 0, y: 650 },
      { x: 430, y: 650 },
      { x: 600, y: 750 },
      { x: 850, y: 750 },
      { x: 1000, y: 585 },
      { x: 1320, y: 585 },
      { x: 1480, y: 755 },
      { x: 1930, y: 755 },
      { x: 2100, y: 500 },
      { x: 2470, y: 500 },
      { x: 2670, y: 755 },
      { x: 3120, y: 755 },
      { x: 3330, y: 570 },
      { x: 3760, y: 570 },
      { x: 3960, y: 755 },
      { x: 4400, y: 755 },
      { x: 4600, y: 640 },
      { x: 5000, y: 640 },
    ],
    targets: [
      { x: 1170, y: 585, name: "Jamie" },
      { x: 2310, y: 500, name: "Casey" },
      { x: 3570, y: 570, name: "Robin" },
    ],
    hazards: [
      { type: "tower", x: 1590, height: 315 },
      { type: "tower", x: 2790, height: 350 },
      { type: "tree", x: 3340, height: 130 },
      { type: "tower", x: 4110, height: 300 },
    ],
  },
  {
    id: "03",
    name: "Ember Valley",
    region: "SIERRA NEVADA",
    description:
      "The forest is burning. Reach the fire crew before the valley is lost.",
    difficulty: "EXPERT",
    conditions: "Smoke & updrafts",
    wind: 15,
    image: "/images/wildfire-backdrop.png",
    theme: "fire",
    width: 5100,
    terrain: [
      { x: 0, y: 650 },
      { x: 430, y: 650 },
      { x: 660, y: 710 },
      { x: 940, y: 560 },
      { x: 1320, y: 560 },
      { x: 1500, y: 685 },
      { x: 1820, y: 680 },
      { x: 2070, y: 520 },
      { x: 2460, y: 520 },
      { x: 2700, y: 700 },
      { x: 3040, y: 700 },
      { x: 3350, y: 490 },
      { x: 3790, y: 490 },
      { x: 4100, y: 670 },
      { x: 4550, y: 700 },
      { x: 5100, y: 650 },
    ],
    targets: [
      { x: 1160, y: 560, name: "Taylor" },
      { x: 2280, y: 520, name: "Reese" },
      { x: 3580, y: 490, name: "Drew" },
    ],
    hazards: [
      { type: "fire", x: 750, height: 135 },
      { type: "tree", x: 1500, height: 175 },
      { type: "fire", x: 1710, height: 210 },
      { type: "tower", x: 1940, height: 220 },
      { type: "fire", x: 2790, height: 190 },
      { type: "tree", x: 3100, height: 180 },
      { type: "fire", x: 3960, height: 210 },
      { type: "fire", x: 4200, height: 170 },
    ],
  },
];

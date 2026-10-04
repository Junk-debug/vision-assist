import { Messages } from '../common/Messages';

export const CENTER_FRACTION: number = 0.28;

const BLACK_VALUE: number = 0.13;
const BLACK_LIGHTNESS: number = 0.2;
const BLACK_SATURATION: number = 0.35;
const DIM_VALUE: number = 0.25;
const DIM_SATURATION: number = 0.3;
const GRAY_SATURATION: number = 0.15;
const WHITE_LIGHTNESS: number = 0.78;
const NEUTRAL_BLACK_LIGHTNESS: number = 0.22;
const LIGHT_GRAY_LIGHTNESS: number = 0.64;
const DARK_GRAY_LIGHTNESS: number = 0.36;
const BEIGE_SATURATION: number = 0.38;
const BEIGE_LIGHTNESS: number = 0.6;
const BROWN_LIGHTNESS: number = 0.55;
const PINK_LIGHTNESS: number = 0.78;
const PINK_SATURATION: number = 0.55;
const DARK_LIGHTNESS: number = 0.3;
const LIGHT_LIGHTNESS: number = 0.86;
const LIGHT_SATURATION: number = 0.45;
const HUE_MARGIN_DEGREES: number = 10;
const LIGHTNESS_MARGIN: number = 0.08;

const SURROUND_SAMPLES: number = 6000;
const CENTER_SAMPLES_PER_CELL: number = 36;
const GRID_CELLS: number = 10;
const DARK_PIXEL: number = 20;
const CLIPPED_PIXEL: number = 250;
const BRIGHT_SHARE: number = 0.1;
const MIN_ESTIMATE_SAMPLES: number = 50;
const WARM_LIMIT: number = 0.48;
const COOL_LIMIT: number = 0.27;
const TINT_LIMIT: number = 0.12;
const BALANCE_BLEND: number = 0.85;
const SPECULAR_PIXEL: number = 245;
const SPECULAR_RATIO: number = 1.25;
const SHADOW_PIXEL: number = 40;
const SHADOW_RATIO: number = 0.3;
const MIN_KEPT_SHARE: number = 0.25;
const REFERENCE_PERCENTILE: number = 0.95;
const MIN_REFERENCE_WHITE: number = 150;
const SURE_SHARE: number = 0.6;
const MIXED_SHARE: number = 0.4;
const SECOND_SHARE: number = 0.2;
const SURE_MARGIN: number = 0.3;

export interface RgbaFrame {
  data: Uint8Array;
  width: number;
  height: number;
  rowBytes: number;
}

export interface Rgb {
  red: number;
  green: number;
  blue: number;
}

export interface PixelRegion {
  x: number;
  y: number;
  width: number;
  height: number;
}

export interface WhiteBalance {
  red: number;
  green: number;
  blue: number;
  clamped: boolean;
}

export interface ColorName {
  name: string;
  base: string;
  margin: number;
}

export enum ColorConfidence {
  SURE,
  PROBABLE,
  MIXED
}

export interface ColorReading {
  name: string;
  base: string;
  second: string;
  share: number;
  confidence: ColorConfidence;
  color: Rgb;
  balance: WhiteBalance;
}

interface HueBand {
  limit: number;
  name: string;
}

const HUE_BANDS: HueBand[] = [
  { limit: 12, name: 'red' },
  { limit: 40, name: 'orange' },
  { limit: 70, name: 'yellow' },
  { limit: 170, name: 'green' },
  { limit: 260, name: 'blue' },
  { limit: 290, name: 'purple' },
  { limit: 345, name: 'pink' },
  { limit: 361, name: 'red' }
];

const MODIFIED_NAMES: string[] = ['red', 'green', 'blue', 'purple'];
const LIGHTENED_NAMES: string[] = ['green', 'blue', 'purple'];

interface Hsv {
  hue: number;
  saturation: number;
  value: number;
}

function toHsv(red: number, green: number, blue: number): Hsv {
  const r = Math.min(255, Math.max(0, red)) / 255;
  const g = Math.min(255, Math.max(0, green)) / 255;
  const b = Math.min(255, Math.max(0, blue)) / 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const delta = max - min;
  let hue = 0;
  if (delta > 0) {
    if (max === r) {
      hue = 60 * (((g - b) / delta) % 6);
    } else if (max === g) {
      hue = 60 * ((b - r) / delta + 2);
    } else {
      hue = 60 * ((r - g) / delta + 4);
    }
  }
  if (hue < 0) {
    hue += 360;
  }
  return { hue: hue, saturation: max === 0 ? 0 : delta / max, value: max };
}

function clamp01(value: number): number {
  return Math.min(1, Math.max(0, value));
}

function hueMargin(hue: number): number {
  let nearest = 360;
  for (const band of HUE_BANDS) {
    if (band.limit <= 360) {
      nearest = Math.min(nearest, Math.abs(hue - band.limit));
    }
  }
  return clamp01(nearest / HUE_MARGIN_DEGREES);
}

function lightnessMargin(lightness: number, limits: number[]): number {
  let nearest = 1;
  for (const limit of limits) {
    nearest = Math.min(nearest, Math.abs(lightness - limit));
  }
  return clamp01(nearest / LIGHTNESS_MARGIN);
}

function hueName(hue: number): string {
  for (const band of HUE_BANDS) {
    if (hue < band.limit) {
      return band.name;
    }
  }
  return 'red';
}

function neutralName(lightness: number, saturationMargin: number): ColorName {
  const margin = Math.min(saturationMargin, lightnessMargin(lightness, [NEUTRAL_BLACK_LIGHTNESS, WHITE_LIGHTNESS]));
  if (lightness >= WHITE_LIGHTNESS) {
    return { name: 'white', base: 'white', margin: margin };
  }
  if (lightness <= NEUTRAL_BLACK_LIGHTNESS) {
    return { name: 'black', base: 'black', margin: margin };
  }
  if (lightness > LIGHT_GRAY_LIGHTNESS) {
    return { name: 'light gray', base: 'gray', margin: margin };
  }
  if (lightness < DARK_GRAY_LIGHTNESS) {
    return { name: 'dark gray', base: 'gray', margin: margin };
  }
  return { name: 'gray', base: 'gray', margin: margin };
}

export function nameColor(red: number, green: number, blue: number, lightness: number = -1): ColorName {
  const hsv = toHsv(red, green, blue);
  const light = lightness < 0 ? hsv.value : clamp01(lightness);
  if (hsv.value < BLACK_VALUE || (light < BLACK_LIGHTNESS && hsv.saturation < BLACK_SATURATION)) {
    const margin = hsv.value < BLACK_VALUE ? 1 : lightnessMargin(light, [BLACK_LIGHTNESS]);
    return { name: 'black', base: 'black', margin: margin };
  }
  if (hsv.saturation < GRAY_SATURATION || (hsv.value < DIM_VALUE && hsv.saturation < DIM_SATURATION)) {
    return neutralName(light, clamp01((GRAY_SATURATION - hsv.saturation) / GRAY_SATURATION));
  }
  const saturationMargin = clamp01((hsv.saturation - GRAY_SATURATION) / GRAY_SATURATION);
  const margin = Math.min(saturationMargin, hueMargin(hsv.hue));
  const name = hueName(hsv.hue);
  const warm = hsv.hue >= 20 && hsv.hue < 65;
  if (warm && hsv.saturation < BEIGE_SATURATION && light >= BEIGE_LIGHTNESS) {
    return { name: 'beige', base: 'beige', margin: Math.min(margin, lightnessMargin(light, [BEIGE_LIGHTNESS])) };
  }
  if (hsv.hue >= 12 && hsv.hue < 70 && light < BROWN_LIGHTNESS) {
    return { name: 'brown', base: 'brown', margin: Math.min(saturationMargin, lightnessMargin(light, [BROWN_LIGHTNESS])) };
  }
  if (name === 'red' && light >= PINK_LIGHTNESS && hsv.saturation < PINK_SATURATION) {
    return { name: 'pink', base: 'pink', margin: Math.min(margin, lightnessMargin(light, [PINK_LIGHTNESS])) };
  }
  if (MODIFIED_NAMES.indexOf(name) >= 0 && light < DARK_LIGHTNESS) {
    return { name: `dark ${name}`, base: name, margin: margin };
  }
  if (LIGHTENED_NAMES.indexOf(name) >= 0 && light > LIGHT_LIGHTNESS && hsv.saturation < LIGHT_SATURATION) {
    return { name: `light ${name}`, base: name, margin: margin };
  }
  return { name: name, base: name, margin: margin };
}

export function centerRegion(width: number, height: number, fraction: number = CENTER_FRACTION): PixelRegion {
  const size = Math.min(width, height, Math.max(2, Math.round(Math.min(width, height) * fraction)));
  return { x: Math.max(0, Math.round((width - size) / 2)), y: Math.max(0, Math.round((height - size) / 2)), width: size, height: size };
}

function inside(region: PixelRegion, x: number, y: number): boolean {
  return x >= region.x && x < region.x + region.width && y >= region.y && y < region.y + region.height;
}

function maxChannel(color: Rgb): number {
  return Math.max(color.red, color.green, color.blue);
}

function pixelAt(frame: RgbaFrame, x: number, y: number): Rgb {
  const offset = y * frame.rowBytes + x * 4;
  return { red: frame.data[offset], green: frame.data[offset + 1], blue: frame.data[offset + 2] };
}

function surroundSamples(frame: RgbaFrame, center: PixelRegion): Rgb[] {
  const step = Math.max(1, Math.floor(Math.sqrt(frame.width * frame.height / SURROUND_SAMPLES)));
  const samples: Rgb[] = [];
  for (let y = Math.floor(step / 2); y < frame.height; y += step) {
    for (let x = Math.floor(step / 2); x < frame.width; x += step) {
      if (!inside(center, x, y)) {
        samples.push(pixelAt(frame, x, y));
      }
    }
  }
  return samples;
}

const IDENTITY: WhiteBalance = { red: 1, green: 1, blue: 1, clamped: false };

function normalised(sum: Rgb): Rgb {
  const mean = (sum.red + sum.green + sum.blue) / 3;
  return { red: sum.red / mean, green: sum.green / mean, blue: sum.blue / mean };
}

function meanOf(colors: Rgb[]): Rgb {
  let red = 0;
  let green = 0;
  let blue = 0;
  for (const color of colors) {
    red += color.red;
    green += color.green;
    blue += color.blue;
  }
  const count = Math.max(1, colors.length);
  return { red: red / count, green: green / count, blue: blue / count };
}

export function balanceFromSamples(samples: Rgb[]): WhiteBalance {
  const usable = samples.filter((color: Rgb) => {
    const max = maxChannel(color);
    return max >= DARK_PIXEL && max < CLIPPED_PIXEL && Math.min(color.red, color.green, color.blue) > 0;
  });
  if (usable.length < MIN_ESTIMATE_SAMPLES) {
    return IDENTITY;
  }
  const grayWorld = normalised(meanOf(usable));
  const bright = usable.slice().sort((a: Rgb, b: Rgb) => maxChannel(b) - maxChannel(a))
    .slice(0, Math.max(1, Math.round(usable.length * BRIGHT_SHARE)));
  const whitePatch = normalised(meanOf(bright));
  const logRed = Math.log((grayWorld.red + whitePatch.red) / 2);
  const logGreen = Math.log((grayWorld.green + whitePatch.green) / 2);
  const logBlue = Math.log((grayWorld.blue + whitePatch.blue) / 2);
  const logMean = (logRed + logGreen + logBlue) / 3;
  const castRed = logRed - logMean;
  const castGreen = logGreen - logMean;
  const castBlue = logBlue - logMean;
  const warmth = (castRed - castBlue) / 2;
  const tint = castGreen - (castRed + castBlue) / 2;
  const limitedWarmth = Math.min(WARM_LIMIT, Math.max(-COOL_LIMIT, warmth));
  const limitedTint = Math.min(TINT_LIMIT, Math.max(-TINT_LIMIT, tint));
  const appliedWarmth = limitedWarmth * BALANCE_BLEND;
  const appliedTint = limitedTint * BALANCE_BLEND;
  return {
    red: Math.exp(-(appliedWarmth - appliedTint / 3)),
    green: Math.exp(-(2 * appliedTint / 3)),
    blue: Math.exp(-(-appliedWarmth - appliedTint / 3)),
    clamped: limitedWarmth !== warmth || limitedTint !== tint
  };
}

export function applyBalance(color: Rgb, balance: WhiteBalance): Rgb {
  return {
    red: Math.min(255, color.red * balance.red),
    green: Math.min(255, color.green * balance.green),
    blue: Math.min(255, color.blue * balance.blue)
  };
}

function median(values: number[]): number {
  if (values.length === 0) {
    return 0;
  }
  const sorted = values.slice().sort((a: number, b: number) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 === 1 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
}

function percentile(values: number[], share: number): number {
  if (values.length === 0) {
    return 0;
  }
  const sorted = values.slice().sort((a: number, b: number) => a - b);
  return sorted[Math.min(sorted.length - 1, Math.floor(sorted.length * share))];
}

function centerCells(frame: RgbaFrame, center: PixelRegion): Rgb[] {
  const cellWidth = center.width / GRID_CELLS;
  const cellHeight = center.height / GRID_CELLS;
  const step = Math.max(1, Math.floor(Math.min(cellWidth, cellHeight) / Math.sqrt(CENTER_SAMPLES_PER_CELL)));
  const cells: Rgb[][] = [];
  const all: Rgb[] = [];
  for (let row = 0; row < GRID_CELLS; row++) {
    for (let column = 0; column < GRID_CELLS; column++) {
      const pixels: Rgb[] = [];
      const x0 = center.x + Math.floor(column * cellWidth);
      const y0 = center.y + Math.floor(row * cellHeight);
      const x1 = Math.max(x0 + 1, center.x + Math.floor((column + 1) * cellWidth));
      const y1 = Math.max(y0 + 1, center.y + Math.floor((row + 1) * cellHeight));
      for (let y = y0; y < y1 && y < frame.height; y += step) {
        for (let x = x0; x < x1 && x < frame.width; x += step) {
          const pixel = pixelAt(frame, x, y);
          pixels.push(pixel);
          all.push(pixel);
        }
      }
      cells.push(pixels);
    }
  }
  const typical = median(all.map((pixel: Rgb) => maxChannel(pixel)));
  const kept = (pixel: Rgb): boolean => {
    const max = maxChannel(pixel);
    const specular = max >= SPECULAR_PIXEL && max > typical * SPECULAR_RATIO;
    const shadow = max < SHADOW_PIXEL && max < typical * SHADOW_RATIO;
    return !specular && !shadow;
  };
  const keptCount = all.filter(kept).length;
  const filter = keptCount >= all.length * MIN_KEPT_SHARE;
  const means: Rgb[] = [];
  for (const pixels of cells) {
    const chosen = filter ? pixels.filter(kept) : pixels;
    if (chosen.length > 0) {
      means.push(meanOf(chosen));
    }
  }
  return means;
}

function describeConfidence(share: number, margin: number, clamped: boolean): ColorConfidence {
  if (share < MIXED_SHARE) {
    return ColorConfidence.MIXED;
  }
  if (share < SURE_SHARE || margin < SURE_MARGIN || clamped) {
    return ColorConfidence.PROBABLE;
  }
  return ColorConfidence.SURE;
}

export function readColor(frame: RgbaFrame, fraction: number = CENTER_FRACTION): ColorReading {
  return readColorInRegion(frame, centerRegion(frame.width, frame.height, fraction));
}

export function readColorInRegion(frame: RgbaFrame, region: PixelRegion): ColorReading {
  const center = region;
  const surround = surroundSamples(frame, center);
  const balance = balanceFromSamples(surround);
  const cells = centerCells(frame, center).map((cell: Rgb) => applyBalance(cell, balance));
  const brightness = surround.filter((color: Rgb) => maxChannel(color) < CLIPPED_PIXEL)
    .map((color: Rgb) => maxChannel(applyBalance(color, balance)))
    .concat(cells.map((cell: Rgb) => maxChannel(cell)));
  const referenceWhite = Math.max(MIN_REFERENCE_WHITE, percentile(brightness, REFERENCE_PERCENTILE));
  const lightnessOf = (color: Rgb): number => clamp01(maxChannel(color) / referenceWhite);
  const counts: Map<string, Rgb[]> = new Map<string, Rgb[]>();
  for (const cell of cells) {
    const base = nameColor(cell.red, cell.green, cell.blue, lightnessOf(cell)).base;
    const group = counts.get(base);
    if (group === undefined) {
      counts.set(base, [cell]);
    } else {
      group.push(cell);
    }
  }
  const ranked = Array.from(counts.entries()).sort((a: [string, Rgb[]], b: [string, Rgb[]]) => b[1].length - a[1].length);
  if (ranked.length === 0) {
    return {
      name: 'black', base: 'black', second: '', share: 0, confidence: ColorConfidence.MIXED,
      color: { red: 0, green: 0, blue: 0 }, balance: balance
    };
  }
  const total = Math.max(1, cells.length);
  const dominant = ranked[0][1];
  const color: Rgb = {
    red: median(dominant.map((cell: Rgb) => cell.red)),
    green: median(dominant.map((cell: Rgb) => cell.green)),
    blue: median(dominant.map((cell: Rgb) => cell.blue))
  };
  const named = nameColor(color.red, color.green, color.blue, lightnessOf(color));
  const share = dominant.length / total;
  const second = ranked.length > 1 && ranked[1][1].length / total >= SECOND_SHARE ? ranked[1][0] : '';
  return {
    name: named.base === ranked[0][0] ? named.name : ranked[0][0],
    base: ranked[0][0],
    second: second,
    share: share,
    confidence: describeConfidence(share, named.margin, balance.clamped),
    color: color,
    balance: balance
  };
}

export function describeColor(reading: ColorReading): string {
  if (reading.confidence === ColorConfidence.MIXED) {
    return Messages.mixedColours(reading.base, reading.second);
  }
  if (reading.confidence === ColorConfidence.PROBABLE) {
    return Messages.probablyColour(reading.name);
  }
  return reading.name;
}

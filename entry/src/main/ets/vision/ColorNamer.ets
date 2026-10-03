const BLACK_VALUE: number = 0.16;
const WHITE_VALUE: number = 0.82;
const GRAY_SATURATION: number = 0.14;
const LIGHT_VALUE: number = 0.78;
const DARK_VALUE: number = 0.38;
const BROWN_VALUE: number = 0.6;

interface HueBand {
  limit: number;
  name: string;
}

const HUE_BANDS: HueBand[] = [
  { limit: 15, name: 'red' },
  { limit: 42, name: 'orange' },
  { limit: 68, name: 'yellow' },
  { limit: 165, name: 'green' },
  { limit: 200, name: 'turquoise' },
  { limit: 255, name: 'blue' },
  { limit: 290, name: 'purple' },
  { limit: 345, name: 'pink' },
  { limit: 361, name: 'red' }
];

export function nameColor(red: number, green: number, blue: number): string {
  const r = red / 255;
  const g = green / 255;
  const b = blue / 255;
  const max = Math.max(r, g, b);
  const min = Math.min(r, g, b);
  const delta = max - min;
  const value = max;
  const saturation = max === 0 ? 0 : delta / max;
  if (value < BLACK_VALUE) {
    return 'black';
  }
  if (saturation < GRAY_SATURATION) {
    if (value > WHITE_VALUE) {
      return 'white';
    }
    return value > 0.5 ? 'light gray' : 'dark gray';
  }
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
  let name = 'red';
  for (const band of HUE_BANDS) {
    if (hue < band.limit) {
      name = band.name;
      break;
    }
  }
  if ((name === 'orange' || name === 'yellow') && value < BROWN_VALUE) {
    return 'brown';
  }
  if (value > LIGHT_VALUE && saturation < 0.5) {
    return `light ${name}`;
  }
  if (value < DARK_VALUE) {
    return `dark ${name}`;
  }
  return name;
}

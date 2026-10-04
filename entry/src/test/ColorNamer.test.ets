import { describe, it, expect } from '@ohos/hypium';
import {
  balanceFromSamples, ColorConfidence, ColorReading, describeColor, nameColor, readColor, readColorInRegion, Rgb,
  RgbaFrame
} from '../main/ets/vision/ColorNamer';

const WIDTH: number = 160;
const HEIGHT: number = 120;

const WARM: Rgb = { red: 1.0, green: 0.78, blue: 0.55 };
const COOL: Rgb = { red: 0.75, green: 0.88, blue: 1.0 };
const NEUTRAL: Rgb = { red: 1, green: 1, blue: 1 };

const WALL: Rgb = { red: 215, green: 215, blue: 215 };
const TABLE: Rgb = { red: 105, green: 105, blue: 105 };
const BLUE_SHIRT: Rgb = { red: 40, green: 80, blue: 180 };
const WHITE_PAPER: Rgb = { red: 232, green: 232, blue: 232 };
const GRAY_PAPER: Rgb = { red: 128, green: 128, blue: 128 };

type Painter = (x: number, y: number) => Rgb;

function frameOf(paint: Painter, cast: Rgb): RgbaFrame {
  const data = new Uint8Array(WIDTH * HEIGHT * 4);
  let seed = 7;
  for (let y = 0; y < HEIGHT; y++) {
    for (let x = 0; x < WIDTH; x++) {
      seed = (seed * 1103515245 + 12345) % 2147483648;
      const noise = (seed % 9) - 4;
      const color = paint(x, y);
      const offset = (y * WIDTH + x) * 4;
      data[offset] = Math.max(0, Math.min(255, Math.round(color.red * cast.red + noise)));
      data[offset + 1] = Math.max(0, Math.min(255, Math.round(color.green * cast.green + noise)));
      data[offset + 2] = Math.max(0, Math.min(255, Math.round(color.blue * cast.blue + noise)));
      data[offset + 3] = 255;
    }
  }
  return { data: data, width: WIDTH, height: HEIGHT, rowBytes: WIDTH * 4 };
}

function inCenter(x: number, y: number, half: number): boolean {
  return Math.abs(x - WIDTH / 2) < half && Math.abs(y - HEIGHT / 2) < half;
}

function room(object: Rgb, half: number = 30): Painter {
  return (x: number, y: number): Rgb => {
    if (inCenter(x, y, half)) {
      return object;
    }
    return y < HEIGHT * 0.55 ? WALL : TABLE;
  };
}

function read(paint: Painter, cast: Rgb): ColorReading {
  return readColor(frameOf(paint, cast));
}

export default function colorNamerTest() {
  describe('colorNamer', () => {
    it('namesCoarseColors', 0, () => {
      expect(nameColor(230, 30, 30).name).assertEqual('red');
      expect(nameColor(240, 140, 20).name).assertEqual('orange');
      expect(nameColor(240, 220, 30).name).assertEqual('yellow');
      expect(nameColor(40, 180, 60).name).assertEqual('green');
      expect(nameColor(30, 60, 220).name).assertEqual('blue');
      expect(nameColor(130, 40, 200).name).assertEqual('purple');
      expect(nameColor(230, 60, 170).name).assertEqual('pink');
      expect(nameColor(120, 70, 20).name).assertEqual('brown');
      expect(nameColor(225, 205, 170).name).assertEqual('beige');
    });
    it('namesNeutrals', 0, () => {
      expect(nameColor(5, 5, 5).name).assertEqual('black');
      expect(nameColor(250, 250, 250).name).assertEqual('white');
      expect(nameColor(128, 128, 128).name).assertEqual('gray');
      expect(nameColor(70, 70, 70).name).assertEqual('dark gray');
    });
    it('addsLightAndDarkOnlyWhenClear', 0, () => {
      expect(nameColor(0, 0, 60).name).assertEqual('dark blue');
      expect(nameColor(170, 210, 245).name).assertEqual('light blue');
      expect(nameColor(250, 180, 180).name).assertEqual('pink');
      expect(nameColor(40, 80, 180).name).assertEqual('blue');
    });
    it('usesRelativeLightnessForNeutrals', 0, () => {
      expect(nameColor(150, 150, 150, 0.95).name).assertEqual('white');
      expect(nameColor(150, 150, 150, 0.5).name).assertEqual('gray');
    });
    it('keepsNeutralLightUnchanged', 0, () => {
      const samples: Rgb[] = [];
      for (let index = 0; index < 200; index++) {
        samples.push(index % 2 === 0 ? WALL : TABLE);
      }
      const balance = balanceFromSamples(samples);
      expect(Math.abs(balance.red - 1) < 0.01).assertTrue();
      expect(Math.abs(balance.blue - 1) < 0.01).assertTrue();
      expect(balance.clamped).assertFalse();
    });
    it('correctsAWarmCast', 0, () => {
      const samples: Rgb[] = [];
      for (let index = 0; index < 200; index++) {
        const base = index % 2 === 0 ? WALL : TABLE;
        samples.push({ red: base.red * WARM.red, green: base.green * WARM.green, blue: base.blue * WARM.blue });
      }
      const balance = balanceFromSamples(samples);
      expect(balance.blue > balance.green).assertTrue();
      expect(balance.green > balance.red).assertTrue();
    });
    it('namesABlueObjectUnderWarmAndCoolLight', 0, () => {
      expect(read(room(BLUE_SHIRT), WARM).base).assertEqual('blue');
      expect(read(room(BLUE_SHIRT), COOL).base).assertEqual('blue');
      expect(read(room(BLUE_SHIRT), NEUTRAL).name).assertEqual('blue');
    });
    it('namesWhitePaperUnderCasts', 0, () => {
      expect(nameColor(232, 181, 128).name).assertEqual('orange');
      expect(read(room(WHITE_PAPER), WARM).name).assertEqual('white');
      expect(read(room(WHITE_PAPER), COOL).name).assertEqual('white');
      expect(read(room(WHITE_PAPER), NEUTRAL).name).assertEqual('white');
    });
    it('namesGrayPaperUnderCasts', 0, () => {
      expect(read(room(GRAY_PAPER), WARM).base).assertEqual('gray');
      expect(read(room(GRAY_PAPER), COOL).base).assertEqual('gray');
    });
    it('namesBlack', 0, () => {
      const reading = read(room({ red: 16, green: 16, blue: 18 }), NEUTRAL);
      expect(reading.name).assertEqual('black');
      expect(describeColor(reading)).assertEqual('black');
    });
    it('ignoresSpecularHighlights', 0, () => {
      const shiny: Painter = (x: number, y: number): Rgb => {
        if (inCenter(x, y, 30) && (x + y) % 5 === 0) {
          return { red: 255, green: 255, blue: 255 };
        }
        return room(BLUE_SHIRT)(x, y);
      };
      const reading = read(shiny, NEUTRAL);
      expect(reading.name).assertEqual('blue');
      expect(reading.confidence).assertEqual(ColorConfidence.SURE);
    });
    it('doesNotNeutraliseALargeColouredObject', 0, () => {
      const reading = read((x: number, y: number): Rgb => BLUE_SHIRT, NEUTRAL);
      expect(reading.base).assertEqual('blue');
      expect(describeColor(reading)).assertEqual('probably blue');
    });
    it('saysMixedWhenNoColourDominates', 0, () => {
      const striped: Painter = (x: number, y: number): Rgb => {
        if (inCenter(x, y, 30)) {
          return x < WIDTH / 2 ? { red: 200, green: 30, blue: 30 } : BLUE_SHIRT;
        }
        return room(BLUE_SHIRT)(x, y);
      };
      const reading = read(striped, NEUTRAL);
      expect(reading.confidence).assertEqual(ColorConfidence.PROBABLE);
      const quarters: Painter = (x: number, y: number): Rgb => {
        if (inCenter(x, y, 30)) {
          const left = x < WIDTH / 2;
          const top = y < HEIGHT / 2;
          if (left && top) {
            return { red: 200, green: 30, blue: 30 };
          }
          if (left) {
            return BLUE_SHIRT;
          }
          return top ? { red: 40, green: 170, blue: 60 } : { red: 240, green: 220, blue: 30 };
        }
        return room(BLUE_SHIRT)(x, y);
      };
      const mixed = read(quarters, NEUTRAL);
      expect(mixed.confidence).assertEqual(ColorConfidence.MIXED);
      expect(describeColor(mixed).startsWith('mixed colours')).assertTrue();
    });
    it('readsAnyRegionOfTheFrame', 0, () => {
      const frame = frameOf((x: number, y: number): Rgb => x < 40 && y < 40 ? { red: 200, green: 30, blue: 30 } : WALL, WARM);
      expect(readColorInRegion(frame, { x: 5, y: 5, width: 30, height: 25 }).base).assertEqual('red');
    });
    it('saysProbablyForAWeakColour', 0, () => {
      const reading = read(room({ red: 120, green: 128, blue: 146 }), NEUTRAL);
      expect(describeColor(reading).startsWith('probably')).assertTrue();
    });
  });
}

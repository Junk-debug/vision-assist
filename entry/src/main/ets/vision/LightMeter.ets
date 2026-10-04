import { image } from '@kit.ImageKit';
import { sensor } from '@kit.SensorServiceKit';
import { describeError, log } from '../common/Logger';

const SENSOR_INTERVAL_NS: number = 200000000;
const LUMA_SAMPLE_STEP: number = 16;
const DARK_LUX: number = 10;
const DIM_LUX: number = 60;
const DARK_LUMA: number = 35;
const DIM_LUMA: number = 70;
const SENSOR_CONFLICT_LUMA: number = 80;

export enum Brightness {
  DARK,
  DIM,
  LIT
}

export function brightnessFrom(lux: number | undefined, luma: number | undefined): Brightness | undefined {
  const sensorBroken = lux !== undefined && lux < DARK_LUX && luma !== undefined && luma > SENSOR_CONFLICT_LUMA;
  if (lux !== undefined && !sensorBroken) {
    return lux < DARK_LUX ? Brightness.DARK : (lux < DIM_LUX ? Brightness.DIM : Brightness.LIT);
  }
  if (luma !== undefined) {
    return luma < DARK_LUMA ? Brightness.DARK : (luma < DIM_LUMA ? Brightness.DIM : Brightness.LIT);
  }
  return undefined;
}

export async function frameLuma(frame: image.PixelMap): Promise<number> {
  const info = await frame.getImageInfo();
  const buffer = new ArrayBuffer(frame.getPixelBytesNumber());
  await frame.readPixelsToBuffer(buffer);
  const pixels = new Uint8Array(buffer);
  const rowBytes = pixels.length / info.size.height;
  let sum = 0;
  let count = 0;
  for (let y = 0; y < info.size.height; y += LUMA_SAMPLE_STEP) {
    for (let x = 0; x < info.size.width; x += LUMA_SAMPLE_STEP) {
      const offset = y * rowBytes + x * 4;
      sum += 0.299 * pixels[offset] + 0.587 * pixels[offset + 1] + 0.114 * pixels[offset + 2];
      count++;
    }
  }
  return count === 0 ? 0 : sum / count;
}

export class LightMeter {
  private lux: number | undefined = undefined;
  private listening: boolean = false;

  start(): void {
    if (this.listening) {
      return;
    }
    try {
      sensor.on(sensor.SensorId.AMBIENT_LIGHT, (data: sensor.LightResponse) => {
        this.lux = data.intensity;
      }, { interval: SENSOR_INTERVAL_NS });
      this.listening = true;
    } catch (error) {
      log(`light sensor unavailable ${describeError(error)}`);
    }
  }

  stop(): void {
    if (!this.listening) {
      return;
    }
    try {
      sensor.off(sensor.SensorId.AMBIENT_LIGHT);
    } catch (error) {
      log(`light sensor off failed ${describeError(error)}`);
    }
    this.listening = false;
  }

  async measure(frame: image.PixelMap): Promise<Brightness | undefined> {
    const luma = await frameLuma(frame);
    return brightnessFrom(this.lux, luma);
  }
}

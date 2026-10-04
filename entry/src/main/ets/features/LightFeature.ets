import { image } from '@kit.ImageKit';
import { sensor } from '@kit.SensorServiceKit';
import { Feature, FeatureServices } from './Feature';
import { describeError, log } from '../common/Logger';
import { LightLevel, Messages } from '../common/Messages';
import { normalizeFrame } from '../vision/FrameNormalizer';

const SENSOR_TIMEOUT_MS: number = 1500;
const SENSOR_INTERVAL_NS: number = 100000000;
const LUMA_SAMPLE_STEP: number = 16;
const DARK_LUX: number = 5;
const DIM_LUX: number = 50;
const NORMAL_LUX: number = 500;
const BRIGHT_LUX: number = 2000;
const DARK_LUMA: number = 35;
const DIM_LUMA: number = 85;
const NORMAL_LUMA: number = 170;
const SENSOR_CONFLICT_LUMA: number = 80;

export function describeLux(lux: number): string {
  if (lux < DARK_LUX) {
    return Messages.lightFromLux(LightLevel.DARK, lux);
  }
  if (lux < DIM_LUX) {
    return Messages.lightFromLux(LightLevel.DIM, lux);
  }
  if (lux < NORMAL_LUX) {
    return Messages.lightFromLux(LightLevel.NORMAL, lux);
  }
  if (lux < BRIGHT_LUX) {
    return Messages.lightFromLux(LightLevel.BRIGHT, lux);
  }
  return Messages.lightFromLux(LightLevel.DAYLIGHT, lux);
}

export function describeLuma(luma: number): string {
  if (luma < DARK_LUMA) {
    return Messages.LUMA_DARK;
  }
  if (luma < DIM_LUMA) {
    return Messages.LUMA_DIM;
  }
  if (luma < NORMAL_LUMA) {
    return Messages.LUMA_NORMAL;
  }
  return Messages.LUMA_BRIGHT;
}

export class LightFeature implements Feature {
  readonly id: string = 'light';
  readonly continuous: boolean = false;
  private readonly services: FeatureServices;

  constructor(services: FeatureServices) {
    this.services = services;
  }

  startedMessage(): string {
    return '';
  }

  stoppedMessage(): string {
    return '';
  }

  async start(): Promise<void> {
    this.services.overlay.clear();
    this.services.setStatus(Messages.CHECKING_LIGHT);
    const lux = await this.readSensor();
    let luma: number | undefined = undefined;
    try {
      const frame = await this.services.camera.nextFrame();
      await normalizeFrame(frame, this.services.camera.frameRotation());
      luma = await this.averageLuma(frame);
      frame.release();
    } catch (error) {
      log(`light estimate from camera failed ${describeError(error)}`);
    }
    const sensorLooksBroken = lux !== undefined && lux < DARK_LUX && luma !== undefined && luma > SENSOR_CONFLICT_LUMA;
    if (lux !== undefined && !sensorLooksBroken) {
      this.services.reportResult(describeLux(lux));
    } else if (luma !== undefined) {
      this.services.reportResult(describeLuma(luma));
    } else {
      this.services.reportFailure(Messages.LIGHT_FAILED);
    }
  }

  stop(): void {
  }

  private readSensor(): Promise<number | undefined> {
    return new Promise((resolve: (value: number | undefined) => void) => {
      let done = false;
      const finish = (lux: number | undefined): void => {
        if (done) {
          return;
        }
        done = true;
        try {
          sensor.off(sensor.SensorId.AMBIENT_LIGHT);
        } catch (error) {
          log(`light sensor off failed ${describeError(error)}`);
        }
        resolve(lux);
      };
      try {
        sensor.on(sensor.SensorId.AMBIENT_LIGHT, (data: sensor.LightResponse) => {
          finish(data.intensity);
        }, { interval: SENSOR_INTERVAL_NS });
      } catch (error) {
        log(`light sensor unavailable ${describeError(error)}`);
        finish(undefined);
        return;
      }
      setTimeout(() => finish(undefined), SENSOR_TIMEOUT_MS);
    });
  }

  private async averageLuma(frame: image.PixelMap): Promise<number> {
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
}

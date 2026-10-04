import { Feature, FeatureServices } from './Feature';
import { describeError, log } from '../common/Logger';
import { Messages } from '../common/Messages';
import { normalizeFrame } from '../vision/FrameNormalizer';
import { nameColor } from '../vision/ColorNamer';

const SAMPLE_FRACTION: number = 0.12;
const MARKER_COLOR: string = '#FFFFFF';

export class ColorFeature implements Feature {
  readonly id: string = 'color';
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
    this.services.setStatus(Messages.CHECKING_COLOR);
    try {
      const frame = await this.services.camera.nextFrame();
      const content = await normalizeFrame(frame, this.services.camera.frameRotation());
      const info = await frame.getImageInfo();
      const buffer = new ArrayBuffer(frame.getPixelBytesNumber());
      await frame.readPixelsToBuffer(buffer);
      frame.release();
      const pixels = new Uint8Array(buffer);
      const rowBytes = pixels.length / info.size.height;
      const half = Math.max(2, Math.round(Math.min(info.size.width, info.size.height) * SAMPLE_FRACTION));
      const centerX = Math.round(info.size.width / 2);
      const centerY = Math.round(info.size.height / 2);
      let red = 0;
      let green = 0;
      let blue = 0;
      let count = 0;
      for (let y = centerY - half; y < centerY + half; y++) {
        for (let x = centerX - half; x < centerX + half; x++) {
          const offset = y * rowBytes + x * 4;
          red += pixels[offset];
          green += pixels[offset + 1];
          blue += pixels[offset + 2];
          count++;
        }
      }
      const name = nameColor(red / count, green / count, blue / count);
      this.services.overlay.drawCenterMarker(content, MARKER_COLOR);
      this.services.report(name);
    } catch (error) {
      log(`color check failed ${describeError(error)}`);
      this.services.report(Messages.COLOR_FAILED);
    }
  }

  stop(): void {
  }
}

import { Feature, FeatureServices } from './Feature';
import { describeError, log } from '../common/Logger';
import { Messages } from '../common/Messages';
import { normalizeFrame } from '../vision/FrameNormalizer';
import { centerRegion, describeColor, readColor } from '../vision/ColorNamer';

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
      const width = info.size.width;
      const height = info.size.height;
      const reading = readColor({ data: pixels, width: width, height: height, rowBytes: pixels.length / height });
      const region = centerRegion(width, height);
      this.services.overlay.drawRegion({
        x1: region.x / width,
        y1: region.y / height,
        x2: (region.x + region.width) / width,
        y2: (region.y + region.height) / height
      }, content, MARKER_COLOR);
      log(`color ${reading.name} share ${reading.share.toFixed(2)} gains ${reading.balance.red.toFixed(2)}/` +
        `${reading.balance.green.toFixed(2)}/${reading.balance.blue.toFixed(2)}`);
      this.services.reportResult(describeColor(reading));
    } catch (error) {
      log(`color check failed ${describeError(error)}`);
      this.services.reportFailure(Messages.COLOR_FAILED);
    }
  }

  stop(): void {
  }
}

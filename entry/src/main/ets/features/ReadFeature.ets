import { Feature, FeatureServices } from './Feature';
import { describeError, log } from '../common/Logger';
import { ContentRect } from '../vision/DetectionTypes';
import { normalizeFrame } from '../vision/FrameNormalizer';
import { TextReadResult } from '../vision/text/TextTypes';

const MAX_SPOKEN_CHARS: number = 1200;

export class ReadFeature implements Feature {
  readonly id: string = 'read';
  readonly title: string = 'Read text';
  readonly activeTitle: string = 'Reading text';
  readonly hint: string = 'Double tap to read the printed text in front of the camera';
  readonly continuous: boolean = false;
  private readonly services: FeatureServices;

  constructor(services: FeatureServices) {
    this.services = services;
  }

  async start(): Promise<void> {
    this.services.overlay.clear();
    this.finish('Reading text.');
    if (!this.services.textReader.isAvailable()) {
      this.finish('Text reading is not available on this device yet.');
      return;
    }
    try {
      const frame = await this.services.camera.nextFrame();
      const content = await normalizeFrame(frame, this.services.camera.frameRotation());
      const result = await this.services.textReader.read(frame);
      frame.release();
      if (result === undefined) {
        this.finish('Text could not be read.');
        return;
      }
      this.show(result, content);
    } catch (error) {
      log(`reading failed ${describeError(error)}`);
      this.finish('Text could not be read.');
    }
  }

  stop(): void {
  }

  private show(result: TextReadResult, content: ContentRect): void {
    const text = result.text.trim();
    if (text.length === 0) {
      this.finish('No text found. Move closer and try again.');
      return;
    }
    this.services.overlay.drawTextLines(result.lines, content);
    this.services.setTiming(`${result.engine} OCR ${result.elapsedMs} ms`);
    this.finish(text.length > MAX_SPOKEN_CHARS ? text.substring(0, MAX_SPOKEN_CHARS) : text);
  }

  private finish(message: string): void {
    this.services.setStatus(message);
    this.services.narrator.announce(message, true);
  }
}

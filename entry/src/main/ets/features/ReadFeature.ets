import { image } from '@kit.ImageKit';
import { Feature, FeatureServices, PhotoAnalyzer } from './Feature';
import { describeError, log } from '../common/Logger';
import { Messages } from '../common/Messages';
import { ContentRect } from '../vision/DetectionTypes';
import { normalizeFrame } from '../vision/FrameNormalizer';
import { summarizeText } from '../vision/text/TextSummary';
import { TextReadResult } from '../vision/text/TextTypes';

const MAX_SPOKEN_CHARS: number = 1200;

export class ReadFeature implements Feature, PhotoAnalyzer {
  readonly id: string = 'read';
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
    this.services.setResultText('');
    this.services.setStatus(Messages.READING_TEXT);
    if (!this.services.textReader.isAvailable()) {
      this.services.reportFailure(Messages.TEXT_READER_UNAVAILABLE);
      return;
    }
    try {
      const frame = await this.services.camera.nextFrame();
      try {
        const content = await normalizeFrame(frame, this.services.camera.frameRotation());
        const result = await this.services.textReader.read(frame);
        if (result === undefined) {
          this.services.reportFailure(Messages.TEXT_READ_FAILED);
          return;
        }
        this.show(result, content, Messages.NO_TEXT_FOUND);
      } finally {
        frame.release();
      }
    } catch (error) {
      log(`reading failed ${describeError(error)}`);
      this.services.reportFailure(Messages.TEXT_READ_FAILED);
    }
  }

  stop(): void {
  }

  async analyzePhoto(photo: image.PixelMap, content: ContentRect): Promise<void> {
    this.services.overlay.clear();
    this.services.setResultText('');
    this.services.setStatus(Messages.ANALYSING_PHOTO);
    if (!this.services.textReader.isAvailable()) {
      this.services.reportFailure(Messages.TEXT_READER_UNAVAILABLE);
      return;
    }
    const result = await this.services.textReader.read(photo);
    if (result === undefined) {
      this.services.reportFailure(Messages.TEXT_READ_FAILED);
      return;
    }
    this.show(result, content, Messages.NO_TEXT_IN_PHOTO);
  }

  private show(result: TextReadResult, content: ContentRect, emptyMessage: string): void {
    const text = result.text.trim();
    if (text.length === 0) {
      this.services.reportFailure(emptyMessage);
      return;
    }
    this.services.overlay.drawTextLines(result.lines, content);
    this.services.setTiming(Messages.ocrTiming(result.engine, result.elapsedMs));
    this.services.setResultText(text);
    this.services.setStatus(summarizeText(text));
    this.services.resultReady();
    this.services.narrator.announce(text.length > MAX_SPOKEN_CHARS ? text.substring(0, MAX_SPOKEN_CHARS) : text);
  }
}

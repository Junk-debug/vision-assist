import { image } from '@kit.ImageKit';
import { Feature, FeatureServices } from './Feature';
import { GuidanceCoach } from './GuidanceCoach';
import { FIND_WORD_TUNING, WORD_FRAME_INTERVAL_MS } from '../common/Config';
import { log } from '../common/Logger';
import { Messages } from '../common/Messages';
import { normalizeFrame } from '../vision/FrameNormalizer';
import { findWord, WordMatch } from '../vision/text/WordMatcher';

export class FindWordFeature implements Feature {
  readonly id: string = 'findword';
  readonly continuous: boolean = true;
  private readonly services: FeatureServices;
  private coach?: GuidanceCoach;
  private target: string = '';
  private running: boolean = false;

  constructor(services: FeatureServices) {
    this.services = services;
  }

  setTarget(word: string): void {
    this.target = word.trim();
  }

  startedMessage(): string {
    return Messages.wordStarted(this.target);
  }

  stoppedMessage(): string {
    return Messages.SEARCH_STOPPED;
  }

  async start(): Promise<void> {
    this.running = true;
    this.coach = new GuidanceCoach(this.services, {
      name: this.target,
      spokenName: this.target.toLowerCase(),
      searchingStatus: Messages.wordSearchingStatus(this.target)
    }, FIND_WORD_TUNING);
    this.coach.start(Date.now());
    this.services.camera.setFrameHandler((frame: image.PixelMap) => this.process(frame), WORD_FRAME_INTERVAL_MS);
  }

  stop(): void {
    this.running = false;
    this.services.camera.setFrameHandler(undefined, 0);
    this.coach?.stop();
    this.services.overlay.clear();
  }

  private async process(frame: image.PixelMap): Promise<void> {
    if (!this.running) {
      return;
    }
    const content = await normalizeFrame(frame, this.services.camera.frameRotation());
    const result = await this.services.textReader.read(frame);
    if (!this.running) {
      return;
    }
    if (result === undefined) {
      log('word search: text could not be read');
      this.services.overlay.clear();
      this.coach?.update(undefined, Date.now());
      return;
    }
    const match: WordMatch | undefined = findWord(result.words, this.target);
    const outcome = match === undefined ? 'no match' : `matched ${match.text}`;
    log(`word search ${this.target}: ${result.words.length} words, ${result.elapsedMs} ms, ${result.engine}, ${outcome}`);
    this.services.setTiming(Messages.ocrTiming(result.engine, result.elapsedMs));
    this.services.overlay.drawWordMatch(result.words, match, content);
    this.coach?.update(match, Date.now(), result.elapsedMs);
  }
}

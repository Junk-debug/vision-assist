import { image } from '@kit.ImageKit';
import { Feature, FeatureServices } from './Feature';
import { computeGuidance } from './FindGuidance';
import { GuidanceCoach } from './GuidanceCoach';
import { WORD_FRAME_INTERVAL_MS, WORD_FULL_SIZE_SIDE, WORD_HOLD_MS } from '../common/Config';
import { describeError, log } from '../common/Logger';
import { normalizeFrame } from '../vision/FrameNormalizer';
import { findWord, WordMatch } from '../vision/text/WordMatcher';

export class FindWordFeature implements Feature {
  readonly id: string = 'findword';
  readonly title: string = 'Find a word';
  readonly activeTitle: string = 'Stop finding word';
  readonly hint: string = 'Double tap to choose or type a word to find, then follow the vibration and voice';
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

  async start(): Promise<void> {
    this.running = true;
    const spoken = this.target.toLowerCase();
    this.coach = new GuidanceCoach(this.services, {
      name: this.target,
      searchingStatus: `Searching for ${this.target}.`,
      searchingSpeech: `Searching for ${spoken}, move the phone slowly`
    }, WORD_HOLD_MS);
    this.coach.start(Date.now());
    this.services.setStatus(`Looking for the word ${this.target}.`);
    this.services.narrator.announce(`Looking for the word ${spoken}`, true);
    this.services.camera.setFrameHandler((frame: image.PixelMap) => this.process(frame), WORD_FRAME_INTERVAL_MS);
  }

  stop(): void {
    this.running = false;
    this.services.camera.setFrameHandler(undefined, 0);
    this.coach?.stop();
    this.services.overlay.clear();
    this.services.setStatus('Stopped.');
    this.services.narrator.announce('Search stopped', true);
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
    this.services.setTiming(`${result.engine} OCR ${result.elapsedMs} ms`);
    this.services.overlay.drawWordMatch(result.words, match, content);
    this.coach?.update(match === undefined ? undefined : computeGuidance(match, WORD_FULL_SIZE_SIDE), Date.now());
  }
}

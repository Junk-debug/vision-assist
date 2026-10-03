import { image } from '@kit.ImageKit';
import { Feature, FeatureServices } from './Feature';
import { computeGuidance, Guidance, NOT_FOUND } from './FindGuidance';
import { FIND_FRAME_INTERVAL_MS, FIND_THRESHOLD, FRAME_ROTATION } from '../common/Config';
import { Haptics } from '../haptics/Haptics';
import { Detection } from '../vision/DetectionTypes';
import { normalizeFrame } from '../vision/FrameNormalizer';

const PULSE_DURATION_MS: number = 40;
const ARRIVED_VIBRATION_MS: number = 600;
const SPEECH_GAP_MS: number = 3000;
const LOST_AFTER_MS: number = 1500;
const TREND_MARGIN: number = 0.08;

export class FindFeature implements Feature {
  readonly id: string = 'find';
  readonly title: string = 'Find an object';
  readonly activeTitle: string = 'Stop finding';
  readonly hint: string = 'Double tap to choose an object to find, then follow the vibration and voice';
  readonly continuous: boolean = true;
  private readonly services: FeatureServices;
  private readonly haptics: Haptics = new Haptics();
  private target: string = '';
  private running: boolean = false;
  private pulseTimer: number = -1;
  private pulsePeriod: number = 0;
  private lastCloseness: number = 0;
  private lastSpeechAt: number = 0;
  private lastSeenAt: number = 0;
  private arrivedAnnounced: boolean = false;

  constructor(services: FeatureServices) {
    this.services = services;
  }

  setTarget(label: string): void {
    this.target = label;
  }

  async start(): Promise<void> {
    this.running = true;
    this.lastCloseness = 0;
    this.lastSpeechAt = 0;
    this.lastSeenAt = Date.now();
    this.arrivedAnnounced = false;
    this.services.setStatus(`Looking for ${this.target.toLowerCase()}.`);
    this.services.narrator.announce(`Looking for ${this.target.toLowerCase()}. Move the phone slowly.`, true);
    this.services.camera.setFrameHandler((frame: image.PixelMap) => this.process(frame), FIND_FRAME_INTERVAL_MS);
  }

  stop(): void {
    this.running = false;
    this.services.camera.setFrameHandler(undefined, 0);
    this.setPulse(0);
    this.haptics.stop();
    this.services.overlay.clear();
    this.services.setStatus('Stopped.');
    this.services.narrator.announce('Search stopped', true);
  }

  private async process(frame: image.PixelMap): Promise<void> {
    if (!this.running) {
      return;
    }
    const content = await normalizeFrame(frame, FRAME_ROTATION);
    const result = await this.services.detector.detect(frame, FIND_THRESHOLD);
    if (!this.running) {
      return;
    }
    this.services.overlay.drawDetections(result.detections, content, this.target);
    const match = this.bestMatch(result.detections);
    const now = Date.now();
    if (match === undefined) {
      this.onLost(now);
      return;
    }
    this.lastSeenAt = now;
    this.onGuidance(computeGuidance(match), now);
  }

  private bestMatch(detections: Detection[]): Detection | undefined {
    let best: Detection | undefined = undefined;
    for (const detection of detections) {
      if (detection.label === this.target && (best === undefined || detection.score > best.score)) {
        best = detection;
      }
    }
    return best;
  }

  private onLost(now: number): void {
    this.setPulse(0);
    this.lastCloseness = 0;
    this.arrivedAnnounced = false;
    if (now - this.lastSeenAt > LOST_AFTER_MS) {
      this.services.setStatus(`Searching for ${this.target.toLowerCase()}.`);
      this.speak('Searching. Turn slowly.', now);
    }
  }

  private onGuidance(guidance: Guidance, now: number): void {
    const percent = Math.round(guidance.closeness * 100);
    this.services.setStatus(`${this.target}: ${percent}% close. ${guidance.direction}`);
    if (guidance.arrived) {
      this.setPulse(0);
      if (!this.arrivedAnnounced) {
        this.arrivedAnnounced = true;
        this.haptics.pulse(ARRIVED_VIBRATION_MS);
        this.services.narrator.announce(`${this.target} is right in front of you.`, true);
        this.lastSpeechAt = now;
      }
      return;
    }
    this.arrivedAnnounced = false;
    this.setPulse(guidance.pulseMs);
    const trend = guidance.closeness - this.lastCloseness;
    let message = guidance.direction;
    if (trend > TREND_MARGIN) {
      message = `Warmer. ${guidance.direction}`;
    } else if (trend < -TREND_MARGIN) {
      message = `Colder. ${guidance.direction}`;
    }
    this.lastCloseness = guidance.closeness;
    this.speak(message, now);
  }

  private speak(message: string, now: number): void {
    if (message === '' || now - this.lastSpeechAt < SPEECH_GAP_MS) {
      return;
    }
    this.lastSpeechAt = now;
    this.services.narrator.announce(message);
  }

  private setPulse(periodMs: number): void {
    if (periodMs === this.pulsePeriod) {
      return;
    }
    if (this.pulseTimer >= 0) {
      clearInterval(this.pulseTimer);
      this.pulseTimer = -1;
    }
    this.pulsePeriod = periodMs;
    if (periodMs > 0) {
      this.pulseTimer = setInterval(() => this.haptics.pulse(PULSE_DURATION_MS), periodMs);
    }
  }
}

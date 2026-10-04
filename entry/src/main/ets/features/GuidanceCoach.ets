import { FeatureServices } from './Feature';
import { Guidance } from './FindGuidance';
import { Messages } from '../common/Messages';
import { Haptics } from '../haptics/Haptics';
import { Priority } from '../speech/Narrator';

const PULSE_DURATION_MS: number = 40;
const ARRIVED_VIBRATION_MS: number = 600;
const SPEECH_GAP_MS: number = 3000;
const LOST_AFTER_MS: number = 1500;
const TREND_MARGIN: number = 0.08;

export interface CoachTexts {
  name: string;
  searchingStatus: string;
  searchingSpeech: string;
}

export class GuidanceCoach {
  private readonly services: FeatureServices;
  private readonly texts: CoachTexts;
  private readonly holdMs: number;
  private readonly haptics: Haptics = new Haptics();
  private pulseTimer: number = -1;
  private pulsePeriod: number = 0;
  private lastCloseness: number = 0;
  private lastSpeechAt: number = 0;
  private lastSeenAt: number = 0;
  private arrivedAnnounced: boolean = false;
  private lastGuidance?: Guidance;

  constructor(services: FeatureServices, texts: CoachTexts, holdMs: number) {
    this.services = services;
    this.texts = texts;
    this.holdMs = holdMs;
  }

  start(now: number): void {
    this.lastCloseness = 0;
    this.lastSpeechAt = 0;
    this.lastSeenAt = now;
    this.arrivedAnnounced = false;
    this.lastGuidance = undefined;
  }

  stop(): void {
    this.setPulse(0);
    this.haptics.stop();
  }

  update(guidance: Guidance | undefined, now: number): void {
    if (guidance === undefined) {
      this.onLost(now);
      return;
    }
    this.lastSeenAt = now;
    this.lastGuidance = guidance;
    this.onGuidance(guidance, now);
  }

  private onLost(now: number): void {
    const sinceSeen = now - this.lastSeenAt;
    if (this.lastGuidance !== undefined && sinceSeen < this.holdMs) {
      return;
    }
    this.lastGuidance = undefined;
    this.setPulse(0);
    this.lastCloseness = 0;
    this.arrivedAnnounced = false;
    if (sinceSeen > LOST_AFTER_MS) {
      this.services.setStatus(this.texts.searchingStatus);
      this.speak(this.texts.searchingSpeech, now);
    }
  }

  private onGuidance(guidance: Guidance, now: number): void {
    const percent = Math.round(guidance.closeness * 100);
    this.services.setStatus(Messages.closeness(this.texts.name, percent, guidance.direction));
    if (guidance.arrived) {
      this.setPulse(0);
      if (!this.arrivedAnnounced) {
        this.arrivedAnnounced = true;
        this.haptics.pulse(ARRIVED_VIBRATION_MS);
        this.services.narrator.announce(Messages.arrived(this.texts.name), Priority.URGENT);
        this.lastSpeechAt = now;
      }
      return;
    }
    this.arrivedAnnounced = false;
    this.setPulse(guidance.pulseMs);
    const trend = guidance.closeness - this.lastCloseness;
    let message = guidance.direction;
    if (trend > TREND_MARGIN) {
      message = Messages.warmer(guidance.direction);
    } else if (trend < -TREND_MARGIN) {
      message = Messages.colder(guidance.direction);
    }
    this.lastCloseness = guidance.closeness;
    this.speak(message, now);
  }

  private speak(message: string, now: number): void {
    if (message === '' || now - this.lastSpeechAt < SPEECH_GAP_MS) {
      return;
    }
    this.lastSpeechAt = now;
    this.services.narrator.announce(message, Priority.BACKGROUND);
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

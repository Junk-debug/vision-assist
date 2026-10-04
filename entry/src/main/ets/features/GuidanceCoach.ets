import { FeatureServices } from './Feature';
import { FindCue, FindStateMachine, FindStep, FindTexts, PulseKind, SpeechLevel } from './FindStateMachine';
import { FindTuning } from '../common/Config';
import { haptics } from '../haptics/Haptics';
import { Priority } from '../speech/Narrator';
import { NormalizedBox } from '../vision/DetectionTypes';

function priorityOf(level: SpeechLevel): Priority {
  if (level === SpeechLevel.URGENT) {
    return Priority.URGENT;
  }
  return level === SpeechLevel.RESULT ? Priority.RESULT : Priority.BACKGROUND;
}

export class GuidanceCoach {
  private readonly services: FeatureServices;
  private readonly machine: FindStateMachine;
  private pulseTimer: number = -1;
  private pulseKind: PulseKind = PulseKind.NONE;
  private pulsePeriod: number = 0;

  constructor(services: FeatureServices, texts: FindTexts, tuning: FindTuning) {
    this.services = services;
    this.machine = new FindStateMachine(texts, tuning);
  }

  start(now: number): void {
    this.apply(this.machine.start(now));
  }

  stop(): void {
    this.setPulse(PulseKind.NONE, 0);
    haptics.stop();
  }

  update(target: NormalizedBox | undefined, now: number): void {
    this.apply(this.machine.update(target, now));
  }

  private apply(step: FindStep): void {
    this.services.setStatus(step.status);
    this.setPulse(step.pulse, step.pulseMs);
    if (step.cue === FindCue.ACQUIRED) {
      haptics.acquired();
    } else if (step.cue === FindCue.LOST) {
      haptics.lost();
    } else if (step.cue === FindCue.ARRIVED) {
      haptics.arrived();
    }
    if (step.speech !== '') {
      this.services.narrator.announce(step.speech, priorityOf(step.speechLevel));
    }
  }

  private setPulse(kind: PulseKind, periodMs: number): void {
    const kindChanged = kind !== this.pulseKind;
    this.pulseKind = kind;
    this.pulsePeriod = periodMs;
    if (kind === PulseKind.NONE || periodMs <= 0) {
      this.clearPulse();
      return;
    }
    if (kindChanged) {
      this.clearPulse();
    }
    if (this.pulseTimer < 0) {
      this.schedulePulse();
    }
  }

  private schedulePulse(): void {
    this.pulseTimer = setTimeout(() => {
      this.pulseTimer = -1;
      if (this.pulseKind === PulseKind.NONE || this.pulsePeriod <= 0) {
        return;
      }
      if (this.pulseKind === PulseKind.SEARCH_TICK) {
        haptics.searchTick();
      } else {
        haptics.guidancePulse();
      }
      this.schedulePulse();
    }, this.pulsePeriod);
  }

  private clearPulse(): void {
    if (this.pulseTimer >= 0) {
      clearTimeout(this.pulseTimer);
      this.pulseTimer = -1;
    }
  }
}

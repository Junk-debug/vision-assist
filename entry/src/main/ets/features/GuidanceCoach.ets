import { FeatureServices } from './Feature';
import { FindCue, FindState, FindStateMachine, FindStep, FindTexts, PulseKind, SpeechLevel } from './FindStateMachine';
import { growthOf, measureTarget, TargetView } from './FindGuidance';
import { DEBUG_SUMMARY_MS, FindTuning } from '../common/Config';
import { DebugState } from '../common/DebugState';
import { log } from '../common/Logger';
import { haptics } from '../haptics/Haptics';
import { Priority } from '../speech/Narrator';
import { NormalizedBox } from '../vision/DetectionTypes';

function priorityOf(level: SpeechLevel): Priority {
  if (level === SpeechLevel.URGENT) {
    return Priority.URGENT;
  }
  return level === SpeechLevel.RESULT ? Priority.RESULT : Priority.BACKGROUND;
}

function stateName(state: FindState): string {
  switch (state) {
    case FindState.SEARCHING:
      return 'searching';
    case FindState.ACQUIRED:
      return 'in view';
    case FindState.GUIDING:
      return 'guiding';
    case FindState.ARRIVED:
      return 'within reach';
    default:
      return 'lost';
  }
}

function pct(value: number): string {
  return `${Math.round(value * 100)}%`;
}

export class GuidanceCoach {
  private readonly services: FeatureServices;
  private readonly machine: FindStateMachine;
  private pulseTimer: number = -1;
  private pulseKind: PulseKind = PulseKind.NONE;
  private pulsePeriod: number = 0;
  private lastState: FindState = FindState.SEARCHING;
  private lastSpeech: string = '';
  private lastCloseness: number = 0;
  private inferenceMs: number = 0;
  private lastSummaryAt: number = 0;

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

  update(target: NormalizedBox | undefined, now: number, inferenceMs: number = 0): void {
    this.inferenceMs = inferenceMs;
    this.apply(this.machine.update(target, now));
    if (DebugState.enabled) {
      this.reportDebug(target, now);
    }
  }

  private reportDebug(target: NormalizedBox | undefined, now: number): void {
    const view: TargetView | undefined = target === undefined ? undefined : measureTarget(target);
    const side = view === undefined ? 0 : view.largerSide;
    const growth = view === undefined ? 0 : growthOf(view, this.machine.acquiredLargerSide());
    const offset = view === undefined ? 'none' : `${view.offsetX.toFixed(2)}, ${view.offsetY.toFixed(2)}`;
    const line = `state ${stateName(this.lastState)}, closeness ${pct(this.lastCloseness)}, offset ${offset}, ` +
      `side ${pct(side)}, growth x${growth.toFixed(2)}, pulse ${this.pulsePeriod} ms, said "${this.lastSpeech}", ` +
      `inference ${this.inferenceMs} ms`;
    this.services.showDebug(line.split(', ').join('\n'));
    if (now - this.lastSummaryAt >= DEBUG_SUMMARY_MS) {
      this.lastSummaryAt = now;
      log(`find debug ${line}`);
    }
  }

  private apply(step: FindStep): void {
    if (step.state !== this.lastState) {
      log(`find state ${stateName(this.lastState)} -> ${stateName(step.state)}`);
      this.lastState = step.state;
    }
    this.lastCloseness = step.closeness;
    if (step.speech !== '') {
      this.lastSpeech = step.speech;
    }
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

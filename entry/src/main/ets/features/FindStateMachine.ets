import { FindTuning } from '../common/Config';
import { Messages } from '../common/Messages';
import { NormalizedBox } from '../vision/DetectionTypes';
import {
  closenessOf,
  directionOf,
  isCentred,
  isWithinReach,
  measureTarget,
  positionOf,
  pulseMsFor,
  TargetView
} from './FindGuidance';

export enum FindState {
  SEARCHING,
  ACQUIRED,
  GUIDING,
  ARRIVED,
  LOST
}

export enum FindCue {
  NONE,
  ACQUIRED,
  LOST,
  ARRIVED
}

export enum PulseKind {
  NONE,
  SEARCH_TICK,
  GUIDANCE
}

export enum SpeechLevel {
  BACKGROUND,
  RESULT,
  URGENT
}

export interface FindTexts {
  name: string;
  spokenName: string;
  searchingStatus: string;
}

export interface FindStep {
  state: FindState;
  speech: string;
  speechLevel: SpeechLevel;
  cue: FindCue;
  pulse: PulseKind;
  pulseMs: number;
  closeness: number;
  status: string;
}

export class FindStateMachine {
  private readonly texts: FindTexts;
  private tuning: FindTuning;
  private state: FindState = FindState.SEARCHING;
  private hits: boolean[] = [];
  private lastSeenAt: number = 0;
  private acquiredSide: number = 0;
  private arriveStreak: number = 0;
  private centred: boolean = false;
  private holdSteadySaid: boolean = false;
  private closerCount: number = 0;
  private lastCloserAt: number = 0;
  private lastSearchSpeechAt: number = 0;
  private lastGuideSpeechAt: number = Number.NEGATIVE_INFINITY;
  private lastDirection: string = '';
  private lastPulseMs: number = 0;
  private lastCloseness: number = 0;

  setTuning(tuning: FindTuning): void {
    this.tuning = tuning;
  }

  constructor(texts: FindTexts, tuning: FindTuning) {
    this.texts = texts;
    this.tuning = tuning;
  }

  current(): FindState {
    return this.state;
  }

  acquiredLargerSide(): number {
    return this.acquiredSide;
  }

  start(now: number): FindStep {
    this.state = FindState.SEARCHING;
    this.hits = [];
    this.lastSeenAt = now;
    this.resetTracking();
    this.lastSearchSpeechAt = now;
    return this.searchingStep('');
  }

  update(box: NormalizedBox | undefined, now: number): FindStep {
    this.hits.push(box !== undefined);
    while (this.hits.length > this.tuning.acquireWindow) {
      this.hits.shift();
    }
    if (box === undefined) {
      return this.onMissing(now);
    }
    const view = measureTarget(box);
    this.lastSeenAt = now;
    if (this.state === FindState.SEARCHING || this.state === FindState.LOST) {
      if (this.hitCount() >= this.tuning.acquireHits) {
        return this.acquire(view, now);
      }
      this.state = FindState.SEARCHING;
      return this.searchingStep(this.searchSpeech(now));
    }
    return this.track(view, now);
  }

  private hitCount(): number {
    return this.hits.filter((hit: boolean) => hit).length;
  }

  private resetTracking(): void {
    this.acquiredSide = 0;
    this.arriveStreak = 0;
    this.resetCentring();
    this.lastGuideSpeechAt = Number.NEGATIVE_INFINITY;
    this.lastDirection = '';
    this.lastPulseMs = 0;
    this.lastCloseness = 0;
  }

  private resetCentring(): void {
    this.centred = false;
    this.holdSteadySaid = false;
    this.closerCount = 0;
  }

  private onMissing(now: number): FindStep {
    if (this.state === FindState.SEARCHING || this.state === FindState.LOST) {
      this.state = FindState.SEARCHING;
      return this.searchingStep(this.searchSpeech(now));
    }
    if (now - this.lastSeenAt <= this.tuning.lostAfterMs) {
      return this.holdStep();
    }
    this.state = FindState.LOST;
    this.hits = [];
    this.resetTracking();
    this.lastSearchSpeechAt = now;
    return this.step(Messages.lostTarget(this.texts.spokenName), SpeechLevel.RESULT, FindCue.LOST,
      PulseKind.SEARCH_TICK, this.tuning.searchTickMs, 0, Messages.lostTarget(this.texts.name));
  }

  private acquire(view: TargetView, now: number): FindStep {
    this.state = FindState.ACQUIRED;
    this.resetTracking();
    this.acquiredSide = view.largerSide;
    this.centred = isCentred(view, this.tuning.centredTolerance);
    this.lastGuideSpeechAt = now;
    const closeness = closenessOf(view, this.acquiredSide, this.tuning);
    this.lastCloseness = closeness;
    this.lastPulseMs = pulseMsFor(closeness, this.tuning);
    const position = positionOf(view);
    return this.step(Messages.inView(this.texts.spokenName, position), SpeechLevel.RESULT, FindCue.ACQUIRED,
      PulseKind.GUIDANCE, this.lastPulseMs, closeness, Messages.inView(this.texts.name, position));
  }

  private track(view: TargetView, now: number): FindStep {
    const tolerance = this.centred ? this.tuning.leaveCentredTolerance : this.tuning.centredTolerance;
    const centredNow = isCentred(view, tolerance);
    if (this.state === FindState.ARRIVED) {
      if (centredNow) {
        return this.step('', SpeechLevel.BACKGROUND, FindCue.NONE, PulseKind.NONE, 0, 1,
          Messages.withinReach(this.texts.name));
      }
      this.arriveStreak = 0;
      this.lastGuideSpeechAt = Number.NEGATIVE_INFINITY;
      this.lastDirection = '';
    }
    this.state = FindState.GUIDING;
    if (!centredNow) {
      this.resetCentring();
    } else {
      this.centred = true;
    }
    const closeness = closenessOf(view, this.acquiredSide, this.tuning);
    this.lastCloseness = closeness;
    if (centredNow && isWithinReach(view, this.acquiredSide, this.tuning)) {
      this.arriveStreak++;
    } else {
      this.arriveStreak = 0;
    }
    if (this.arriveStreak >= this.tuning.arriveFrames) {
      this.state = FindState.ARRIVED;
      this.lastPulseMs = 0;
      return this.step(Messages.withinReach(this.texts.spokenName), SpeechLevel.URGENT, FindCue.ARRIVED,
        PulseKind.NONE, 0, 1, Messages.withinReach(this.texts.name));
    }
    this.lastPulseMs = pulseMsFor(closeness, this.tuning);
    const direction = centredNow ? '' : directionOf(view, this.tuning.centredTolerance);
    return this.step(this.guideSpeech(direction, now), SpeechLevel.BACKGROUND, FindCue.NONE, PulseKind.GUIDANCE,
      this.lastPulseMs, closeness, this.guideStatus(closeness, direction));
  }

  private guideSpeech(direction: string, now: number): string {
    const sinceSpeech = now - this.lastGuideSpeechAt;
    if (sinceSpeech < this.tuning.directionGapMs) {
      return '';
    }
    if (direction !== '') {
      if (direction === this.lastDirection && sinceSpeech < this.tuning.directionRepeatMs) {
        return '';
      }
      this.lastDirection = direction;
      this.lastGuideSpeechAt = now;
      return Messages.sentence(direction);
    }
    if (!this.holdSteadySaid) {
      this.holdSteadySaid = true;
      this.lastDirection = '';
      this.lastGuideSpeechAt = now;
      this.lastCloserAt = now;
      return Messages.HOLD_STEADY;
    }
    if (this.closerCount < this.tuning.closerRepeatLimit && now - this.lastCloserAt >= this.tuning.closerGapMs) {
      this.closerCount++;
      this.lastCloserAt = now;
      this.lastGuideSpeechAt = now;
      return Messages.MOVE_CLOSER_SLOWLY;
    }
    return '';
  }

  private guideStatus(closeness: number, direction: string): string {
    return Messages.closeness(this.texts.name, Math.round(closeness * 100), direction);
  }

  private searchSpeech(now: number): string {
    if (now - this.lastSearchSpeechAt < this.tuning.searchSpeechGapMs) {
      return '';
    }
    this.lastSearchSpeechAt = now;
    return Messages.searchingTurnSlowly(this.texts.spokenName);
  }

  private searchingStep(speech: string): FindStep {
    return this.step(speech, SpeechLevel.BACKGROUND, FindCue.NONE, PulseKind.SEARCH_TICK, this.tuning.searchTickMs, 0,
      this.texts.searchingStatus);
  }

  private holdStep(): FindStep {
    if (this.state === FindState.ARRIVED) {
      return this.step('', SpeechLevel.BACKGROUND, FindCue.NONE, PulseKind.NONE, 0, 1,
        Messages.withinReach(this.texts.name));
    }
    return this.step('', SpeechLevel.BACKGROUND, FindCue.NONE, PulseKind.GUIDANCE, this.lastPulseMs, this.lastCloseness,
      this.guideStatus(this.lastCloseness, ''));
  }

  private step(speech: string, level: SpeechLevel, cue: FindCue, pulse: PulseKind, pulseMs: number, closeness: number,
    status: string): FindStep {
    return {
      state: this.state,
      speech: speech,
      speechLevel: level,
      cue: cue,
      pulse: pulse,
      pulseMs: pulseMs,
      closeness: closeness,
      status: status
    };
  }
}

import { describe, it, expect } from '@ohos/hypium';
import { FIND_OBJECT_TUNING, FIND_WORD_TUNING, FindTuning } from '../main/ets/common/Config';
import { FindCue, FindState, FindStateMachine, FindStep, PulseKind, SpeechLevel } from '../main/ets/features/FindStateMachine';
import { NormalizedBox } from '../main/ets/vision/DetectionTypes';

const FRAME_MS: number = 150;
const WORD_FRAME_MS: number = 700;

class Run {
  readonly machine: FindStateMachine;
  readonly steps: FindStep[] = [];
  readonly times: number[] = [];
  readonly frameMs: number;
  now: number = 1000;

  constructor(name: string, tuning: FindTuning, frameMs: number) {
    this.machine = new FindStateMachine({ name: name, spokenName: name.toLowerCase(), searchingStatus: `Searching for ${name}.` },
      tuning);
    this.frameMs = frameMs;
    this.steps.push(this.machine.start(this.now));
    this.times.push(this.now);
  }

  feed(box: NormalizedBox | undefined, frames: number = 1): FindStep {
    for (let i = 0; i < frames; i++) {
      this.now += this.frameMs;
      this.steps.push(this.machine.update(box, this.now));
      this.times.push(this.now);
    }
    return this.steps[this.steps.length - 1];
  }

  spoken(): string[] {
    return this.steps.filter((step: FindStep) => step.speech !== '').map((step: FindStep) => step.speech);
  }

  speechTimes(text: string): number[] {
    const times: number[] = [];
    for (let i = 0; i < this.steps.length; i++) {
      if (this.steps[i].speech === text) {
        times.push(this.times[i]);
      }
    }
    return times;
  }

  count(text: string): number {
    return this.speechTimes(text).length;
  }

  cues(cue: FindCue): number {
    return this.steps.filter((step: FindStep) => step.cue === cue).length;
  }
}

function box(cx: number, cy: number, w: number, h: number): NormalizedBox {
  return { x1: cx - w / 2, y1: cy - h / 2, x2: cx + w / 2, y2: cy + h / 2 };
}

function minGap(times: number[]): number {
  let gap = Number.POSITIVE_INFINITY;
  for (let i = 1; i < times.length; i++) {
    gap = Math.min(gap, times[i] - times[i - 1]);
  }
  return gap;
}

function acquire(run: Run, target: NormalizedBox): FindStep {
  run.feed(target);
  return run.feed(target);
}

export default function findStateMachineTest() {
  describe('findStateMachine', () => {
    it('startsSearchingWithASoftTick', 0, () => {
      const run = new Run('Mug', FIND_OBJECT_TUNING, FRAME_MS);
      expect(run.steps[0].state).assertEqual(FindState.SEARCHING);
      expect(run.steps[0].pulse).assertEqual(PulseKind.SEARCH_TICK);
      expect(run.steps[0].pulseMs).assertEqual(FIND_OBJECT_TUNING.searchTickMs);
      expect(run.steps[0].speech).assertEqual('');
    });
    it('searchingSpeaksAtMostEveryFourSeconds', 0, () => {
      const run = new Run('Mug', FIND_OBJECT_TUNING, FRAME_MS);
      run.feed(undefined, 70);
      const times = run.speechTimes('Searching for mug. Turn slowly.');
      expect(times.length).assertEqual(2);
      expect(minGap(times) >= FIND_OBJECT_TUNING.searchSpeechGapMs).assertTrue();
      expect(run.steps[run.steps.length - 1].pulse).assertEqual(PulseKind.SEARCH_TICK);
    });
    it('acquiresAfterTwoOfThreeFramesAndAnnouncesOnce', 0, () => {
      const run = new Run('Mug', FIND_OBJECT_TUNING, FRAME_MS);
      const left = box(0.15, 0.5, 0.1, 0.1);
      expect(run.feed(left).state).assertEqual(FindState.SEARCHING);
      expect(run.feed(undefined).state).assertEqual(FindState.SEARCHING);
      const acquired = run.feed(left);
      expect(acquired.state).assertEqual(FindState.ACQUIRED);
      expect(acquired.speech).assertEqual('Mug in view, on the left.');
      expect(acquired.speechLevel).assertEqual(SpeechLevel.RESULT);
      expect(acquired.cue).assertEqual(FindCue.ACQUIRED);
      expect(acquired.pulse).assertEqual(PulseKind.GUIDANCE);
      expect(run.feed(left).state).assertEqual(FindState.GUIDING);
      run.feed(left, 10);
      expect(run.cues(FindCue.ACQUIRED)).assertEqual(1);
    });
    it('singleFlickerDoesNotAcquire', 0, () => {
      const run = new Run('Mug', FIND_OBJECT_TUNING, FRAME_MS);
      const target = box(0.5, 0.5, 0.1, 0.1);
      run.feed(target);
      run.feed(undefined, 2);
      run.feed(target);
      run.feed(undefined, 2);
      expect(run.cues(FindCue.ACQUIRED)).assertEqual(0);
    });
    it('approachFromTheEdgeGuidesThenArrivesOnce', 0, () => {
      const run = new Run('Mug', FIND_OBJECT_TUNING, FRAME_MS);
      acquire(run, box(0.08, 0.5, 0.06, 0.08));
      const pulses: number[] = [];
      for (let i = 0; i <= 60; i++) {
        const t = i / 60;
        const step = run.feed(box(0.08 + 0.42 * t, 0.5, 0.06 + 0.3 * t, 0.08 + 0.4 * t));
        if (step.pulse === PulseKind.GUIDANCE) {
          pulses.push(step.pulseMs);
        }
      }
      run.feed(box(0.5, 0.5, 0.36, 0.48), 20);
      const spoken = run.spoken();
      expect(spoken[0]).assertEqual('Mug in view, on the left.');
      expect(spoken.includes('Turn right.')).assertFalse();
      expect(spoken.includes('Turn left.')).assertTrue();
      expect(run.count('Mug is right in front of you, within reach.')).assertEqual(1);
      expect(run.cues(FindCue.ARRIVED)).assertEqual(1);
      const last = run.steps[run.steps.length - 1];
      expect(last.state).assertEqual(FindState.ARRIVED);
      expect(last.pulse).assertEqual(PulseKind.NONE);
      expect(last.speech).assertEqual('');
      expect(pulses[pulses.length - 1] < pulses[0]).assertTrue();
    });
    it('sidewaysJitterNearTheCentreDoesNotFlipDirections', 0, () => {
      const run = new Run('Mug', FIND_OBJECT_TUNING, FRAME_MS);
      acquire(run, box(0.5, 0.5, 0.1, 0.1));
      for (let i = 0; i < 60; i++) {
        run.feed(box(i % 2 === 0 ? 0.31 : 0.69, 0.5, 0.1, 0.1));
      }
      const spoken = run.spoken();
      expect(spoken.includes('Turn left.')).assertFalse();
      expect(spoken.includes('Turn right.')).assertFalse();
      expect(run.count('Hold steady.')).assertEqual(1);
    });
    it('directionIsNotRepeatedTooOften', 0, () => {
      const run = new Run('Mug', FIND_OBJECT_TUNING, FRAME_MS);
      acquire(run, box(0.1, 0.5, 0.1, 0.1));
      run.feed(box(0.1, 0.5, 0.1, 0.1), 80);
      const times = run.speechTimes('Turn left.');
      expect(times.length >= 2).assertTrue();
      expect(minGap(times) >= FIND_OBJECT_TUNING.directionRepeatMs).assertTrue();
    });
    it('changedDirectionWaitsOnlyForTheShortGap', 0, () => {
      const run = new Run('Mug', FIND_OBJECT_TUNING, FRAME_MS);
      acquire(run, box(0.1, 0.5, 0.1, 0.1));
      run.feed(box(0.1, 0.5, 0.1, 0.1), 20);
      run.feed(box(0.9, 0.5, 0.1, 0.1), 20);
      const left = run.speechTimes('Turn left.');
      const right = run.speechTimes('Turn right.');
      expect(left.length).assertEqual(1);
      expect(right.length).assertEqual(1);
      expect(right[0] - left[0] >= FIND_OBJECT_TUNING.directionGapMs).assertTrue();
      expect(right[0] - left[0] < FIND_OBJECT_TUNING.directionRepeatMs).assertTrue();
    });
    it('centredButFarSaysHoldSteadyThenMoveCloserAFewTimes', 0, () => {
      const run = new Run('Mug', FIND_OBJECT_TUNING, FRAME_MS);
      const far = box(0.5, 0.5, 0.06, 0.06);
      acquire(run, far);
      run.feed(far, 300);
      expect(run.count('Hold steady.')).assertEqual(1);
      const closer = run.speechTimes('Move the phone closer slowly.');
      expect(closer.length).assertEqual(FIND_OBJECT_TUNING.closerRepeatLimit);
      expect(minGap(closer) >= FIND_OBJECT_TUNING.closerGapMs).assertTrue();
      expect(closer[0] > run.speechTimes('Hold steady.')[0]).assertTrue();
      expect(run.count('Mug is right in front of you, within reach.')).assertEqual(0);
    });
    it('shortGapKeepsGuidingAndLongGapAnnouncesLost', 0, () => {
      const run = new Run('Mug', FIND_OBJECT_TUNING, FRAME_MS);
      const target = box(0.3, 0.5, 0.1, 0.1);
      acquire(run, target);
      run.feed(target, 3);
      const held = run.feed(undefined, 5);
      expect(held.state).assertEqual(FindState.GUIDING);
      expect(held.pulse).assertEqual(PulseKind.GUIDANCE);
      run.feed(target, 3);
      expect(run.cues(FindCue.LOST)).assertEqual(0);
      run.feed(undefined, 6);
      const lost = run.feed(undefined);
      expect(lost.state).assertEqual(FindState.LOST);
      expect(lost.speech).assertEqual('Lost mug. Move back slowly.');
      expect(lost.cue).assertEqual(FindCue.LOST);
      expect(lost.pulse).assertEqual(PulseKind.SEARCH_TICK);
      expect(run.feed(undefined).state).assertEqual(FindState.SEARCHING);
      expect(run.cues(FindCue.LOST)).assertEqual(1);
    });
    it('reacquiresAfterLost', 0, () => {
      const run = new Run('Mug', FIND_OBJECT_TUNING, FRAME_MS);
      const target = box(0.8, 0.5, 0.1, 0.1);
      acquire(run, target);
      run.feed(undefined, 10);
      expect(run.feed(target).state).assertEqual(FindState.SEARCHING);
      const again = run.feed(target);
      expect(again.state).assertEqual(FindState.ACQUIRED);
      expect(again.speech).assertEqual('Mug in view, on the right.');
      expect(run.cues(FindCue.ACQUIRED)).assertEqual(2);
    });
    it('tallThinBottleArrivesWhenItFillsTheFrameHeight', 0, () => {
      const run = new Run('Bottle', FIND_OBJECT_TUNING, FRAME_MS);
      const bottle = box(0.5, 0.5, 0.08, 0.5);
      acquire(run, bottle);
      expect(run.feed(bottle).state).assertEqual(FindState.GUIDING);
      const arrived = run.feed(bottle);
      expect(arrived.state).assertEqual(FindState.ARRIVED);
      expect(arrived.speech).assertEqual('Bottle is right in front of you, within reach.');
      expect(arrived.speechLevel).assertEqual(SpeechLevel.URGENT);
      expect(arrived.cue).assertEqual(FindCue.ARRIVED);
    });
    it('arrivalNeedsTwoConsecutiveFrames', 0, () => {
      const run = new Run('Bottle', FIND_OBJECT_TUNING, FRAME_MS);
      const near = box(0.5, 0.5, 0.1, 0.5);
      const far = box(0.5, 0.5, 0.05, 0.2);
      acquire(run, far);
      for (let i = 0; i < 10; i++) {
        run.feed(i % 2 === 0 ? near : far);
      }
      expect(run.cues(FindCue.ARRIVED)).assertEqual(0);
    });
    it('smallObjectArrivesByGrowthButNotWhileTiny', 0, () => {
      const run = new Run('Watch', FIND_OBJECT_TUNING, FRAME_MS);
      acquire(run, box(0.5, 0.5, 0.03, 0.03));
      run.feed(box(0.5, 0.5, 0.07, 0.07), 5);
      expect(run.cues(FindCue.ARRIVED)).assertEqual(0);
      run.feed(box(0.5, 0.5, 0.14, 0.14), 2);
      expect(run.cues(FindCue.ARRIVED)).assertEqual(1);
    });
    it('offCentreLargeBoxDoesNotArrive', 0, () => {
      const run = new Run('Chair', FIND_OBJECT_TUNING, FRAME_MS);
      const side = box(0.8, 0.5, 0.3, 0.6);
      acquire(run, side);
      run.feed(side, 20);
      expect(run.cues(FindCue.ARRIVED)).assertEqual(0);
      expect(run.spoken().includes('Turn right.')).assertTrue();
    });
    it('driftAfterArrivalReturnsToGuidingAndArrivesAgain', 0, () => {
      const run = new Run('Bottle', FIND_OBJECT_TUNING, FRAME_MS);
      const centred = box(0.5, 0.5, 0.1, 0.5);
      acquire(run, centred);
      run.feed(centred, 5);
      const drifted = run.feed(box(0.85, 0.5, 0.1, 0.5));
      expect(drifted.state).assertEqual(FindState.GUIDING);
      expect(drifted.speech).assertEqual('Turn right.');
      expect(drifted.pulse).assertEqual(PulseKind.GUIDANCE);
      run.feed(centred, 3);
      expect(run.count('Bottle is right in front of you, within reach.')).assertEqual(2);
    });
    it('smallJitterAfterArrivalStaysQuiet', 0, () => {
      const run = new Run('Bottle', FIND_OBJECT_TUNING, FRAME_MS);
      acquire(run, box(0.5, 0.5, 0.1, 0.5));
      run.feed(box(0.5, 0.5, 0.1, 0.5), 2);
      const before = run.spoken().length;
      for (let i = 0; i < 30; i++) {
        run.feed(box(i % 2 === 0 ? 0.3 : 0.7, 0.5, 0.1, 0.5));
      }
      expect(run.spoken().length).assertEqual(before);
      expect(run.steps[run.steps.length - 1].state).assertEqual(FindState.ARRIVED);
    });
    it('arrivedThenMissingAnnouncesLost', 0, () => {
      const run = new Run('Bottle', FIND_OBJECT_TUNING, FRAME_MS);
      const bottle = box(0.5, 0.5, 0.1, 0.5);
      acquire(run, bottle);
      run.feed(bottle, 3);
      run.feed(undefined, 10);
      expect(run.count('Lost bottle. Move back slowly.')).assertEqual(1);
    });
    it('wideThinWordArrivesWithWordTuning', 0, () => {
      const run = new Run('EXIT', FIND_WORD_TUNING, WORD_FRAME_MS);
      const word = box(0.5, 0.5, 0.32, 0.06);
      acquire(run, word);
      run.feed(word, 2);
      expect(run.count('Exit is right in front of you, within reach.')).assertEqual(1);
      expect(run.count('Exit in view, ahead.')).assertEqual(1);
    });
    it('farWordNeedsToGrowBeforeArriving', 0, () => {
      const run = new Run('EXIT', FIND_WORD_TUNING, WORD_FRAME_MS);
      acquire(run, box(0.5, 0.5, 0.06, 0.012));
      run.feed(box(0.5, 0.5, 0.12, 0.024), 4);
      expect(run.cues(FindCue.ARRIVED)).assertEqual(0);
      run.feed(box(0.5, 0.5, 0.2, 0.04), 2);
      expect(run.cues(FindCue.ARRIVED)).assertEqual(1);
    });
    it('wordSurvivesOneMissedOcrRun', 0, () => {
      const run = new Run('EXIT', FIND_WORD_TUNING, WORD_FRAME_MS);
      const word = box(0.2, 0.5, 0.1, 0.02);
      acquire(run, word);
      run.feed(undefined, 2);
      run.feed(word);
      expect(run.cues(FindCue.LOST)).assertEqual(0);
      run.feed(undefined, 4);
      expect(run.cues(FindCue.LOST)).assertEqual(1);
    });
  });
}

import { describe, it, expect } from '@ohos/hypium';
import { FIND_OBJECT_TUNING, FIND_WORD_TUNING } from '../main/ets/common/Config';
import {
  closenessOf,
  directionOf,
  isCentred,
  isWithinReach,
  measureTarget,
  positionOf,
  pulseMsFor
} from '../main/ets/features/FindGuidance';

export default function findGuidanceTest() {
  describe('findGuidance', () => {
    it('measuresTheLargerSideAndOffset', 0, () => {
      const view = measureTarget({ x1: 0.46, y1: 0.25, x2: 0.54, y2: 0.75 });
      expect(Math.abs(view.largerSide - 0.5) < 1e-9).assertTrue();
      expect(Math.abs(view.offsetX) < 1e-9).assertTrue();
      expect(isCentred(view, FIND_OBJECT_TUNING.centredTolerance)).assertTrue();
    });
    it('givesDirectionsOutsideTheDeadZone', 0, () => {
      const tolerance = FIND_OBJECT_TUNING.centredTolerance;
      expect(directionOf(measureTarget({ x1: 0.0, y1: 0.45, x2: 0.1, y2: 0.55 }), tolerance)).assertEqual('turn left');
      expect(directionOf(measureTarget({ x1: 0.85, y1: 0.45, x2: 0.95, y2: 0.55 }), tolerance)).assertEqual('turn right');
      expect(directionOf(measureTarget({ x1: 0.45, y1: 0.0, x2: 0.55, y2: 0.1 }), tolerance)).assertEqual('tilt up');
      expect(directionOf(measureTarget({ x1: 0.45, y1: 0.9, x2: 0.55, y2: 1.0 }), tolerance)).assertEqual('tilt down');
      expect(directionOf(measureTarget({ x1: 0.45, y1: 0.45, x2: 0.55, y2: 0.55 }), tolerance)).assertEqual('');
    });
    it('namesThePosition', 0, () => {
      expect(positionOf(measureTarget({ x1: 0.0, y1: 0.4, x2: 0.2, y2: 0.6 }))).assertEqual('on the left');
      expect(positionOf(measureTarget({ x1: 0.4, y1: 0.4, x2: 0.6, y2: 0.6 }))).assertEqual('ahead');
      expect(positionOf(measureTarget({ x1: 0.8, y1: 0.4, x2: 1.0, y2: 0.6 }))).assertEqual('on the right');
    });
    it('tallThinBottleIsWithinReachWhereTheAreaRuleFailed', 0, () => {
      const bottle = measureTarget({ x1: 0.46, y1: 0.25, x2: 0.54, y2: 0.75 });
      expect(isWithinReach(bottle, 0.5, FIND_OBJECT_TUNING)).assertTrue();
      const area = Math.sqrt(0.08 * 0.5);
      expect(area / 0.5 < 0.6).assertTrue();
    });
    it('growthCountsOnlyAboveTheMinimumSide', 0, () => {
      expect(isWithinReach(measureTarget({ x1: 0.465, y1: 0.465, x2: 0.535, y2: 0.535 }), 0.03, FIND_OBJECT_TUNING))
        .assertFalse();
      expect(isWithinReach(measureTarget({ x1: 0.43, y1: 0.43, x2: 0.57, y2: 0.57 }), 0.06, FIND_OBJECT_TUNING))
        .assertTrue();
    });
    it('wideWordUsesItsOwnTuning', 0, () => {
      const word = measureTarget({ x1: 0.34, y1: 0.47, x2: 0.66, y2: 0.53 });
      expect(isWithinReach(word, 0.32, FIND_OBJECT_TUNING)).assertFalse();
      expect(isWithinReach(word, 0.32, FIND_WORD_TUNING)).assertTrue();
    });
    it('closerAndMoreCentredPulsesFaster', 0, () => {
      const far = measureTarget({ x1: 0.0, y1: 0.0, x2: 0.1, y2: 0.1 });
      const near = measureTarget({ x1: 0.3, y1: 0.3, x2: 0.7, y2: 0.7 });
      const farCloseness = closenessOf(far, 0.1, FIND_OBJECT_TUNING);
      const nearCloseness = closenessOf(near, 0.1, FIND_OBJECT_TUNING);
      expect(nearCloseness > farCloseness).assertTrue();
      expect(pulseMsFor(nearCloseness, FIND_OBJECT_TUNING) < pulseMsFor(farCloseness, FIND_OBJECT_TUNING)).assertTrue();
    });
    it('pulseIsQuantisedWithinLimits', 0, () => {
      const values: number[] = [];
      for (let i = 0; i <= 100; i++) {
        const pulse = pulseMsFor(i / 100, FIND_OBJECT_TUNING);
        expect(pulse >= FIND_OBJECT_TUNING.fastestPulseMs && pulse <= FIND_OBJECT_TUNING.slowestPulseMs).assertTrue();
        if (!values.includes(pulse)) {
          values.push(pulse);
        }
      }
      expect(values.length <= FIND_OBJECT_TUNING.pulseSteps).assertTrue();
      expect(pulseMsFor(1, FIND_OBJECT_TUNING)).assertEqual(FIND_OBJECT_TUNING.fastestPulseMs);
      expect(pulseMsFor(0, FIND_OBJECT_TUNING)).assertEqual(FIND_OBJECT_TUNING.slowestPulseMs);
    });
  });
}

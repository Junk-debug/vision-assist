import { describe, it, expect } from '@ohos/hypium';
import { NormalizedBox } from '../main/ets/vision/DetectionTypes';
import { computeGuidance } from '../main/ets/features/FindGuidance';

export default function findGuidanceTest() {
  describe('findGuidance', () => {
    it('centeredLargeBoxHasArrived', 0, () => {
      const guidance = computeGuidance({ x1: 0.2, y1: 0.2, x2: 0.8, y2: 0.8 });
      expect(guidance.arrived).assertTrue();
      expect(guidance.closeness > 0.9).assertTrue();
      expect(guidance.direction).assertEqual('');
    });
    it('smallBoxOnTheLeftSaysTurnLeft', 0, () => {
      const guidance = computeGuidance({ x1: 0.0, y1: 0.45, x2: 0.1, y2: 0.55 });
      expect(guidance.arrived).assertFalse();
      expect(guidance.direction).assertEqual('turn left');
    });
    it('boxOnTheRightSaysTurnRight', 0, () => {
      expect(computeGuidance({ x1: 0.85, y1: 0.45, x2: 0.95, y2: 0.55 }).direction).assertEqual('turn right');
    });
    it('boxHighUpSaysTiltUp', 0, () => {
      expect(computeGuidance({ x1: 0.45, y1: 0.0, x2: 0.55, y2: 0.1 }).direction).assertEqual('tilt up');
      expect(computeGuidance({ x1: 0.45, y1: 0.9, x2: 0.55, y2: 1.0 }).direction).assertEqual('tilt down');
    });
    it('smallCenteredBoxSaysMoveCloser', 0, () => {
      expect(computeGuidance({ x1: 0.45, y1: 0.45, x2: 0.55, y2: 0.55 }).direction).assertEqual('move closer');
    });
    it('closerBoxPulsesFaster', 0, () => {
      const far = computeGuidance({ x1: 0.0, y1: 0.0, x2: 0.1, y2: 0.1 });
      const near = computeGuidance({ x1: 0.3, y1: 0.3, x2: 0.7, y2: 0.7 });
      expect(near.closeness > far.closeness).assertTrue();
      expect(near.pulseMs < far.pulseMs).assertTrue();
    });
    it('smallerFullSizeSideMakesWideWordsArrive', 0, () => {
      const word: NormalizedBox = { x1: 0.3, y1: 0.47, x2: 0.7, y2: 0.53 };
      expect(computeGuidance(word).arrived).assertFalse();
      expect(computeGuidance(word, 0.25).arrived).assertTrue();
    });
  });
}

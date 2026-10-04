import { describe, it, expect } from '@ohos/hypium';
import { Detection } from '../main/ets/vision/DetectionTypes';
import { describeScene, SceneTracker } from '../main/ets/vision/SceneTracker';

function detection(label: string, x1: number, x2: number): Detection {
  return { classId: 0, label: label, score: 0.9, x1: x1, y1: 0.4, x2: x2, y2: 0.6 };
}

export default function sceneTrackerTest() {
  describe('sceneTracker', () => {
    it('waitsForTwoFramesBeforeAnnouncing', 0, () => {
      const tracker = new SceneTracker();
      expect(tracker.update([detection('cup', 0.0, 0.2)], 10000) === undefined).assertTrue();
      expect(tracker.update([detection('cup', 0.0, 0.2)], 10300)).assertEqual('cup on the left');
    });
    it('doesNotRepeatTheSameScene', 0, () => {
      const tracker = new SceneTracker();
      tracker.update([detection('cup', 0.4, 0.6)], 10000);
      expect(tracker.update([detection('cup', 0.4, 0.6)], 10300)).assertEqual('cup ahead');
      expect(tracker.update([detection('cup', 0.4, 0.6)], 16000) === undefined).assertTrue();
    });
    it('mergesPeopleLabels', 0, () => {
      const tracker = new SceneTracker();
      const people: Detection[] = [detection('man', 0.7, 0.9), detection('human face', 0.72, 0.8)];
      tracker.update(people, 10000);
      expect(tracker.update(people, 10300)).assertEqual('person on the right');
    });
    it('countsSeveralObjects', 0, () => {
      const tracker = new SceneTracker();
      const cups: Detection[] = [detection('cup', 0.4, 0.6), detection('cup', 0.1, 0.2)];
      tracker.update(cups, 10000);
      expect(tracker.update(cups, 10300)).assertEqual('2 cups ahead');
    });
    it('ignoresClothing', 0, () => {
      const tracker = new SceneTracker();
      tracker.update([detection('clothing', 0.4, 0.6)], 10000);
      expect(tracker.update([detection('clothing', 0.4, 0.6)], 10300) === undefined).assertTrue();
    });
    it('describesAWholePhotoAtOnce', 0, () => {
      const scene: Detection[] = [detection('cup', 0.0, 0.2), detection('chair', 0.7, 0.9), detection('chair', 0.4, 0.6)];
      expect(describeScene(scene)).assertEqual('cup on the left, 2 chairs on the right');
      expect(describeScene([])).assertEqual('');
    });
  });
}

import { describe, it, expect } from '@ohos/hypium';
import { LIVE_SPEECH_GAP_MS } from '../main/ets/common/Config';
import { Detection } from '../main/ets/vision/DetectionTypes';
import { describeScene, groupScene, LiveSceneTracker, relevanceOf } from '../main/ets/vision/SceneTracker';

const FRAME_MS: number = 250;

function detection(label: string, x1: number, x2: number, score: number = 0.9): Detection {
  return { classId: 0, label: label, score: score, x1: x1, y1: 0.4, x2: x2, y2: 0.6 };
}

class LiveRun {
  readonly tracker: LiveSceneTracker = new LiveSceneTracker();
  readonly said: string[] = [];
  readonly times: number[] = [];
  now: number = 10000;

  feed(detections: Detection[], frames: number = 1): void {
    for (let i = 0; i < frames; i++) {
      this.now += FRAME_MS;
      const sentence = this.tracker.update(detections, this.now);
      if (sentence !== undefined) {
        this.said.push(sentence);
        this.times.push(this.now);
      }
    }
  }
}

export default function sceneTrackerTest() {
  describe('sceneTracker', () => {
    it('describesAtMostThreeObjectsAsSentences', 0, () => {
      const scene: Detection[] = [detection('bottle', 0.4, 0.6), detection('chair', 0.0, 0.3, 0.8),
        detection('person', 0.7, 1.0, 0.7), detection('cup', 0.75, 0.85, 0.5)];
      expect(describeScene(scene)).assertEqual('Bottle ahead. Chair on the left. Person on the right.');
    });
    it('ordersByRelevanceNotByScoreAlone', 0, () => {
      const scene: Detection[] = [detection('cup', 0.0, 0.05, 0.95), detection('table', 0.2, 0.8, 0.6)];
      expect(describeScene(scene)).assertEqual('Table ahead. Cup on the left.');
      expect(relevanceOf(scene[1]) > relevanceOf(scene[0])).assertTrue();
    });
    it('dropsObjectsBelowTheRelevanceThreshold', 0, () => {
      const tiny: Detection = { classId: 0, label: 'pen', score: 0.36, x1: 0.9, y1: 0.9, x2: 0.92, y2: 0.92 };
      expect(describeScene([tiny])).assertEqual('');
      expect(describeScene([tiny, detection('door', 0.3, 0.7)])).assertEqual('Door ahead.');
    });
    it('mergesPeopleAndFaces', 0, () => {
      const people: Detection[] = [detection('man', 0.7, 0.9), detection('human face', 0.72, 0.8)];
      expect(describeScene(people)).assertEqual('Person on the right.');
      const two: Detection[] = [detection('human face', 0.4, 0.5), detection('human face', 0.6, 0.7)];
      expect(describeScene(two)).assertEqual('2 people ahead.');
    });
    it('countsSeveralObjectsOfOneKind', 0, () => {
      const chairs: Detection[] = [detection('chair', 0.4, 0.6), detection('chair', 0.1, 0.2)];
      expect(describeScene(chairs)).assertEqual('2 chairs ahead.');
    });
    it('skipsLowValueClasses', 0, () => {
      const scene: Detection[] = [detection('clothing', 0.3, 0.7), detection('footwear', 0.4, 0.6),
        detection('human hand', 0.4, 0.6), detection('fashion accessory', 0.4, 0.6), detection('jeans', 0.4, 0.6)];
      expect(describeScene(scene)).assertEqual('');
      expect(groupScene(scene).length).assertEqual(0);
    });
    it('liveAnnouncesNewObjectsAfterTwoFrames', 0, () => {
      const run = new LiveRun();
      run.feed([detection('person', 0.7, 0.9)]);
      expect(run.said.length).assertEqual(0);
      run.feed([detection('person', 0.7, 0.9)]);
      expect(run.said[0]).assertEqual('New: person on the right.');
    });
    it('liveDoesNotRepeatAnUnchangedScene', 0, () => {
      const run = new LiveRun();
      run.feed([detection('bottle', 0.4, 0.6), detection('chair', 0.0, 0.3)], 60);
      expect(run.said.length).assertEqual(1);
      expect(run.said[0]).assertEqual('New: bottle ahead, chair on the left.');
    });
    it('liveIgnoresFlicker', 0, () => {
      const run = new LiveRun();
      const bottle = detection('bottle', 0.4, 0.6);
      run.feed([bottle], 4);
      for (let i = 0; i < 20; i++) {
        run.feed(i % 3 === 0 ? [] : [bottle]);
      }
      run.feed([detection('cup', 0.0, 0.2)]);
      run.feed([bottle], 4);
      expect(run.said.length).assertEqual(1);
    });
    it('liveSaysWhenSomethingIsGone', 0, () => {
      const run = new LiveRun();
      run.feed([detection('bottle', 0.4, 0.6)], 4);
      run.feed([], 20);
      expect(run.said[run.said.length - 1]).assertEqual('Bottle gone.');
      run.feed([], 20);
      expect(run.said.length).assertEqual(2);
    });
    it('liveSpeaksAtMostOneSentenceEveryThreeSeconds', 0, () => {
      const run = new LiveRun();
      const labels: string[] = ['bottle', 'chair', 'door', 'table', 'laptop'];
      for (let i = 0; i < 40; i++) {
        const label = labels[Math.floor(i / 4) % labels.length];
        run.feed([detection(label, 0.3, 0.7)]);
      }
      for (let i = 1; i < run.times.length; i++) {
        expect(run.times[i] - run.times[i - 1] >= LIVE_SPEECH_GAP_MS).assertTrue();
      }
      expect(run.said.length >= 2).assertTrue();
    });
    it('liveResetForgetsTheScene', 0, () => {
      const run = new LiveRun();
      run.feed([detection('bottle', 0.4, 0.6)], 4);
      run.tracker.reset();
      run.feed([detection('bottle', 0.4, 0.6)], 4);
      expect(run.said.length).assertEqual(2);
    });
  });
}

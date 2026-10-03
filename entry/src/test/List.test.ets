import localUnitTest from './LocalUnit.test';
import colorNamerTest from './ColorNamer.test';
import findGuidanceTest from './FindGuidance.test';
import sceneTrackerTest from './SceneTracker.test';
import wordMatcherTest from './WordMatcher.test';

export default function testsuite() {
  localUnitTest();
  wordMatcherTest();
  findGuidanceTest();
  colorNamerTest();
  sceneTrackerTest();
}

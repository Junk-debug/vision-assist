import localUnitTest from './LocalUnit.test';
import colorNamerTest from './ColorNamer.test';
import findGuidanceTest from './FindGuidance.test';
import sceneTrackerTest from './SceneTracker.test';
import wordMatcherTest from './WordMatcher.test';
import messagesTest from './Messages.test';
import textSummaryTest from './TextSummary.test';
import photoMathTest from './PhotoMath.test';
import accessibilityTest from './Accessibility.test';
import textEnginesTest from './TextEngines.test';

export default function testsuite() {
  localUnitTest();
  wordMatcherTest();
  findGuidanceTest();
  colorNamerTest();
  sceneTrackerTest();
  messagesTest();
  textSummaryTest();
  photoMathTest();
  accessibilityTest();
  textEnginesTest();
}

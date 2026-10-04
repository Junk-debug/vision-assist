import localUnitTest from './LocalUnit.test';
import objectColorTest from './ObjectColor.test';
import colorNamerTest from './ColorNamer.test';
import findGuidanceTest from './FindGuidance.test';
import findStateMachineTest from './FindStateMachine.test';
import sceneTrackerTest from './SceneTracker.test';
import wordMatcherTest from './WordMatcher.test';
import messagesTest from './Messages.test';
import textSummaryTest from './TextSummary.test';
import photoMathTest from './PhotoMath.test';
import accessibilityTest from './Accessibility.test';
import hapticsTest from './Haptics.test';
import textEnginesTest from './TextEngines.test';
import frameSourceTest from './FrameSource.test';
import rotatedBoxTest from './RotatedBox.test';
import readAloudTest from './ReadAloud.test';

export default function testsuite() {
  localUnitTest();
  objectColorTest();
  wordMatcherTest();
  findGuidanceTest();
  findStateMachineTest();
  colorNamerTest();
  sceneTrackerTest();
  messagesTest();
  textSummaryTest();
  photoMathTest();
  accessibilityTest();
  hapticsTest();
  textEnginesTest();
  frameSourceTest();
  rotatedBoxTest();
  readAloudTest();
}

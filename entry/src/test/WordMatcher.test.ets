import { describe, it, expect } from '@ohos/hypium';
import { findWord, splitWords, withinOneEdit } from '../main/ets/vision/text/WordMatcher';
import { TextWordResult } from '../main/ets/vision/text/TextTypes';

function word(text: string, x1: number, y1: number, x2: number, y2: number): TextWordResult {
  return { text: text, x1: x1, y1: y1, x2: x2, y2: y2 };
}

export default function wordMatcherTest() {
  describe('wordMatcher', () => {
    it('splitWordsStripsPunctuationAndCase', 0, () => {
      expect(splitWords('Exit, NOW!').join('|')).assertEqual('exit|now');
      expect(splitWords('  --  ').length).assertEqual(0);
    });
    it('withinOneEdit', 0, () => {
      expect(withinOneEdit('exit', 'exit')).assertTrue();
      expect(withinOneEdit('exit', 'exlt')).assertTrue();
      expect(withinOneEdit('exit', 'exi')).assertTrue();
      expect(withinOneEdit('exit', 'exits')).assertTrue();
      expect(withinOneEdit('exit', 'xit')).assertTrue();
      expect(withinOneEdit('exit', 'ex')).assertFalse();
      expect(withinOneEdit('exit', 'exot2')).assertFalse();
    });
    it('exactMatchIgnoresCaseAndPunctuation', 0, () => {
      const match = findWord([word('PUSH.', 0.1, 0.1, 0.3, 0.2)], 'push');
      expect(match === undefined).assertFalse();
      expect((match as TextWordResult).x1).assertEqual(0.1);
    });
    it('shortTargetsNeedExactMatch', 0, () => {
      expect(findWord([word('WX', 0, 0, 0.1, 0.1)], 'WC') === undefined).assertTrue();
      expect(findWord([word('WC', 0, 0, 0.1, 0.1)], 'wc') === undefined).assertFalse();
      expect(findWord([word('WCS', 0, 0, 0.1, 0.1)], 'WC') === undefined).assertTrue();
    });
    it('toleratesOneOcrError', 0, () => {
      expect(findWord([word('PHARMACY', 0, 0, 0.1, 0.1)], 'PHARMACY') === undefined).assertFalse();
      expect(findWord([word('PHARMAGY', 0, 0, 0.1, 0.1)], 'PHARMACY') === undefined).assertFalse();
      expect(findWord([word('PHARMAGV', 0, 0, 0.1, 0.1)], 'PHARMACY') === undefined).assertTrue();
    });
    it('acceptsSubstringsForLongTargets', 0, () => {
      expect(findWord([word('EXITING', 0, 0, 0.1, 0.1)], 'EXIT') === undefined).assertFalse();
      expect(findWord([word('EMERGENCY', 0, 0, 0.1, 0.1)], 'emergency exit') === undefined).assertTrue();
      expect(findWord([word('PHARMACY24', 0, 0, 0.1, 0.1)], 'pharmacy') === undefined).assertFalse();
    });
    it('findsWordInsideBoxWithSeveralWords', 0, () => {
      const match = findWord([word('NO EXIT HERE', 0.2, 0.3, 0.6, 0.4)], 'exit');
      expect(match === undefined).assertFalse();
      expect((match as TextWordResult).x2).assertEqual(0.6);
    });
    it('picksBestScoringBox', 0, () => {
      const words: TextWordResult[] = [word('EXITS', 0.1, 0.1, 0.2, 0.2), word('EXIT', 0.5, 0.5, 0.7, 0.6)];
      const match = findWord(words, 'exit');
      expect((match as TextWordResult).x1).assertEqual(0.5);
    });
    it('multiWordTargetNeedsConsecutiveWords', 0, () => {
      const words: TextWordResult[] = [word('FIRE', 0.1, 0.1, 0.2, 0.2), word('EXIT', 0.25, 0.1, 0.4, 0.2)];
      const match = findWord(words, 'fire exit');
      expect(match === undefined).assertFalse();
      expect((match as TextWordResult).x1).assertEqual(0.1);
      expect((match as TextWordResult).x2).assertEqual(0.4);
      expect(findWord([word('EXIT', 0, 0, 0.1, 0.1), word('FIRE', 0.2, 0, 0.3, 0.1)], 'fire exit') === undefined).assertTrue();
    });
    it('emptyInputsGiveNoMatch', 0, () => {
      expect(findWord([], 'exit') === undefined).assertTrue();
      expect(findWord([word('EXIT', 0, 0, 0.1, 0.1)], '  ') === undefined).assertTrue();
    });
  });
}

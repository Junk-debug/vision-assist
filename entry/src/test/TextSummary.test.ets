import { describe, it, expect } from '@ohos/hypium';
import { previewOf, splitLines, summarizeText } from '../main/ets/vision/text/TextSummary';

export default function textSummaryTest() {
  describe('textSummary', () => {
    it('splitsAndTrimsLines', 0, () => {
      const lines = splitLines('  First line \r\n\nSecond line\n   \nThird');
      expect(lines.length).assertEqual(3);
      expect(lines[0]).assertEqual('First line');
      expect(lines[2]).assertEqual('Third');
    });
    it('keepsShortPreviews', 0, () => {
      expect(previewOf('EXIT')).assertEqual('EXIT');
    });
    it('cutsLongPreviewsAtAWord', 0, () => {
      const preview = previewOf('The quick brown fox jumps over the lazy dog', 20);
      expect(preview).assertEqual('The quick brown fox…');
    });
    it('summarisesEmptyTextAsEmpty', 0, () => {
      expect(summarizeText(' \n ')).assertEqual('');
      expect(summarizeText('Menu\nSoup\nBread')).assertEqual('Read 3 lines. Starts with: Menu');
    });
  });
}

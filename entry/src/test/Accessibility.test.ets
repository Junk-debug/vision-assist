import { describe, it, expect } from '@ohos/hypium';
import { nextInChain } from '../main/ets/accessibility/FocusChain';
import { RateLimiter } from '../main/ets/accessibility/RateLimiter';

export default function accessibilityTest() {
  describe('accessibility', () => {
    it('findsTheNextFocus', 0, () => {
      const chain: string[] = ['title', 'status', 'primary', 'back'];
      expect(nextInChain(chain, 'title')).assertEqual('status');
      expect(nextInChain(chain, 'primary')).assertEqual('back');
    });
    it('endsTheChainAtTheLastElement', 0, () => {
      expect(nextInChain(['title', 'back'], 'back')).assertEqual('');
      expect(nextInChain(['title', 'back'], 'missing')).assertEqual('');
    });
    it('rateLimitsBackgroundAnnouncements', 0, () => {
      const limiter = new RateLimiter(4000);
      expect(limiter.allow(1000)).assertTrue();
      expect(limiter.allow(3000)).assertFalse();
      expect(limiter.allow(5000)).assertTrue();
      limiter.reset();
      expect(limiter.allow(5001)).assertTrue();
    });
  });
}

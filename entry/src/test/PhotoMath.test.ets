import { describe, it, expect } from '@ohos/hypium';
import { containRect, fitWithin, orientationDegrees } from '../main/ets/photo/PhotoMath';

export default function photoMathTest() {
  describe('photoMath', () => {
    it('keepsSmallPhotos', 0, () => {
      const size = fitWithin(1200, 800, 2048);
      expect(size.width).assertEqual(1200);
      expect(size.height).assertEqual(800);
    });
    it('capsTheLongestSide', 0, () => {
      const landscape = fitWithin(4096, 3072, 2048);
      expect(landscape.width).assertEqual(2048);
      expect(landscape.height).assertEqual(1536);
      const portrait = fitWithin(3000, 4000, 2048);
      expect(portrait.width).assertEqual(1536);
      expect(portrait.height).assertEqual(2048);
    });
    it('mapsExifOrientation', 0, () => {
      expect(orientationDegrees('Top-left')).assertEqual(0);
      expect(orientationDegrees('Right-top')).assertEqual(90);
      expect(orientationDegrees('Bottom-right')).assertEqual(180);
      expect(orientationDegrees('Left-bottom')).assertEqual(270);
      expect(orientationDegrees('')).assertEqual(0);
    });
    it('letterboxesWidePhotos', 0, () => {
      const rect = containRect(400, 200);
      expect(rect.left).assertEqual(0);
      expect(rect.width).assertEqual(1);
      expect(rect.top).assertEqual(0.25);
      expect(rect.height).assertEqual(0.5);
    });
    it('pillarboxesTallPhotos', 0, () => {
      const rect = containRect(200, 400);
      expect(rect.top).assertEqual(0);
      expect(rect.left).assertEqual(0.25);
      expect(rect.width).assertEqual(0.5);
    });
  });
}

import { describe, it, expect } from '@ohos/hypium';
import { nameColor } from '../main/ets/vision/ColorNamer';

export default function colorNamerTest() {
  describe('colorNamer', () => {
    it('namesPrimaryColors', 0, () => {
      expect(nameColor(255, 0, 0)).assertEqual('red');
      expect(nameColor(0, 200, 0)).assertEqual('green');
      expect(nameColor(0, 0, 255)).assertEqual('blue');
      expect(nameColor(255, 255, 0)).assertEqual('yellow');
    });
    it('namesNeutrals', 0, () => {
      expect(nameColor(5, 5, 5)).assertEqual('black');
      expect(nameColor(250, 250, 250)).assertEqual('white');
      expect(nameColor(200, 200, 200)).assertEqual('light gray');
      expect(nameColor(90, 90, 90)).assertEqual('dark gray');
    });
    it('namesBrownAndShades', 0, () => {
      expect(nameColor(120, 70, 20)).assertEqual('brown');
      expect(nameColor(255, 190, 190)).assertEqual('light red');
      expect(nameColor(0, 0, 90)).assertEqual('dark blue');
    });
  });
}

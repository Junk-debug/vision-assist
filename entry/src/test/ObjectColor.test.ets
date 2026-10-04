import { describe, it, expect } from '@ohos/hypium';
import { RgbaFrame } from '../main/ets/vision/ColorNamer';
import { Detection } from '../main/ets/vision/DetectionTypes';
import { colorOfDetection, innerRegionOf } from '../main/ets/vision/ObjectColor';
import { describeScene } from '../main/ets/vision/SceneTracker';

const WIDTH: number = 200;
const HEIGHT: number = 200;

function frameWithBlueBox(): RgbaFrame {
  const data = new Uint8Array(WIDTH * HEIGHT * 4);
  for (let y = 0; y < HEIGHT; y++) {
    for (let x = 0; x < WIDTH; x++) {
      const inside = x >= 60 && x < 140 && y >= 40 && y < 160;
      const o = (y * WIDTH + x) * 4;
      data[o] = inside ? 30 : 210;
      data[o + 1] = inside ? 60 : 210;
      data[o + 2] = inside ? 190 : 210;
      data[o + 3] = 255;
    }
  }
  return { data: data, width: WIDTH, height: HEIGHT, rowBytes: WIDTH * 4 };
}

function detection(label: string): Detection {
  return { classId: 0, label: label, score: 0.9, x1: 0.3, y1: 0.2, x2: 0.7, y2: 0.8 };
}

export default function objectColorTest() {
  describe('ObjectColor', () => {
    it('innerRegionStaysInsideTheBox', 0, () => {
      const region = innerRegionOf(detection('Bottle'), WIDTH, HEIGHT);
      expect(region.x).assertEqual(80);
      expect(region.y).assertEqual(70);
      expect(region.width).assertEqual(40);
      expect(region.height).assertEqual(60);
    });
    it('namesTheColorOfAnObject', 0, () => {
      expect(colorOfDetection(frameWithBlueBox(), detection('Bottle'))).assertContain('blue');
    });
    it('skipsColorForPeople', 0, () => {
      expect(colorOfDetection(frameWithBlueBox(), detection('Person'))).assertEqual('');
    });
    it('describesWithColor', 0, () => {
      const sentence = describeScene([detection('Bottle')], (): string => 'blue');
      expect(sentence).assertContain('Blue bottle ahead');
    });
  });
}

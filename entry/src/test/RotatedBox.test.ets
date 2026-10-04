import { describe, it, expect } from '@ohos/hypium';
import {
  convexHull, lineSpan, minAreaRect, MIN_TEXT_ANGLE, normalizeAngle, pageAngle, Point, rectAtAngle, rectCorners,
  RotatedRect, rowHull, textRect
} from '../main/ets/vision/text/RotatedBox';
import { cropSource, resizeRgb, rotatedCrop, stripWidth } from '../main/ets/vision/text/ImageOps';
import { extractBoxes, groupIntoLines, TextBox } from '../main/ets/vision/text/DbPostProcessor';

const DEGREE: number = Math.PI / 180;
const MAP_SIZE: number = 200;

function near(actual: number, expected: number, tolerance: number): boolean {
  return Math.abs(actual - expected) <= tolerance;
}

function rect(cx: number, cy: number, width: number, height: number, angle: number): RotatedRect {
  return { cx: cx, cy: cy, width: width, height: height, angle: angle };
}

function inside(r: RotatedRect, x: number, y: number): boolean {
  const dx = x - r.cx;
  const dy = y - r.cy;
  const u = dx * Math.cos(r.angle) + dy * Math.sin(r.angle);
  const v = -dx * Math.sin(r.angle) + dy * Math.cos(r.angle);
  return Math.abs(u) <= r.width / 2 && Math.abs(v) <= r.height / 2;
}

function paint(map: Float32Array, r: RotatedRect): void {
  for (let y = 0; y < MAP_SIZE; y++) {
    for (let x = 0; x < MAP_SIZE; x++) {
      if (inside(r, x + 0.5, y + 0.5)) {
        map[y * MAP_SIZE + x] = 0.9;
      }
    }
  }
}

function hullOf(r: RotatedRect): Point[] {
  const rowStart = new Int32Array(MAP_SIZE).fill(MAP_SIZE);
  const rowEnd = new Int32Array(MAP_SIZE).fill(-1);
  let top = MAP_SIZE;
  let bottom = -1;
  for (let y = 0; y < MAP_SIZE; y++) {
    for (let x = 0; x < MAP_SIZE; x++) {
      if (inside(r, x + 0.5, y + 0.5)) {
        rowStart[y] = Math.min(rowStart[y], x);
        rowEnd[y] = Math.max(rowEnd[y], x);
        top = Math.min(top, y);
        bottom = Math.max(bottom, y);
      }
    }
  }
  return rowHull(rowStart, rowEnd, top, bottom);
}

function gradientImage(width: number, height: number): Uint8Array {
  const pixels = new Uint8Array(width * height * 4);
  for (let y = 0; y < height; y++) {
    for (let x = 0; x < width; x++) {
      const index = (y * width + x) * 4;
      pixels[index] = x;
      pixels[index + 1] = y;
      pixels[index + 2] = (x + y) % 256;
      pixels[index + 3] = 255;
    }
  }
  return pixels;
}

function box(r: RotatedRect): TextBox {
  return { x0: r.cx - r.width / 2, y0: r.cy - r.height / 2, x1: r.cx + r.width / 2, y1: r.cy + r.height / 2, rect: r };
}

export default function rotatedBoxTest() {
  describe('rotatedBox', () => {
    it('convexHullDropsInteriorAndDuplicatePoints', 0, () => {
      const points: Point[] = [{ x: 0, y: 0 }, { x: 4, y: 0 }, { x: 2, y: 1 }, { x: 4, y: 3 }, { x: 0, y: 3 },
        { x: 4, y: 0 }, { x: 2, y: 3 }];
      const hull = convexHull(points);
      expect(hull.length).assertEqual(4);
      const xs = hull.map((p: Point) => `${p.x},${p.y}`).sort().join(' ');
      expect(xs).assertEqual('0,0 0,3 4,0 4,3');
    });
    it('rowHullCoversPixelSquares', 0, () => {
      const rowStart = new Int32Array([5, 5, 5]);
      const rowEnd = new Int32Array([14, 14, 14]);
      const r = minAreaRect(rowHull(rowStart, rowEnd, 0, 2));
      expect(r.angle).assertEqual(0);
      expect(r.width).assertEqual(10);
      expect(r.height).assertEqual(3);
      expect(r.cx).assertEqual(10);
      expect(r.cy).assertEqual(1.5);
    });
    it('normalizeAngleKeepsQuarterTurnRange', 0, () => {
      expect(near(normalizeAngle(100 * DEGREE), 10 * DEGREE, 1e-9)).assertTrue();
      expect(near(normalizeAngle(-80 * DEGREE), 10 * DEGREE, 1e-9)).assertTrue();
      expect(near(normalizeAngle(-Math.PI / 4), Math.PI / 4, 1e-9)).assertTrue();
      expect(near(normalizeAngle(Math.PI), 0, 1e-9)).assertTrue();
    });
    it('estimatesAngleOfRotatedBars', 0, () => {
      const angles: number[] = [-15, -10, -5, -3, 3, 5, 10, 15];
      for (const degrees of angles) {
        const r = textRect(hullOf(rect(100, 100, 120, 16, degrees * DEGREE)));
        expect(near(r.angle / DEGREE, degrees, 0.75)).assertTrue();
        expect(near(r.width, 120, 2)).assertTrue();
        expect(near(r.height, 16, 2)).assertTrue();
        expect(near(r.cx, 100, 1)).assertTrue();
        expect(near(r.cy, 100, 1)).assertTrue();
      }
    });
    it('treatsTallComponentsAsUpright', 0, () => {
      const r = textRect(hullOf(rect(100, 100, 12, 60, 8 * DEGREE)));
      expect(r.angle).assertEqual(0);
      expect(r.height > r.width).assertTrue();
    });
    it('axisAlignedBarStaysBelowRotationThreshold', 0, () => {
      const r = textRect(hullOf(rect(100, 100, 120, 16, 0)));
      expect(Math.abs(r.angle) < MIN_TEXT_ANGLE).assertTrue();
    });
    it('rectAtAngleZeroIsBoundingBox', 0, () => {
      const hull: Point[] = [{ x: 1, y: 2 }, { x: 9, y: 2 }, { x: 9, y: 6 }, { x: 1, y: 6 }];
      const r = rectAtAngle(hull, 0);
      expect(r.cx).assertEqual(5);
      expect(r.cy).assertEqual(4);
      expect(r.width).assertEqual(8);
      expect(r.height).assertEqual(4);
    });
    it('rectCornersFollowTheAngle', 0, () => {
      const corners = rectCorners(rect(10, 20, 4, 2, 90 * DEGREE));
      expect(near(corners[0].x, 11, 1e-9) && near(corners[0].y, 18, 1e-9)).assertTrue();
      expect(near(corners[1].x, 11, 1e-9) && near(corners[1].y, 22, 1e-9)).assertTrue();
      expect(near(corners[2].x, 9, 1e-9) && near(corners[2].y, 22, 1e-9)).assertTrue();
      expect(near(corners[3].x, 9, 1e-9) && near(corners[3].y, 18, 1e-9)).assertTrue();
    });
    it('cropSourceMapsStripCornersOntoRect', 0, () => {
      const upright = rect(50, 30, 100, 48, 0);
      const first = cropSource(upright, 100, 48, 0, 0);
      expect(near(first.x, 0, 1e-9) && near(first.y, 6, 1e-9)).assertTrue();
      const tilted = rect(50, 50, 40, 20, 30 * DEGREE);
      const outW = stripWidth(tilted, 20);
      expect(outW).assertEqual(40);
      const centre = cropSource(tilted, outW, 20, 19.5, 9.5);
      expect(near(centre.x, 49.5, 1e-9) && near(centre.y, 49.5, 1e-9)).assertTrue();
      const end = cropSource(tilted, outW, 20, 39.5, 9.5);
      expect(near(end.x, 49.5 + 20 * Math.cos(30 * DEGREE), 1e-9)).assertTrue();
      expect(near(end.y, 49.5 + 20 * Math.sin(30 * DEGREE), 1e-9)).assertTrue();
    });
    it('rotatedCropAtZeroMatchesResize', 0, () => {
      const pixels = gradientImage(64, 48);
      const strip = rotatedCrop(pixels, 64 * 4, 64, 48, rect(30, 20, 40, 24, 0), 48);
      const resized = resizeRgb(pixels, 64 * 4, 10, 8, 40, 24, 80, 48);
      expect(strip.length).assertEqual(resized.length);
      let worst = 0;
      for (let i = 0; i < strip.length; i++) {
        worst = Math.max(worst, Math.abs(strip[i] - resized[i]));
      }
      expect(worst <= 1).assertTrue();
    });
    it('rotatedCropReadsAlongTheRotatedAxis', 0, () => {
      const pixels = gradientImage(64, 64);
      const strip = rotatedCrop(pixels, 64 * 4, 64, 64, rect(32, 32, 20, 10, 90 * DEGREE), 10);
      expect(strip.length).assertEqual(20 * 10 * 3);
      expect(near(strip[0], 36, 1)).assertTrue();
      expect(near(strip[1], 22, 1)).assertTrue();
      const last = (9 * 20 + 19) * 3;
      expect(near(strip[last], 27, 1)).assertTrue();
      expect(near(strip[last + 1], 41, 1)).assertTrue();
    });
    it('extractBoxesKeepsAxisAlignedBoxes', 0, () => {
      const map = new Float32Array(MAP_SIZE * MAP_SIZE);
      for (let y = 40; y < 50; y++) {
        for (let x = 20; x < 120; x++) {
          map[y * MAP_SIZE + x] = 0.9;
        }
      }
      const boxes = extractBoxes(map, MAP_SIZE, MAP_SIZE, MAP_SIZE, 1, MAP_SIZE, MAP_SIZE);
      expect(boxes.length).assertEqual(1);
      expect(boxes[0].rect.angle).assertEqual(0);
      expect(boxes[0].x0).assertEqual(13);
      expect(boxes[0].y0).assertEqual(33);
      expect(boxes[0].x1).assertEqual(127);
      expect(boxes[0].y1).assertEqual(57);
    });
    it('extractBoxesFindsRotatedLine', 0, () => {
      const map = new Float32Array(MAP_SIZE * MAP_SIZE);
      paint(map, rect(100, 100, 120, 14, -8 * DEGREE));
      const boxes = extractBoxes(map, MAP_SIZE, MAP_SIZE, MAP_SIZE, 0.5, 400, 400);
      expect(boxes.length).assertEqual(1);
      const found = boxes[0].rect;
      expect(near(found.angle / DEGREE, -8, 0.75)).assertTrue();
      expect(near(found.cx, 200, 2) && near(found.cy, 200, 2)).assertTrue();
      expect(found.width > 240 && found.height > 50 && found.height < 90).assertTrue();
      for (const corner of rectCorners(found)) {
        expect(corner.x >= boxes[0].x0 - 1 && corner.x <= boxes[0].x1 + 1).assertTrue();
        expect(corner.y >= boxes[0].y0 - 1 && corner.y <= boxes[0].y1 + 1).assertTrue();
      }
    });
    it('pageAngleIsWidthWeightedMedian', 0, () => {
      const rects: RotatedRect[] = [rect(0, 0, 300, 20, 6 * DEGREE), rect(0, 0, 10, 20, -20 * DEGREE),
        rect(0, 0, 10, 20, 30 * DEGREE)];
      expect(near(pageAngle(rects), 6 * DEGREE, 1e-9)).assertTrue();
      expect(pageAngle([rect(0, 0, 100, 20, 1 * DEGREE)])).assertEqual(0);
      expect(pageAngle([])).assertEqual(0);
    });
    it('lineSpanAtZeroIsTheBox', 0, () => {
      const span = lineSpan(rect(50, 30, 40, 10, 0), 0);
      expect(span.top).assertEqual(25);
      expect(span.bottom).assertEqual(35);
      expect(span.left).assertEqual(30);
    });
    it('groupsWordsOfATiltedLine', 0, () => {
      const angle = -10 * DEGREE;
      const slope = Math.tan(angle);
      const left = box(rect(100, 300, 120, 30, angle));
      const right = box(rect(600, 300 + 500 * slope, 80, 30, angle));
      const below = box(rect(100, 360, 120, 30, angle));
      const lines = groupIntoLines([right, below, left]);
      expect(lines.length).assertEqual(2);
      expect(lines[0].length).assertEqual(2);
      expect(lines[0][0] === left).assertTrue();
      expect(lines[0][1] === right).assertTrue();
      expect(lines[1][0] === below).assertTrue();
    });
  });
}

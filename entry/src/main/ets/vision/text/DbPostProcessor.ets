import { lineSpan, LineSpan, MIN_TEXT_ANGLE, pageAngle, rectCorners, RotatedRect, rowHull, textRect } from './RotatedBox';

const BINARY_THRESHOLD: number = 0.3;
const MIN_SIDE: number = 3;
const MIN_SCORE: number = 0.6;
const UNCLIP_RATIO: number = 1.6;
const MIN_OUTPUT_SIDE: number = 2;
const LINE_OVERLAP: number = 0.5;

export interface TextBox {
  x0: number;
  y0: number;
  x1: number;
  y1: number;
  rect: RotatedRect;
}

interface PlacedBox {
  box: TextBox;
  span: LineSpan;
}

function unclipOffset(width: number, height: number): number {
  return width * height * UNCLIP_RATIO / (2 * (width + height));
}

function clampRound(value: number, limit: number): number {
  return Math.min(limit, Math.max(0, Math.round(value)));
}

function axisAlignedBox(minX: number, minY: number, maxX: number, maxY: number, usedW: number, usedH: number,
  scale: number, sourceW: number, sourceH: number): TextBox | undefined {
  const boxW = maxX - minX + 1;
  const boxH = maxY - minY + 1;
  if (Math.min(boxW, boxH) < MIN_SIDE) {
    return undefined;
  }
  const offset = unclipOffset(boxW, boxH);
  const x0 = clampRound(Math.max(0, minX - offset) / scale, sourceW);
  const y0 = clampRound(Math.max(0, minY - offset) / scale, sourceH);
  const x1 = clampRound(Math.min(usedW, maxX + 1 + offset) / scale, sourceW);
  const y1 = clampRound(Math.min(usedH, maxY + 1 + offset) / scale, sourceH);
  if (x1 - x0 < MIN_OUTPUT_SIDE || y1 - y0 < MIN_OUTPUT_SIDE) {
    return undefined;
  }
  const rect: RotatedRect = { cx: (x0 + x1) / 2, cy: (y0 + y1) / 2, width: x1 - x0, height: y1 - y0, angle: 0 };
  return { x0: x0, y0: y0, x1: x1, y1: y1, rect: rect };
}

export function rotatedBox(mapRect: RotatedRect, scale: number, sourceW: number, sourceH: number): TextBox | undefined {
  if (Math.min(mapRect.width, mapRect.height) < MIN_SIDE) {
    return undefined;
  }
  const offset = unclipOffset(mapRect.width, mapRect.height);
  const rect: RotatedRect = {
    cx: mapRect.cx / scale,
    cy: mapRect.cy / scale,
    width: (mapRect.width + 2 * offset) / scale,
    height: (mapRect.height + 2 * offset) / scale,
    angle: mapRect.angle
  };
  let left = Number.MAX_VALUE;
  let top = Number.MAX_VALUE;
  let right = -Number.MAX_VALUE;
  let bottom = -Number.MAX_VALUE;
  for (const corner of rectCorners(rect)) {
    left = Math.min(left, corner.x);
    top = Math.min(top, corner.y);
    right = Math.max(right, corner.x);
    bottom = Math.max(bottom, corner.y);
  }
  const x0 = clampRound(left, sourceW);
  const y0 = clampRound(top, sourceH);
  const x1 = clampRound(right, sourceW);
  const y1 = clampRound(bottom, sourceH);
  if (x1 - x0 < MIN_OUTPUT_SIDE || y1 - y0 < MIN_OUTPUT_SIDE) {
    return undefined;
  }
  return { x0: x0, y0: y0, x1: x1, y1: y1, rect: rect };
}

export function extractBoxes(probability: Float32Array, mapSize: number, usedW: number, usedH: number,
  scale: number, sourceW: number, sourceH: number): TextBox[] {
  const visited = new Uint8Array(mapSize * mapSize);
  const queue = new Int32Array(mapSize * mapSize);
  const rowStart = new Int32Array(mapSize).fill(mapSize);
  const rowEnd = new Int32Array(mapSize).fill(-1);
  const boxes: TextBox[] = [];
  for (let startY = 0; startY < usedH; startY++) {
    for (let startX = 0; startX < usedW; startX++) {
      const start = startY * mapSize + startX;
      if (visited[start] === 1 || probability[start] <= BINARY_THRESHOLD) {
        continue;
      }
      let head = 0;
      let tail = 0;
      queue[tail++] = start;
      visited[start] = 1;
      let minX = startX;
      let maxX = startX;
      let minY = startY;
      let maxY = startY;
      let sum = 0;
      let count = 0;
      while (head < tail) {
        const index = queue[head++];
        const y = Math.floor(index / mapSize);
        const x = index - y * mapSize;
        sum += probability[index];
        count++;
        minX = Math.min(minX, x);
        maxX = Math.max(maxX, x);
        minY = Math.min(minY, y);
        maxY = Math.max(maxY, y);
        if (x < rowStart[y]) {
          rowStart[y] = x;
        }
        if (x > rowEnd[y]) {
          rowEnd[y] = x;
        }
        if (x > 0 && visited[index - 1] === 0 && probability[index - 1] > BINARY_THRESHOLD) {
          visited[index - 1] = 1;
          queue[tail++] = index - 1;
        }
        if (x < usedW - 1 && visited[index + 1] === 0 && probability[index + 1] > BINARY_THRESHOLD) {
          visited[index + 1] = 1;
          queue[tail++] = index + 1;
        }
        if (y > 0 && visited[index - mapSize] === 0 && probability[index - mapSize] > BINARY_THRESHOLD) {
          visited[index - mapSize] = 1;
          queue[tail++] = index - mapSize;
        }
        if (y < usedH - 1 && visited[index + mapSize] === 0 && probability[index + mapSize] > BINARY_THRESHOLD) {
          visited[index + mapSize] = 1;
          queue[tail++] = index + mapSize;
        }
      }
      let box: TextBox | undefined = undefined;
      if (sum / count >= MIN_SCORE) {
        const mapRect = textRect(rowHull(rowStart, rowEnd, minY, maxY));
        box = Math.abs(mapRect.angle) < MIN_TEXT_ANGLE ?
          axisAlignedBox(minX, minY, maxX, maxY, usedW, usedH, scale, sourceW, sourceH) :
          rotatedBox(mapRect, scale, sourceW, sourceH);
      }
      rowStart.fill(mapSize, minY, maxY + 1);
      rowEnd.fill(-1, minY, maxY + 1);
      if (box !== undefined) {
        boxes.push(box);
      }
    }
  }
  return boxes;
}

export function groupIntoLines(boxes: TextBox[]): TextBox[][] {
  const angle = pageAngle(boxes.map((box: TextBox) => box.rect));
  const placed: PlacedBox[] = boxes.map((box: TextBox) => {
    const item: PlacedBox = { box: box, span: lineSpan(box.rect, angle) };
    return item;
  });
  placed.sort((a: PlacedBox, b: PlacedBox) => (a.span.top + a.span.bottom) - (b.span.top + b.span.bottom));
  const lines: PlacedBox[][] = [];
  const spans: number[][] = [];
  for (const item of placed) {
    const top = item.span.top;
    const bottom = item.span.bottom;
    let joined = false;
    for (let i = 0; i < lines.length; i++) {
      const overlap = Math.min(bottom, spans[i][1]) - Math.max(top, spans[i][0]);
      const limit = LINE_OVERLAP * Math.min(bottom - top, spans[i][1] - spans[i][0]);
      if (overlap > limit) {
        lines[i].push(item);
        spans[i][0] = Math.min(spans[i][0], top);
        spans[i][1] = Math.max(spans[i][1], bottom);
        joined = true;
        break;
      }
    }
    if (!joined) {
      lines.push([item]);
      spans.push([top, bottom]);
    }
  }
  const order: number[] = lines.map((line: PlacedBox[], i: number) => i);
  order.sort((a: number, b: number) => (spans[a][0] + spans[a][1]) - (spans[b][0] + spans[b][1]));
  const result: TextBox[][] = [];
  for (const index of order) {
    const line = lines[index].slice().sort((a: PlacedBox, b: PlacedBox) => a.span.left - b.span.left);
    result.push(line.map((item: PlacedBox) => item.box));
  }
  return result;
}

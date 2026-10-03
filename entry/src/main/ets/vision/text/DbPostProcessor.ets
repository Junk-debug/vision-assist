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
}

export function extractBoxes(probability: Float32Array, mapSize: number, usedW: number, usedH: number,
  scale: number, sourceW: number, sourceH: number): TextBox[] {
  const visited = new Uint8Array(mapSize * mapSize);
  const queue = new Int32Array(mapSize * mapSize);
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
      const boxW = maxX - minX + 1;
      const boxH = maxY - minY + 1;
      if (Math.min(boxW, boxH) < MIN_SIDE || sum / count < MIN_SCORE) {
        continue;
      }
      const offset = boxW * boxH * UNCLIP_RATIO / (2 * (boxW + boxH));
      const left = Math.max(0, minX - offset);
      const top = Math.max(0, minY - offset);
      const right = Math.min(usedW, maxX + 1 + offset);
      const bottom = Math.min(usedH, maxY + 1 + offset);
      const box: TextBox = {
        x0: Math.min(sourceW, Math.max(0, Math.round(left / scale))),
        y0: Math.min(sourceH, Math.max(0, Math.round(top / scale))),
        x1: Math.min(sourceW, Math.max(0, Math.round(right / scale))),
        y1: Math.min(sourceH, Math.max(0, Math.round(bottom / scale)))
      };
      if (box.x1 - box.x0 >= MIN_OUTPUT_SIDE && box.y1 - box.y0 >= MIN_OUTPUT_SIDE) {
        boxes.push(box);
      }
    }
  }
  return boxes;
}

export function groupIntoLines(boxes: TextBox[]): TextBox[][] {
  const ordered = boxes.slice().sort((a: TextBox, b: TextBox) => (a.y0 + a.y1) - (b.y0 + b.y1));
  const lines: TextBox[][] = [];
  const spans: number[][] = [];
  for (const box of ordered) {
    let placed = false;
    for (let i = 0; i < lines.length; i++) {
      const overlap = Math.min(box.y1, spans[i][1]) - Math.max(box.y0, spans[i][0]);
      const limit = LINE_OVERLAP * Math.min(box.y1 - box.y0, spans[i][1] - spans[i][0]);
      if (overlap > limit) {
        lines[i].push(box);
        spans[i][0] = Math.min(spans[i][0], box.y0);
        spans[i][1] = Math.max(spans[i][1], box.y1);
        placed = true;
        break;
      }
    }
    if (!placed) {
      lines.push([box]);
      spans.push([box.y0, box.y1]);
    }
  }
  const order: number[] = lines.map((line: TextBox[], i: number) => i);
  order.sort((a: number, b: number) => (spans[a][0] + spans[a][1]) - (spans[b][0] + spans[b][1]));
  const result: TextBox[][] = [];
  for (const index of order) {
    result.push(lines[index].slice().sort((a: TextBox, b: TextBox) => a.x0 - b.x0));
  }
  return result;
}

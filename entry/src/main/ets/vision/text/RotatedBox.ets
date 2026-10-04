export const MIN_TEXT_ANGLE: number = 2 * Math.PI / 180;

export interface Point {
  x: number;
  y: number;
}

export interface RotatedRect {
  cx: number;
  cy: number;
  width: number;
  height: number;
  angle: number;
}

export interface LineSpan {
  top: number;
  bottom: number;
  left: number;
}

export function rowHull(rowStart: Int32Array, rowEnd: Int32Array, top: number, bottom: number): Point[] {
  const points: Point[] = [];
  for (let level = top; level <= bottom + 1; level++) {
    let start = Number.MAX_VALUE;
    let end = -Number.MAX_VALUE;
    if (level <= bottom) {
      start = rowStart[level];
      end = rowEnd[level] + 1;
    }
    if (level > top) {
      start = Math.min(start, rowStart[level - 1]);
      end = Math.max(end, rowEnd[level - 1] + 1);
    }
    points.push({ x: start, y: level });
    points.push({ x: end, y: level });
  }
  return convexHull(points);
}

function cross(origin: Point, a: Point, b: Point): number {
  return (a.x - origin.x) * (b.y - origin.y) - (a.y - origin.y) * (b.x - origin.x);
}

export function convexHull(points: Point[]): Point[] {
  const sorted = points.slice().sort((a: Point, b: Point) => a.y === b.y ? a.x - b.x : a.y - b.y);
  const unique: Point[] = [];
  for (const point of sorted) {
    const last = unique.length > 0 ? unique[unique.length - 1] : undefined;
    if (last === undefined || last.x !== point.x || last.y !== point.y) {
      unique.push(point);
    }
  }
  if (unique.length < 3) {
    return unique;
  }
  const lower: Point[] = [];
  for (const point of unique) {
    while (lower.length >= 2 && cross(lower[lower.length - 2], lower[lower.length - 1], point) <= 0) {
      lower.pop();
    }
    lower.push(point);
  }
  const upper: Point[] = [];
  for (let i = unique.length - 1; i >= 0; i--) {
    const point = unique[i];
    while (upper.length >= 2 && cross(upper[upper.length - 2], upper[upper.length - 1], point) <= 0) {
      upper.pop();
    }
    upper.push(point);
  }
  lower.pop();
  upper.pop();
  return lower.concat(upper);
}

export function rectAtAngle(hull: Point[], angle: number): RotatedRect {
  const cos = Math.cos(angle);
  const sin = Math.sin(angle);
  let u0 = Number.MAX_VALUE;
  let u1 = -Number.MAX_VALUE;
  let v0 = Number.MAX_VALUE;
  let v1 = -Number.MAX_VALUE;
  for (const point of hull) {
    const u = point.x * cos + point.y * sin;
    const v = -point.x * sin + point.y * cos;
    u0 = Math.min(u0, u);
    u1 = Math.max(u1, u);
    v0 = Math.min(v0, v);
    v1 = Math.max(v1, v);
  }
  const cu = (u0 + u1) / 2;
  const cv = (v0 + v1) / 2;
  return { cx: cu * cos - cv * sin, cy: cu * sin + cv * cos, width: u1 - u0, height: v1 - v0, angle: angle };
}

export function normalizeAngle(angle: number): number {
  let result = angle;
  while (result > Math.PI / 4) {
    result -= Math.PI / 2;
  }
  while (result <= -Math.PI / 4) {
    result += Math.PI / 2;
  }
  return result;
}

export function minAreaRect(hull: Point[]): RotatedRect {
  let best = rectAtAngle(hull, 0);
  for (let i = 0; i < hull.length; i++) {
    const from = hull[i];
    const to = hull[(i + 1) % hull.length];
    const rect = rectAtAngle(hull, normalizeAngle(Math.atan2(to.y - from.y, to.x - from.x)));
    if (rect.width * rect.height < best.width * best.height - 1e-9) {
      best = rect;
    }
  }
  return best;
}

export function textRect(hull: Point[]): RotatedRect {
  const rect = minAreaRect(hull);
  return rect.width < rect.height ? rectAtAngle(hull, 0) : rect;
}

export function rectCorners(rect: RotatedRect): Point[] {
  const cos = Math.cos(rect.angle);
  const sin = Math.sin(rect.angle);
  const halfW = rect.width / 2;
  const halfH = rect.height / 2;
  const offsets: number[][] = [[-halfW, -halfH], [halfW, -halfH], [halfW, halfH], [-halfW, halfH]];
  return offsets.map((offset: number[]) => {
    const corner: Point = { x: rect.cx + offset[0] * cos - offset[1] * sin, y: rect.cy + offset[0] * sin + offset[1] * cos };
    return corner;
  });
}

export function pageAngle(rects: RotatedRect[]): number {
  const ordered = rects.slice().sort((a: RotatedRect, b: RotatedRect) => a.angle - b.angle);
  let total = 0;
  for (const rect of ordered) {
    total += rect.width;
  }
  let seen = 0;
  for (const rect of ordered) {
    seen += rect.width;
    if (seen >= total / 2) {
      return Math.abs(rect.angle) >= MIN_TEXT_ANGLE ? rect.angle : 0;
    }
  }
  return 0;
}

export function lineSpan(rect: RotatedRect, angle: number): LineSpan {
  const cos = Math.cos(angle);
  const sin = Math.sin(angle);
  const relative = rect.angle - angle;
  const halfV = rect.height / 2 * Math.abs(Math.cos(relative)) + rect.width / 2 * Math.abs(Math.sin(relative));
  const halfU = rect.width / 2 * Math.abs(Math.cos(relative)) + rect.height / 2 * Math.abs(Math.sin(relative));
  const u = rect.cx * cos + rect.cy * sin;
  const v = -rect.cx * sin + rect.cy * cos;
  return { top: v - halfV, bottom: v + halfV, left: u - halfU };
}

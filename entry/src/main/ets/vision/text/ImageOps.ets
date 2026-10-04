import { Point, RotatedRect } from './RotatedBox';

export function resizeRgb(pixels: Uint8Array, rowBytes: number, cropX: number, cropY: number,
  cropW: number, cropH: number, outW: number, outH: number): Uint8Array {
  const out = new Uint8Array(outW * outH * 3);
  const scaleX = cropW / outW;
  const scaleY = cropH / outH;
  const left = new Int32Array(outW);
  const right = new Int32Array(outW);
  const weightX = new Float32Array(outW);
  for (let x = 0; x < outW; x++) {
    const fx = Math.min(cropW - 1, Math.max(0, (x + 0.5) * scaleX - 0.5));
    const x0 = Math.floor(fx);
    left[x] = (cropX + x0) * 4;
    right[x] = (cropX + Math.min(cropW - 1, x0 + 1)) * 4;
    weightX[x] = fx - x0;
  }
  let target = 0;
  for (let y = 0; y < outH; y++) {
    const fy = Math.min(cropH - 1, Math.max(0, (y + 0.5) * scaleY - 0.5));
    const y0 = Math.floor(fy);
    const weightY = fy - y0;
    const row0 = (cropY + y0) * rowBytes;
    const row1 = (cropY + Math.min(cropH - 1, y0 + 1)) * rowBytes;
    for (let x = 0; x < outW; x++) {
      const wx = weightX[x];
      const w00 = (1 - wx) * (1 - weightY);
      const w01 = wx * (1 - weightY);
      const w10 = (1 - wx) * weightY;
      const w11 = wx * weightY;
      const a = row0 + left[x];
      const b = row0 + right[x];
      const c = row1 + left[x];
      const d = row1 + right[x];
      for (let channel = 0; channel < 3; channel++) {
        out[target++] = pixels[a + channel] * w00 + pixels[b + channel] * w01 +
          pixels[c + channel] * w10 + pixels[d + channel] * w11;
      }
    }
  }
  return out;
}

export function stripWidth(rect: RotatedRect, outH: number): number {
  return Math.max(1, Math.round(outH * rect.width / rect.height));
}

export function cropSource(rect: RotatedRect, outW: number, outH: number, x: number, y: number): Point {
  const cos = Math.cos(rect.angle);
  const sin = Math.sin(rect.angle);
  const a = ((x + 0.5) / outW - 0.5) * rect.width;
  const b = ((y + 0.5) / outH - 0.5) * rect.height;
  return { x: rect.cx + a * cos - b * sin - 0.5, y: rect.cy + a * sin + b * cos - 0.5 };
}

export function rotatedCrop(pixels: Uint8Array, rowBytes: number, sourceW: number, sourceH: number,
  rect: RotatedRect, outH: number): Uint8Array {
  const outW = stripWidth(rect, outH);
  const out = new Uint8Array(outW * outH * 3);
  const origin = cropSource(rect, outW, outH, 0, 0);
  const cos = Math.cos(rect.angle);
  const sin = Math.sin(rect.angle);
  const stepX = rect.width / outW;
  const stepY = rect.height / outH;
  const maxX = sourceW - 1;
  const maxY = sourceH - 1;
  let target = 0;
  for (let y = 0; y < outH; y++) {
    const rowX = origin.x - y * stepY * sin;
    const rowY = origin.y + y * stepY * cos;
    for (let x = 0; x < outW; x++) {
      const fx = Math.min(maxX, Math.max(0, rowX + x * stepX * cos));
      const fy = Math.min(maxY, Math.max(0, rowY + x * stepX * sin));
      const x0 = Math.floor(fx);
      const y0 = Math.floor(fy);
      const wx = fx - x0;
      const wy = fy - y0;
      const row0 = y0 * rowBytes;
      const row1 = Math.min(maxY, y0 + 1) * rowBytes;
      const col0 = x0 * 4;
      const col1 = Math.min(maxX, x0 + 1) * 4;
      const w00 = (1 - wx) * (1 - wy);
      const w01 = wx * (1 - wy);
      const w10 = (1 - wx) * wy;
      const w11 = wx * wy;
      for (let channel = 0; channel < 3; channel++) {
        out[target++] = pixels[row0 + col0 + channel] * w00 + pixels[row0 + col1 + channel] * w01 +
          pixels[row1 + col0 + channel] * w10 + pixels[row1 + col1 + channel] * w11;
      }
    }
  }
  return out;
}

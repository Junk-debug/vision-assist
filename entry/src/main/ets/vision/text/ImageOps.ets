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

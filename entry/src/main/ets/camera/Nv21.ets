export function nv21ToRgba(source: Uint8Array, width: number, height: number, stride: number): ArrayBuffer {
  const out = new Uint8Array(width * height * 4);
  const uvStart = stride * height;
  let target = 0;
  for (let y = 0; y < height; y++) {
    const yRow = y * stride;
    const uvRow = uvStart + (y >> 1) * stride;
    for (let x = 0; x < width; x++) {
      const luma = source[yRow + x];
      const uvIndex = uvRow + (x & ~1);
      const v = source[uvIndex] - 128;
      const u = source[uvIndex + 1] - 128;
      const c = 298 * (luma - 16);
      let r = (c + 409 * v + 128) >> 8;
      let g = (c - 100 * u - 208 * v + 128) >> 8;
      let b = (c + 516 * u + 128) >> 8;
      out[target] = r < 0 ? 0 : (r > 255 ? 255 : r);
      out[target + 1] = g < 0 ? 0 : (g > 255 ? 255 : g);
      out[target + 2] = b < 0 ? 0 : (b > 255 ? 255 : b);
      out[target + 3] = 255;
      target += 4;
    }
  }
  return out.buffer;
}

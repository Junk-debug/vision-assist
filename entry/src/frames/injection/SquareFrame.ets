export const RGBA_BYTES: number = 4;

export interface SquareLayout {
  side: number;
  offsetX: number;
  offsetY: number;
}

export function squareLayout(width: number, height: number): SquareLayout {
  const side = Math.max(width, height);
  return {
    side: side,
    offsetX: Math.floor((side - width) / 2),
    offsetY: Math.floor((side - height) / 2)
  };
}

export function padToSquare(pixels: Uint8Array, width: number, height: number, rowBytes: number): Uint8Array {
  const layout = squareLayout(width, height);
  const out = new Uint8Array(layout.side * layout.side * RGBA_BYTES);
  const lineBytes = width * RGBA_BYTES;
  for (let y = 0; y < height; y++) {
    const from = y * rowBytes;
    const to = ((y + layout.offsetY) * layout.side + layout.offsetX) * RGBA_BYTES;
    out.set(pixels.subarray(from, from + lineBytes), to);
  }
  return out;
}

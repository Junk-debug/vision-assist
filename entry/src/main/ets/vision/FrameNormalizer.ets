import { image } from '@kit.ImageKit';
import { ContentRect } from './DetectionTypes';

const BORDER_LUMA_SUM: number = 90;
const SAMPLE_STEP: number = 8;
const EDGE_MARGIN: number = 4;

function toDisplayRect(rotation: number, bufferW: number, bufferH: number,
  x0: number, y0: number, cropW: number, cropH: number): ContentRect {
  if (rotation === 90) {
    return {
      left: (bufferH - y0 - cropH) / bufferH,
      top: x0 / bufferW,
      width: cropH / bufferH,
      height: cropW / bufferW
    };
  }
  if (rotation === 180) {
    return {
      left: (bufferW - x0 - cropW) / bufferW,
      top: (bufferH - y0 - cropH) / bufferH,
      width: cropW / bufferW,
      height: cropH / bufferH
    };
  }
  if (rotation === 270) {
    return {
      left: y0 / bufferH,
      top: (bufferW - x0 - cropW) / bufferW,
      width: cropH / bufferH,
      height: cropW / bufferW
    };
  }
  return { left: x0 / bufferW, top: y0 / bufferH, width: cropW / bufferW, height: cropH / bufferH };
}

export async function normalizeFrame(frame: image.PixelMap, rotation: number): Promise<ContentRect> {
  const info = await frame.getImageInfo();
  const width = info.size.width;
  const height = info.size.height;
  const buffer = new ArrayBuffer(frame.getPixelBytesNumber());
  await frame.readPixelsToBuffer(buffer);
  const pixels = new Uint8Array(buffer);
  const rowBytes = pixels.length / height;
  let minX = width;
  let maxX = -1;
  let minY = height;
  let maxY = -1;
  for (let y = 0; y < height; y += SAMPLE_STEP) {
    for (let x = 0; x < width; x += SAMPLE_STEP) {
      const offset = y * rowBytes + x * 4;
      if (pixels[offset] + pixels[offset + 1] + pixels[offset + 2] > BORDER_LUMA_SUM) {
        minX = Math.min(minX, x);
        maxX = Math.max(maxX, x);
        minY = Math.min(minY, y);
        maxY = Math.max(maxY, y);
      }
    }
  }
  let cropX = 0;
  let cropY = 0;
  let cropW = width;
  let cropH = height;
  if (maxX > minX && maxY > minY) {
    cropX = Math.max(0, minX - EDGE_MARGIN);
    cropY = Math.max(0, minY - EDGE_MARGIN);
    cropW = Math.min(width - cropX, maxX - cropX + SAMPLE_STEP + EDGE_MARGIN);
    cropH = Math.min(height - cropY, maxY - cropY + SAMPLE_STEP + EDGE_MARGIN);
    await frame.crop({ x: cropX, y: cropY, size: { width: cropW, height: cropH } });
  }
  if (rotation !== 0) {
    await frame.rotate(rotation);
  }
  return toDisplayRect(rotation, width, height, cropX, cropY, cropW, cropH);
}

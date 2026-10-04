import { image } from '@kit.ImageKit';
import { ColorConfidence, PixelRegion, readColorInRegion, RgbaFrame } from './ColorNamer';
import { Detection } from './DetectionTypes';
import { ColorOf } from './SceneTracker';

const INNER_FRACTION: number = 0.5;
const MIN_REGION_PX: number = 12;
const COLORLESS_LABELS: string[] = [
  'person', 'man', 'woman', 'boy', 'girl', 'human face', 'door', 'window', 'building', 'tree', 'houseplant',
  'plant', 'stairs', 'street light', 'traffic light', 'traffic sign', 'stop sign', 'curtain', 'window blind'
];

export function innerRegionOf(detection: Detection, width: number, height: number): PixelRegion {
  const boxW = (detection.x2 - detection.x1) * width;
  const boxH = (detection.y2 - detection.y1) * height;
  const regionW = Math.max(1, Math.round(boxW * INNER_FRACTION));
  const regionH = Math.max(1, Math.round(boxH * INNER_FRACTION));
  const x = Math.round(detection.x1 * width + (boxW - regionW) / 2);
  const y = Math.round(detection.y1 * height + (boxH - regionH) / 2);
  return {
    x: Math.min(Math.max(0, x), Math.max(0, width - regionW)),
    y: Math.min(Math.max(0, y), Math.max(0, height - regionH)),
    width: Math.min(regionW, width),
    height: Math.min(regionH, height)
  };
}

export function colorOfDetection(frame: RgbaFrame, detection: Detection): string {
  if (COLORLESS_LABELS.includes(detection.label.toLowerCase())) {
    return '';
  }
  const region = innerRegionOf(detection, frame.width, frame.height);
  if (region.width < MIN_REGION_PX || region.height < MIN_REGION_PX) {
    return '';
  }
  const reading = readColorInRegion(frame, region);
  return reading.confidence === ColorConfidence.SURE ? reading.name : '';
}

export async function colorResolverFor(frame: image.PixelMap): Promise<ColorOf> {
  const info = await frame.getImageInfo();
  const buffer = new ArrayBuffer(frame.getPixelBytesNumber());
  await frame.readPixelsToBuffer(buffer);
  const data = new Uint8Array(buffer);
  const rgba: RgbaFrame = {
    data: data,
    width: info.size.width,
    height: info.size.height,
    rowBytes: data.length / info.size.height
  };
  return (detection: Detection): string => colorOfDetection(rgba, detection);
}

import { ContentRect } from '../vision/DetectionTypes';

export interface PixelSize {
  width: number;
  height: number;
}

export function fitWithin(width: number, height: number, maxSide: number): PixelSize {
  const longest = Math.max(width, height);
  if (longest <= maxSide || longest <= 0) {
    return { width: width, height: height };
  }
  const scale = maxSide / longest;
  return { width: Math.max(1, Math.round(width * scale)), height: Math.max(1, Math.round(height * scale)) };
}

export function orientationDegrees(orientation: string): number {
  const value = orientation.trim().toLowerCase();
  if (value === 'right-top' || value === '6') {
    return 90;
  }
  if (value === 'bottom-right' || value === '3') {
    return 180;
  }
  if (value === 'left-bottom' || value === '8') {
    return 270;
  }
  return 0;
}

export function containRect(width: number, height: number): ContentRect {
  if (width <= 0 || height <= 0) {
    return { left: 0, top: 0, width: 1, height: 1 };
  }
  if (width >= height) {
    const share = height / width;
    return { left: 0, top: (1 - share) / 2, width: 1, height: share };
  }
  const share = width / height;
  return { left: (1 - share) / 2, top: 0, width: share, height: 1 };
}

import { Messages } from '../common/Messages';
import { NormalizedBox } from '../vision/DetectionTypes';

const CENTER_WEIGHT: number = 0.55;
const SIZE_WEIGHT: number = 0.45;
const CENTER_RANGE: number = 0.5;
const FULL_SIZE_SIDE: number = 0.5;
const ARRIVED_CLOSENESS: number = 0.8;
const ARRIVED_SIZE: number = 0.6;
const SLOWEST_PULSE_MS: number = 1000;
const FASTEST_PULSE_MS: number = 110;
const DIRECTION_DEADZONE: number = 0.15;

export interface Guidance {
  found: boolean;
  closeness: number;
  arrived: boolean;
  pulseMs: number;
  direction: string;
}

function clamp01(value: number): number {
  return Math.min(1, Math.max(0, value));
}

export function computeGuidance(target: NormalizedBox, fullSizeSide: number = FULL_SIZE_SIDE): Guidance {
  const centerX = (target.x1 + target.x2) / 2;
  const centerY = (target.y1 + target.y2) / 2;
  const offsetX = centerX - 0.5;
  const offsetY = centerY - 0.5;
  const offCenter = Math.sqrt(offsetX * offsetX + offsetY * offsetY);
  const centerScore = 1 - clamp01(offCenter / CENTER_RANGE);
  const side = Math.sqrt(Math.max(0, (target.x2 - target.x1) * (target.y2 - target.y1)));
  const sizeScore = clamp01(side / fullSizeSide);
  const closeness = clamp01(CENTER_WEIGHT * centerScore + SIZE_WEIGHT * sizeScore);
  const arrived = closeness >= ARRIVED_CLOSENESS && sizeScore >= ARRIVED_SIZE;
  const pulseMs = SLOWEST_PULSE_MS - (SLOWEST_PULSE_MS - FASTEST_PULSE_MS) * Math.pow(closeness, 1.5);
  let direction = '';
  if (Math.abs(offsetX) >= Math.abs(offsetY) && Math.abs(offsetX) > DIRECTION_DEADZONE) {
    direction = offsetX < 0 ? Messages.TURN_LEFT : Messages.TURN_RIGHT;
  } else if (Math.abs(offsetY) > DIRECTION_DEADZONE) {
    direction = offsetY < 0 ? Messages.TILT_UP : Messages.TILT_DOWN;
  } else if (sizeScore < ARRIVED_SIZE) {
    direction = Messages.MOVE_CLOSER;
  }
  return { found: true, closeness: closeness, arrived: arrived, pulseMs: Math.round(pulseMs), direction: direction };
}

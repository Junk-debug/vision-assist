import { FindTuning } from '../common/Config';
import { Messages } from '../common/Messages';
import { NormalizedBox } from '../vision/DetectionTypes';

const CENTER_WEIGHT: number = 0.55;
const SIZE_WEIGHT: number = 0.45;
const CENTER_RANGE: number = 0.5;
const LEFT_LIMIT: number = 0.35;
const RIGHT_LIMIT: number = 0.65;
const PULSE_CURVE: number = 1.5;

export interface TargetView {
  offsetX: number;
  offsetY: number;
  largerSide: number;
}

function clamp01(value: number): number {
  return Math.min(1, Math.max(0, value));
}

export function measureTarget(box: NormalizedBox): TargetView {
  const width = Math.max(0, box.x2 - box.x1);
  const height = Math.max(0, box.y2 - box.y1);
  return {
    offsetX: (box.x1 + box.x2) / 2 - 0.5,
    offsetY: (box.y1 + box.y2) / 2 - 0.5,
    largerSide: Math.max(width, height)
  };
}

export function isCentred(view: TargetView, tolerance: number): boolean {
  return Math.abs(view.offsetX) <= tolerance && Math.abs(view.offsetY) <= tolerance;
}

export function directionOf(view: TargetView, tolerance: number): string {
  if (Math.abs(view.offsetX) >= Math.abs(view.offsetY) && Math.abs(view.offsetX) > tolerance) {
    return view.offsetX < 0 ? Messages.TURN_LEFT : Messages.TURN_RIGHT;
  }
  if (Math.abs(view.offsetY) > tolerance) {
    return view.offsetY < 0 ? Messages.TILT_UP : Messages.TILT_DOWN;
  }
  return '';
}

export function positionOf(view: TargetView): string {
  const center = view.offsetX + 0.5;
  if (center < LEFT_LIMIT) {
    return Messages.ON_THE_LEFT;
  }
  if (center > RIGHT_LIMIT) {
    return Messages.ON_THE_RIGHT;
  }
  return Messages.AHEAD;
}

export function growthOf(view: TargetView, acquiredSide: number): number {
  return acquiredSide > 0 ? view.largerSide / acquiredSide : 1;
}

export function closenessOf(view: TargetView, acquiredSide: number, tuning: FindTuning): number {
  const offCenter = Math.max(Math.abs(view.offsetX), Math.abs(view.offsetY));
  const centerScore = 1 - clamp01(offCenter / CENTER_RANGE);
  const sideScore = clamp01(view.largerSide / tuning.arriveSide);
  const growthScore = view.largerSide >= tuning.arriveMinSide ?
    clamp01((growthOf(view, acquiredSide) - 1) / Math.max(0.01, tuning.arriveGrowth - 1)) : 0;
  return clamp01(CENTER_WEIGHT * centerScore + SIZE_WEIGHT * Math.max(sideScore, growthScore));
}

export function isWithinReach(view: TargetView, acquiredSide: number, tuning: FindTuning): boolean {
  if (view.largerSide >= tuning.arriveSide) {
    return true;
  }
  return view.largerSide >= tuning.arriveMinSide && growthOf(view, acquiredSide) >= tuning.arriveGrowth;
}

export function pulseMsFor(closeness: number, tuning: FindTuning): number {
  const steps = Math.max(1, tuning.pulseSteps - 1);
  const level = Math.round(Math.pow(clamp01(closeness), PULSE_CURVE) * steps) / steps;
  return Math.round(tuning.slowestPulseMs - (tuning.slowestPulseMs - tuning.fastestPulseMs) * level);
}

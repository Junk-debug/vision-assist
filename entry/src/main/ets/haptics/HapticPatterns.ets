export enum HapticCue {
  TAP,
  RESULT_READY,
  ERROR,
  GUIDANCE_PULSE,
  ARRIVED,
  SEARCH_TICK,
  ACQUIRED,
  LOST
}

export type HapticUsage = 'touch' | 'notification';

export const UI_USAGE: HapticUsage = 'touch';
export const GUIDANCE_USAGE: HapticUsage = 'notification';

export interface HapticPreset {
  effectId: string;
  intensity: number;
  count: number;
}

export interface HapticPattern {
  usage: HapticUsage;
  preset: HapticPreset;
  fallbackMs: number[];
}

export interface TimedPulse {
  atMs: number;
  durationMs: number;
}

export interface HapticPlan {
  usage: HapticUsage;
  preset?: HapticPreset;
  pulses: TimedPulse[];
}

const TAP: HapticPattern = {
  usage: UI_USAGE,
  preset: { effectId: 'haptic.effect.soft', intensity: 50, count: 1 },
  fallbackMs: [15]
};

const RESULT_READY: HapticPattern = {
  usage: UI_USAGE,
  preset: { effectId: 'haptic.notice.success', intensity: 70, count: 1 },
  fallbackMs: [30, 70, 30]
};

const ERROR: HapticPattern = {
  usage: UI_USAGE,
  preset: { effectId: 'haptic.notice.fail', intensity: 100, count: 1 },
  fallbackMs: [60, 60, 60, 60, 60]
};

const GUIDANCE_PULSE: HapticPattern = {
  usage: GUIDANCE_USAGE,
  preset: { effectId: 'haptic.clock.timer', intensity: 100, count: 1 },
  fallbackMs: [40]
};

const ARRIVED: HapticPattern = {
  usage: GUIDANCE_USAGE,
  preset: { effectId: 'haptic.effect.hard', intensity: 100, count: 3 },
  fallbackMs: [120, 80, 120, 80, 200]
};

const SEARCH_TICK: HapticPattern = {
  usage: GUIDANCE_USAGE,
  preset: { effectId: 'haptic.effect.soft', intensity: 35, count: 2 },
  fallbackMs: [10, 90, 10]
};

const ACQUIRED: HapticPattern = {
  usage: GUIDANCE_USAGE,
  preset: { effectId: 'haptic.effect.sharp', intensity: 100, count: 2 },
  fallbackMs: [30, 50, 90]
};

const LOST: HapticPattern = {
  usage: GUIDANCE_USAGE,
  preset: { effectId: 'haptic.notice.warning', intensity: 80, count: 1 },
  fallbackMs: [90, 50, 30]
};

export const ALL_CUES: HapticCue[] = [HapticCue.TAP, HapticCue.RESULT_READY, HapticCue.ERROR, HapticCue.GUIDANCE_PULSE,
  HapticCue.ARRIVED, HapticCue.SEARCH_TICK, HapticCue.ACQUIRED, HapticCue.LOST];

export function patternFor(cue: HapticCue): HapticPattern {
  switch (cue) {
    case HapticCue.TAP:
      return TAP;
    case HapticCue.RESULT_READY:
      return RESULT_READY;
    case HapticCue.ERROR:
      return ERROR;
    case HapticCue.GUIDANCE_PULSE:
      return GUIDANCE_PULSE;
    case HapticCue.SEARCH_TICK:
      return SEARCH_TICK;
    case HapticCue.ACQUIRED:
      return ACQUIRED;
    case HapticCue.LOST:
      return LOST;
    default:
      return ARRIVED;
  }
}

export function presetIds(): string[] {
  const ids: string[] = [];
  for (const cue of ALL_CUES) {
    const id = patternFor(cue).preset.effectId;
    if (!ids.includes(id)) {
      ids.push(id);
    }
  }
  return ids;
}

export function fallbackPulses(segmentsMs: number[]): TimedPulse[] {
  const pulses: TimedPulse[] = [];
  let at = 0;
  for (let i = 0; i < segmentsMs.length; i++) {
    const length = Math.max(0, Math.round(segmentsMs[i]));
    if (i % 2 === 0 && length > 0) {
      pulses.push({ atMs: at, durationMs: length });
    }
    at += length;
  }
  return pulses;
}

export function totalMs(segmentsMs: number[]): number {
  let total = 0;
  for (const segment of segmentsMs) {
    total += Math.max(0, Math.round(segment));
  }
  return total;
}

export function planFor(cue: HapticCue, presetSupported: boolean): HapticPlan {
  const pattern = patternFor(cue);
  if (presetSupported) {
    return { usage: pattern.usage, preset: pattern.preset, pulses: [] };
  }
  return { usage: pattern.usage, pulses: fallbackPulses(pattern.fallbackMs) };
}

import { vibrator } from '@kit.SensorServiceKit';
import { describeError, log } from '../common/Logger';
import { HapticCue, HapticPlan, HapticPreset, HapticUsage, patternFor, planFor, presetIds, TimedPulse } from './HapticPatterns';

export class Haptics {
  private readonly support: Map<string, boolean> = new Map<string, boolean>();
  private readonly timers: number[] = [];
  private prepared: boolean = false;

  tap(): void {
    this.play(HapticCue.TAP);
  }

  resultReady(): void {
    this.play(HapticCue.RESULT_READY);
  }

  error(): void {
    this.play(HapticCue.ERROR);
  }

  guidancePulse(): void {
    this.play(HapticCue.GUIDANCE_PULSE);
  }

  arrived(): void {
    this.play(HapticCue.ARRIVED);
  }

  stop(): void {
    this.clearTimers();
    try {
      vibrator.stopVibration().catch((error: Object) => {
        log(`stop vibration failed ${describeError(error)}`);
      });
    } catch (error) {
      log(`stop vibration failed ${describeError(error)}`);
    }
  }

  private play(cue: HapticCue): void {
    this.prepare();
    const plan = planFor(cue, this.isSupported(cue));
    if (plan.preset !== undefined) {
      this.startPreset(plan.preset, plan.usage);
      return;
    }
    this.startPulses(plan);
  }

  private isSupported(cue: HapticCue): boolean {
    return this.support.get(patternFor(cue).preset.effectId) === true;
  }

  private prepare(): void {
    if (this.prepared) {
      return;
    }
    this.prepared = true;
    for (const id of presetIds()) {
      try {
        vibrator.isSupportEffect(id).then((supported: boolean) => {
          this.support.set(id, supported);
        }).catch((error: Object) => {
          log(`haptic effect ${id} query failed ${describeError(error)}`);
        });
      } catch (error) {
        log(`haptic effect ${id} unavailable ${describeError(error)}`);
      }
    }
  }

  private startPreset(preset: HapticPreset, usage: HapticUsage): void {
    const effect: vibrator.VibratePreset = {
      type: 'preset',
      effectId: preset.effectId,
      count: preset.count,
      intensity: preset.intensity
    };
    this.start(effect, usage);
  }

  private startPulses(plan: HapticPlan): void {
    this.clearTimers();
    for (const pulse of plan.pulses) {
      if (pulse.atMs === 0) {
        this.startTime(pulse, plan.usage);
      } else {
        const timer = setTimeout(() => this.startTime(pulse, plan.usage), pulse.atMs);
        this.timers.push(timer);
      }
    }
  }

  private startTime(pulse: TimedPulse, usage: HapticUsage): void {
    const effect: vibrator.VibrateTime = { type: 'time', duration: pulse.durationMs };
    this.start(effect, usage);
  }

  private start(effect: vibrator.VibrateEffect, usage: HapticUsage): void {
    const attribute: vibrator.VibrateAttribute = { id: 0, usage: usage };
    try {
      vibrator.startVibration(effect, attribute).catch((error: Object) => {
        log(`vibration failed ${describeError(error)}`);
      });
    } catch (error) {
      log(`vibration unavailable ${describeError(error)}`);
    }
  }

  private clearTimers(): void {
    for (const timer of this.timers) {
      clearTimeout(timer);
    }
    this.timers.length = 0;
  }
}

export const haptics: Haptics = new Haptics();

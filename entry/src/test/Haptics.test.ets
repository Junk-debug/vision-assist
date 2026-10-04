import { describe, it, expect } from '@ohos/hypium';
import {
  ALL_CUES,
  fallbackPulses,
  GUIDANCE_USAGE,
  HapticCue,
  patternFor,
  planFor,
  presetIds,
  totalMs,
  UI_USAGE
} from '../main/ets/haptics/HapticPatterns';

const TOUCH_SWITCH_USAGES: string[] = ['unknown', 'touch', 'media', 'physicalFeedback', 'simulateReality'];

export default function hapticsTest() {
  describe('haptics', () => {
    it('fallbackTurnsSegmentsIntoTimedPulses', 0, () => {
      const pulses = fallbackPulses([30, 70, 30]);
      expect(pulses.length).assertEqual(2);
      expect(pulses[0].atMs).assertEqual(0);
      expect(pulses[0].durationMs).assertEqual(30);
      expect(pulses[1].atMs).assertEqual(100);
      expect(pulses[1].durationMs).assertEqual(30);
    });
    it('fallbackSkipsEmptyPulsesAndKeepsGaps', 0, () => {
      const pulses = fallbackPulses([0, 50, 20, -5]);
      expect(pulses.length).assertEqual(1);
      expect(pulses[0].atMs).assertEqual(50);
      expect(pulses[0].durationMs).assertEqual(20);
      expect(fallbackPulses([]).length).assertEqual(0);
    });
    it('planUsesPresetOnlyWhenSupported', 0, () => {
      const preset = planFor(HapticCue.RESULT_READY, true);
      expect(preset.preset?.effectId).assertEqual('haptic.notice.success');
      expect(preset.pulses.length).assertEqual(0);
      const fallback = planFor(HapticCue.RESULT_READY, false);
      expect(fallback.preset === undefined).assertTrue();
      expect(fallback.pulses.length).assertEqual(2);
    });
    it('uiCuesRespectTouchFeedbackSwitch', 0, () => {
      expect(TOUCH_SWITCH_USAGES.includes(UI_USAGE)).assertTrue();
      expect(patternFor(HapticCue.TAP).usage).assertEqual(UI_USAGE);
      expect(patternFor(HapticCue.RESULT_READY).usage).assertEqual(UI_USAGE);
      expect(patternFor(HapticCue.ERROR).usage).assertEqual(UI_USAGE);
    });
    it('guidanceIsNotMutedByTouchFeedbackOff', 0, () => {
      expect(TOUCH_SWITCH_USAGES.includes(GUIDANCE_USAGE)).assertFalse();
      expect(patternFor(HapticCue.GUIDANCE_PULSE).usage).assertEqual(GUIDANCE_USAGE);
      expect(patternFor(HapticCue.ARRIVED).usage).assertEqual(GUIDANCE_USAGE);
      expect(patternFor(HapticCue.SEARCH_TICK).usage).assertEqual(GUIDANCE_USAGE);
      expect(patternFor(HapticCue.ACQUIRED).usage).assertEqual(GUIDANCE_USAGE);
      expect(patternFor(HapticCue.LOST).usage).assertEqual(GUIDANCE_USAGE);
    });
    it('searchTickIsSoftAndFitsTheTickPeriod', 0, () => {
      const tick = patternFor(HapticCue.SEARCH_TICK);
      expect(tick.preset.intensity < patternFor(HapticCue.GUIDANCE_PULSE).preset.intensity).assertTrue();
      expect(totalMs(tick.fallbackMs) < 1500).assertTrue();
    });
    it('fallbackPatternsAreDistinctAndShort', 0, () => {
      const seen: string[] = [];
      for (const cue of ALL_CUES) {
        const segments = patternFor(cue).fallbackMs;
        const key = segments.join(',');
        expect(seen.includes(key)).assertFalse();
        seen.push(key);
        expect(totalMs(segments) <= 600).assertTrue();
      }
    });
    it('guidancePulseFitsTheFastestPeriod', 0, () => {
      expect(totalMs(patternFor(HapticCue.GUIDANCE_PULSE).fallbackMs) < 110).assertTrue();
      expect(totalMs(patternFor(HapticCue.TAP).fallbackMs) <= 20).assertTrue();
    });
    it('presetsAreDistinctAndIntensityInRange', 0, () => {
      const keys: string[] = [];
      for (const cue of ALL_CUES) {
        const preset = patternFor(cue).preset;
        const key = `${preset.effectId}/${preset.intensity}/${preset.count}`;
        expect(keys.includes(key)).assertFalse();
        keys.push(key);
        expect(preset.intensity > 0 && preset.intensity <= 100).assertTrue();
        expect(preset.count >= 1).assertTrue();
      }
      for (const id of presetIds()) {
        expect(id.startsWith('haptic.')).assertTrue();
      }
    });
  });
}

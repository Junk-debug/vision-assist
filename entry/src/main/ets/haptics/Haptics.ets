import { vibrator } from '@kit.SensorServiceKit';
import { describeError, log } from '../common/Logger';

const VIBRATION_USAGE: vibrator.Usage = 'touch';

export class Haptics {
  pulse(durationMs: number): void {
    const effect: vibrator.VibrateTime = { type: 'time', duration: durationMs };
    const attribute: vibrator.VibrateAttribute = { id: 0, usage: VIBRATION_USAGE };
    try {
      vibrator.startVibration(effect, attribute).catch((error: Object) => {
        log(`vibration failed ${describeError(error)}`);
      });
    } catch (error) {
      log(`vibration unavailable ${describeError(error)}`);
    }
  }

  stop(): void {
    try {
      vibrator.stopVibration();
    } catch (error) {
      log(`stop vibration failed ${describeError(error)}`);
    }
  }
}

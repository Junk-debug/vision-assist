import { accessibility } from '@kit.AccessibilityKit';
import { bundleManager } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { describeError, log } from '../common/Logger';

export class ScreenReader {
  private bundleName: string = '';

  async init(): Promise<void> {
    try {
      this.bundleName = (await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)).name;
    } catch (error) {
      log(`bundle name lookup failed ${describeError(error)}`);
    }
  }

  isOn(): boolean {
    try {
      return accessibility.isScreenReaderOpenSync();
    } catch (error) {
      return false;
    }
  }

  announce(text: string, interrupt: boolean): void {
    this.send({
      type: interrupt ? 'announceForAccessibility' : 'announceForAccessibilityNotInterrupt',
      bundleName: this.bundleName,
      triggerAction: 'common',
      textAnnouncedForAccessibility: text
    });
  }

  focus(id: string, delayMs: number = 0): void {
    if (id === '' || !this.isOn()) {
      return;
    }
    const event: accessibility.EventInfo = {
      type: 'requestFocusForAccessibility',
      bundleName: this.bundleName,
      triggerAction: 'common',
      customId: id
    };
    if (delayMs <= 0) {
      this.send(event);
      return;
    }
    setTimeout(() => this.send(event), delayMs);
  }

  private send(event: accessibility.EventInfo): void {
    accessibility.sendAccessibilityEvent(event).catch((error: BusinessError) => {
      log(`accessibility event ${event.type} failed ${describeError(error)}`);
    });
  }
}

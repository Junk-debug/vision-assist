import { accessibility } from '@kit.AccessibilityKit';
import { bundleManager } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { describeError, log } from '../common/Logger';

export class ScreenReader {
  private bundleName: string = '';
  private lastState: boolean | undefined = undefined;

  async init(): Promise<void> {
    try {
      this.bundleName = (await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)).name;
    } catch (error) {
      log(`bundle name lookup failed ${describeError(error)}`);
    }
  }

  isOn(): boolean {
    const on = this.readerOpen() || this.touchGuideOpen();
    if (on !== this.lastState) {
      this.lastState = on;
      log(`screen reader ${on ? 'on' : 'off'} (reader ${this.readerOpen()}, touch guide ${this.touchGuideOpen()})`);
    }
    return on;
  }

  private readerOpen(): boolean {
    try {
      return accessibility.isScreenReaderOpenSync();
    } catch (error) {
      return false;
    }
  }

  private touchGuideOpen(): boolean {
    try {
      return accessibility.isOpenTouchGuideSync();
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

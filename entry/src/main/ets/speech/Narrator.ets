import { textToSpeech } from '@kit.CoreSpeechKit';
import { accessibility } from '@kit.AccessibilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { bundleManager } from '@kit.AbilityKit';
import { describeError, log } from '../common/Logger';

const ENGINE_NAME: string = 'vision-assist';
const SPEECH_RATE: number = 1.1;

interface VoiceOption {
  language: string;
  person: number;
}

const VOICES: VoiceOption[] = [
  { language: 'en-US', person: 8 },
  { language: 'zh-CN', person: 13 }
];

export class Narrator {
  private engine?: textToSpeech.TextToSpeechEngine;
  private speaking: boolean = false;
  private voiceName: string = 'none';
  private bundleName: string = '';

  async init(): Promise<void> {
    try {
      this.bundleName = (await bundleManager.getBundleInfoForSelf(bundleManager.BundleFlag.GET_BUNDLE_INFO_DEFAULT)).name;
    } catch (error) {
      log(`bundle name lookup failed ${describeError(error)}`);
    }
    for (const voice of VOICES) {
      const extra: Record<string, Object> = { 'style': 'interaction-broadcast', 'locate': 'CN', 'name': ENGINE_NAME };
      const params: textToSpeech.CreateEngineParams = { language: voice.language, person: voice.person, online: 1, extraParams: extra };
      try {
        this.engine = await textToSpeech.createEngine(params);
        this.voiceName = `${voice.language}/${voice.person}`;
        break;
      } catch (error) {
        log(`voice ${voice.language}/${voice.person} unavailable ${describeError(error)}`);
      }
    }
    if (this.engine) {
      this.engine.setListener({
        onStart: (): void => { this.speaking = true; },
        onComplete: (): void => { this.speaking = false; },
        onStop: (): void => { this.speaking = false; },
        onError: (id: string, code: number, message: string): void => {
          this.speaking = false;
          log(`speech error ${id} ${code} ${message}`);
        }
      });
    }
    log(`narrator ready, voice ${this.voiceName}, screen reader ${this.screenReaderOpen()}`);
  }

  screenReaderOpen(): boolean {
    try {
      return accessibility.isScreenReaderOpenSync();
    } catch (error) {
      return false;
    }
  }

  announce(text: string, interrupt: boolean = false): void {
    if (this.screenReaderOpen()) {
      const info: accessibility.EventInfo = {
        type: 'announceForAccessibility',
        bundleName: this.bundleName,
        triggerAction: 'common',
        textAnnouncedForAccessibility: text
      };
      accessibility.sendAccessibilityEvent(info).catch((error: BusinessError) => {
        log(`announce failed ${describeError(error)}`);
      });
      return;
    }
    this.speak(text, interrupt);
  }

  speak(text: string, interrupt: boolean = false): void {
    if (!this.engine) {
      return;
    }
    if (this.speaking) {
      if (!interrupt) {
        return;
      }
      this.engine.stop();
    }
    const extra: Record<string, Object> = {
      'queueMode': 0,
      'speed': SPEECH_RATE,
      'volume': 2,
      'pitch': 1,
      'languageContext': 'en-US',
      'audioType': 'pcm',
      'playType': 1
    };
    const params: textToSpeech.SpeakParams = { requestId: `speech-${Date.now()}`, extraParams: extra };
    this.speaking = true;
    this.engine.speak(text, params);
  }

  release(): void {
    this.engine?.shutdown();
    this.engine = undefined;
  }
}

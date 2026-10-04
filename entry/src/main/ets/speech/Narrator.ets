import { textToSpeech } from '@kit.CoreSpeechKit';
import { RateLimiter } from '../accessibility/RateLimiter';
import { ScreenReader } from '../accessibility/ScreenReader';
import { SCREEN_READER_BACKGROUND_GAP_MS } from '../common/Config';
import { describeError, log } from '../common/Logger';

const ENGINE_NAME: string = 'vision-assist';
const SPEECH_RATE: number = 1.1;

export enum Priority {
  BACKGROUND,
  RESULT,
  URGENT
}

interface VoiceOption {
  language: string;
  person: number;
}

const VOICES: VoiceOption[] = [
  { language: 'en-US', person: 8 },
  { language: 'zh-CN', person: 13 }
];

export class Narrator {
  readonly screenReader: ScreenReader = new ScreenReader();
  private readonly backgroundLimiter: RateLimiter = new RateLimiter(SCREEN_READER_BACKGROUND_GAP_MS);
  private engine?: textToSpeech.TextToSpeechEngine;
  private speaking: boolean = false;
  private voiceName: string = 'none';

  async init(): Promise<void> {
    await this.screenReader.init();
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
    log(`narrator ready, voice ${this.voiceName}, screen reader ${this.screenReader.isOn()}`);
  }

  announce(text: string, priority: Priority = Priority.RESULT): void {
    if (text === '') {
      return;
    }
    if (this.screenReader.isOn()) {
      if (priority === Priority.BACKGROUND && !this.backgroundLimiter.allow(Date.now())) {
        return;
      }
      this.screenReader.announce(text, priority === Priority.URGENT);
      return;
    }
    this.speak(text, priority !== Priority.BACKGROUND);
  }

  announceScreen(name: string): void {
    if (!this.screenReader.isOn()) {
      this.speak(name, true);
    }
  }

  stopSpeaking(): void {
    if (this.engine && this.speaking) {
      this.engine.stop();
    }
  }

  private speak(text: string, interrupt: boolean): void {
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

import { textToSpeech } from '@kit.CoreSpeechKit';
import { RateLimiter } from '../accessibility/RateLimiter';
import { ScreenReader } from '../accessibility/ScreenReader';
import { SCREEN_READER_BACKGROUND_GAP_MS } from '../common/Config';
import { describeError, log } from '../common/Logger';
import { ChunkSpeaker, ReadAloud } from './ReadAloud';
import { splitIntoChunks } from './TextChunks';

const ENGINE_NAME: string = 'vision-assist';
const SPEECH_RATE: number = 1.1;
const PLAYBACK_COMPLETE: number = 1;
const SCREEN_READER_MS_PER_CHAR: number = 55;
const SCREEN_READER_CHUNK_GAP_MS: number = 400;
const NO_TIMER: number = -1;

export function screenReaderChunkMs(text: string): number {
  return SCREEN_READER_CHUNK_GAP_MS + text.length * SCREEN_READER_MS_PER_CHAR;
}

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

export class Narrator implements ChunkSpeaker {
  readonly screenReader: ScreenReader = new ScreenReader();
  readonly reader: ReadAloud;
  private readonly backgroundLimiter: RateLimiter = new RateLimiter(SCREEN_READER_BACKGROUND_GAP_MS);
  private engine?: textToSpeech.TextToSpeechEngine;
  private speaking: boolean = false;
  private voiceName: string = 'none';
  private requestCount: number = 0;
  private chunkRequestId: string = '';
  private chunkDone?: () => void;
  private chunkTimer: number = NO_TIMER;

  constructor() {
    this.reader = new ReadAloud(this);
  }

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
        onComplete: (id: string, response: textToSpeech.CompleteResponse): void => {
          this.speaking = false;
          if (response.type === PLAYBACK_COMPLETE) {
            this.finishChunk(id);
          }
        },
        onStop: (): void => { this.speaking = false; },
        onError: (id: string, code: number, message: string): void => {
          this.speaking = false;
          log(`speech error ${id} ${code} ${message}`);
          this.finishChunk(id);
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
    this.reader.stop();
    if (this.engine && this.speaking) {
      this.engine.stop();
    }
  }

  readText(text: string): void {
    this.reader.start(splitIntoChunks(text));
  }

  readChunks(chunks: string[]): void {
    this.reader.start(chunks);
  }

  stopReading(): boolean {
    return this.reader.stop();
  }

  isReading(): boolean {
    return this.reader.isReading();
  }

  speakChunk(text: string, done: () => void): void {
    this.clearChunk();
    if (this.screenReader.isOn()) {
      this.screenReader.announce(text, false);
      this.chunkTimer = setTimeout(done, screenReaderChunkMs(text));
      return;
    }
    if (!this.engine) {
      this.chunkTimer = setTimeout(done, 0);
      return;
    }
    if (this.speaking) {
      this.engine.stop();
    }
    this.chunkDone = done;
    this.chunkRequestId = this.nextRequestId();
    this.play(text, this.chunkRequestId);
  }

  cancelChunk(): void {
    this.clearChunk();
    if (this.engine && this.speaking) {
      this.engine.stop();
    }
  }

  private clearChunk(): void {
    if (this.chunkTimer !== NO_TIMER) {
      clearTimeout(this.chunkTimer);
      this.chunkTimer = NO_TIMER;
    }
    this.chunkDone = undefined;
    this.chunkRequestId = '';
  }

  private finishChunk(requestId: string): void {
    if (requestId === '' || requestId !== this.chunkRequestId || this.chunkDone === undefined) {
      return;
    }
    const done = this.chunkDone;
    this.chunkDone = undefined;
    this.chunkRequestId = '';
    done();
  }

  private nextRequestId(): string {
    this.requestCount++;
    return `speech-${Date.now()}-${this.requestCount}`;
  }

  private speak(text: string, interrupt: boolean): void {
    if (!this.engine) {
      return;
    }
    if (this.reader.isReading()) {
      if (!interrupt) {
        return;
      }
      this.reader.stop();
    }
    if (this.speaking) {
      if (!interrupt) {
        return;
      }
      this.engine.stop();
    }
    this.play(text, this.nextRequestId());
  }

  private play(text: string, requestId: string): void {
    if (!this.engine) {
      return;
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
    const params: textToSpeech.SpeakParams = { requestId: requestId, extraParams: extra };
    this.speaking = true;
    this.engine.speak(text, params);
  }

  release(): void {
    this.reader.stop();
    this.engine?.shutdown();
    this.engine = undefined;
  }
}

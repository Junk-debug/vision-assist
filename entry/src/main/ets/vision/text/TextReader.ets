import { image } from '@kit.ImageKit';
import { TextReadResult, TextRecognizer } from './TextTypes';
import { describeError, log } from '../../common/Logger';

export class TextReader {
  private recognizers: TextRecognizer[] = [];

  add(recognizer: TextRecognizer): void {
    this.recognizers.push(recognizer);
  }

  async prepare(): Promise<void> {
    await Promise.all(this.recognizers.map(async (recognizer: TextRecognizer) => {
      const ready = await recognizer.prepare();
      log(`text recognizer ${recognizer.name} ready: ${ready}`);
    }));
  }

  isAvailable(): boolean {
    return this.recognizers.some((recognizer: TextRecognizer) => recognizer.isReady());
  }

  async read(frame: image.PixelMap): Promise<TextReadResult | undefined> {
    for (const recognizer of this.recognizers) {
      if (!recognizer.isReady()) {
        continue;
      }
      try {
        return await recognizer.recognize(frame);
      } catch (error) {
        log(`text recognizer ${recognizer.name} failed ${describeError(error)}`);
      }
    }
    return undefined;
  }

  release(): void {
    for (const recognizer of this.recognizers) {
      recognizer.release();
    }
  }
}

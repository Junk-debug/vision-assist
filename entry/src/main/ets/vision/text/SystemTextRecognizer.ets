import { image } from '@kit.ImageKit';
import { textRecognition } from '@kit.CoreVisionKit';
import { TextLineResult, TextReadResult, TextRecognizer, TextWordResult } from './TextTypes';
import { NormalizedBox } from '../DetectionTypes';
import { describeError, log } from '../../common/Logger';

function boundsOf(points: textRecognition.PixelPoint[], width: number, height: number): NormalizedBox {
  let minX = width;
  let maxX = 0;
  let minY = height;
  let maxY = 0;
  for (const point of points) {
    minX = Math.min(minX, point.x);
    maxX = Math.max(maxX, point.x);
    minY = Math.min(minY, point.y);
    maxY = Math.max(maxY, point.y);
  }
  return { x1: minX / width, y1: minY / height, x2: maxX / width, y2: maxY / height };
}

export class SystemTextRecognizer implements TextRecognizer {
  readonly name: string = 'system';
  private ready: boolean = false;

  async prepare(): Promise<boolean> {
    try {
      this.ready = await textRecognition.init();
    } catch (error) {
      log(`system text recognition unavailable ${describeError(error)}`);
      this.ready = false;
    }
    return this.ready;
  }

  isReady(): boolean {
    return this.ready;
  }

  async recognize(frame: image.PixelMap): Promise<TextReadResult> {
    const start = Date.now();
    const info = await frame.getImageInfo();
    const width = info.size.width;
    const height = info.size.height;
    const visionInfo: textRecognition.VisionInfo = { pixelMap: frame };
    const result = await textRecognition.recognizeText(visionInfo);
    const lines: TextLineResult[] = [];
    const words: TextWordResult[] = [];
    for (const block of result.blocks) {
      for (const line of block.lines) {
        const lineBox = boundsOf(line.cornerPoints, width, height);
        lines.push({ text: line.value, x1: lineBox.x1, y1: lineBox.y1, x2: lineBox.x2, y2: lineBox.y2 });
        for (const word of line.words) {
          const wordBox = boundsOf(word.cornerPoints, width, height);
          words.push({ text: word.value, x1: wordBox.x1, y1: wordBox.y1, x2: wordBox.x2, y2: wordBox.y2 });
        }
      }
    }
    return { text: result.value, lines: lines, words: words, engine: this.name, elapsedMs: Date.now() - start };
  }

  release(): void {
    if (this.ready) {
      textRecognition.release();
      this.ready = false;
    }
  }
}

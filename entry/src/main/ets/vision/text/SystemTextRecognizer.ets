import { image } from '@kit.ImageKit';
import { textRecognition } from '@kit.CoreVisionKit';
import { TextLineResult, TextReadResult, TextRecognizer } from './TextTypes';
import { describeError, log } from '../../common/Logger';

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
    for (const block of result.blocks) {
      for (const line of block.lines) {
        let minX = width;
        let maxX = 0;
        let minY = height;
        let maxY = 0;
        for (const point of line.cornerPoints) {
          minX = Math.min(minX, point.x);
          maxX = Math.max(maxX, point.x);
          minY = Math.min(minY, point.y);
          maxY = Math.max(maxY, point.y);
        }
        lines.push({ text: line.value, x1: minX / width, y1: minY / height, x2: maxX / width, y2: maxY / height });
      }
    }
    return { text: result.value, lines: lines, engine: this.name, elapsedMs: Date.now() - start };
  }

  release(): void {
    if (this.ready) {
      textRecognition.release();
      this.ready = false;
    }
  }
}

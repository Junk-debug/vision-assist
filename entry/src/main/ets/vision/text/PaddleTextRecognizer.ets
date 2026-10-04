import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { mindSporeLite } from '@kit.MindSporeLiteKit';
import { util } from '@kit.ArkTS';
import { buildCharset, decodeGreedy } from './CtcDecoder';
import { extractBoxes, groupIntoLines, TextBox } from './DbPostProcessor';
import { resizeRgb } from './ImageOps';
import { TextLineResult, TextReadResult, TextRecognizer, TextWordResult } from './TextTypes';
import { ON_DEVICE_PREPARE_TIMEOUT_MS, ON_DEVICE_RECOGNIZE_TIMEOUT_MS } from './TextEngineConfig';
import { describeError, log } from '../../common/Logger';
import { loadModel } from '../ModelLoader';

const DETECTOR_FILE: string = 'ocr_det.ms';
const RECOGNIZER_FILE: string = 'ocr_rec.ms';
const DICTIONARY_FILE: string = 'ocr_dict.txt';
const DETECTOR_SIZE: number = 640;
const STRIP_HEIGHT: number = 48;
const STRIP_WIDTH: number = 320;
const CTC_STEPS: number = 40;
const CTC_CLASSES: number = 97;
const DETECTOR_MEAN: number[] = [0.485, 0.456, 0.406];
const DETECTOR_STD: number[] = [0.229, 0.224, 0.225];
const QUIET_RATIO: number = 0.03;
const SPACE_GAP_PX: number = 8;
const SPLIT_SEARCH_START: number = 200;
const MIN_CONFIDENCE: number = 0.3;

interface Strip {
  rgb: Uint8Array;
  width: number;
  gapAfter: boolean;
}

export class PaddleTextRecognizer implements TextRecognizer {
  readonly name: string = 'on-device';
  readonly prepareTimeoutMs: number = ON_DEVICE_PREPARE_TIMEOUT_MS;
  readonly recognizeTimeoutMs: number = ON_DEVICE_RECOGNIZE_TIMEOUT_MS;
  private detector?: mindSporeLite.Model;
  private recognizer?: mindSporeLite.Model;
  private charset: string[] = [];
  private readonly context: common.UIAbilityContext;
  private ready: boolean = false;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async prepare(): Promise<boolean> {
    try {
      this.detector = await loadModel(this.context, DETECTOR_FILE);
      this.recognizer = await loadModel(this.context, RECOGNIZER_FILE);
      const dictionaryBytes = await this.context.resourceManager.getRawFileContent(DICTIONARY_FILE);
      this.charset = buildCharset(new util.TextDecoder('utf-8').decodeToString(dictionaryBytes));
      this.ready = true;
    } catch (error) {
      log(`on-device OCR unavailable ${describeError(error)}`);
      this.ready = false;
    }
    return this.ready;
  }

  async recognize(frame: image.PixelMap): Promise<TextReadResult> {
    const start = Date.now();
    const info = await frame.getImageInfo();
    const width = info.size.width;
    const height = info.size.height;
    const bytes = new ArrayBuffer(frame.getPixelBytesNumber());
    await frame.readPixelsToBuffer(bytes);
    const pixels = new Uint8Array(bytes);
    const rowBytes = pixels.length / height;
    const boxes = await this.detectBoxes(pixels, rowBytes, width, height);
    const lines = groupIntoLines(boxes);
    const lineTexts: string[] = [];
    const lineResults: TextLineResult[] = [];
    const wordResults: TextWordResult[] = [];
    for (const line of lines) {
      const words: string[] = [];
      let x0 = width;
      let y0 = height;
      let x1 = 0;
      let y1 = 0;
      for (const box of line) {
        const text = await this.readBox(pixels, rowBytes, box);
        if (text.length > 0) {
          words.push(text);
          wordResults.push({ text: text, x1: box.x0 / width, y1: box.y0 / height, x2: box.x1 / width, y2: box.y1 / height });
          x0 = Math.min(x0, box.x0);
          y0 = Math.min(y0, box.y0);
          x1 = Math.max(x1, box.x1);
          y1 = Math.max(y1, box.y1);
        }
      }
      if (words.length > 0) {
        const text = words.join(' ');
        lineTexts.push(text);
        lineResults.push({ text: text, x1: x0 / width, y1: y0 / height, x2: x1 / width, y2: y1 / height });
      }
    }
    return { text: lineTexts.join('\n'), lines: lineResults, words: wordResults, engine: this.name, elapsedMs: Date.now() - start };
  }

  private async detectBoxes(pixels: Uint8Array, rowBytes: number, width: number, height: number): Promise<TextBox[]> {
    const model = this.detector as mindSporeLite.Model;
    const scale = DETECTOR_SIZE / Math.max(width, height);
    const usedW = Math.min(DETECTOR_SIZE, Math.max(1, Math.round(width * scale)));
    const usedH = Math.min(DETECTOR_SIZE, Math.max(1, Math.round(height * scale)));
    const resized = resizeRgb(pixels, rowBytes, 0, 0, width, height, usedW, usedH);
    const tensor = new Float32Array(DETECTOR_SIZE * DETECTOR_SIZE * 3);
    for (let y = 0; y < usedH; y++) {
      let source = y * usedW * 3;
      let target = y * DETECTOR_SIZE * 3;
      for (let x = 0; x < usedW; x++) {
        tensor[target] = (resized[source + 2] / 255 - DETECTOR_MEAN[0]) / DETECTOR_STD[0];
        tensor[target + 1] = (resized[source + 1] / 255 - DETECTOR_MEAN[1]) / DETECTOR_STD[1];
        tensor[target + 2] = (resized[source] / 255 - DETECTOR_MEAN[2]) / DETECTOR_STD[2];
        source += 3;
        target += 3;
      }
    }
    const input = model.getInputs()[0];
    input.setData(tensor.buffer as ArrayBuffer);
    const outputs = await model.predict([input]);
    const probability = new Float32Array(outputs[0].getData());
    return extractBoxes(probability, DETECTOR_SIZE, usedW, usedH, scale, width, height);
  }

  private async readBox(pixels: Uint8Array, rowBytes: number, box: TextBox): Promise<string> {
    const boxW = box.x1 - box.x0;
    const boxH = box.y1 - box.y0;
    const targetW = Math.max(1, Math.round(STRIP_HEIGHT * boxW / boxH));
    const rgb = resizeRgb(pixels, rowBytes, box.x0, box.y0, boxW, boxH, targetW, STRIP_HEIGHT);
    const strips = this.splitStrips(rgb, targetW);
    let text = '';
    for (const strip of strips) {
      const decoded = await this.decodeStrip(strip);
      if (decoded.length > 0) {
        text += decoded + (strip.gapAfter ? ' ' : '');
      }
    }
    return text.trim();
  }

  private splitStrips(rgb: Uint8Array, totalW: number): Strip[] {
    if (totalW <= STRIP_WIDTH) {
      return [{ rgb: rgb, width: totalW, gapAfter: false }];
    }
    const ink = this.inkProfile(rgb, totalW);
    let maxInk = 0;
    for (let x = 0; x < totalW; x++) {
      maxInk = Math.max(maxInk, ink[x]);
    }
    const strips: Strip[] = [];
    let begin = 0;
    while (totalW - begin > STRIP_WIDTH) {
      let bestStart = -1;
      let bestLength = 0;
      let runStart = -1;
      const limit = begin + STRIP_WIDTH;
      for (let x = begin + SPLIT_SEARCH_START; x <= limit; x++) {
        const quiet = x < limit && ink[x] < QUIET_RATIO * maxInk;
        if (quiet && runStart < 0) {
          runStart = x;
        }
        if (!quiet && runStart >= 0) {
          if (x - runStart > bestLength) {
            bestLength = x - runStart;
            bestStart = runStart;
          }
          runStart = -1;
        }
      }
      let cut = limit;
      if (bestLength > 0) {
        cut = bestStart + Math.floor(bestLength / 2);
      } else {
        let lowest = Number.MAX_VALUE;
        for (let x = begin + SPLIT_SEARCH_START; x < limit; x++) {
          if (ink[x] < lowest) {
            lowest = ink[x];
            cut = x;
          }
        }
      }
      strips.push({ rgb: this.sliceColumns(rgb, totalW, begin, cut), width: cut - begin, gapAfter: bestLength >= SPACE_GAP_PX });
      begin = cut;
    }
    strips.push({ rgb: this.sliceColumns(rgb, totalW, begin, totalW), width: totalW - begin, gapAfter: false });
    return strips;
  }

  private sliceColumns(rgb: Uint8Array, totalW: number, from: number, to: number): Uint8Array {
    const width = to - from;
    const out = new Uint8Array(width * STRIP_HEIGHT * 3);
    for (let y = 0; y < STRIP_HEIGHT; y++) {
      const source = (y * totalW + from) * 3;
      for (let i = 0; i < width * 3; i++) {
        out[y * width * 3 + i] = rgb[source + i];
      }
    }
    return out;
  }

  private inkProfile(rgb: Uint8Array, totalW: number): Float32Array {
    const gray = new Uint8Array(totalW * STRIP_HEIGHT);
    const histogram = new Int32Array(256);
    for (let i = 0; i < gray.length; i++) {
      const value = Math.round(0.299 * rgb[i * 3] + 0.587 * rgb[i * 3 + 1] + 0.114 * rgb[i * 3 + 2]);
      gray[i] = value;
      histogram[value]++;
    }
    let median = 0;
    let seen = 0;
    while (median < 255 && seen + histogram[median] < gray.length / 2) {
      seen += histogram[median];
      median++;
    }
    const ink = new Float32Array(totalW);
    for (let x = 0; x < totalW; x++) {
      let sum = 0;
      for (let y = 0; y < STRIP_HEIGHT; y++) {
        sum += Math.abs(gray[y * totalW + x] - median);
      }
      ink[x] = sum / STRIP_HEIGHT;
    }
    return ink;
  }

  private async decodeStrip(strip: Strip): Promise<string> {
    const model = this.recognizer as mindSporeLite.Model;
    const tensor = new Float32Array(STRIP_HEIGHT * STRIP_WIDTH * 3);
    for (let y = 0; y < STRIP_HEIGHT; y++) {
      for (let x = 0; x < strip.width; x++) {
        const source = (y * strip.width + x) * 3;
        const target = (y * STRIP_WIDTH + x) * 3;
        tensor[target] = (strip.rgb[source + 2] / 255 - 0.5) / 0.5;
        tensor[target + 1] = (strip.rgb[source + 1] / 255 - 0.5) / 0.5;
        tensor[target + 2] = (strip.rgb[source] / 255 - 0.5) / 0.5;
      }
    }
    const input = model.getInputs()[0];
    input.setData(tensor.buffer as ArrayBuffer);
    const outputs = await model.predict([input]);
    const decoded = decodeGreedy(new Float32Array(outputs[0].getData()), CTC_STEPS, CTC_CLASSES, this.charset);
    return decoded.confidence >= MIN_CONFIDENCE ? decoded.text : '';
  }

  release(): void {
    this.detector = undefined;
    this.recognizer = undefined;
    this.ready = false;
  }
}

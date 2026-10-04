import { image } from '@kit.ImageKit';
import { NormalizedBox } from '../DetectionTypes';

export interface TextLineResult extends NormalizedBox {
  text: string;
}

export interface TextWordResult extends NormalizedBox {
  text: string;
}

export interface TextReadResult {
  text: string;
  lines: TextLineResult[];
  words: TextWordResult[];
  engine: string;
  elapsedMs: number;
}

export interface TextEngine<F> {
  readonly name: string;
  readonly prepareTimeoutMs: number;
  readonly recognizeTimeoutMs: number;
  prepare(): Promise<boolean>;
  recognize(frame: F): Promise<TextReadResult>;
  release(): void;
}

export interface TextRecognizer extends TextEngine<image.PixelMap> {
}

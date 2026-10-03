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

export interface TextRecognizer {
  readonly name: string;
  prepare(): Promise<boolean>;
  isReady(): boolean;
  recognize(frame: image.PixelMap): Promise<TextReadResult>;
  release(): void;
}

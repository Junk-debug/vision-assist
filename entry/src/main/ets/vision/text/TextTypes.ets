import { image } from '@kit.ImageKit';

export interface TextLineResult {
  text: string;
  x1: number;
  y1: number;
  x2: number;
  y2: number;
}

export interface TextReadResult {
  text: string;
  lines: TextLineResult[];
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

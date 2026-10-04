import { image } from '@kit.ImageKit';
import { FrameSource } from '../camera/FrameSource';
import { haptics } from '../haptics/Haptics';
import { Narrator } from '../speech/Narrator';
import { Overlay } from '../ui/Overlay';
import { ContentRect } from '../vision/DetectionTypes';
import { YoloDetector } from '../vision/YoloDetector';
import { TextReader } from '../vision/text/TextReader';

export interface Feature {
  readonly id: string;
  readonly continuous: boolean;
  start(): Promise<void>;
  stop(): void;
  startedMessage(): string;
  stoppedMessage(): string;
}

export interface PhotoAnalyzer {
  analyzePhoto(photo: image.PixelMap, content: ContentRect): Promise<void>;
}

export interface LiveMode {
  isLive(): boolean;
  startLive(): Promise<void>;
  stopLive(): void;
}

export class FeatureServices {
  readonly camera: FrameSource;
  readonly detector: YoloDetector;
  readonly narrator: Narrator;
  readonly overlay: Overlay;
  readonly textReader: TextReader;
  readonly setStatus: (text: string) => void;
  readonly setTiming: (text: string) => void;
  readonly setResultText: (text: string) => void;

  constructor(camera: FrameSource, detector: YoloDetector, narrator: Narrator, overlay: Overlay,
    textReader: TextReader, setStatus: (text: string) => void, setTiming: (text: string) => void,
    setResultText: (text: string) => void) {
    this.camera = camera;
    this.detector = detector;
    this.narrator = narrator;
    this.overlay = overlay;
    this.textReader = textReader;
    this.setStatus = setStatus;
    this.setTiming = setTiming;
    this.setResultText = setResultText;
  }

  report(message: string): void {
    this.setStatus(message);
    this.narrator.announce(message);
  }

  reportResult(message: string): void {
    haptics.resultReady();
    this.report(message);
  }

  reportFailure(message: string): void {
    haptics.error();
    this.report(message);
  }

  resultReady(): void {
    haptics.resultReady();
  }
}

import { image } from '@kit.ImageKit';
import { FrameSource } from '../camera/FrameSource';
import { haptics } from '../haptics/Haptics';
import { Narrator } from '../speech/Narrator';
import { Overlay } from '../ui/Overlay';
import { ContentRect } from '../vision/DetectionTypes';
import { FindEngine } from '../vision/FindEngine';
import { Sam3Detector } from '../vision/Sam3Detector';
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
  readonly cloudDetector: Sam3Detector;
  readonly findEngine: FindEngine;
  readonly narrator: Narrator;
  readonly overlay: Overlay;
  readonly textReader: TextReader;
  readonly setStatus: (text: string) => void;
  readonly setTiming: (text: string) => void;
  readonly setResultText: (text: string) => void;
  private debugSink: (text: string) => void = (text: string) => {};

  constructor(camera: FrameSource, detector: YoloDetector, cloudDetector: Sam3Detector, findEngine: FindEngine, narrator: Narrator, overlay: Overlay,
    textReader: TextReader, setStatus: (text: string) => void, setTiming: (text: string) => void,
    setResultText: (text: string) => void) {
    this.camera = camera;
    this.detector = detector;
    this.cloudDetector = cloudDetector;
    this.findEngine = findEngine;
    this.narrator = narrator;
    this.overlay = overlay;
    this.textReader = textReader;
    this.setStatus = setStatus;
    this.setTiming = setTiming;
    this.setResultText = setResultText;
  }

  setDebugSink(sink: (text: string) => void): void {
    this.debugSink = sink;
  }

  showDebug(text: string): void {
    this.debugSink(text);
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

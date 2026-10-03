import { CameraSource } from '../camera/CameraSource';
import { Narrator } from '../speech/Narrator';
import { Overlay } from '../ui/Overlay';
import { YoloDetector } from '../vision/YoloDetector';
import { TextReader } from '../vision/text/TextReader';

export interface Feature {
  readonly id: string;
  readonly continuous: boolean;
  start(): Promise<void>;
  stop(): void;
}

export class FeatureServices {
  readonly camera: CameraSource;
  readonly detector: YoloDetector;
  readonly narrator: Narrator;
  readonly overlay: Overlay;
  readonly textReader: TextReader;
  readonly setStatus: (text: string) => void;
  readonly setTiming: (text: string) => void;

  constructor(camera: CameraSource, detector: YoloDetector, narrator: Narrator, overlay: Overlay,
    textReader: TextReader, setStatus: (text: string) => void, setTiming: (text: string) => void) {
    this.camera = camera;
    this.detector = detector;
    this.narrator = narrator;
    this.overlay = overlay;
    this.textReader = textReader;
    this.setStatus = setStatus;
    this.setTiming = setTiming;
  }
}

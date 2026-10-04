import { image } from '@kit.ImageKit';
import { Feature, FeatureServices } from './Feature';
import { GuidanceCoach } from './GuidanceCoach';
import {
  CLOUD_FIND_FRAME_INTERVAL_MS, CLOUD_FIND_THRESHOLD, DEBUG_DISPLAY_THRESHOLD, FIND_CLOUD_TUNING, FIND_FRAME_INTERVAL_MS,
  FIND_OBJECT_TUNING, FIND_THRESHOLD, FindTuning
} from '../common/Config';
import { DebugState } from '../common/DebugState';
import { Messages } from '../common/Messages';
import { Priority } from '../speech/Narrator';
import { Detection, DetectionResult } from '../vision/DetectionTypes';
import { EngineKind } from '../vision/FindEngine';
import { normalizeFrame } from '../vision/FrameNormalizer';

export class FindFeature implements Feature {
  readonly id: string = 'find';
  readonly continuous: boolean = true;
  private readonly services: FeatureServices;
  private coach?: GuidanceCoach;
  private target: string = '';
  private running: boolean = false;
  private engine: EngineKind = EngineKind.DEVICE;

  constructor(services: FeatureServices) {
    this.services = services;
  }

  setTarget(label: string): void {
    const known = this.services.detector.canonicalLabel(label);
    this.target = known !== '' ? known : label;
  }

  startedMessage(): string {
    return Messages.findStarted(this.target);
  }

  stoppedMessage(): string {
    return Messages.SEARCH_STOPPED;
  }

  async start(): Promise<void> {
    this.running = true;
    this.engine = this.services.findEngine.current(Date.now());
    this.coach = new GuidanceCoach(this.services, {
      name: this.target,
      spokenName: this.target.toLowerCase(),
      searchingStatus: Messages.searchingFor(this.target)
    }, this.tuning());
    this.coach.start(Date.now());
    this.warnIfDeviceCannotFind();
    this.services.camera.setFrameHandler((frame: image.PixelMap) => this.process(frame), this.frameInterval());
  }

  stop(): void {
    this.running = false;
    this.services.camera.setFrameHandler(undefined, 0);
    this.coach?.stop();
    this.services.overlay.clear();
  }

  private async process(frame: image.PixelMap): Promise<void> {
    if (!this.running) {
      return;
    }
    const content = await normalizeFrame(frame, this.services.camera.frameRotation());
    const debug = DebugState.enabled;
    const wanted = this.services.findEngine.current(Date.now());
    if (wanted !== this.engine) {
      this.switchEngine(wanted);
    }
    const result = await this.detect(frame, debug);
    if (!this.running) {
      return;
    }
    const threshold = this.threshold();
    const guidable = result.detections.filter((detection: Detection) => detection.score >= threshold);
    this.services.overlay.drawDetections(debug ? result.detections : guidable, content, this.target);
    const match = this.bestMatch(guidable);
    this.coach?.update(match, Date.now(), result.inferenceMs);
  }

  private async detect(frame: image.PixelMap, debug: boolean): Promise<DetectionResult> {
    if (this.engine === EngineKind.CLOUD) {
      try {
        return await this.services.cloudDetector.detect(frame, this.target, this.displayThreshold(debug));
      } catch (error) {
        this.services.findEngine.reportCloudFailure(Date.now());
        this.switchEngine(EngineKind.DEVICE);
      }
    }
    return this.services.detector.detect(frame, this.displayThreshold(debug));
  }

  // Swaps the detector mid-search; the guidance keeps its state, only timing and thresholds change.
  private switchEngine(engine: EngineKind): void {
    if (!this.running || engine === this.engine) {
      return;
    }
    this.engine = engine;
    this.coach?.setTuning(this.tuning());
    this.services.camera.setFrameHandler((frame: image.PixelMap) => this.process(frame), this.frameInterval());
    this.services.narrator.announce(this.engineMessage(), Priority.RESULT);
    this.warnIfDeviceCannotFind();
  }

  private warnIfDeviceCannotFind(): void {
    if (this.engine === EngineKind.DEVICE && this.services.detector.canonicalLabel(this.target) === '') {
      this.services.report(Messages.needsInternet(this.target));
    }
  }

  private engineMessage(): string {
    if (this.engine === EngineKind.CLOUD) {
      return Messages.ENGINE_CLOUD;
    }
    const reason = this.services.findEngine.deviceReason(Date.now());
    if (reason === 'chosen') {
      return Messages.ENGINE_DEVICE_CHOSEN;
    }
    return reason === 'offline' ? Messages.ENGINE_DEVICE_OFFLINE : Messages.ENGINE_DEVICE_FAILED;
  }

  private tuning(): FindTuning {
    return this.engine === EngineKind.CLOUD ? FIND_CLOUD_TUNING : FIND_OBJECT_TUNING;
  }

  private frameInterval(): number {
    return this.engine === EngineKind.CLOUD ? CLOUD_FIND_FRAME_INTERVAL_MS : FIND_FRAME_INTERVAL_MS;
  }

  private threshold(): number {
    return this.engine === EngineKind.CLOUD ? CLOUD_FIND_THRESHOLD : FIND_THRESHOLD;
  }

  private displayThreshold(debug: boolean): number {
    return debug ? Math.min(this.threshold(), DEBUG_DISPLAY_THRESHOLD) : this.threshold();
  }

  private bestMatch(detections: Detection[]): Detection | undefined {
    let best: Detection | undefined = undefined;
    for (const detection of detections) {
      if (detection.label === this.target && (best === undefined || detection.score > best.score)) {
        best = detection;
      }
    }
    return best;
  }
}

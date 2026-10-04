import { image } from '@kit.ImageKit';
import { Feature, FeatureServices } from './Feature';
import { GuidanceCoach } from './GuidanceCoach';
import { DEBUG_DISPLAY_THRESHOLD, FIND_FRAME_INTERVAL_MS, FIND_OBJECT_TUNING, FIND_THRESHOLD } from '../common/Config';
import { DebugState } from '../common/DebugState';
import { Messages } from '../common/Messages';
import { Detection } from '../vision/DetectionTypes';
import { normalizeFrame } from '../vision/FrameNormalizer';

export class FindFeature implements Feature {
  readonly id: string = 'find';
  readonly continuous: boolean = true;
  private readonly services: FeatureServices;
  private coach?: GuidanceCoach;
  private target: string = '';
  private running: boolean = false;

  constructor(services: FeatureServices) {
    this.services = services;
  }

  setTarget(label: string): void {
    this.target = label;
  }

  startedMessage(): string {
    return Messages.findStarted(this.target);
  }

  stoppedMessage(): string {
    return Messages.SEARCH_STOPPED;
  }

  async start(): Promise<void> {
    this.running = true;
    this.coach = new GuidanceCoach(this.services, {
      name: this.target,
      spokenName: this.target.toLowerCase(),
      searchingStatus: Messages.searchingFor(this.target)
    }, FIND_OBJECT_TUNING);
    this.coach.start(Date.now());
    this.services.camera.setFrameHandler((frame: image.PixelMap) => this.process(frame), FIND_FRAME_INTERVAL_MS);
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
    const result = await this.services.detector.detect(frame, debug ? Math.min(FIND_THRESHOLD, DEBUG_DISPLAY_THRESHOLD) : FIND_THRESHOLD);
    if (!this.running) {
      return;
    }
    const guidable = result.detections.filter((detection: Detection) => detection.score >= FIND_THRESHOLD);
    this.services.overlay.drawDetections(debug ? result.detections : guidable, content, this.target);
    const match = this.bestMatch(guidable);
    this.coach?.update(match, Date.now(), result.inferenceMs);
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

import { image } from '@kit.ImageKit';
import { Feature, FeatureServices } from './Feature';
import { computeGuidance } from './FindGuidance';
import { GuidanceCoach } from './GuidanceCoach';
import { FIND_FRAME_INTERVAL_MS, FIND_THRESHOLD } from '../common/Config';
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
      searchingStatus: Messages.searchingFor(this.target),
      searchingSpeech: Messages.SEARCHING_TURN_SLOWLY
    }, 0);
    this.coach.start(Date.now());
    this.services.setStatus(Messages.findStatus(this.target));
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
    const result = await this.services.detector.detect(frame, FIND_THRESHOLD);
    if (!this.running) {
      return;
    }
    this.services.overlay.drawDetections(result.detections, content, this.target);
    const match = this.bestMatch(result.detections);
    this.coach?.update(match === undefined ? undefined : computeGuidance(match), Date.now());
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

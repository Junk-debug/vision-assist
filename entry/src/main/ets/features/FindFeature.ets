import { image } from '@kit.ImageKit';
import { Feature, FeatureServices } from './Feature';
import { computeGuidance } from './FindGuidance';
import { GuidanceCoach } from './GuidanceCoach';
import { FIND_FRAME_INTERVAL_MS, FIND_THRESHOLD } from '../common/Config';
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

  async start(): Promise<void> {
    this.running = true;
    this.coach = new GuidanceCoach(this.services, {
      name: this.target,
      searchingStatus: `Searching for ${this.target.toLowerCase()}.`,
      searchingSpeech: 'Searching. Turn slowly.'
    }, 0);
    this.coach.start(Date.now());
    this.services.setStatus(`Looking for ${this.target.toLowerCase()}.`);
    this.services.narrator.announce(`Looking for ${this.target.toLowerCase()}. Move the phone slowly.`, true);
    this.services.camera.setFrameHandler((frame: image.PixelMap) => this.process(frame), FIND_FRAME_INTERVAL_MS);
  }

  stop(): void {
    this.running = false;
    this.services.camera.setFrameHandler(undefined, 0);
    this.coach?.stop();
    this.services.overlay.clear();
    this.services.setStatus('Stopped.');
    this.services.narrator.announce('Search stopped', true);
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

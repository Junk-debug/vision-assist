import { image } from '@kit.ImageKit';
import { Feature, FeatureServices, LiveMode, PhotoAnalyzer } from './Feature';
import { DETECTION_THRESHOLD, LIVE_FRAME_INTERVAL_MS } from '../common/Config';
import { describeError, log } from '../common/Logger';
import { Messages } from '../common/Messages';
import { Priority } from '../speech/Narrator';
import { normalizeFrame } from '../vision/FrameNormalizer';
import { ContentRect, DetectionResult } from '../vision/DetectionTypes';
import { describeScene, LiveSceneTracker } from '../vision/SceneTracker';

export class DescribeFeature implements Feature, PhotoAnalyzer, LiveMode {
  readonly id: string = 'describe';
  readonly continuous: boolean = false;
  private readonly services: FeatureServices;
  private readonly tracker: LiveSceneTracker = new LiveSceneTracker();
  private live: boolean = false;

  constructor(services: FeatureServices) {
    this.services = services;
  }

  startedMessage(): string {
    return '';
  }

  stoppedMessage(): string {
    return '';
  }

  async start(): Promise<void> {
    this.services.setStatus(Messages.DESCRIBE_LOOKING);
    try {
      const frame = await this.services.camera.nextFrame();
      try {
        const content = await normalizeFrame(frame, this.services.camera.frameRotation());
        const result = await this.services.detector.detect(frame, DETECTION_THRESHOLD);
        this.services.overlay.drawDetections(result.detections, content);
        this.services.setTiming(this.timings(result));
        this.announce(describeScene(result.detections), Messages.NOTHING_TO_DESCRIBE);
      } finally {
        frame.release();
      }
    } catch (error) {
      log(`describing failed ${describeError(error)}`);
      this.services.reportFailure(Messages.CAMERA_NOT_READY);
    }
  }

  stop(): void {
    this.stopLive();
  }

  isLive(): boolean {
    return this.live;
  }

  async startLive(): Promise<void> {
    this.tracker.reset();
    this.live = true;
    this.services.setStatus(Messages.LIVE_WATCHING);
    this.services.camera.setFrameHandler((frame: image.PixelMap) => this.process(frame), LIVE_FRAME_INTERVAL_MS);
  }

  stopLive(): void {
    if (!this.live) {
      return;
    }
    this.live = false;
    this.services.camera.setFrameHandler(undefined, 0);
    this.services.overlay.clear();
  }

  async analyzePhoto(photo: image.PixelMap, content: ContentRect): Promise<void> {
    this.services.overlay.clear();
    this.services.setStatus(Messages.ANALYSING_PHOTO);
    const result = await this.services.detector.detect(photo, DETECTION_THRESHOLD);
    this.services.overlay.drawDetections(result.detections, content);
    this.services.setTiming(this.timings(result));
    this.announce(describeScene(result.detections), Messages.NOTHING_IN_PHOTO);
  }

  private announce(sentence: string, emptyMessage: string): void {
    if (sentence === '') {
      this.services.reportFailure(emptyMessage);
    } else {
      this.services.reportResult(sentence);
    }
  }

  private async process(frame: image.PixelMap): Promise<void> {
    if (!this.live) {
      return;
    }
    const content = await normalizeFrame(frame, this.services.camera.frameRotation());
    const result = await this.services.detector.detect(frame, DETECTION_THRESHOLD);
    if (!this.live) {
      return;
    }
    this.services.overlay.drawDetections(result.detections, content);
    this.services.setTiming(this.timings(result));
    const sentence = this.tracker.update(result.detections, Date.now());
    if (sentence !== undefined) {
      this.services.setStatus(sentence);
      this.services.resultReady();
      this.services.narrator.announce(sentence, Priority.RESULT);
    }
  }

  private timings(result: DetectionResult): string {
    const total = result.preprocessMs + result.inferenceMs + result.postprocessMs;
    return Messages.timing(total, result.preprocessMs, result.inferenceMs, result.postprocessMs);
  }
}

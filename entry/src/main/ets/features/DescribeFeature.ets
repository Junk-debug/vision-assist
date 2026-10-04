import { image } from '@kit.ImageKit';
import { Feature, FeatureServices, LiveMode, PhotoAnalyzer } from './Feature';
import { DESCRIBE_TEXT_BUDGET_MS, DETECTION_THRESHOLD, LIVE_FRAME_INTERVAL_MS, LIVE_TEXT_INTERVAL_MS } from '../common/Config';
import { describeError, log } from '../common/Logger';
import { Messages } from '../common/Messages';
import { Priority } from '../speech/Narrator';
import { normalizeFrame } from '../vision/FrameNormalizer';
import { ContentRect, DetectionResult } from '../vision/DetectionTypes';
import { describeScene, LiveSceneTracker } from '../vision/SceneTracker';
import { colorResolverFor } from '../vision/ObjectColor';
import { describeWithText, normalizeText, planDescription } from '../vision/text/TextHint';
import { SystemTimer, withTimeout } from '../vision/text/EngineRunner';

export class DescribeFeature implements Feature, PhotoAnalyzer, LiveMode {
  readonly id: string = 'describe';
  readonly continuous: boolean = false;
  private readonly services: FeatureServices;
  private readonly tracker: LiveSceneTracker = new LiveSceneTracker();
  private live: boolean = false;
  private readonly timer: SystemTimer = new SystemTimer();
  private lastTextCheckAt: number = 0;
  private textVisible: boolean = false;

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
    this.services.setResultText('');
    this.services.setStatus(Messages.DESCRIBE_LOOKING);
    try {
      const frame = await this.services.camera.nextFrame();
      try {
        const content = await normalizeFrame(frame, this.services.camera.frameRotation());
        const result = await this.services.detector.detect(frame, DETECTION_THRESHOLD);
        const colorOf = await colorResolverFor(frame);
        this.services.overlay.drawDetections(result.detections, content, '', colorOf);
        this.services.setTiming(this.timings(result));
        const text = await this.recognisedText(frame);
        this.deliver(describeScene(result.detections, colorOf), text, Messages.NOTHING_TO_DESCRIBE);
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
    this.lastTextCheckAt = 0;
    this.textVisible = false;
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
    this.services.setResultText('');
    this.services.setStatus(Messages.ANALYSING_PHOTO);
    const result = await this.services.detector.detect(photo, DETECTION_THRESHOLD);
    const colorOf = await colorResolverFor(photo);
    this.services.overlay.drawDetections(result.detections, content, '', colorOf);
    this.services.setTiming(this.timings(result));
    const text = await this.recognisedText(photo);
    this.deliver(describeScene(result.detections, colorOf), text, Messages.NOTHING_IN_PHOTO);
  }

  private deliver(scene: string, text: string, emptyMessage: string): void {
    const plan = planDescription(scene, text);
    this.services.setResultText(text);
    if (plan.sentence === '') {
      this.services.reportFailure(emptyMessage);
      return;
    }
    if (plan.readChunks.length === 0) {
      this.services.reportResult(plan.sentence);
      return;
    }
    this.services.setStatus(plan.sentence);
    this.services.resultReady();
    this.services.narrator.readChunks(plan.readChunks);
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
    const colorOf = await colorResolverFor(frame);
    this.services.overlay.drawDetections(result.detections, content, '', colorOf);
    this.services.setTiming(this.timings(result));
    const now = Date.now();
    let sentence = this.tracker.update(result.detections, now, colorOf);
    const appeared = await this.textAppeared(frame, now);
    if (appeared) {
      sentence = describeWithText(sentence ?? '', Messages.TEXT_AHEAD);
    }
    if (sentence !== undefined && this.live) {
      this.services.setStatus(sentence);
      this.services.resultReady();
      this.services.narrator.announce(sentence, Priority.RESULT);
    }
  }

  private async textAppeared(frame: image.PixelMap, now: number): Promise<boolean> {
    if (now - this.lastTextCheckAt < LIVE_TEXT_INTERVAL_MS) {
      return false;
    }
    this.lastTextCheckAt = now;
    const found = (await this.recognisedText(frame)) !== '';
    const appeared = found && !this.textVisible;
    this.textVisible = found;
    return appeared;
  }

  private async recognisedText(frame: image.PixelMap): Promise<string> {
    try {
      const result = await withTimeout(this.services.textReader.read(frame), DESCRIBE_TEXT_BUDGET_MS, this.timer,
        'describe text');
      return normalizeText(result?.text);
    } catch (error) {
      log(`text hint skipped ${describeError(error)}`);
      return '';
    }
  }

  private timings(result: DetectionResult): string {
    const total = result.preprocessMs + result.inferenceMs + result.postprocessMs;
    return Messages.timing(total, result.preprocessMs, result.inferenceMs, result.postprocessMs);
  }
}

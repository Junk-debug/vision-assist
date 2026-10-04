import { common } from '@kit.AbilityKit';
import { image } from '@kit.ImageKit';
import { http } from '@kit.NetworkKit';
import { FrameGate } from '../../main/ets/camera/FrameGate';
import { FrameHandler, FrameInjector, PreviewListener } from '../../main/ets/camera/FrameSource';
import { describeError, log } from '../../main/ets/common/Logger';
import { fitWithin, orientationDegrees } from '../../main/ets/photo/PhotoMath';
import { padToSquare, squareLayout } from './SquareFrame';

const FRAME_URL: string = 'http://127.0.0.1:8766/frame';
const PROBE_TIMEOUT_MS: number = 700;
const FETCH_TIMEOUT_MS: number = 3000;
const POLL_INTERVAL_MS: number = 120;
const RETRY_INTERVAL_MS: number = 1000;
const MAX_SIDE: number = 1024;
const PREVIEWS_KEPT: number = 3;
const HTTP_OK: number = 200;

interface PaddedFrame {
  bytes: ArrayBuffer;
  side: number;
}

type FrameRequest = (frame: image.PixelMap) => void;

function sleep(ms: number): Promise<void> {
  return new Promise<void>((resolve: () => void) => {
    setTimeout(resolve, ms);
  });
}

async function fetchFrame(timeoutMs: number): Promise<ArrayBuffer | undefined> {
  const request = http.createHttp();
  try {
    const response = await request.request(FRAME_URL, {
      method: http.RequestMethod.GET,
      expectDataType: http.HttpDataType.ARRAY_BUFFER,
      connectTimeout: timeoutMs,
      readTimeout: timeoutMs,
      usingCache: false
    });
    if (response.responseCode === HTTP_OK && response.result instanceof ArrayBuffer) {
      return response.result as ArrayBuffer;
    }
    return undefined;
  } catch (error) {
    return undefined;
  } finally {
    request.destroy();
  }
}

async function readOrientation(source: image.ImageSource): Promise<number> {
  try {
    return orientationDegrees(await source.getImageProperty(image.PropertyKey.ORIENTATION));
  } catch (error) {
    return 0;
  }
}

async function decodeSquare(encoded: ArrayBuffer): Promise<PaddedFrame | undefined> {
  const source = image.createImageSource(encoded);
  try {
    const info = await source.getImageInfo();
    const decoded = await source.createPixelMap({
      desiredSize: fitWithin(info.size.width, info.size.height, MAX_SIDE),
      desiredPixelFormat: image.PixelMapFormat.RGBA_8888
    });
    const rotation = await readOrientation(source);
    if (rotation !== 0) {
      await decoded.rotate(rotation);
    }
    const decodedInfo = await decoded.getImageInfo();
    const width = decodedInfo.size.width;
    const height = decodedInfo.size.height;
    const buffer = new ArrayBuffer(decoded.getPixelBytesNumber());
    await decoded.readPixelsToBuffer(buffer);
    decoded.release();
    const square = padToSquare(new Uint8Array(buffer), width, height, buffer.byteLength / height);
    const frame: PaddedFrame = { bytes: square.buffer as ArrayBuffer, side: squareLayout(width, height).side };
    return frame;
  } catch (error) {
    log(`injected frame decode failed ${describeError(error)}`);
    return undefined;
  } finally {
    await source.release();
  }
}

function toPixelMap(frame: PaddedFrame): Promise<image.PixelMap> {
  return image.createPixelMap(frame.bytes.slice(0), {
    size: { width: frame.side, height: frame.side },
    srcPixelFormat: image.PixelMapFormat.RGBA_8888,
    pixelFormat: image.PixelMapFormat.RGBA_8888,
    editable: true
  });
}

export class InjectedFrameSource implements FrameInjector {
  private handler?: FrameHandler;
  private previewListener?: PreviewListener;
  private gate: FrameGate = new FrameGate();
  private active: boolean = false;
  private generation: number = 0;
  private requests: FrameRequest[] = [];
  private previews: image.PixelMap[] = [];

  async isReachable(): Promise<boolean> {
    return (await fetchFrame(PROBE_TIMEOUT_MS)) !== undefined;
  }

  setFrameHandler(handler: FrameHandler | undefined, minIntervalMs: number): void {
    this.handler = handler;
    this.gate.setInterval(minIntervalMs);
  }

  setPreviewListener(listener: PreviewListener | undefined): void {
    this.previewListener = listener;
  }

  async start(context: common.UIAbilityContext, surfaceId: string): Promise<boolean> {
    if (!this.active) {
      this.active = true;
      this.generation++;
      this.run(this.generation);
      log('injected frames started');
    }
    return true;
  }

  async stop(): Promise<void> {
    if (!this.active) {
      return;
    }
    this.active = false;
    this.generation++;
    if (this.previewListener !== undefined) {
      this.previewListener(undefined);
    }
    this.previews.forEach((preview: image.PixelMap) => preview.release());
    this.previews = [];
    log('injected frames stopped');
  }

  async switchPosition(context: common.UIAbilityContext, surfaceId: string): Promise<boolean> {
    return false;
  }

  nextFrame(): Promise<image.PixelMap> {
    return new Promise((resolve: FrameRequest) => {
      this.requests.push(resolve);
    });
  }

  isActive(): boolean {
    return this.active;
  }

  isFront(): boolean {
    return false;
  }

  canSwitch(): boolean {
    return false;
  }

  frameRotation(): number {
    return 0;
  }

  previewMirrored(): boolean {
    return false;
  }

  previewOnSurface(): boolean {
    return false;
  }

  private current(generation: number): boolean {
    return this.active && generation === this.generation;
  }

  private async run(generation: number): Promise<void> {
    while (this.current(generation)) {
      const encoded = await fetchFrame(FETCH_TIMEOUT_MS);
      if (encoded === undefined) {
        await sleep(RETRY_INTERVAL_MS);
        continue;
      }
      const frame = await decodeSquare(encoded);
      if (frame !== undefined && this.current(generation)) {
        await this.deliver(frame);
      }
      await sleep(POLL_INTERVAL_MS);
    }
  }

  private async deliver(frame: PaddedFrame): Promise<void> {
    try {
      await this.showPreview(frame);
      const requests = this.requests;
      this.requests = [];
      for (const request of requests) {
        request(await toPixelMap(frame));
      }
      if (this.handler !== undefined && this.gate.tryTake(Date.now())) {
        this.handle(this.handler, frame);
      }
    } catch (error) {
      log(`injected frame delivery failed ${describeError(error)}`);
    }
  }

  private async handle(handler: FrameHandler, frame: PaddedFrame): Promise<void> {
    try {
      const pixelMap = await toPixelMap(frame);
      await handler(pixelMap);
      pixelMap.release();
    } catch (error) {
      log(`injected frame handling failed ${describeError(error)}`);
    }
    this.gate.release();
  }

  private async showPreview(frame: PaddedFrame): Promise<void> {
    const listener = this.previewListener;
    if (listener === undefined) {
      return;
    }
    const preview = await toPixelMap(frame);
    listener(preview);
    this.previews.push(preview);
    while (this.previews.length > PREVIEWS_KEPT) {
      const old = this.previews.shift();
      old?.release();
    }
  }
}

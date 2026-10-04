import { camera } from '@kit.CameraKit';
import { choosePreviewProfile, isYuv } from './PreviewProfile';
import { nv21ToRgba } from './Nv21';
import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { BACK_FRAME_ROTATION, FRONT_FRAME_ROTATION, FRONT_PREVIEW_MIRRORED } from '../common/Config';
import { describeError, log } from '../common/Logger';
import { FrameGate } from './FrameGate';
import { FrameHandler, FrameSource, PreviewListener } from './FrameSource';

const RECEIVER_CAPACITY: number = 4;
const BYTES_PER_PIXEL: number = 4;
const YUV_PLANES_FACTOR: number = 1.5;

export class CameraSource implements FrameSource {
  private manager?: camera.CameraManager;
  private input?: camera.CameraInput;
  private previewOutput?: camera.PreviewOutput;
  private frameOutput?: camera.PreviewOutput;
  private session?: camera.PhotoSession;
  private receiver?: image.ImageReceiver;
  private handler?: FrameHandler;
  private gate: FrameGate = new FrameGate();
  private yuvFrames: boolean = false;
  private active: boolean = false;
  private frameRequest?: (frame: image.PixelMap) => void;
  private position: camera.CameraPosition = camera.CameraPosition.CAMERA_POSITION_BACK;
  private positions: camera.CameraPosition[] = [];
  private queue: Promise<boolean> = Promise.resolve(true);

  setFrameHandler(handler: FrameHandler | undefined, minIntervalMs: number): void {
    this.handler = handler;
    this.gate.setInterval(minIntervalMs);
  }

  setPreviewListener(listener: PreviewListener | undefined): void {
  }

  previewOnSurface(): boolean {
    return true;
  }

  start(context: common.UIAbilityContext, surfaceId: string): Promise<boolean> {
    return this.enqueue(() => this.open(context, surfaceId));
  }

  stop(): Promise<void> {
    return this.enqueue(async () => {
      await this.close();
      return true;
    }).then(() => undefined);
  }

  switchPosition(context: common.UIAbilityContext, surfaceId: string): Promise<boolean> {
    return this.enqueue(async () => {
      const previous = this.position;
      await this.close();
      this.position = this.isFront() ? camera.CameraPosition.CAMERA_POSITION_BACK :
        camera.CameraPosition.CAMERA_POSITION_FRONT;
      if (await this.open(context, surfaceId)) {
        return true;
      }
      this.position = previous;
      await this.open(context, surfaceId);
      return false;
    });
  }

  isFront(): boolean {
    return this.position === camera.CameraPosition.CAMERA_POSITION_FRONT;
  }

  canSwitch(): boolean {
    return this.positions.includes(camera.CameraPosition.CAMERA_POSITION_BACK) &&
      this.positions.includes(camera.CameraPosition.CAMERA_POSITION_FRONT);
  }

  frameRotation(): number {
    return this.isFront() ? FRONT_FRAME_ROTATION : BACK_FRAME_ROTATION;
  }

  previewMirrored(): boolean {
    return this.isFront() && FRONT_PREVIEW_MIRRORED;
  }

  private enqueue(task: () => Promise<boolean>): Promise<boolean> {
    const next = this.queue.then(() => task());
    this.queue = next.catch(() => false);
    return next;
  }

  private async open(context: common.UIAbilityContext, surfaceId: string): Promise<boolean> {
    if (this.session) {
      return true;
    }
    try {
      this.manager = camera.getCameraManager(context);
      const devices = this.manager.getSupportedCameras();
      this.positions = devices.map((d: camera.CameraDevice) => d.cameraPosition);
      let device = devices.find((d: camera.CameraDevice) => d.cameraPosition === this.position);
      if (!device) {
        device = devices[0];
        this.position = device.cameraPosition;
      }
      const capability = this.manager.getSupportedOutputCapability(device, camera.SceneMode.NORMAL_PHOTO);
      const profile = choosePreviewProfile(capability.previewProfiles);
      this.yuvFrames = isYuv(profile);
      log(`preview profiles ${capability.previewProfiles.map((p: camera.Profile) => `${p.size.width}x${p.size.height}/f${p.format}`).join(' ')}; chosen ${profile.size.width}x${profile.size.height}/f${profile.format}`);
      this.input = this.manager.createCameraInput(device);
      await this.input.open();
      this.previewOutput = this.manager.createPreviewOutput(profile, surfaceId);
      this.receiver = image.createImageReceiver(profile.size, image.ImageFormat.JPEG, RECEIVER_CAPACITY);
      const receiverSurface = await this.receiver.getReceivingSurfaceId();
      this.frameOutput = this.manager.createPreviewOutput(profile, receiverSurface);
      this.receiver.on('imageArrival', () => {
        this.readFrame(profile.size.width, profile.size.height);
      });
      this.session = this.manager.createSession(camera.SceneMode.NORMAL_PHOTO) as camera.PhotoSession;
      this.session.on('error', (error: BusinessError) => {
        log(`camera session error ${describeError(error)}`);
      });
      this.session.beginConfig();
      this.session.addInput(this.input);
      this.session.addOutput(this.previewOutput);
      this.session.addOutput(this.frameOutput);
      await this.session.commitConfig();
      await this.session.start();
      this.active = true;
      log(`camera ${device.cameraId} started, position ${device.cameraPosition}, orientation ${device.cameraOrientation}, preview ${profile.size.width}x${profile.size.height}`);
      return true;
    } catch (error) {
      log(`camera start failed ${describeError(error)}`);
      await this.close();
      return false;
    }
  }

  nextFrame(): Promise<image.PixelMap> {
    return new Promise((resolve: (frame: image.PixelMap) => void) => {
      this.frameRequest = resolve;
    });
  }

  private readFrame(width: number, height: number): void {
    const receiver = this.receiver;
    if (!receiver) {
      return;
    }
    receiver.readNextImage().then(async (frame: image.Image) => {
      const requested = this.frameRequest;
      if (requested !== undefined) {
        this.frameRequest = undefined;
        try {
          requested(await this.toPixelMap(frame, width, height));
        } catch (error) {
          log(`requested frame failed ${describeError(error)}`);
        }
        frame.release();
        return;
      }
      if (this.handler !== undefined && this.gate.tryTake(Date.now())) {
        try {
          const pixelMap = await this.toPixelMap(frame, width, height);
          await (this.handler as FrameHandler)(pixelMap);
          pixelMap.release();
        } catch (error) {
          log(`frame handling failed ${describeError(error)}`);
        }
        this.gate.release();
      }
      frame.release();
    }).catch((error: BusinessError) => {
      log(`readNextImage failed ${describeError(error)}`);
    });
  }

  private async toPixelMap(frame: image.Image, width: number, height: number): Promise<image.PixelMap> {
    const component = await frame.getComponent(image.ComponentType.JPEG);
    if (this.yuvFrames) {
      return this.yuvToPixelMap(component, width, height);
    }
    const stride = component.rowStride > 0 ? component.rowStride / BYTES_PER_PIXEL : width;
    const options: image.InitializationOptions = {
      size: { width: stride, height: height },
      srcPixelFormat: image.PixelMapFormat.RGBA_8888,
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      editable: true
    };
    const bytes = component.byteBuffer.slice(0, stride * height * BYTES_PER_PIXEL);
    const pixelMap = await image.createPixelMap(bytes, options);
    if (stride !== width) {
      await pixelMap.crop({ x: 0, y: 0, size: { width: width, height: height } });
    }
    return pixelMap;
  }

  private async yuvToPixelMap(component: image.Component, width: number, height: number): Promise<image.PixelMap> {
    if (component === null || component === undefined || !component.byteBuffer) {
      throw new Error(`empty YUV component ${component === null || component === undefined ? 'missing' : 'without buffer'}`);
    }
    const stride = component.rowStride > 0 ? component.rowStride : width;
    const rgba = nv21ToRgba(new Uint8Array(component.byteBuffer), width, height, stride);
    const options: image.InitializationOptions = {
      size: { width: width, height: height },
      srcPixelFormat: image.PixelMapFormat.RGBA_8888,
      pixelFormat: image.PixelMapFormat.RGBA_8888,
      editable: true
    };
    const pixelMap = await image.createPixelMap(rgba, options);
    return pixelMap;
  }

  isActive(): boolean {
    return this.active;
  }

  private async close(): Promise<void> {
    this.active = false;
    try {
      await this.session?.stop();
      await this.session?.release();
    } catch (error) {
      log(`session release failed ${describeError(error)}`);
    }
    try {
      await this.input?.close();
    } catch (error) {
      log(`input close failed ${describeError(error)}`);
    }
    try {
      await this.receiver?.release();
    } catch (error) {
      log(`receiver release failed ${describeError(error)}`);
    }
    this.session = undefined;
    this.input = undefined;
    this.previewOutput = undefined;
    this.frameOutput = undefined;
    this.receiver = undefined;
  }
}

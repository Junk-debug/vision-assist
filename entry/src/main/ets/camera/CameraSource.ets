import { camera } from '@kit.CameraKit';
import { image } from '@kit.ImageKit';
import { common } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { describeError, log } from '../common/Logger';

const RECEIVER_CAPACITY: number = 4;
const BYTES_PER_PIXEL: number = 4;

export type FrameHandler = (frame: image.PixelMap) => Promise<void>;

export class CameraSource {
  private manager?: camera.CameraManager;
  private input?: camera.CameraInput;
  private previewOutput?: camera.PreviewOutput;
  private frameOutput?: camera.PreviewOutput;
  private session?: camera.PhotoSession;
  private receiver?: image.ImageReceiver;
  private handler?: FrameHandler;
  private busy: boolean = false;
  private lastFrameAt: number = 0;
  private minIntervalMs: number = 0;
  private active: boolean = false;

  setFrameHandler(handler: FrameHandler | undefined, minIntervalMs: number): void {
    this.handler = handler;
    this.minIntervalMs = minIntervalMs;
  }

  async start(context: common.UIAbilityContext, surfaceId: string): Promise<boolean> {
    if (this.session) {
      return true;
    }
    try {
      this.manager = camera.getCameraManager(context);
      const devices = this.manager.getSupportedCameras();
      let device = devices.find((d: camera.CameraDevice) => d.cameraPosition === camera.CameraPosition.CAMERA_POSITION_BACK);
      if (!device) {
        device = devices[0];
      }
      const capability = this.manager.getSupportedOutputCapability(device, camera.SceneMode.NORMAL_PHOTO);
      const profile = capability.previewProfiles[0];
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
      log(`camera started, preview ${profile.size.width}x${profile.size.height}`);
      return true;
    } catch (error) {
      log(`camera start failed ${describeError(error)}`);
      await this.stop();
      return false;
    }
  }

  private readFrame(width: number, height: number): void {
    const receiver = this.receiver;
    if (!receiver) {
      return;
    }
    receiver.readNextImage().then(async (frame: image.Image) => {
      const now = Date.now();
      const wanted = this.handler !== undefined && !this.busy && now - this.lastFrameAt >= this.minIntervalMs;
      if (wanted) {
        this.busy = true;
        this.lastFrameAt = now;
        try {
          const pixelMap = await this.toPixelMap(frame, width, height);
          await (this.handler as FrameHandler)(pixelMap);
          pixelMap.release();
        } catch (error) {
          log(`frame handling failed ${describeError(error)}`);
        }
        this.busy = false;
      }
      frame.release();
    }).catch((error: BusinessError) => {
      log(`readNextImage failed ${describeError(error)}`);
    });
  }

  private async toPixelMap(frame: image.Image, width: number, height: number): Promise<image.PixelMap> {
    const component = await frame.getComponent(image.ComponentType.JPEG);
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

  isActive(): boolean {
    return this.active;
  }

  async stop(): Promise<void> {
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

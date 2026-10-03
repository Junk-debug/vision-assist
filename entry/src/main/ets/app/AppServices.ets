import { abilityAccessCtrl, common, Permissions } from '@kit.AbilityKit';
import { CameraSource } from '../camera/CameraSource';
import { describeError, log } from '../common/Logger';
import { Narrator } from '../speech/Narrator';
import { YoloDetector } from '../vision/YoloDetector';
import { PaddleTextRecognizer } from '../vision/text/PaddleTextRecognizer';
import { SystemTextRecognizer } from '../vision/text/SystemTextRecognizer';
import { TextReader } from '../vision/text/TextReader';

const CAMERA_PERMISSION: Permissions = 'ohos.permission.CAMERA';

export class AppServices {
  readonly camera: CameraSource = new CameraSource();
  readonly detector: YoloDetector = new YoloDetector();
  readonly narrator: Narrator = new Narrator();
  readonly textReader: TextReader = new TextReader();
  private loading?: Promise<void>;

  init(context: common.UIAbilityContext): Promise<void> {
    if (this.loading === undefined) {
      this.loading = this.load(context);
    }
    return this.loading;
  }

  private async load(context: common.UIAbilityContext): Promise<void> {
    this.textReader.add(new SystemTextRecognizer());
    this.textReader.add(new PaddleTextRecognizer(context));
    this.textReader.prepare();
    await this.narrator.init();
    try {
      await this.detector.load(context);
    } catch (error) {
      log(`model load failed ${describeError(error)}`);
    }
  }

  async ensureCameraPermission(context: common.UIAbilityContext): Promise<boolean> {
    const manager = abilityAccessCtrl.createAtManager();
    try {
      const status = await manager.checkAccessToken(context.applicationInfo.accessTokenId, CAMERA_PERMISSION);
      if (status === abilityAccessCtrl.GrantStatus.PERMISSION_GRANTED) {
        return true;
      }
      const result = await manager.requestPermissionsFromUser(context, [CAMERA_PERMISSION]);
      return result.authResults[0] === 0;
    } catch (error) {
      log(`camera permission failed ${describeError(error)}`);
      return false;
    }
  }

  release(): void {
    this.camera.stop();
    this.textReader.release();
    this.narrator.release();
  }
}

export const appServices: AppServices = new AppServices();

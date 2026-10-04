import { image } from '@kit.ImageKit';
import { EnginePolicy } from './EnginePolicy';
import { EngineRunner, SystemTimer } from './EngineRunner';
import { MAX_ENGINE_FAILURES } from './TextEngineConfig';
import { describeError, log } from '../../common/Logger';

export class TextReader extends EngineRunner<image.PixelMap> {
  constructor() {
    super(new EnginePolicy(MAX_ENGINE_FAILURES), {
      timer: new SystemTimer(),
      log: (message: string) => log(message),
      describe: (error: Object) => describeError(error)
    });
  }
}

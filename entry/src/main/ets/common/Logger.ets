import { hilog } from '@kit.PerformanceAnalysisKit';
import { BusinessError } from '@kit.BasicServicesKit';

const TAG: string = 'VisionAssist';
const DOMAIN: number = 0x0001;

export function log(message: string): void {
  hilog.info(DOMAIN, TAG, '%{public}s', message);
}

export function describeError(error: Object): string {
  const businessError = error as BusinessError;
  const stack = (error as Error).stack ?? '';
  return `code=${businessError.code} message=${businessError.message} ${stack.split('\n').slice(0, 3).join(' | ')}`;
}

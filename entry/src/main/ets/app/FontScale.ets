import { Configuration } from '@kit.AbilityKit';

export const FONT_SCALE_KEY: string = 'fontScale';

export function publishFontScale(config: Configuration): void {
  const scale = config.fontSizeScale;
  AppStorage.setOrCreate<number>(FONT_SCALE_KEY, scale !== undefined ? scale : 1);
}

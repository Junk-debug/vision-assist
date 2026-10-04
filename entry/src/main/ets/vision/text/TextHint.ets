import { Messages } from '../../common/Messages';
import { TEXT_HINT_MAX_WORDS } from '../../common/Config';

export function textHintFor(text: string | undefined, maxWords: number = TEXT_HINT_MAX_WORDS): string {
  if (text === undefined) {
    return '';
  }
  const trimmed = text.trim().replace(/\s+/g, ' ');
  if (trimmed === '') {
    return '';
  }
  const words = trimmed.split(' ').length;
  return words <= maxWords ? Messages.textAheadShort(trimmed) : Messages.TEXT_AHEAD_LONG;
}

export function describeWithText(scene: string, hint: string): string {
  if (hint === '') {
    return scene;
  }
  return scene === '' ? hint : `${scene} ${hint}`;
}

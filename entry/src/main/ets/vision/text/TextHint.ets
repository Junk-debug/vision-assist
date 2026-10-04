import { Messages } from '../../common/Messages';
import { TEXT_HINT_MAX_WORDS } from '../../common/Config';
import { splitIntoChunks } from '../../speech/TextChunks';

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

export function normalizeText(text: string | undefined): string {
  return text === undefined ? '' : text.trim().replace(/\s+/g, ' ');
}

export class DescribePlan {
  readonly sentence: string;
  readonly readChunks: string[];

  constructor(sentence: string, readChunks: string[]) {
    this.sentence = sentence;
    this.readChunks = readChunks;
  }
}

export function planDescription(scene: string, text: string | undefined, maxWords: number = TEXT_HINT_MAX_WORDS): DescribePlan {
  const hint = textHintFor(text, maxWords);
  const sentence = describeWithText(scene, hint);
  if (hint !== Messages.TEXT_AHEAD_LONG) {
    return new DescribePlan(sentence, []);
  }
  return new DescribePlan(sentence, [sentence, ...splitIntoChunks(text ?? '')]);
}

export function liveTextPhrase(centerX: number): string {
  const position = centerX < 0.35 ? Messages.ON_THE_LEFT : (centerX > 0.65 ? Messages.ON_THE_RIGHT : Messages.AHEAD);
  return Messages.textLive(position);
}

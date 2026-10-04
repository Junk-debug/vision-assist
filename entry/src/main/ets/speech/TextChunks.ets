import { splitLines } from '../vision/text/TextSummary';

const TARGET_CHARS: number = 160;
const MAX_CHARS: number = 240;
const PROSE_LINE_CHARS: number = 25;
const SENTENCE_END: RegExp = /[.!?:;]["')\]]*$/;
const SENTENCE: RegExp = /\S.*?(?:[.!?;:]+["')\]]*(?=\s)|$)/g;
const LOWER_START: RegExp = /^[a-z]/;

function sentencesOf(line: string): string[] {
  const found = line.match(SENTENCE);
  if (found === null) {
    return [line];
  }
  return found.map((sentence: string) => sentence.trim()).filter((sentence: string) => sentence.length > 0);
}

function splitAtSpaces(text: string): string[] {
  const pieces: string[] = [];
  let rest = text;
  while (rest.length > MAX_CHARS) {
    const cut = rest.lastIndexOf(' ', TARGET_CHARS);
    const at = cut > 0 ? cut : TARGET_CHARS;
    pieces.push(rest.substring(0, at).trim());
    rest = rest.substring(at).trim();
  }
  if (rest.length > 0) {
    pieces.push(rest);
  }
  return pieces;
}

function splitLong(line: string): string[] {
  if (line.length <= MAX_CHARS) {
    return [line];
  }
  const pieces: string[] = [];
  let current = '';
  for (const sentence of sentencesOf(line)) {
    const joined = current === '' ? sentence : `${current} ${sentence}`;
    if (joined.length <= TARGET_CHARS) {
      current = joined;
      continue;
    }
    if (current !== '') {
      pieces.push(current);
    }
    const parts = splitAtSpaces(sentence);
    current = parts[parts.length - 1];
    for (let index = 0; index < parts.length - 1; index++) {
      pieces.push(parts[index]);
    }
  }
  if (current !== '') {
    pieces.push(current);
  }
  return pieces;
}

function continues(previous: string, next: string): boolean {
  if (previous.length >= TARGET_CHARS || SENTENCE_END.test(previous) || previous.length + next.length + 1 > MAX_CHARS) {
    return false;
  }
  return LOWER_START.test(next) || previous.length >= PROSE_LINE_CHARS;
}

export function splitIntoChunks(text: string): string[] {
  const chunks: string[] = [];
  let current = '';
  for (const line of splitLines(text)) {
    for (const piece of splitLong(line)) {
      if (current !== '' && continues(current, piece)) {
        current = `${current} ${piece}`;
        continue;
      }
      if (current !== '') {
        chunks.push(current);
      }
      current = piece;
    }
  }
  if (current !== '') {
    chunks.push(current);
  }
  return chunks;
}

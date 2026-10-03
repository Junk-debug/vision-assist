import { NormalizedBox } from '../DetectionTypes';
import { TextWordResult } from './TextTypes';

const MIN_FUZZY_LENGTH: number = 4;
const EXACT_SCORE: number = 1;
const TYPO_SCORE: number = 0.9;
const CONTAINS_SCORE: number = 0.8;

export interface WordMatch extends NormalizedBox {
  text: string;
  score: number;
}

interface Token {
  text: string;
  wordIndex: number;
}

function isLetterOrDigit(char: string): boolean {
  return char.toLowerCase() !== char.toUpperCase() || (char >= '0' && char <= '9');
}

export function splitWords(text: string): string[] {
  const words: string[] = [];
  let current = '';
  const lower = text.toLowerCase();
  for (let i = 0; i < lower.length; i++) {
    const char = lower.charAt(i);
    if (isLetterOrDigit(char)) {
      current += char;
    } else if (current.length > 0) {
      words.push(current);
      current = '';
    }
  }
  if (current.length > 0) {
    words.push(current);
  }
  return words;
}

export function withinOneEdit(a: string, b: string): boolean {
  if (Math.abs(a.length - b.length) > 1) {
    return false;
  }
  const longer = a.length >= b.length ? a : b;
  const shorter = a.length >= b.length ? b : a;
  let start = 0;
  while (start < shorter.length && longer.charAt(start) === shorter.charAt(start)) {
    start++;
  }
  if (start === shorter.length) {
    return true;
  }
  if (longer.length === shorter.length) {
    return longer.substring(start + 1) === shorter.substring(start + 1);
  }
  return longer.substring(start + 1) === shorter.substring(start);
}

function tokenScore(token: string, target: string): number {
  if (token === target) {
    return EXACT_SCORE;
  }
  if (target.length < MIN_FUZZY_LENGTH) {
    return 0;
  }
  if (withinOneEdit(token, target)) {
    return TYPO_SCORE;
  }
  if (token.length >= MIN_FUZZY_LENGTH && (token.includes(target) || target.includes(token))) {
    return CONTAINS_SCORE;
  }
  return 0;
}

function tokenize(words: TextWordResult[]): Token[] {
  const tokens: Token[] = [];
  for (let i = 0; i < words.length; i++) {
    for (const text of splitWords(words[i].text)) {
      tokens.push({ text: text, wordIndex: i });
    }
  }
  return tokens;
}

function matchAt(tokens: Token[], start: number, targets: string[]): number {
  let total = 0;
  for (let i = 0; i < targets.length; i++) {
    const score = tokenScore(tokens[start + i].text, targets[i]);
    if (score === 0) {
      return 0;
    }
    total += score;
  }
  return total / targets.length;
}

function mergeBoxes(words: TextWordResult[], first: number, last: number): NormalizedBox {
  let x1 = 1;
  let y1 = 1;
  let x2 = 0;
  let y2 = 0;
  for (let i = first; i <= last; i++) {
    x1 = Math.min(x1, words[i].x1);
    y1 = Math.min(y1, words[i].y1);
    x2 = Math.max(x2, words[i].x2);
    y2 = Math.max(y2, words[i].y2);
  }
  return { x1: x1, y1: y1, x2: x2, y2: y2 };
}

export function findWord(words: TextWordResult[], target: string): WordMatch | undefined {
  const targets = splitWords(target);
  const tokens = tokenize(words);
  if (targets.length === 0) {
    return undefined;
  }
  let bestScore = 0;
  let bestStart = -1;
  for (let start = 0; start + targets.length <= tokens.length; start++) {
    const score = matchAt(tokens, start, targets);
    if (score > bestScore) {
      bestScore = score;
      bestStart = start;
    }
  }
  if (bestStart < 0) {
    return undefined;
  }
  const first = tokens[bestStart].wordIndex;
  const last = tokens[bestStart + targets.length - 1].wordIndex;
  const box = mergeBoxes(words, first, last);
  return { text: words[first].text, score: bestScore, x1: box.x1, y1: box.y1, x2: box.x2, y2: box.y2 };
}

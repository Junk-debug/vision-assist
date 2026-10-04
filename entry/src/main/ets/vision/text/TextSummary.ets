import { Messages } from '../../common/Messages';

const PREVIEW_CHARS: number = 60;

export function splitLines(text: string): string[] {
  return text.split(/\r?\n/).map((line: string) => line.trim()).filter((line: string) => line.length > 0);
}

export function previewOf(line: string, maxChars: number = PREVIEW_CHARS): string {
  if (line.length <= maxChars) {
    return line;
  }
  const cut = line.substring(0, maxChars);
  const space = cut.lastIndexOf(' ');
  return `${(space > maxChars / 2 ? cut.substring(0, space) : cut).trim()}…`;
}

export function summarizeText(text: string): string {
  const lines = splitLines(text);
  if (lines.length === 0) {
    return '';
  }
  return Messages.textSummary(lines.length, previewOf(lines[0]));
}

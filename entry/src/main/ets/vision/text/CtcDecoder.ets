export interface DecodedText {
  text: string;
  confidence: number;
}

export function buildCharset(dictionary: string): string[] {
  const lines = dictionary.split('\n');
  if (lines.length > 0 && lines[lines.length - 1] === '') {
    lines.pop();
  }
  const charset: string[] = [''];
  for (const line of lines) {
    charset.push(line);
  }
  charset.push(' ');
  return charset;
}

export function decodeGreedy(probabilities: Float32Array, steps: number, classes: number, charset: string[]): DecodedText {
  let text = '';
  let previous = -1;
  let confidenceSum = 0;
  let emitted = 0;
  for (let t = 0; t < steps; t++) {
    let best = 0;
    let bestValue = probabilities[t * classes];
    for (let c = 1; c < classes; c++) {
      const value = probabilities[t * classes + c];
      if (value > bestValue) {
        bestValue = value;
        best = c;
      }
    }
    if (best !== 0 && best !== previous && best < charset.length) {
      text += charset[best];
      confidenceSum += bestValue;
      emitted++;
    }
    previous = best;
  }
  return { text: text, confidence: emitted === 0 ? 0 : confidenceSum / emitted };
}

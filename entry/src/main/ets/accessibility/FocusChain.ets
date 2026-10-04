export function nextInChain(chain: string[], id: string): string {
  const index = chain.indexOf(id);
  if (index < 0 || index === chain.length - 1) {
    return '';
  }
  return chain[index + 1];
}

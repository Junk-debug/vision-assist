export interface ChunkSpeaker {
  speakChunk(text: string, done: () => void): void;
  cancelChunk(): void;
}

export type ReadingListener = (index: number) => void;

export class ReadAloud {
  private readonly speaker: ChunkSpeaker;
  private readonly listeners: ReadingListener[] = [];
  private chunks: string[] = [];
  private index: number = -1;
  private generation: number = 0;

  constructor(speaker: ChunkSpeaker) {
    this.speaker = speaker;
  }

  addListener(listener: ReadingListener): void {
    if (this.listeners.indexOf(listener) < 0) {
      this.listeners.push(listener);
    }
  }

  removeListener(listener: ReadingListener): void {
    const at = this.listeners.indexOf(listener);
    if (at >= 0) {
      this.listeners.splice(at, 1);
    }
  }

  isReading(): boolean {
    return this.index >= 0;
  }

  currentIndex(): number {
    return this.index;
  }

  currentChunks(): string[] {
    return this.chunks;
  }

  start(chunks: string[]): void {
    this.stop();
    if (chunks.length === 0) {
      return;
    }
    this.chunks = chunks;
    this.speakAt(0, this.generation);
  }

  stop(): boolean {
    if (this.index < 0) {
      return false;
    }
    this.generation++;
    this.index = -1;
    this.speaker.cancelChunk();
    this.notifyEnd();
    return true;
  }

  private speakAt(index: number, generation: number): void {
    this.index = index;
    this.listeners.slice().forEach((listener: ReadingListener) => listener(index));
    this.speaker.speakChunk(this.chunks[index], () => {
      this.onChunkDone(index, generation);
    });
  }

  private onChunkDone(index: number, generation: number): void {
    if (generation !== this.generation || index !== this.index) {
      return;
    }
    if (index + 1 < this.chunks.length) {
      this.speakAt(index + 1, generation);
      return;
    }
    this.generation++;
    this.index = -1;
    this.notifyEnd();
  }

  private notifyEnd(): void {
    this.listeners.slice().forEach((listener: ReadingListener) => listener(-1));
  }
}

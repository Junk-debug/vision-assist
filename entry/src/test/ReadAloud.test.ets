import { describe, it, expect } from '@ohos/hypium';
import { ChunkSpeaker, ReadAloud } from '../main/ets/speech/ReadAloud';
import { splitIntoChunks } from '../main/ets/speech/TextChunks';
import { screenReaderChunkMs } from '../main/ets/speech/Narrator';

class FakeSpeaker implements ChunkSpeaker {
  spoken: string[] = [];
  cancels: number = 0;
  private pending: (() => void)[] = [];

  speakChunk(text: string, done: () => void): void {
    this.spoken.push(text);
    this.pending.push(done);
  }

  cancelChunk(): void {
    this.cancels++;
  }

  finishOldest(): void {
    const done = this.pending.shift();
    if (done !== undefined) {
      done();
    }
  }
}

export default function readAloudTest() {
  describe('readAloud', () => {
    it('keepsShortLinesAsTheirOwnChunks', 0, () => {
      expect(splitIntoChunks('EXIT\nPush bar')).assertDeepEquals(['EXIT', 'Push bar']);
      expect(splitIntoChunks('  \n')).assertDeepEquals([]);
    });
    it('joinsWrappedProseIntoSentences', 0, () => {
      const text = 'Dear Anna, your appointment is on\nMonday at 10:00.\nPlease bring your ID to the\nreception desk.';
      expect(splitIntoChunks(text)).assertDeepEquals([
        'Dear Anna, your appointment is on Monday at 10:00.',
        'Please bring your ID to the reception desk.'
      ]);
    });
    it('splitsALongLineAtSentencesWithoutLosingWords', 0, () => {
      const sentence = 'This sentence has exactly enough words to be long enough for testing.';
      const line = `${sentence} ${sentence} ${sentence} ${sentence}`;
      const chunks = splitIntoChunks(line);
      expect(chunks.length > 1).assertTrue();
      expect(chunks.every((chunk: string) => chunk.length <= 240)).assertTrue();
      expect(chunks.join(' ')).assertEqual(line);
    });
    it('splitsAVeryLongSentenceAtSpaces', 0, () => {
      const words: string[] = [];
      for (let index = 0; index < 120; index++) {
        words.push(`word${index}`);
      }
      const line = words.join(' ');
      const chunks = splitIntoChunks(line);
      expect(chunks.every((chunk: string) => chunk.length <= 240)).assertTrue();
      expect(chunks.join(' ')).assertEqual(line);
    });
    it('readsChunksOneAfterAnother', 0, () => {
      const speaker = new FakeSpeaker();
      const reader = new ReadAloud(speaker);
      const seen: number[] = [];
      reader.addListener((index: number) => {
        seen.push(index);
      });
      reader.start(['one', 'two']);
      expect(speaker.spoken).assertDeepEquals(['one']);
      expect(reader.isReading()).assertTrue();
      speaker.finishOldest();
      expect(speaker.spoken).assertDeepEquals(['one', 'two']);
      speaker.finishOldest();
      expect(reader.isReading()).assertFalse();
      expect(seen).assertDeepEquals([0, 1, -1]);
    });
    it('stopsWithoutQueueingMore', 0, () => {
      const speaker = new FakeSpeaker();
      const reader = new ReadAloud(speaker);
      reader.start(['one', 'two', 'three']);
      expect(reader.stop()).assertTrue();
      expect(speaker.cancels).assertEqual(1);
      speaker.finishOldest();
      expect(speaker.spoken).assertDeepEquals(['one']);
      expect(reader.isReading()).assertFalse();
      expect(reader.stop()).assertFalse();
    });
    it('ignoresALateDoneFromAnEarlierReading', 0, () => {
      const speaker = new FakeSpeaker();
      const reader = new ReadAloud(speaker);
      reader.start(['old one', 'old two']);
      reader.start(['new one', 'new two']);
      speaker.finishOldest();
      expect(speaker.spoken).assertDeepEquals(['old one', 'new one']);
      speaker.finishOldest();
      expect(speaker.spoken).assertDeepEquals(['old one', 'new one', 'new two']);
    });
    it('estimatesScreenReaderChunkTime', 0, () => {
      expect(screenReaderChunkMs('') > 0).assertTrue();
      expect(screenReaderChunkMs('a much longer sentence') > screenReaderChunkMs('short')).assertTrue();
    });
  });
}

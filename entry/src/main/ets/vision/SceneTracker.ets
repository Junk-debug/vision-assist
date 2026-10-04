import { Detection } from './DetectionTypes';
import { Messages } from '../common/Messages';

const APPEAR_FRAMES: number = 2;
const DISAPPEAR_FRAMES: number = 4;
const MIN_SPEECH_GAP_MS: number = 2500;
const MAX_ANNOUNCED_OBJECTS: number = 4;
const LEFT_LIMIT: number = 0.35;
const RIGHT_LIMIT: number = 0.65;
const PERSON_LABEL: string = 'person';
const WHOLE_PERSON_LABELS: string[] = ['person', 'man', 'woman', 'boy', 'girl'];
const FACE_LABEL: string = 'human face';
const SILENT_LABELS: string[] = ['clothing', 'footwear', 'fashion accessory'];

interface Track {
  streak: number;
  absent: number;
  best: Detection;
}

interface Group {
  count: number;
  best: Detection;
}

function groupForSpeech(detections: Detection[]): Map<string, Group> {
  const groups: Map<string, Group> = new Map();
  const wholePeople: Map<string, number> = new Map();
  let faces = 0;
  let personBest: Detection | undefined = undefined;
  for (const detection of detections) {
    const label = detection.label.toLowerCase();
    if (SILENT_LABELS.includes(label)) {
      continue;
    }
    if (WHOLE_PERSON_LABELS.includes(label) || label === FACE_LABEL) {
      if (label === FACE_LABEL) {
        faces++;
      } else {
        wholePeople.set(label, (wholePeople.get(label) ?? 0) + 1);
      }
      if (personBest === undefined || detection.score > personBest.score) {
        personBest = detection;
      }
      continue;
    }
    const group = groups.get(label);
    if (group === undefined) {
      groups.set(label, { count: 1, best: detection });
    } else {
      group.count++;
      if (detection.score > group.best.score) {
        group.best = detection;
      }
    }
  }
  if (personBest !== undefined) {
    const person = wholePeople.get(PERSON_LABEL) ?? 0;
    const gendered = (wholePeople.get('man') ?? 0) + (wholePeople.get('woman') ?? 0) +
      (wholePeople.get('boy') ?? 0) + (wholePeople.get('girl') ?? 0);
    groups.set(PERSON_LABEL, { count: Math.max(1, person, gendered, faces), best: personBest });
  }
  return groups;
}

function positionOf(detection: Detection): string {
  const center = (detection.x1 + detection.x2) / 2;
  if (center < LEFT_LIMIT) {
    return Messages.ON_THE_LEFT;
  }
  if (center > RIGHT_LIMIT) {
    return Messages.ON_THE_RIGHT;
  }
  return Messages.AHEAD;
}

function sentenceFor(labels: string[], groups: Map<string, Group>): string {
  const phrases: string[] = [];
  for (const label of labels.slice(0, MAX_ANNOUNCED_OBJECTS)) {
    const group = groups.get(label) as Group;
    phrases.push(Messages.objectAt(label, group.count, positionOf(group.best)));
  }
  return phrases.join(', ');
}

export function describeScene(detections: Detection[]): string {
  const groups = groupForSpeech(detections);
  const labels: string[] = [];
  groups.forEach((group: Group, label: string) => {
    labels.push(label);
  });
  labels.sort((a: string, b: string) => (groups.get(b) as Group).best.score - (groups.get(a) as Group).best.score);
  return sentenceFor(labels, groups);
}

export class SceneTracker {
  private tracks: Map<string, Track> = new Map();
  private lastSignature: string = '';
  private lastSpeechAt: number = 0;

  reset(): void {
    this.tracks.clear();
    this.lastSignature = '';
    this.lastSpeechAt = 0;
  }

  update(detections: Detection[], now: number): string | undefined {
    const groups = groupForSpeech(detections);
    const present: Map<string, Detection> = new Map();
    groups.forEach((group: Group, label: string) => {
      present.set(label, group.best);
    });
    present.forEach((best: Detection, label: string) => {
      const track = this.tracks.get(label);
      if (track === undefined) {
        this.tracks.set(label, { streak: 1, absent: 0, best: best });
      } else {
        track.streak++;
        track.absent = 0;
        track.best = best;
      }
    });
    this.tracks.forEach((track: Track, label: string) => {
      if (!present.has(label)) {
        track.absent++;
        track.streak = 0;
      }
    });
    const stale: string[] = [];
    this.tracks.forEach((track: Track, label: string) => {
      if (track.absent >= DISAPPEAR_FRAMES) {
        stale.push(label);
      }
    });
    for (const label of stale) {
      this.tracks.delete(label);
    }
    const active: string[] = [];
    this.tracks.forEach((track: Track, label: string) => {
      if (track.absent === 0 && track.streak >= APPEAR_FRAMES) {
        active.push(label);
      }
    });
    active.sort((a: string, b: string) => (this.tracks.get(b) as Track).best.score - (this.tracks.get(a) as Track).best.score);
    if (active.length === 0) {
      this.lastSignature = '';
      return undefined;
    }
    const signature = active.slice().sort().join('|');
    if (signature === this.lastSignature || now - this.lastSpeechAt < MIN_SPEECH_GAP_MS) {
      return undefined;
    }
    this.lastSignature = signature;
    this.lastSpeechAt = now;
    return sentenceFor(active, groups);
  }
}

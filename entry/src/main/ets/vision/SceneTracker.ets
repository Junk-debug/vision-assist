import { Detection } from './DetectionTypes';
import {
  DESCRIBE_MAX_OBJECTS,
  DESCRIBE_MIN_RELEVANCE,
  LIVE_APPEAR_FRAMES,
  LIVE_DISAPPEAR_FRAMES,
  LIVE_MAX_NEW_PER_SENTENCE,
  LIVE_SPEECH_GAP_MS
} from '../common/Config';
import { Messages } from '../common/Messages';

const LEFT_LIMIT: number = 0.35;
const RIGHT_LIMIT: number = 0.65;
const CENTER_BONUS: number = 0.4;
const PERSON_LABEL: string = 'person';
const WHOLE_PERSON_LABELS: string[] = ['person', 'man', 'woman', 'boy', 'girl'];
const FACE_LABEL: string = 'human face';
const SILENT_LABELS: string[] = [
  'clothing', 'footwear', 'fashion accessory', 'jeans', 'trousers', 'shirt', 'dress', 'jacket', 'coat', 'scarf', 'tie',
  'belt', 'glove', 'earrings', 'necklace', 'human body', 'human head', 'human arm', 'human hand', 'human leg',
  'human foot', 'human eye', 'human ear', 'human nose', 'human mouth', 'human hair', 'human beard'
];

export interface SceneGroup {
  label: string;
  count: number;
  best: Detection;
  relevance: number;
}

interface Track {
  streak: number;
  absent: number;
  confirmed: boolean;
  group: SceneGroup;
}

export interface LiveSceneConfig {
  appearFrames: number;
  disappearFrames: number;
  speechGapMs: number;
  maxNewPerSentence: number;
  minRelevance: number;
  maxObjects: number;
}

export const DEFAULT_LIVE_CONFIG: LiveSceneConfig = {
  appearFrames: LIVE_APPEAR_FRAMES,
  disappearFrames: LIVE_DISAPPEAR_FRAMES,
  speechGapMs: LIVE_SPEECH_GAP_MS,
  maxNewPerSentence: LIVE_MAX_NEW_PER_SENTENCE,
  minRelevance: DESCRIBE_MIN_RELEVANCE,
  maxObjects: DESCRIBE_MAX_OBJECTS
};

export function relevanceOf(detection: Detection): number {
  const width = Math.max(0, detection.x2 - detection.x1);
  const height = Math.max(0, detection.y2 - detection.y1);
  const side = Math.sqrt(width * height);
  const offCenter = Math.abs((detection.x1 + detection.x2) / 2 - 0.5) * 2;
  const centered = 1 - Math.min(1, offCenter);
  return side * detection.score * (1 - CENTER_BONUS + CENTER_BONUS * centered);
}

function add(groups: Map<string, SceneGroup>, label: string, detection: Detection): void {
  const relevance = relevanceOf(detection);
  const group = groups.get(label);
  if (group === undefined) {
    groups.set(label, { label: label, count: 1, best: detection, relevance: relevance });
    return;
  }
  group.count++;
  if (relevance > group.relevance) {
    group.relevance = relevance;
    group.best = detection;
  }
}

export function groupScene(detections: Detection[]): SceneGroup[] {
  const groups: Map<string, SceneGroup> = new Map();
  const wholePeople: Map<string, number> = new Map();
  let faces = 0;
  let person: SceneGroup | undefined = undefined;
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
      const relevance = relevanceOf(detection);
      if (person === undefined || relevance > person.relevance) {
        person = { label: PERSON_LABEL, count: 1, best: detection, relevance: relevance };
      }
      continue;
    }
    add(groups, label, detection);
  }
  const result: SceneGroup[] = [];
  groups.forEach((group: SceneGroup) => {
    result.push(group);
  });
  if (person !== undefined) {
    const gendered = (wholePeople.get('man') ?? 0) + (wholePeople.get('woman') ?? 0) +
      (wholePeople.get('boy') ?? 0) + (wholePeople.get('girl') ?? 0);
    person.count = Math.max(1, wholePeople.get(PERSON_LABEL) ?? 0, gendered, faces);
    result.push(person);
  }
  result.sort((a: SceneGroup, b: SceneGroup) => b.relevance - a.relevance);
  return result;
}

export function positionOf(detection: Detection): string {
  const center = (detection.x1 + detection.x2) / 2;
  if (center < LEFT_LIMIT) {
    return Messages.ON_THE_LEFT;
  }
  if (center > RIGHT_LIMIT) {
    return Messages.ON_THE_RIGHT;
  }
  return Messages.AHEAD;
}

export type ColorOf = (detection: Detection) => string;

const NO_COLOR: ColorOf = (): string => '';

function phraseOf(group: SceneGroup, colorOf: ColorOf = NO_COLOR): string {
  const color = group.count === 1 && group.label !== PERSON_LABEL ? colorOf(group.best) : '';
  return Messages.objectAt(group.label, group.count, positionOf(group.best), color);
}

export function relevantGroups(detections: Detection[], minRelevance: number = DESCRIBE_MIN_RELEVANCE,
  maxObjects: number = DESCRIBE_MAX_OBJECTS): SceneGroup[] {
  return groupScene(detections).filter((group: SceneGroup) => group.relevance >= minRelevance).slice(0, maxObjects);
}

export function describeScene(detections: Detection[], colorOf: ColorOf = NO_COLOR): string {
  const phrases = relevantGroups(detections).map((group: SceneGroup) => phraseOf(group, colorOf));
  return Messages.sceneSnapshot(phrases);
}

export class LiveSceneTracker {
  private readonly config: LiveSceneConfig;
  private tracks: Map<string, Track> = new Map();
  private announced: string[] = [];
  private lastSpeechAt: number = Number.NEGATIVE_INFINITY;

  constructor(config: LiveSceneConfig = DEFAULT_LIVE_CONFIG) {
    this.config = config;
  }

  reset(): void {
    this.tracks.clear();
    this.announced = [];
    this.lastSpeechAt = Number.NEGATIVE_INFINITY;
  }

  update(detections: Detection[], now: number, colorOf: ColorOf = NO_COLOR): string | undefined {
    this.observe(groupScene(detections));
    if (now - this.lastSpeechAt < this.config.speechGapMs) {
      return undefined;
    }
    const sentence = this.nextChange(colorOf);
    if (sentence !== undefined) {
      this.lastSpeechAt = now;
    }
    return sentence;
  }

  private observe(groups: SceneGroup[]): void {
    const seen: string[] = [];
    for (const group of groups) {
      seen.push(group.label);
      const track = this.tracks.get(group.label);
      if (track === undefined) {
        this.tracks.set(group.label, { streak: 1, absent: 0, confirmed: false, group: group });
      } else {
        track.streak++;
        track.absent = 0;
        track.group = group;
      }
    }
    const stale: string[] = [];
    this.tracks.forEach((track: Track, label: string) => {
      if (!seen.includes(label)) {
        track.absent++;
        track.streak = 0;
        if (track.absent >= this.config.disappearFrames || !track.confirmed) {
          stale.push(label);
        }
      } else if (!track.confirmed && track.streak >= this.config.appearFrames &&
        track.group.relevance >= this.config.minRelevance) {
        track.confirmed = true;
      }
    });
    for (const label of stale) {
      this.tracks.delete(label);
    }
  }

  private nextChange(colorOf: ColorOf): string | undefined {
    const added: SceneGroup[] = [];
    this.tracks.forEach((track: Track, label: string) => {
      if (track.confirmed && track.absent === 0 && !this.announced.includes(label)) {
        added.push(track.group);
      }
    });
    added.sort((a: SceneGroup, b: SceneGroup) => b.relevance - a.relevance);
    const fresh = added.slice(0, Math.min(this.config.maxObjects, this.config.maxNewPerSentence));
    if (fresh.length > 0) {
      for (const group of fresh) {
        this.announced.push(group.label);
      }
      return Messages.sceneNew(fresh.map((group: SceneGroup) => phraseOf(group, colorOf)));
    }
    const gone = this.announced.filter((label: string) => !this.tracks.has(label));
    if (gone.length > 0) {
      this.announced = this.announced.filter((label: string) => this.tracks.has(label));
      return Messages.sceneGone(gone);
    }
    return undefined;
  }
}

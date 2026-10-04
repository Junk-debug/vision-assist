export const BACK_FRAME_ROTATION: number = 90;
export const FRONT_FRAME_ROTATION: number = 270;
export const FRONT_PREVIEW_MIRRORED: boolean = true;
export const DETECTION_THRESHOLD: number = 0.35;
export const FIND_THRESHOLD: number = 0.25;
export const DEBUG_DISPLAY_THRESHOLD: number = 0.15;
export const DEBUG_SUMMARY_MS: number = 1000;
export const LIVE_FRAME_INTERVAL_MS: number = 250;
export const FIND_FRAME_INTERVAL_MS: number = 150;
export const FIND_TARGETS: string[] = [
  'Mobile phone', 'Watch', 'Coin', 'Glasses', 'Bottle', 'Mug', 'Coffee cup', 'Backpack', 'Handbag',
  'Laptop', 'Tablet computer', 'Remote control', 'Computer mouse', 'Book', 'Umbrella', 'Chair', 'Door', 'Person'
];
export const WORD_FRAME_INTERVAL_MS: number = 700;
export const WORD_TARGETS: string[] = ['EXIT', 'WC', 'PUSH', 'PULL', 'OPEN', 'CLOSED', 'PHARMACY', 'STOP'];
export const SCREEN_READER_BACKGROUND_GAP_MS: number = 4000;
export const FOCUS_AFTER_TRANSITION_MS: number = 400;
export const PHOTO_MAX_SIDE: number = 2048;
export const DESCRIBE_MAX_OBJECTS: number = 3;
export const DESCRIBE_MIN_RELEVANCE: number = 0.03;
export const LIVE_APPEAR_FRAMES: number = 2;
export const LIVE_DISAPPEAR_FRAMES: number = 5;
export const LIVE_SPEECH_GAP_MS: number = 3000;
export const LIVE_MAX_NEW_PER_SENTENCE: number = 2;

export interface FindTuning {
  acquireWindow: number;
  acquireHits: number;
  lostAfterMs: number;
  searchTickMs: number;
  searchSpeechGapMs: number;
  directionGapMs: number;
  directionRepeatMs: number;
  closerGapMs: number;
  closerRepeatLimit: number;
  centredTolerance: number;
  leaveCentredTolerance: number;
  arriveSide: number;
  arriveGrowth: number;
  arriveMinSide: number;
  arriveFrames: number;
  slowestPulseMs: number;
  fastestPulseMs: number;
  pulseSteps: number;
}

export const FIND_OBJECT_TUNING: FindTuning = {
  acquireWindow: 3,
  acquireHits: 2,
  lostAfterMs: 1000,
  searchTickMs: 1500,
  searchSpeechGapMs: 4000,
  directionGapMs: 2500,
  directionRepeatMs: 5000,
  closerGapMs: 4000,
  closerRepeatLimit: 3,
  centredTolerance: 0.15,
  leaveCentredTolerance: 0.25,
  arriveSide: 0.45,
  arriveGrowth: 2.0,
  arriveMinSide: 0.12,
  arriveFrames: 2,
  slowestPulseMs: 1000,
  fastestPulseMs: 150,
  pulseSteps: 8
};

export const FIND_WORD_TUNING: FindTuning = {
  acquireWindow: 3,
  acquireHits: 2,
  lostAfterMs: 2200,
  searchTickMs: 1500,
  searchSpeechGapMs: 4000,
  directionGapMs: 2500,
  directionRepeatMs: 5000,
  closerGapMs: 4000,
  closerRepeatLimit: 3,
  centredTolerance: 0.18,
  leaveCentredTolerance: 0.28,
  arriveSide: 0.3,
  arriveGrowth: 3.0,
  arriveMinSide: 0.15,
  arriveFrames: 2,
  slowestPulseMs: 1000,
  fastestPulseMs: 150,
  pulseSteps: 8
};

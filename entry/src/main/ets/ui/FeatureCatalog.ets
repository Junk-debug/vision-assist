import { FIND_TARGETS, WORD_TARGETS } from '../common/Config';
import { Accent } from './theme/Theme';

export enum PickerKind {
  NONE,
  OBJECT,
  WORD
}

export interface FeatureInfo {
  id: string;
  name: string;
  description: string;
  icon: Resource;
  accent: string;
  tint: string;
  needsDetector: boolean;
  startLabel: string;
  stopLabel: string;
  busyLabel: string;
  actionHint: string;
  readyText: string;
  picker: PickerKind;
  targets: string[];
  targetPrompt: string;
  changeTargetLabel: string;
  chooseTargetLabel: string;
  photoInput: boolean;
}

export const FEATURE_CATALOG: FeatureInfo[] = [
  {
    id: 'describe',
    name: 'Describe surroundings',
    description: 'Hear what is in front of you',
    icon: $r('sys.symbol.eye_viewfinder'),
    accent: Accent.describe,
    tint: Accent.describeTint,
    needsDetector: true,
    startLabel: 'Describe now',
    stopLabel: 'Describe now',
    busyLabel: 'Describing',
    actionHint: 'Says up to three things in front of the camera, once',
    readyText: 'Point the phone ahead, then press Describe now.',
    picker: PickerKind.NONE,
    targets: [],
    targetPrompt: '',
    changeTargetLabel: '',
    chooseTargetLabel: '',
    photoInput: true
  },
  {
    id: 'read',
    name: 'Read text',
    description: 'Read printed text aloud',
    icon: $r('sys.symbol.doc_text'),
    accent: Accent.read,
    tint: Accent.readTint,
    needsDetector: false,
    startLabel: 'Read now',
    stopLabel: 'Read now',
    busyLabel: 'Reading',
    actionHint: 'Reads the printed text in front of the camera',
    readyText: 'Hold the text about 30 centimetres away, then press Read now.',
    picker: PickerKind.NONE,
    targets: [],
    targetPrompt: '',
    changeTargetLabel: '',
    chooseTargetLabel: '',
    photoInput: true
  },
  {
    id: 'find',
    name: 'Find an object',
    description: 'Vibrates faster as you get closer',
    icon: $r('sys.symbol.magnifyingglass'),
    accent: Accent.find,
    tint: Accent.findTint,
    needsDetector: true,
    startLabel: 'Start finding',
    stopLabel: 'Stop finding',
    busyLabel: 'Finding',
    actionHint: 'Starts or stops the search',
    readyText: 'Move the phone slowly around the room.',
    picker: PickerKind.OBJECT,
    targets: FIND_TARGETS,
    targetPrompt: 'What do you want to find?',
    changeTargetLabel: 'Choose another object',
    chooseTargetLabel: 'Choose an object',
    photoInput: false
  },
  {
    id: 'findword',
    name: 'Find a word',
    description: 'Signs like EXIT or WC',
    icon: $r('sys.symbol.text_and_magnifyingglass'),
    accent: Accent.word,
    tint: Accent.wordTint,
    needsDetector: false,
    startLabel: 'Start finding',
    stopLabel: 'Stop finding',
    busyLabel: 'Finding',
    actionHint: 'Starts or stops the search',
    readyText: 'Move the phone slowly along the walls and doors.',
    picker: PickerKind.WORD,
    targets: WORD_TARGETS,
    targetPrompt: 'Which word do you want to find?',
    changeTargetLabel: 'Choose another word',
    chooseTargetLabel: 'Choose a word',
    photoInput: false
  },
  {
    id: 'light',
    name: 'Light check',
    description: 'Hear if the room is lit',
    icon: $r('sys.symbol.lightbulb_max'),
    accent: Accent.light,
    tint: Accent.lightTint,
    needsDetector: false,
    startLabel: 'Check the light',
    stopLabel: 'Check the light',
    busyLabel: 'Checking',
    actionHint: 'Tells you whether the light is on',
    readyText: 'Point the phone into the room, then press Check the light.',
    picker: PickerKind.NONE,
    targets: [],
    targetPrompt: '',
    changeTargetLabel: '',
    chooseTargetLabel: '',
    photoInput: false
  }
];

export function findFeatureInfo(id: string): FeatureInfo {
  const found = FEATURE_CATALOG.find((info: FeatureInfo) => info.id === id);
  return found !== undefined ? found : FEATURE_CATALOG[0];
}

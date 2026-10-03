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
  continuous: boolean;
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
}

export const FEATURE_CATALOG: FeatureInfo[] = [
  {
    id: 'describe',
    name: 'Describe surroundings',
    description: 'Hear what is in front of you, live',
    icon: $r('sys.symbol.eye_viewfinder'),
    accent: Accent.describe,
    tint: Accent.describeTint,
    continuous: true,
    needsDetector: true,
    startLabel: 'Start describing',
    stopLabel: 'Stop describing',
    busyLabel: 'Describing',
    actionHint: 'Double tap to switch the live description on or off',
    readyText: 'Point the phone ahead.',
    picker: PickerKind.NONE,
    targets: [],
    targetPrompt: '',
    changeTargetLabel: ''
  },
  {
    id: 'read',
    name: 'Read text',
    description: 'Read printed text aloud',
    icon: $r('sys.symbol.doc_text'),
    accent: Accent.read,
    tint: Accent.readTint,
    continuous: false,
    needsDetector: false,
    startLabel: 'Read now',
    stopLabel: 'Read now',
    busyLabel: 'Reading',
    actionHint: 'Double tap to read the printed text in front of the camera',
    readyText: 'Hold the text about 30 centimetres away, then press Read now.',
    picker: PickerKind.NONE,
    targets: [],
    targetPrompt: '',
    changeTargetLabel: ''
  },
  {
    id: 'find',
    name: 'Find an object',
    description: 'Vibrates faster as you get closer',
    icon: $r('sys.symbol.magnifyingglass'),
    accent: Accent.find,
    tint: Accent.findTint,
    continuous: true,
    needsDetector: true,
    startLabel: 'Start finding',
    stopLabel: 'Stop finding',
    busyLabel: 'Finding',
    actionHint: 'Double tap to start or stop the search',
    readyText: 'Move the phone slowly around the room.',
    picker: PickerKind.OBJECT,
    targets: FIND_TARGETS,
    targetPrompt: 'What do you want to find?',
    changeTargetLabel: 'Choose another object'
  },
  {
    id: 'findword',
    name: 'Find a word',
    description: 'Signs like EXIT or WC',
    icon: $r('sys.symbol.text_and_magnifyingglass'),
    accent: Accent.word,
    tint: Accent.wordTint,
    continuous: true,
    needsDetector: false,
    startLabel: 'Start finding',
    stopLabel: 'Stop finding',
    busyLabel: 'Finding',
    actionHint: 'Double tap to start or stop the search',
    readyText: 'Move the phone slowly along the walls and doors.',
    picker: PickerKind.WORD,
    targets: WORD_TARGETS,
    targetPrompt: 'Which word do you want to find?',
    changeTargetLabel: 'Choose another word'
  },
  {
    id: 'light',
    name: 'Light check',
    description: 'Hear if the room is lit',
    icon: $r('sys.symbol.lightbulb_max'),
    accent: Accent.light,
    tint: Accent.lightTint,
    continuous: false,
    needsDetector: false,
    startLabel: 'Check the light',
    stopLabel: 'Check the light',
    busyLabel: 'Checking',
    actionHint: 'Double tap to hear whether the light is on',
    readyText: 'Point the phone into the room, then press Check the light.',
    picker: PickerKind.NONE,
    targets: [],
    targetPrompt: '',
    changeTargetLabel: ''
  },
  {
    id: 'color',
    name: 'What color is this?',
    description: 'Name the color in the middle',
    icon: $r('sys.symbol.paintpalette'),
    accent: Accent.color,
    tint: Accent.colorTint,
    continuous: false,
    needsDetector: false,
    startLabel: 'Check the color',
    stopLabel: 'Check the color',
    busyLabel: 'Checking',
    actionHint: 'Double tap to hear the color of what is in the middle of the camera view',
    readyText: 'Hold the item close to the camera, then press Check the color.',
    picker: PickerKind.NONE,
    targets: [],
    targetPrompt: '',
    changeTargetLabel: ''
  }
];

export function findFeatureInfo(id: string): FeatureInfo {
  const found = FEATURE_CATALOG.find((info: FeatureInfo) => info.id === id);
  return found !== undefined ? found : FEATURE_CATALOG[0];
}

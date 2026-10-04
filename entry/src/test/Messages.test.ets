import { describe, it, expect } from '@ohos/hypium';
import { LightLevel, Messages } from '../main/ets/common/Messages';

export default function messagesTest() {
  describe('messages', () => {
    it('countsObjectsAndPeople', 0, () => {
      expect(Messages.objectCount('cup', 1)).assertEqual('cup');
      expect(Messages.objectCount('cup', 3)).assertEqual('3 cups');
      expect(Messages.objectCount('person', 2)).assertEqual('2 people');
      expect(Messages.objectAt('chair', 2, Messages.ON_THE_LEFT)).assertEqual('2 chairs on the left');
    });
    it('buildsFindPhrasesInLowerCase', 0, () => {
      expect(Messages.findStarted('Coffee cup')).assertEqual('Looking for coffee cup. Move the phone slowly.');
      expect(Messages.findStatus('Door')).assertEqual('Looking for door.');
      expect(Messages.searchingFor('Mobile phone')).assertEqual('Searching for mobile phone.');
    });
    it('keepsTheTypedWordInStatusButSpeaksItLowerCase', 0, () => {
      expect(Messages.wordStatus('EXIT')).assertEqual('Looking for the word EXIT.');
      expect(Messages.wordStarted('EXIT')).assertEqual('Looking for the word exit');
      expect(Messages.wordSearchingStatus('WC')).assertEqual('Searching for WC.');
      expect(Messages.wordSearchingSpeech('WC')).assertEqual('Searching for wc, move the phone slowly');
    });
    it('buildsGuidanceWithAndWithoutDirection', 0, () => {
      expect(Messages.closeness('Mug', 42, Messages.TURN_LEFT)).assertEqual('Mug: 42% close. turn left');
      expect(Messages.closeness('Mug', 90, '')).assertEqual('Mug: 90% close.');
      expect(Messages.warmer(Messages.MOVE_CLOSER)).assertEqual('Warmer. move closer');
      expect(Messages.warmer('')).assertEqual('Warmer.');
      expect(Messages.colder(Messages.TILT_UP)).assertEqual('Colder. tilt up');
      expect(Messages.colder('')).assertEqual('Colder.');
      expect(Messages.arrived('Door')).assertEqual('Door is right in front of you.');
    });
    it('buildsFindStateSentences', 0, () => {
      expect(Messages.sentence('turn left')).assertEqual('Turn left.');
      expect(Messages.sentence('')).assertEqual('');
      expect(Messages.searchingTurnSlowly('bottle')).assertEqual('Searching for bottle. Turn slowly.');
      expect(Messages.inView('bottle', Messages.ON_THE_LEFT)).assertEqual('Bottle in view, on the left.');
      expect(Messages.lostTarget('bottle')).assertEqual('Lost bottle. Move back slowly.');
      expect(Messages.withinReach('bottle')).assertEqual('Bottle is right in front of you, within reach.');
    });
    it('buildsDescribeSentences', 0, () => {
      expect(Messages.sceneSnapshot(['bottle ahead', 'chair on the left'])).assertEqual('Bottle ahead. Chair on the left.');
      expect(Messages.sceneNew(['person on the right'])).assertEqual('New: person on the right.');
      expect(Messages.sceneGone(['bottle'])).assertEqual('Bottle gone.');
      expect(Messages.sceneGone(['bottle', 'cup'])).assertEqual('Bottle and cup gone.');
    });
    it('roundsLuxPerLightLevel', 0, () => {
      expect(Messages.lightFromLux(LightLevel.DARK, 1.4)).assertEqual('It is dark. The light is off. About 1 lux.');
      expect(Messages.lightFromLux(LightLevel.NORMAL, 249.6)).assertEqual('The light is on. Normal indoor lighting. About 250 lux.');
      expect(Messages.lightFromLux(LightLevel.DAYLIGHT, 5000)).assertEqual('It is very bright, probably daylight. About 5000 lux.');
    });
    it('summarisesTextWithLineCount', 0, () => {
      expect(Messages.textSummary(1, 'EXIT')).assertEqual('Read 1 line. Starts with: EXIT');
      expect(Messages.textSummary(4, 'Dear customer')).assertEqual('Read 4 lines. Starts with: Dear customer');
    });
    it('joinsScreenNameAndPrompt', 0, () => {
      expect(Messages.screenWithPrompt('Find an object', 'What do you want to find?'))
        .assertEqual('Find an object. What do you want to find?');
    });
    it('formatsTimings', 0, () => {
      expect(Messages.timing(30, 5, 20, 5)).assertEqual('30 ms (prep 5, model 20, post 5)');
      expect(Messages.ocrTiming('system', 120)).assertEqual('system OCR 120 ms');
    });
    it('buildsHints', 0, () => {
      expect(Messages.targetHint('Starts or stops the search', '')).assertEqual('Starts or stops the search');
      expect(Messages.targetHint('Starts or stops the search', 'Mug')).assertEqual('Starts or stops the search. Looking for Mug');
      expect(Messages.changeTargetHint('EXIT')).assertEqual('Currently looking for EXIT');
      expect(Messages.pickTargetHint('Door')).assertEqual('Starts looking for Door');
    });
    it('failuresSayWhatToDoNext', 0, () => {
      const failures: string[] = [Messages.CAMERA_PERMISSION_NEEDED, Messages.CAMERA_START_FAILED, Messages.CAMERA_NOT_READY,
        Messages.CAMERA_SWITCH_FAILED, Messages.MODEL_LOAD_FAILED, Messages.MODEL_LOADING, Messages.TEXT_READER_UNAVAILABLE,
        Messages.TEXT_READ_FAILED, Messages.NO_TEXT_FOUND, Messages.COLOR_FAILED, Messages.LIGHT_FAILED,
        Messages.PHOTO_OPEN_FAILED, Messages.PICKER_OPEN_FAILED, Messages.NOTHING_IN_PHOTO, Messages.NO_TEXT_IN_PHOTO,
        Messages.NOTHING_RECOGNISED, Messages.NOTHING_TO_DESCRIBE];
      for (const failure of failures) {
        const sentences = failure.split('. ').filter((part: string) => part.trim().length > 0);
        expect(sentences.length >= 2).assertTrue();
      }
    });
  });
}

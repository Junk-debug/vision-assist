export enum LightLevel {
  DARK,
  DIM,
  NORMAL,
  BRIGHT,
  DAYLIGHT
}

export class Messages {
  static readonly APP_NAME: string = 'Vision Assist';
  static readonly TAGLINE: string = 'Offline help for what\'s around you';
  static readonly HEADING: string = 'Heading';
  static readonly FEATURE_LIST: string = 'Feature list';

  static readonly BACK_LABEL: string = 'Back';
  static readonly BACK_HINT: string = 'Returns to the list of features';
  static readonly SWITCH_TO_FRONT: string = 'Switch to front camera';
  static readonly SWITCH_TO_BACK: string = 'Switch to back camera';
  static readonly SWITCH_HINT: string = 'Uses the other camera';
  static readonly FRONT_CAMERA_ON: string = 'Front camera on';
  static readonly BACK_CAMERA_ON: string = 'Back camera on';

  static readonly STARTING_CAMERA: string = 'Starting the camera.';
  static readonly STOPPED: string = 'Stopped.';
  static readonly CAMERA_PERMISSION_NEEDED: string =
    'Camera is off. Press Allow camera access, or allow it in Settings.';
  static readonly CAMERA_PERMISSION_LABEL: string = 'Allow camera access';
  static readonly CAMERA_PERMISSION_HINT: string = 'Opens the system dialog to allow the camera';
  static readonly CAMERA_START_FAILED: string =
    'The camera could not start. Close other apps that use the camera, then open this feature again.';
  static readonly CAMERA_NOT_READY: string = 'The camera is not ready yet. Wait a moment and try again.';
  static readonly CAMERA_SWITCH_FAILED: string = 'The camera could not be switched. Try again, or keep using this camera.';
  static readonly MODEL_LOAD_FAILED: string = 'The recognition model could not load. Close the app, open it again and retry.';
  static readonly MODEL_LOADING: string = 'The recognition model is still loading. Try again in a few seconds.';
  static readonly TEXT_READER_UNAVAILABLE: string =
    'Text reading is not available on this device. Close the app, open it again and retry.';

  static readonly TYPE_A_WORD_FIRST: string = 'Type a word first, then press Start.';
  static readonly TYPE_A_WORD: string = 'Type a word';
  static readonly WORD_FIELD_LABEL: string = 'Word to find';
  static readonly WORD_FIELD_HINT: string = 'Type the word you want to find, then press Start';
  static readonly START: string = 'Start';
  static readonly START_TYPED_HINT: string = 'Starts looking for the typed word';
  static readonly OR_CHOOSE_ONE: string = 'Or choose one';
  static readonly CANCEL: string = 'Cancel';
  static readonly CANCEL_PICKER_HINT: string = 'Closes this list without changing anything';
  static readonly PICKER_CLOSED: string = 'Nothing changed.';

  static readonly DESCRIBE_LOOKING: string = 'Looking around.';
  static readonly DESCRIBE_STARTED: string = 'Describing started';
  static readonly DESCRIBE_STOPPED: string = 'Describing stopped';
  static readonly NOTHING_RECOGNISED: string = 'Nothing recognised. Point the phone at objects in good light.';
  static readonly NOTHING_TO_DESCRIBE: string = 'Nothing recognised. Try pointing at a table or a door.';
  static readonly TEXT_AHEAD: string = 'Text ahead.';
  static readonly TEXT_LONG_LIVE: string = 'Hold still and press Describe now to read it.';
  static readonly TEXT_AHEAD_LONG: string = 'Text ahead. Reading it now.';
  static readonly LIVE_DESCRIPTION: string = 'Live description';
  static readonly STOP_LIVE_DESCRIPTION: string = 'Stop live description';
  static readonly LIVE_DESCRIPTION_HINT: string = 'Keeps watching and announces only what changes';
  static readonly LIVE_STARTED: string = 'Live description on. Only changes are announced.';
  static readonly LIVE_STOPPED: string = 'Live description off';
  static readonly LIVE_WATCHING: string = 'Live description on. Watching for changes.';
  static readonly SEARCH_STOPPED: string = 'Search stopped';
  static readonly SEARCHING_TURN_SLOWLY: string = 'Searching. Turn slowly.';

  static readonly TURN_LEFT: string = 'turn left';
  static readonly TURN_RIGHT: string = 'turn right';
  static readonly TILT_UP: string = 'tilt up';
  static readonly TILT_DOWN: string = 'tilt down';
  static readonly MOVE_CLOSER: string = 'move closer';
  static readonly HOLD_STEADY: string = 'Hold steady.';
  static readonly MOVE_CLOSER_SLOWLY: string = 'Move the phone closer slowly.';
  static readonly ON_THE_LEFT: string = 'on the left';
  static readonly ON_THE_RIGHT: string = 'on the right';
  static readonly AHEAD: string = 'ahead';

  static readonly CHECKING_COLOR: string = 'Checking the color.';
  static readonly COLOR_FAILED: string = 'The color could not be checked. Hold the item close to the camera and try again.';
  static readonly CHECKING_LIGHT: string = 'Checking the light.';
  static readonly LIGHT_FAILED: string = 'The light could not be checked. Point the phone into the room and try again.';
  static readonly SCENE_LIT: string = 'Light is on.';
  static readonly SCENE_DIM: string = 'It is dim.';
  static readonly SCENE_DARK: string = 'It is dark. The light may be off.';
  static readonly LIGHT_TURNED_ON: string = 'Light is on now.';
  static readonly LIGHT_TURNED_OFF: string = 'It got dark. The light may be off.';
  static readonly LUMA_DARK: string = 'It looks dark. The light may be off.';
  static readonly LUMA_DIM: string = 'It looks dim.';
  static readonly LUMA_NORMAL: string = 'The light looks on. Normal lighting.';
  static readonly LUMA_BRIGHT: string = 'It looks very bright.';

  static readonly SHOW_FULL_TEXT: string = 'Show full text';
  static readonly SHOW_FULL_TEXT_HINT: string = 'Opens the whole text in large print';
  static readonly FULL_TEXT_TITLE: string = 'Full text';
  static readonly READ_AGAIN: string = 'Read again';
  static readonly READ_AGAIN_HINT: string = 'Reads the whole text aloud from the start';
  static readonly STOP_READING: string = 'Stop reading';
  static readonly STOP_READING_HINT: string = 'Stops reading the text aloud';
  static readonly READING_STOPPED: string = 'Reading stopped.';

  static readonly USE_PHOTO: string = 'Use a photo instead';
  static readonly USE_ANOTHER_PHOTO: string = 'Use another photo';
  static readonly USE_PHOTO_HINT: string = 'Opens the gallery to choose one photo';
  static readonly BACK_TO_CAMERA: string = 'Back to the camera';
  static readonly BACK_TO_CAMERA_HINT: string = 'Closes the photo and uses the live camera again';
  static readonly NO_PHOTO_CHOSEN: string = 'No photo chosen.';
  static readonly PHOTO_OPEN_FAILED: string = 'The photo could not be opened. Choose another photo.';
  static readonly PICKER_OPEN_FAILED: string = 'The gallery could not be opened. Try again, or use the camera.';
  static readonly ANALYSING_PHOTO: string = 'Checking the photo.';
  static readonly NOTHING_IN_PHOTO: string =
    'Nothing recognised in this photo. Choose a photo with clear, well lit objects.';

  static screenWithPrompt(name: string, prompt: string): string {
    return `${name}. ${prompt}`;
  }

  static findStarted(target: string): string {
    return `Looking for ${target.toLowerCase()}. Move the phone slowly.`;
  }

  static findStatus(target: string): string {
    return `Looking for ${target.toLowerCase()}.`;
  }

  static searchingFor(target: string): string {
    return `Searching for ${target.toLowerCase()}.`;
  }

  static wordStarted(word: string): string {
    return `Looking for the word ${word.toLowerCase()}`;
  }

  static wordStatus(word: string): string {
    return `Looking for the word ${word}.`;
  }

  static wordSearchingStatus(word: string): string {
    return `Searching for ${word}.`;
  }

  static wordSearchingSpeech(word: string): string {
    return `Searching for ${word.toLowerCase()}, move the phone slowly`;
  }

  static closeness(name: string, percent: number, direction: string): string {
    const base = `${name}: ${percent}% close.`;
    return direction === '' ? base : `${base} ${direction}`;
  }

  static warmer(direction: string): string {
    return direction === '' ? 'Warmer.' : `Warmer. ${direction}`;
  }

  static colder(direction: string): string {
    return direction === '' ? 'Colder.' : `Colder. ${direction}`;
  }

  static arrived(name: string): string {
    return `${name} is right in front of you.`;
  }

  static sentence(text: string): string {
    if (text === '') {
      return '';
    }
    const capital = `${text.charAt(0).toUpperCase()}${text.slice(1)}`;
    return capital.endsWith('.') ? capital : `${capital}.`;
  }

  static searchingTurnSlowly(name: string): string {
    return `Searching for ${name}. Turn slowly.`;
  }

  static inView(name: string, position: string): string {
    return Messages.sentence(`${name} in view, ${position}`);
  }

  static lostTarget(name: string): string {
    return `Lost ${name}. Move back slowly.`;
  }

  static withinReach(name: string): string {
    return Messages.sentence(`${name} is right in front of you, within reach`);
  }

  static sceneSnapshot(phrases: string[]): string {
    return phrases.map((phrase: string) => Messages.sentence(phrase)).join(' ');
  }

  static sceneNew(phrases: string[]): string {
    return `New: ${phrases.join(', ')}.`;
  }

  static textLive(position: string, text: string, short: boolean): string {
    const where = position === Messages.AHEAD ? 'Text ahead' : `Text ${position}`;
    return short ? `${where}: ${text}.` : `${where}. ${Messages.TEXT_LONG_LIVE}`;
  }

  static textAheadShort(text: string): string {
    return `Text ahead: ${text}.`;
  }

  static sceneGone(labels: string[]): string {
    return Messages.sentence(`${labels.join(' and ')} gone`);
  }

  static objectCount(label: string, count: number): string {
    if (count === 1) {
      return label;
    }
    return label === 'person' ? `${count} people` : `${count} ${label}s`;
  }

  static objectAt(label: string, count: number, position: string, color: string = ''): string {
    const name = Messages.objectCount(label, count);
    return color === '' ? `${name} ${position}` : `${color} ${name} ${position}`;
  }

  static timing(totalMs: number, prepMs: number, modelMs: number, postMs: number): string {
    return `${totalMs} ms (prep ${prepMs}, model ${modelMs}, post ${postMs})`;
  }

  static ocrTiming(engine: string, elapsedMs: number): string {
    return `${engine} OCR ${elapsedMs} ms`;
  }

  static lightFromLux(level: LightLevel, lux: number): string {
    const rounded = Math.round(lux);
    if (level === LightLevel.DARK) {
      return `It is dark. The light is off. About ${rounded} lux.`;
    }
    if (level === LightLevel.DIM) {
      return `It is dim. The light may be off. About ${rounded} lux.`;
    }
    if (level === LightLevel.NORMAL) {
      return `The light is on. Normal indoor lighting. About ${rounded} lux.`;
    }
    if (level === LightLevel.BRIGHT) {
      return `It is bright. About ${rounded} lux.`;
    }
    return `It is very bright, probably daylight. About ${rounded} lux.`;
  }

  static probablyColour(name: string): string {
    return `probably ${name}`;
  }

  static mixedColours(first: string, second: string): string {
    if (first === '') {
      return 'mixed colours';
    }
    return second === '' ? `mixed colours, mostly ${first}` : `mixed colours, mostly ${first} and ${second}`;
  }

  static textSummary(lineCount: number, firstLine: string): string {
    const lines = lineCount === 1 ? '1 line' : `${lineCount} lines`;
    return `Read ${lines}. Starts with: ${firstLine}`;
  }

  static targetHint(actionHint: string, target: string): string {
    return target === '' ? actionHint : `${actionHint}. Looking for ${target}`;
  }

  static changeTargetHint(target: string): string {
    return `Currently looking for ${target}`;
  }

  static pickTargetHint(target: string): string {
    return `Starts looking for ${target}`;
  }
}

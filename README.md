# Vision Assist

**Demo video:** [youtu.be/c6YDpCh5tAw](https://youtu.be/c6YDpCh5tAw)

An offline-first assistive feature for blind and low-vision users on HarmonyOS. Point the phone, and it tells you what is in front of you, with boxes drawn on the live camera view. Recognition runs on the device by default. Find an object can also use SAM 3 in the cloud when the phone is online, to find anything you type or dictate (keys included); offline it falls back to the on-device model by itself.

Built for the HackYeah 2026 Huawei challenge "Imagine What's Next" (Human-Centric Technology, Intelligent Experiences).

## Status

| Feature | State |
|---|---|
| Home screen | Three features: Describe surroundings, Find an object, Find a word |
| Live describe (camera, on-device detection, boxes, spoken summary) | Working on a Kirin 9000S phone and on the emulator |
| Screen reader support | Heading-first focus order, polite announcements, modal pickers; checked through the accessibility tree, see [Accessibility](#accessibility) |
| Front and back camera | Switch button on every feature screen; boxes land on the objects with both emulator cameras |
| Find an object with spoken guidance | Working on a Kirin 9000S phone. Pick from the list (Keys first) or type/dictate any object. Online: SAM 3 cloud search (Roboflow, needs `rawfile/sam3.json`); offline or when the cloud fails: the on-device model. A chip shows the active engine |
| Read printed text | Merged into Describe surroundings: short text is said in the description, longer text is read aloud in chunks after it; the main button becomes Stop reading while it plays; on-device OCR fallback when Core Vision OCR is missing |
| Find a word (typed or preset, spoken guidance) | Implemented; picker, typing and the OCR loop verified on the emulator, guidance on real printed text not verified |
| Full text screen (Show full text in Describe) | Large, scrollable, selectable text, one screen reader stop per line, Read again |
| Photo from the gallery (Describe) | System photo picker, no storage permission; the photo is decoded at most 2048 px on the long side |
| Light status | Part of Describe surroundings (no separate tile). Ambient light sensor, falling back to camera brightness when the sensor reads 0 lux in a bright scene (the emulator sensor always reports 0); verified on the emulator through the camera fallback |
| Object colours | Part of Describe surroundings: each named object gets its colour, with white-balance correction from the rest of the frame (no separate tile; the old `ColorFeature` is kept in the code but not in the menu); unit tested |

## Screens

The app opens on a list of features without starting the camera. Each feature has its own screen with the camera view, a status card with the spoken result and one large action button. Find an object and Find a word ask what to look for in a bottom sheet. Describe can also take a photo from the gallery. Describe reads any text it finds aloud after naming the objects.

| Start screen | Find an object, back camera (cloud search) | Find an object, front camera (cloud search) |
|---|---|---|
| ![Start screen](docs/screenshots/home.png) | ![Bottle found with the back camera, 98 %](docs/screenshots/find-object-back.png) | ![Glasses found with the front camera, 95 %](docs/screenshots/find-object-front.png) |

| Describe surroundings, live (front camera) |
|---|
| ![Describe: man, human face and glasses in boxes; New: person ahead, glasses ahead](docs/screenshots/describe-live.png) |

| Find a word picker | Find an object picker |
|---|---|
| ![Find a word picker](docs/screenshots/picker-find-a-word.png) | ![Find an object picker](docs/screenshots/picker-find-an-object.png) |

Known limits: the on-device detector knows 194 everyday classes. It has no key or wallet class, so those need the cloud search. A typed name is matched to the on-device classes without regard to case; a name the on-device model does not know works only with cloud search, and offline the app says "<X> can only be found with cloud search. Connect to the internet." See `tools/model/README.md`.

Find an object guidance is spoken: "Bottle in view, on the left", directions such as "turn left" or "tilt up", "Hold steady.", "Move the phone closer slowly.", "Lost bottle. Move back slowly." and "Bottle is right in front of you, within reach". The status card shows how close the target is as a percentage.

## How it works

```
Camera Kit (preview + ImageReceiver)
        |  NV21 frame converted to RGBA at half resolution (YUV_DOWNSCALE = 2)
        v
FrameNormalizer   crop black borders, rotate upright
        |
        v
YoloDetector      letterbox 640x640, MindSpore Lite predict (fp16, CPU), class-wise NMS
                  (Find an object online: Sam3Detector, SAM 3 on Roboflow, chosen by FindEngine)
        |
        v
SceneTracker      merge people labels, debounce, build "cup on the left, person ahead"
        |
        +--> Canvas overlay (boxes + labels)
        +--> Narrator: system screen reader announcement if it is on, otherwise Core Speech Kit
```

Source layout (`entry/src/main/ets`):

| Path | Responsibility |
|---|---|
| `pages/Index.ets` | Navigation between the start screen, feature screens and the full text screen |
| `pages/HomePage.ets` | Start screen with the three feature tiles |
| `pages/FeaturePage.ets` | Feature screen: camera or photo, status, action buttons, picker sheet, camera switch |
| `pages/FullTextPage.ets` | Full OCR text, one line per screen reader stop, Read again |
| `common/Messages.ets` | Every spoken or shown sentence: statuses, announcements, guidance, failures |
| `accessibility/*.ets` | Screen reader events (announce, move focus), element ids, focus chain, announcement rate limit |
| `photo/*.ets` | Gallery picker, capped decoding with EXIF rotation, photo analysis |
| `app/AppServices.ets` | Camera, detector, text reader and narrator shared by all screens |
| `ui/FeatureCatalog.ets` | Names, descriptions, icons, colours and labels of the menu features (`describe`, `find`, `findword`) |
| `ui/components/*.ets` | Screen frame (title, back), tile, buttons, status card, camera preview, picker sheet |
| `ui/theme/Theme.ets` | All colours, sizes, spacing and font sizes |
| `ui/Overlay.ets` | Boxes and labels drawn over the camera view, mirrored for the front camera |
| `camera/FrameSource.ets` | What features get frames from: frame handler with a minimum interval, `nextFrame()`, start and stop, camera position |
| `camera/CameraSource.ets` | Camera session, front and back switching, frame delivery with throttling (`FrameGate`) |
| `camera/FrameSourceSwitch.ets` | Chooses the camera or, in the debug-only `frames` build, injected frames from the Mac |
| `vision/FrameNormalizer.ets` | Frame cleanup and mapping to the preview |
| `vision/YoloDetector.ets` | Model loading, preprocessing, decoding, NMS |
| `vision/FindEngine.ets` | Chooses the Find an object detector: cloud when online with a key, on-device otherwise or for 20 s after a failed cloud request |
| `vision/Sam3Detector.ets` | SAM 3 text-prompt segmentation on Roboflow Serverless, 4 s timeout |
| `vision/SceneTracker.ets` | Which objects to announce and when |
| `features/*.ets` | One class per feature; `FindStateMachine` and `GuidanceCoach` are the shared spoken guidance of both find modes |
| `haptics/*.ets` | Short haptic cues; not relied on, guidance is spoken |
| `vision/text/*.ets` | OCR engines, word boxes and `WordMatcher` |
| `speech/Narrator.ets` | Announcement priorities: screen reader announcement when it is on, Core Speech Kit otherwise |

Camera: the switch button in the top bar changes between the back and the front camera. Each camera has its own frame rotation (`BACK_FRAME_ROTATION`, `FRONT_FRAME_ROTATION` in `common/Config.ets`), and the overlay is mirrored for the front camera because its preview is mirrored.

Platform capabilities used: Camera Kit (front and back camera), MindSpore Lite Kit (on-device inference in fp16 on the CPU, 55 to 190 ms per frame for the detector on a Kirin 9000S phone versus 119 ms in fp32; the app also tries the phone's NNRt accelerators first, but on the tested Kirin 9000S phone both NPU drivers return a model without inputs for our float32 graphs, so it falls back to the CPU; an NPU-ready conversion is future work), Core Vision Kit (system text recognition on devices that provide it), Core Speech Kit (offline TTS), Accessibility Kit, Sensor Service Kit (ambient light sensor, used inside Describe), Network Kit (network state and the SAM 3 request in Find an object), Media Library Kit (photo picker), Image Kit (decoding).

## Accessibility

The app is built for people who use it without looking at the screen. The conventions follow WCAG 2.2 for mobile, the VoiceOver and TalkBack conventions and the HarmonyOS screen reader guidelines (Accessibility Kit, "提升屏幕朗读无障碍体验").

Conventions implemented:

| Convention | How | API (minimum API level) |
|---|---|---|
| The first focus on every screen is its title | The title has `accessibilityDefaultFocus(true)` and the description "Heading". ArkUI has no heading role (`AccessibilityRoleType` up to API 24 has none), so "Heading" is read as the element description: "Describe surroundings, Heading" | `accessibilityDefaultFocus` (18), `accessibilityDescription` (12) |
| Reading order: title, status, main action, other actions, camera switch, Back | The node tree is in this order (Back and camera switch are drawn top left and top right with `position`, but come last in the tree) and every element names its successor with `accessibilityNextFocusId`, built from the elements present (`accessibility/FocusChain.ets`) | `accessibilityNextFocusId` (18) |
| One element per control, with a label and a hint | Tiles, buttons and picker rows are `accessibilityGroup` with `accessibilityRole(BUTTON)`, `accessibilityText` and `accessibilityDescription`. Hints say what happens ("Reads the printed text in front of the camera"), not the gesture | `accessibilityGroup` (10), `accessibilityRole` (18) |
| Toggles say their state through their label | "Start describing" becomes "Stop describing" and "Describing started" is announced once; the stop and start colours are never the only cue | `accessibilityText` |
| Results do not steal focus | New results are sent as `announceForAccessibilityNotInterrupt`, so they queue behind what the screen reader is saying and focus stays where it is. Only "X is right in front of you" and explicit commands (Read again, permission problems) interrupt | `sendAccessibilityEvent` (12), `announceForAccessibilityNotInterrupt` (18) |
| Continuous modes do not spam | Describe repeats a scene only when it changes and at most every 2.5 s; Find speaks a direction at most every 2.5 s and the same direction at most every 5 s; with the screen reader on, background announcements are additionally limited to one every 4 s | `accessibility/RateLimiter.ets` |
| No double speech | With the screen reader on, the app does not speak screen names itself; focus does that. With it off, Core Speech Kit announces the screen name | `isScreenReaderOpenSync` (10) |
| Pickers are modal | Pickers are `bindSheet` sheets: the screen behind is covered, the sheet title gets focus when the sheet opens, Cancel is the last item, and closing the sheet moves focus back to the button that opened it. With the screen reader off the picker opens by itself on entering Find; with it on, the screen first reads its title and the user opens the picker with "Choose an object" | `bindSheet`, `requestFocusForAccessibility` (12) |
| Focus comes back where it was | Back from a feature returns focus to its tile; back from the full text returns to Show full text; after the photo picker focus returns to the photo button | `requestFocusForAccessibility` (12) |
| Decorative content is hidden | Camera preview, photo, overlay canvas, icons, dividers and the timing line are `accessibilityLevel('no')` or inside a `no-hide-descendants` container | `accessibilityLevel` (10) |
| Long text is reachable | The full text screen shows every OCR line as its own element in a scroll view, so the screen reader steps line by line and scrolls on its own; the lines can be selected and copied | `copyOption` |
| Failures say what to do next | Every failure sentence in `common/Messages.ets` has a second sentence with the next step ("No text found. Hold the phone 20 to 30 centimetres from the text and try again."); a unit test checks this | |
| Touch targets and text size | Buttons at least 48 vp (main action 56 vp, list rows 64 vp), text in fp, cards grow with the text, one column from font scale 1.6. Secondary text `#5A6573` (5.3:1), feature colours at least 4.1:1 against their chips | `ui/theme/Theme.ets` |

APIs that exist but are not used: `accessibilityStateDescription` (API 23) would need a version guard because the app supports API 20, and the changing label already carries the state; `pageActive` events (API 23) are not needed because every screen is a `NavDestination`.

### Manual test with the screen reader

Turn on Settings, Accessibility, ScreenReader. Swipe right moves to the next element, swipe left to the previous one, double tap activates.

1. Open the app. Expected first: "Vision Assist, Heading". Swipe right: the tagline, then "Describe surroundings, button, Hear what is in front of you, live", then Find an object and Find a word.
2. Double tap Describe surroundings. Expected first: "Describe surroundings, Heading" (not Back). Swipe right: the status, "Start describing" or "Stop describing", "Use a photo instead", "Switch to front camera", and Back last. While describing, results are read after the current element without moving focus.
3. On the main button, double tap: "Describing stopped" is announced once and the button now reads "Start describing".
4. Double tap Back: focus lands on the Describe surroundings tile.
5. Open Find an object: "Find an object, Heading", status "What do you want to find?", "Choose an object". Double tap it: focus moves to "What do you want to find?, Heading" in the sheet. Swipe through the text field "Type or say any object" and the list, which starts with Keys; the screen behind is not reachable. Swipe to the end and double tap Cancel: focus is back on "Choose an object". Open it again and pick Mug: the camera starts and "Looking for mug. Move the phone slowly." is announced; spoken directions follow at most every few seconds.
6. Open Describe surroundings, point at printed text, double tap Describe now: the objects are named, then the text is read; the button says Stop reading meanwhile. Swipe to "Show full text" and open it: "Full text, Heading", then one line per swipe, then Read again, then Back. Back returns focus to Show full text.
7. Double tap "Use a photo instead", cancel the gallery: "No photo chosen" and focus on the photo button. Choose a photo with text: the full text screen opens.
8. Deny the camera permission once: the status reads "Camera is off. Press Allow camera access, or allow it in Settings." and the main button is "Allow camera access".

## How word matching works

"Find a word" runs the text reader (system OCR first, on-device PaddleOCR when the system one is unavailable) about every 700 ms and never overlaps two runs. Each detected text box comes back with its text and a normalised box. `vision/text/WordMatcher.ets` then looks for the target:

- Case and punctuation are ignored; a box with several words is split into words.
- A target of 4 or more letters matches a word that differs by at most one inserted, missing or wrong letter, or that contains the target (or is contained in it, for words of 4 or more letters). Shorter targets such as WC must match exactly.
- A target of several words matches only consecutive words in reading order; the highlighted box is the union of their boxes.
- The best-scoring match wins: exact, then one-letter difference, then substring.

The match box feeds the same spoken guidance as "Find an object" (`features/FindStateMachine.ets` through `GuidanceCoach`): "Exit in view, on the left", directions such as "turn left", "Hold steady.", "Move the phone closer slowly." and "Exit is right in front of you, within reach". A word counts as lost only after 2.2 s without a match, because OCR runs every 700 ms. Without a match it says "Searching for exit. Turn slowly." at most every 4 s. Known limits: OCR confuses similar glyphs (0 and O are not unified) and the on-device OCR cuts by detected box, so a word inside a long box highlights the whole box. If the system OCR fails or times out (2.5 s) twice in a row it is switched off until the app restarts; the first runs after start-up may use the on-device OCR while the system one is still preparing.

Unit tests for the pure logic live in `entry/src/test`. Run them with:

```sh
export DEVECO_SDK_HOME=/Applications/DevEco-Studio.app/Contents/sdk NODE_HOME=/Applications/DevEco-Studio.app/Contents/tools/node
/Applications/DevEco-Studio.app/Contents/tools/hvigor/bin/hvigorw test --no-daemon
```

hvigor prints nothing on success; the per-test result is in `entry/.test/default/intermediates/test/coverage_data/test_result.txt`.

## Requirements

- DevEco Studio 6.1.1 or later (macOS arm64 or Windows). The project targets HarmonyOS API 24 (`6.1.1(24)`) and declares API 20 (`6.0.0(20)`) as the minimum.
- A HarmonyOS emulator (Huawei phone image, API 24) or a physical HarmonyOS device. The emulator image needs the DevEco region set to China; see `docs/EMULATOR.md`.

## Build and run

### Prebuilt package

[GitHub Releases](https://github.com/Junk-debug/vision-assist/releases) has `vision-assist-unsigned.hap`, a release build of the `default` product without a cloud key (fully on-device). HarmonyOS installs only signed packages and a signature is tied to the signer's devices, so sign it for your emulator or phone (DevEco Studio "Automatically generate signature" with a Huawei ID, or `hap-sign-tool.jar sign-app` with your own certificate and profile) and install it with `hdc install`. Building from source, below, signs it for you.


1. Open this folder in DevEco Studio.
2. Create signing material: File, Project Structure, Signing Configs, "Automatically generate signature" (needs a Huawei ID), or use the repository's offline path below.
3. Start an emulator from DevEco Studio's Device Manager (not from the command line, see `docs/EMULATOR.md`).
4. Run the `entry` module, choose a feature and allow camera access when asked.

Installing on a physical phone (signing, USB debugging, things to check): see `docs/DEVICE.md`.

### Cloud search (optional)

Find an object can use SAM 3 on Roboflow Serverless when the phone is online. To turn it on, create `entry/src/main/resources/rawfile/sam3.json` (git-ignored) with your Roboflow key:

```json
{"roboflowApiKey": "..."}
```

Without this file the app is fully offline: the engine chip is hidden and Find uses the on-device model. The published release `.hap` ships without a key. With a key, Find uses the cloud only while the phone has a validated internet connection, falls back to the on-device model when offline or for 20 s after a failed request (4 s timeout), and announces each switch. The chip under the status card shows "Cloud search · Auto" or "On-device · offline", "cloud unreachable" or "chosen"; double tap toggles between Auto and on-device only. Cloud tuning is `FIND_CLOUD_TUNING` in `common/Config.ets`.

Command line (with `devecocli`):

```sh
devecocli build
devecocli run --device 127.0.0.1:5555
```

Offline signing for the emulator (no account) with the sample keys that ship in the OpenHarmony SDK:

```sh
SDK=/Applications/DevEco-Studio.app/Contents/sdk/default/openharmony/toolchains/lib
mkdir -p signatures && cp "$SDK/OpenHarmony.p12" "$SDK/OpenHarmonyProfileRelease.pem" signatures/
```

Create a profile for the bundle `com.hackyeah.visionassist` from `$SDK/UnsgnedReleasedProfileTemplate.json` (change `bundle-name`) and sign it with `hap-sign-tool.jar sign-profile` (sample key password is documented by OpenHarmony). Then add a `signingConfigs` entry to `build-profile.json5` pointing at the files in `signatures/`. The `signatures/` folder is git-ignored on purpose.

## Testing without the webcam

The debug-only `frames` product feeds still images or image sequences from the Mac to the app instead of the camera (`tools/debug/frame_server.py`, `hdc rport`). Only that product contains the frame HTTP client; the `default` product, debug or release, does not, and a release build of `frames` is refused. Both products request `ohos.permission.INTERNET` because the cloud search in Find an object needs it. See "Testing with injected frames" in `docs/EMULATOR.md`.

## Model

`entry/src/main/resources/rawfile/yolov8s_oiv7_640_sub.ms` is committed so the app builds without any model tooling. To rebuild it, follow `tools/model/README.md`.

## System integration (concept)

Not implemented. The idea is a HarmonyOS system feature next to ScreenReader rather than a separate app: an AccessibilityExtensionAbility, a voice entry through Intents Kit and Xiaoyi ("find my keys"), progress in a Live View, guidance on a watch through Wear Engine, and inference on the NPU through NNRt. Today it is built as an ordinary app on the same public kits.

## Next steps

- Keys offline: fine-tune the on-device detector on keys and wallets
- An NPU-ready model conversion, so NNRt can run the detector on the Kirin NPU
- System integration: accessibility extension, Intents Kit voice entry, Live View, watch guidance through Wear Engine
- Cloud calls through our own backend instead of a key inside the app
- Testing with blind users

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Decision log](docs/DECISIONS.md)
- [AI features](docs/AI_FEATURES.md)
- [AI workflow](AI_WORKFLOW.md)
- [Installing on a phone](docs/DEVICE.md)
- [Running on the emulator](docs/EMULATOR.md)
- [Blindfold test](docs/BLIND_TEST.md)
- [Demo script](docs/DEMO_SCRIPT.md)
- [Pitch outline](docs/SLIDES.md)
- [Model pipeline](tools/model/README.md)

## License

Application code: MIT. The bundled model is AGPL-3.0, see `NOTICE.md`.

# Decision log

Each entry: what we decided, why, what else we looked at, and where the evidence is. Entries marked **Plan** are not implemented yet.

Evidence paths outside this repository (`yolo-spike/`, `spike-vision/`) refer to the team's spike folders from the hackathon; their findings are summarised here and in `tools/model/README.md`.

## 1. Offline only, no network permission

- **Decision:** All recognition, speech and guidance run on the phone. The app does not request `ohos.permission.INTERNET`.
- **Why:** Camera frames of a blind person's home, letters and medicine are sensitive. Without the permission, "no frame leaves the phone" is enforced by the system, not by a promise. It also works without signal (stairwells, basements, abroad). It fits the challenge's point about digital sovereignty.
- **Alternatives considered:** Cloud vision-language model for richer descriptions; optional cloud assist behind a switch.
- **Evidence:** `entry/src/main/module.json5` lists only `CAMERA` and `VIBRATE`.
- **Experiment (Oct 2026):** Find picks its detector automatically (`vision/FindEngine.ets`): SAM 3 on Roboflow Serverless (`vision/Sam3Detector.ets`) when the phone has a validated internet connection and a key is set, the on-device model when offline or for 20 s after a failed cloud request. A chip under the status card shows the engine and switches between Auto and on-device only. It needs `ohos.permission.INTERNET` and `GET_NETWORK_INFO`, now declared, and a key in `entry/src/main/resources/rawfile/sam3.json` (gitignored: `{"roboflowApiKey": "..."}`). Without the key the chip is hidden and Find stays offline.
- **Plan:** An optional cloud assist, off by default, is listed under "Later" in `TODO.md`. It would need the network permission and is not started.

## 2. No voice input and no LLM

- **Decision:** Control is by buttons and the system screen reader (swipe and double tap). Output is fixed sentences built in code. No language model.
- **Why:** On-device speech recognition in Core Speech Kit supports only Chinese, and we will not send audio to a cloud service (decision 1). Fixed sentences are deterministic, short, testable (`SceneTracker.test.ets`) and cannot invent objects that are not there.
- **Alternatives considered:** Cloud ASR; an on-device or cloud LLM to phrase descriptions.
- **Evidence:** project brief; `vision/SceneTracker.ets` builds sentences such as "bottle on the left, chair ahead".

## 3. Separate features instead of one combined mode (for now)

- **Decision:** Six features, each on its own screen with one large action button: Describe surroundings, Read text, Find an object, Find a word, Light check, What color is this?
- **Why:** One task per screen is easier with a screen reader, each feature can be tested and demonstrated on its own, and the frame budget goes to one model at a time (the detector and the OCR do not run together).
- **Alternatives considered:** A single "smart" camera mode that detects, reads and guides at once.
- **Evidence:** `features/*.ets`, `pages/FeaturePage.ets`.
- **Plan:** A combined mode may come later; not started.

## 4. YOLOv8s Open Images V7 subset instead of open-vocabulary detectors

- **Decision:** Ship Ultralytics YOLOv8s trained on Open Images V7, with the class head pruned to 194 everyday classes, converted to MindSpore Lite.
- **Why:** The original idea was to find personal items by name with an open-vocabulary model. Benchmarks showed that keys were not found by any model tested, so the vocabulary advantage did not pay off. The Open Images model was the only candidate that found watches (0.89 to 0.95 on the user photo) and coins (0.61 to 0.86) and it is good on phones, glasses and bottles. Pruning cut post-processing on the emulator from about 255 ms to about 60 ms with bit-identical scores.
- **Alternatives considered:**
  - YOLO-World (s, m, l): keys 0 at threshold 0.25; watch, coin, earbuds 0.
  - YOLOE (v8s, v8m, 11s, 11m): best for wallets (0.77 to 0.88 on the user photo) but keys 0, watch and coin 0, about 3x slower than YOLO-World-s.
  - OWLv2-base: highest ceiling (keys 0.44, watch 0.62) but 1.5 s per image on a Mac CPU and not deployable.
  - LW-DETR on Objects365 (has key and wallet classes): output was unusable in the time box.
  - COCO models: no key, wallet, glasses or watch class.
- **Evidence:** `yolo-spike/bench/RESULTS.md` (71 web photos, 8 emulator frames, 9 user photos; "KEYS do not work with any config tested"), `yolo-spike/bench2/RESULTS.md` (keys 0/12 web and 0 on the user photo for every model), `tools/model/README.md`.
- **Consequence:** Keys and wallets are not supported. The README and the demo say so. Fine-tuning on keys and wallets is in `TODO.md` under "Later" (**Plan**).

## 5. System OCR first, own PaddleOCR fallback

- **Decision:** `TextReader` tries Core Vision Kit `textRecognition` first and falls back to PP-OCRv4 mobile (detector plus English recognizer) running in MindSpore Lite. The choice is made at runtime by asking each engine whether it is ready, not by checking for an emulator.
- **Why:** Core Vision Kit does not work on the DevEco emulator, which the challenge names as the default demo target. Text reading must work there, and the system engine should still be used on phones where it exists.
- **Alternatives considered:** System OCR only (no reading on the emulator); own OCR only (ignores the platform service).
- **Evidence:** emulator spike log (`spike-vision/evidence/spike_hilog.txt`): `objectDetection error code=1011000002 msg=The service is abnormal`, `OCR error code=200 msg=Run timed out`. The documentation states the kit does not support the emulator. Converter problems and accuracy (0.886 character accuracy on 8 synthetic samples) are in `yolo-spike/ocr/out/README.md` and `io_spec.md`.
- **Not verified:** system OCR on a real phone.

## 6. HarmonyOS runtime instead of OpenHarmony

- **Decision:** `runtimeOS: "HarmonyOS"`, target `6.1.1(24)`, minimum `6.0.0(20)`.
- **Why:** The DevEco emulator runs HarmonyOS images only, and Core Speech Kit and Core Vision Kit are HarmonyOS kits. An OpenHarmony build would need the Oniro emulator (QEMU with TCG emulation on Apple silicon, slower) and would lose system TTS.
- **Alternatives considered:** OpenHarmony with the Oniro emulator.
- **Evidence:** `build-profile.json5`; `docs/EMULATOR.md` item 7 (string SDK versions are required for the HarmonyOS runtime).
- **Note:** The detector, OCR, guidance and matching code use MindSpore Lite and plain ArkTS, which are also available on OpenHarmony. Porting has not been tried.

## 7. Warmer / colder from box centre and relative size

- **Decision:** Closeness is 0.55 times how central the box is plus 0.45 times how large it is. The vibration period shortens from 1000 ms to 110 ms as closeness rises; "right in front of you" fires when the box is large and central.
- **Why:** A single camera cannot measure absolute distance, and the emulator has no depth sensor. Box size relative to the frame is a usable proxy for "getting closer" with any phone.
- **Alternatives considered:** Metric distance from known object sizes (fragile across items); depth or ToF sensors (not on the emulator, not on every phone); stereo audio panning (idea, not built).
- **Evidence:** `features/FindGuidance.ets`, `FindGuidance.test.ets`.
- **Not verified:** how the vibration feels on a real phone.

## 8. Dropped "where did I last see it"

- **Decision:** No memory of where an object was last seen.
- **Why:** The camera only sees what it is pointed at while the app is open. A blind user does not film the room continuously, so the answer would usually be "never seen" or out of date.
- **Alternatives considered:** Keeping a log of detections with timestamps and positions.
- **Evidence:** project brief.

## 9. Emulator camera needs a GUI start

- **Decision:** Document that the emulator must be started from DevEco Studio's Device Manager, with camera access granted to DevEco Studio in macOS. No code workaround.
- **Why:** Started with `devecocli emulator start`, macOS silently refuses the webcam and the preview stays black. The emulator always opens the first camera in macOS's discovery list, so an iPhone Continuity Camera cannot be chosen without hiding the built-in camera (for example in clamshell mode, not tested).
- **Alternatives considered:** A debug-only frame source that feeds images from the Mac instead of the camera. Now built as the `frames` product (see decision 15).
- **Evidence:** `docs/EMULATOR.md` item 2; emulator log lines with "camera permission denied" (`spike-vision/evidence/emulator_host_camera_denied.txt`).
- **Related:** the app opens on a feature list without starting the camera; the camera starts only on a feature screen.

## 10. HarmonyOS-style interface with contrast-adjusted colours

- **Decision:** Interface style A: HarmonyOS system look (light grey page, white cards, blue `#0A59F7` primary, rounded tiles), one colour per feature. Colours were darkened where needed for contrast: secondary text `#5A6573` (5.3:1 on the page background), feature colours at least 4.1:1 against their tinted chips.
- **Why:** Many users have low vision rather than no vision, so the screen must be readable. Looking like a system app makes the app familiar to HarmonyOS users.
- **Alternatives considered:** Other style mockups (not kept in the repository); a pure black high-contrast theme.
- **Evidence:** `ui/theme/Theme.ets`, README "Accessibility".
- **Note:** 4.1:1 is below the WCAG AA 4.5:1 threshold for small text; it applies to icon chips, not body text.

## 11. Accessibility conventions

- **Decision:**
  - Each tile, button and picker row is one screen reader item with a name and a description (`accessibilityGroup`, `accessibilityText`, `accessibilityDescription`, role button).
  - Icons, the camera view and the overlay are hidden from the screen reader.
  - Focus order: back, title, camera switch, status, action button.
  - When the screen reader is on, results are sent as `announceForAccessibility` events; otherwise Core Speech Kit speaks them.
  - Touch targets at least 48 vp; the action button at least 56 vp high; text in fp; one column from font scale 1.6.
- **Why:** Blind users already know their screen reader. The app should work with it rather than replace it, and speech from the app must not talk over it.
- **Alternatives considered:** A self-voiced app with custom gestures.
- **Evidence:** `ui/components/*.ets`, `speech/Narrator.ets`.
- **Not verified:** a full walkthrough with the screen reader switched on. The accessibility tree was checked on the emulator.

## 12. Licence split

- **Decision:** Application code under MIT. The bundled detector model stays under AGPL-3.0, with its export and conversion scripts in `tools/model/`.
- **Why:** The Ultralytics YOLOv8 weights are AGPL-3.0, so the converted `.ms` file is a derivative and keeps that licence. Keeping the scripts in the repository provides the model's corresponding source.
- **Alternatives considered:** An Apache- or MIT-licensed detector (no candidate with comparable classes was found in the time box); training our own model.
- **Evidence:** `LICENSE`, `NOTICE.md`.
- **Open item:** `NOTICE.md` does not yet list the PaddleOCR / RapidOCR models (`ocr_det.ms`, `ocr_rec.ms`, `ocr_dict.txt`, Apache-2.0).

## 13. English only

- **Decision:** Interface, speech and OCR recognizer are English.
- **Why:** Jury materials must be in English. Polish is not available in the system TTS or in the OCR models we use.
- **Evidence:** challenge rules section 4; project brief.
- **Known issue:** the `en-US` system voice must be downloaded once, which failed on the emulator (`1002300008`); the app falls back to the Chinese voice there.

## 14. Haptic cues and vibration usage types

- **Decision:** Five short cues in `haptics/HapticPatterns.ets`: tap (button or tile activated), result ready, error, guidance pulse and arrived. Each uses a system preset when `vibrator.isSupportEffect` says the phone has it (`haptic.effect.soft`, `haptic.notice.success`, `haptic.notice.fail`, `haptic.clock.timer`, `haptic.effect.hard`) and otherwise a short timed pattern (15 ms; 30-70-30 ms; three 60 ms pulses; 40 ms; 120-80-120-80-200 ms). Tap, result and error use usage `touch`; the find guidance pulse and arrived use usage `notification`.
- **Why:** Per the `@ohos.vibrator` reference, `touch`, `media`, `physicalFeedback`, `simulateReality` and `unknown` are muted when the user turns touch feedback off, while `alarm`, `ring`, `notification` and `communication` follow only the ring / vibrate / silent switch. Guidance vibration is the main output of Find for a blind user, so it must not disappear because touch feedback is off; `notification` is the closest honest category for a user-started cue. Interface ticks are plain touch feedback and should obey the user's setting. Vibration happens only on activation and results, never on focus, so it does not double the screen reader's own focus feedback.
- **Alternatives considered:** `alarm` (also not touch-muted, but meant for alarms and may be treated with higher priority); `touch` for everything (guidance silently lost with touch feedback off); custom `VibrateFromPattern` sequences (API 18+, needs hardware support checks, more than these cues need).
- **Evidence:** `haptics/Haptics.ets`, `haptics/HapticPatterns.ets`, `Haptics.test.ets`; `devecocli docs read "API参考/硬件/Sensor_Service_Kit_传感器服务/ArkTS_API/ohos_vibrator_振动_/js-apis-vibrator"` (Usage, HapticFeedback, VibratePreset).
- **Not verified:** how the cues feel on a real phone (the emulator vibrator fails), preset lengths per device, and whether Do Not Disturb mutes `notification` vibration.

## 15. Injected test frames as a separate debug-only product

- **Decision:** Test images from the Mac reach the app through a separate `frames` product and `entry` target. The target adds the source root `entry/src/frames` (HTTP client `InjectedFrameSource`) and sets `BuildProfile.FRAME_INJECTION`; the root `hvigorfile.ts` adds `ohos.permission.INTERNET` to the module only when the product is `frames`, and fails the build if `frames` is built in release mode. The `default` target compiles `entry/src/default`, whose `createFrameInjector()` returns nothing.
- **Why:** The privacy claim "no network permission" must hold for what ships, and it is easiest to prove when the shipped package contains neither the permission nor the code. hvigor has no per-target `module.json5` and no per-build-mode permissions; per-target source roots (`source.sourceRoots`) and the documented `setModuleJsonOpt` hook in `hvigorfile.ts` are the supported mechanisms. A product, not just a target, keeps `assembleApp` for `default` from packing the debug HAP.
- **Alternatives considered:** A runtime switch in the normal build (would need INTERNET in every build); keying only on build mode (the debug HAP of `default`, used for normal development, would then request INTERNET); a hidden gesture to turn injection on (not needed: the server being reachable is the switch, and only in the `frames` build).
- **Evidence:** built `module.json` of `default` debug and release lists only CAMERA and VIBRATE, and its `modules.abc` does not contain `InjectedFrameSource`; the `frames` debug HAP lists INTERNET as well; `--product frames --build-mode release` fails in the `nodesEvaluated` hook.

## 16. Rotated boxes in the on-device OCR

- **Decision:** The DB post-processing fits a minimum-area rectangle (convex hull of the component plus rotating calipers, no OpenCV), unclips it along its own axes and reads it through a rotated bilinear crop. Boxes under 2 degrees keep the old axis-aligned path. Lines are grouped in the page frame given by the width-weighted median angle. Boxes returned to the app stay axis-aligned.
- **Why:** Blind users hold the phone crooked. With axis-aligned boxes, text rotated by 5 degrees read at 0.41 character accuracy because each crop held slanted text plus pieces of the next line.
- **Alternatives considered:** Angle from second moments (PCA) of the component pixels: same gains on rotated text, but ascenders and descenders tilted short words such as "Settings" past 2 degrees and cost 0.8 points on `03_small`. A 1 or 1.5 degree threshold: slightly worse on the -2 degree book photo; 3 degrees: 3 degree samples fall back to 0.82. Deskewing the whole frame: one angle for the frame, an extra full-frame resample, and no help for mixed angles.
- **Evidence:** Python prototype and evaluation in `yolo-spike/ocr/rot/` (`rot_ocr.py`, `make_rot_samples.py`, `evaluate_rot.py`, `rot_report.json`), same models through onnxruntime. Character accuracy before -> after:

| Samples | Before | After |
|---|---|---|
| `04_rotated` (5 degrees) | 0.411 | 0.984 |
| `06_bookphoto` (-2 degrees, blur, noise) | 0.856 | 0.957 |
| Other 6 original samples | 0.949 to 0.980 | unchanged |
| Original 8, overall | 0.886 | 0.973 |
| 60 rotated samples (6 layouts), 3 degrees | 0.673 | 0.975 |
| 5 degrees | 0.419 | 0.982 |
| 7 degrees | 0.266 | 0.977 |
| 10 degrees | 0.175 | 0.982 |
| 15 degrees | 0.079 | 0.980 |

- **Not verified:** the ArkTS port against the Python numbers on a device (the geometry is unit-tested); real camera photos with perspective.

## 17. Find as a state machine, describe on demand

- **Decision:** Both find modes run `features/FindStateMachine.ets`: searching (soft tick every 1.5 s, "Searching for X. Turn slowly." at most every 4 s), acquired (seen in 2 of the last 3 frames: "X in view, on the left" and a distinct cue, once), guiding (pulse faster when more centred and bigger; a direction at most every 2.5 s and the same one at most every 5 s; "Hold steady." once when centred; "Move the phone closer slowly." at most every 4 s and 3 times), arrived (centred and the larger box side at least 45 % of the frame, or grown 2x since acquisition and at least 12 %, for 2 frames in a row: "X is right in front of you, within reach", strong cue, then quiet) and lost (missing for more than 1 s: "Lost X. Move back slowly."). Thresholds live in `FIND_OBJECT_TUNING` and `FIND_WORD_TUNING` in `common/Config.ets` (words: 30 % side or 3x growth, lost after 2.2 s because OCR runs every 700 ms). Describe surroundings speaks once per tap: at most 3 objects ranked by size x confidence x centredness, low-value classes (clothing, body parts) skipped. "Live description" is a separate toggle that announces only changes ("New: person on the right", "Bottle gone") at most every 3 s.
- **Why:** Blindfold testing: find never said it had found the target (the old area-based closeness almost never reached "arrived" for tall bottles or wide words) and kept saying "move closer"; describe dictated the whole scene continuously.
- **Evidence:** `FindStateMachine.test.ets`, `FindGuidance.test.ets`, `SceneTracker.test.ets`.
- **Not verified:** the thresholds on a real phone.

## 18. Read text from a snapshot, in chunks that can be stopped; colour with white-balance correction

- **Decision (Read text):** Reading works on the frame taken at the moment of the tap. The preview freezes on that frame with a "Snapshot" badge and the detected line boxes; the recognised text is shown at once below it, split into the same chunks that are spoken (lines joined into sentences, at most 240 characters, `speech/TextChunks.ets`). Chunks are spoken one at a time (`speech/ReadAloud.ets`): with Core Speech Kit the next chunk starts on `onComplete` with type 1 (playback finished); with the screen reader on, each chunk is a polite announcement and the next one is sent after an estimated duration, so the app never queues more than one chunk. While reading, the main button is "Stop reading"; stopping cancels the queue and sends an interrupting "Reading stopped.", which also cuts the screen reader's current chunk (its own two-finger tap pauses speech as well). Leaving the screen, opening the full text by hand or going back to the camera stops reading. "Read again" and "Back to camera" sit under the snapshot; the visible text is hidden from the screen reader because "Show full text" offers the same text line by line.
- **Decision (Color):** `vision/ColorNamer.ets` is pure and takes an RGBA buffer and a region (`readColorInRegion`, so it can later name the colour of a detection box). It samples a 10x10 grid of cells over the central 28% square, drops specular highlights and deep shadows relative to the region's median, estimates the light from the rest of the frame (mean of gray-world and the brightest 10%), and corrects the region with that estimate. The correction is limited to the warm–cool axis (R/B up to about 2.6 warm, 1.7 cool) and a small green–magenta tint, and only 85% of it is applied. Cells are named in coarse names (red, orange, yellow, green, blue, purple, pink, brown, black, white, gray, beige; "light"/"dark" only when clear); white, gray and black use lightness relative to the brightest part of the frame. The answer is "probably X" when the dominant name covers less than 60% of the cells, is close to a boundary, or the light estimate hit its limit, and "mixed colours, mostly X and Y" below 40%.
- **Trade-off:** a large uniformly coloured object around the centre looks like a coloured light to gray-world. The limits and the blend keep such an object coloured (a blue shirt filling the frame stays "probably blue") at the cost of leaving part of a very strong cast uncorrected.
- **Alternatives considered:** Camera Kit `setWhiteBalanceMode` (API 20, PhotoSession) offers only fixed presets, manual Kelvin or lock; none knows the scene light better than auto white balance, so it is not used.
- **Evidence:** `ColorNamer.test.ets` (blue object under warm and cool casts, white and gray paper under casts, black, highlights, uniform fill, mixed), `ReadAloud.test.ets`.
- **Not verified:** on a real phone and with the screen reader's actual speaking rate.

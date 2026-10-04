# Decision log

Each entry: what we decided, why, what else we looked at, and where the evidence is. Entries marked **Plan** are not implemented yet.

Evidence paths outside this repository (`yolo-spike/`, `spike-vision/`) refer to the team's spike folders from the hackathon; their findings are summarised here and in `tools/model/README.md`.

## 1. Offline only, no network permission

- **Decision:** All recognition, speech and guidance run on the phone. The app does not request `ohos.permission.INTERNET`.
- **Why:** Camera frames of a blind person's home, letters and medicine are sensitive. Without the permission, "no frame leaves the phone" is enforced by the system, not by a promise. It also works without signal (stairwells, basements, abroad). It fits the challenge's point about digital sovereignty.
- **Alternatives considered:** Cloud vision-language model for richer descriptions; optional cloud assist behind a switch.
- **Evidence:** `entry/src/main/module.json5` lists only `CAMERA` and `VIBRATE`.
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

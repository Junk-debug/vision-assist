# Pitch outline (3 minutes, 9 slides)

Judging criteria and weights (Huawei "Imagine What's Next"): originality 20, usefulness 20, technical execution 20, platform capabilities 20, demo quality 10, reproducibility and transparency 10. Each slide lists the criteria it serves.

Claims marked [verify on device] have not been checked on a real phone yet. Remove the claim or the mark before presenting.

## 1. Title (0:00-0:10)

- Vision Assist: an offline seeing assistant for HarmonyOS
- Team name, HackYeah 2026, Huawei challenge, area: Human-Centric Technology + Intelligent Experiences
- One photo: phone pointed at a table, bottle with a green box

Speaker notes: "43 million people are blind. Vision Assist lets them ask the phone what is in front of them, read text and find things, without the internet."

Criteria: usefulness.

## 2. Problem (0:10-0:30)

- 43 million blind people (WHO / Lancet Global Health, 2020 estimate)
- Daily tasks: Where is my bottle? Which door is the exit? What does this letter say? Is the light on?
- Many existing helpers send camera images to the cloud or need a sighted volunteer

Speaker notes: keep it concrete; one example sentence per task. Mention that the camera sees private things: letters, medicine, the inside of a home.

Criteria: usefulness.

## 3. What exists, and the gap (0:30-0:50)

| App | Platform | How it works | Gap for our users |
|---|---|---|---|
| Xiaoyi "see the world" (小艺看世界) | HarmonyOS | Cloud large model | Chinese, cloud, China only |
| Google Lookout (Find mode) | Android | Find mode with direction and distance for general categories; generative features in the cloud | Not on HarmonyOS |
| Seeing AI | iOS, Android | Text, scenes, colour, light | Not on HarmonyOS |
| Be My Eyes | iOS, Android | Sighted volunteers and an AI assistant | Not on HarmonyOS; needs a connection |

- Gap: no fully offline assistant for HarmonyOS outside China

Speaker notes: be fair. Lookout already has a find mode; our difference is the platform, offline-only, and the haptic warmer/colder loop.

Criteria: originality.

## 4. Solution (0:50-1:10)

Six features, each one tap from the start screen:

- Describe surroundings: "chair ahead, bottle on the left"
- Find an object: vibration gets faster as you get closer, "Bottle is right in front of you"
- Find a word: EXIT, WC, PUSH, PHARMACY, or any typed word, same warmer/colder guidance
- Read text aloud
- Light check (ambient light sensor) and colour naming

Differentiators:

- Fully offline: no network permission at all
- Native HarmonyOS, uses system kits
- Haptic warmer/colder find for objects and for words
- Screen-reader first: works with the system screen reader, announces through it

Criteria: originality, usefulness.

## 5. Demo (1:10-2:10)

- Blindfold video, 60 s cut of `docs/DEMO_SCRIPT.md` (airplane mode, Describe, Find bottle, Find EXIT, Read)
- Caption: "Real device, airplane mode, no edits within scenes" [verify on device]; if recorded on the emulator, say so

Speaker notes: let the video speak; only say what is not visible ("this vibration you can't hear is getting faster" [verify on device]).

Criteria: demo quality, usefulness.

## 6. How it works (2:10-2:25)

- Diagram: Camera Kit -> frame normalizer -> YOLOv8s (MindSpore Lite) or OCR -> trackers and guidance -> overlay, screen reader / speech, vibration
- Detector: YOLOv8s Open Images V7, pruned to 194 classes, converted to MindSpore Lite; about 220-310 ms per frame on the emulator CPU
- Text: system OCR (Core Vision Kit) first, own PaddleOCR in MindSpore Lite as fallback, picked at runtime by what the device supports
- System OCR on a phone [verify on device]

Speaker notes: one sentence on why not open-vocabulary models: we benchmarked YOLO-World, YOLOE and OWLv2; none found keys, and the Open Images model was the only one that found watches and coins.

Criteria: technical execution.

## 7. Platform capabilities (2:25-2:35)

| Kit | Use |
|---|---|
| Camera Kit | Live frames, front and back camera |
| MindSpore Lite Kit | On-device detector and OCR |
| Core Vision Kit | System text recognition |
| Core Speech Kit | Offline speech output |
| Accessibility Kit | Screen reader detection and announcements |
| Sensor Service Kit | Vibrator for guidance, ambient light sensor |

Speaker notes: the app would not run unchanged on another OS; each feature is built on a system kit.

Criteria: platform capabilities.

## 8. Quality and honesty (2:35-2:50)

- 25 unit tests for matching, guidance, scene sentences and colour names
- Error handling: missing model, denied camera, no OCR engine, broken light sensor, missing voice
- Only camera and vibration permissions
- Known limits: no keys or wallet class; English only; distance is relative, not metric; vibration and screen reader walkthrough [verify on device]
- MIT code, AGPL model, decision log and AI workflow published

Criteria: technical execution, reproducibility and transparency.

## 9. Next steps and close (2:50-3:00)

- Fine-tune the detector on keys and wallets
- Full-text reading screen, gallery input
- Optional cloud assist, off by default
- Repository link and QR code

Speaker notes: end on the user: "Everything you saw runs on the phone. No cloud."

Criteria: usefulness, reproducibility.

## Mapping to criteria

| Criterion | Weight | Slides |
|---|---|---|
| Originality | 20 | 3, 4 |
| Demonstrated usefulness | 20 | 1, 2, 4, 5, 9 |
| Technical execution | 20 | 6, 8 |
| Platform capabilities | 20 | 7 |
| Demo quality | 10 | 5 |
| Reproducibility and transparency | 10 | 8, 9 |

# Pitch outline (3 minutes, 11 slides)

Judging criteria and weights (Huawei "Imagine What's Next"): originality 20, usefulness 20, technical execution 20, platform capabilities 20, demo quality 10, reproducibility and transparency 10. Each slide lists the criteria it serves.

Slides 5 and 6 describe a concept. Say so on the slide: the system integration and the watch are not implemented.

## 1. Cover

- Vision Assist: a HarmonyOS system feature for blind and low-vision people
- Team name, HackYeah 2026, Huawei challenge, area: Human-Centric Technology + Intelligent Experiences

Speaker notes: "43 million people are blind. Vision Assist lets them ask the phone what is in front of them and find things, offline first."

Criteria: usefulness.

## 2. Problem

- 43 million blind people (WHO / Lancet Global Health, 2020 estimate)
- Daily tasks: Where are my keys? Which door is the exit? What does this letter say? Is the light on?
- The camera sees private things: letters, medicine, the inside of a home

Criteria: usefulness.

## 3. What exists, and the gap

| App | Platform | How it works | Gap for our users |
|---|---|---|---|
| Xiaoyi "see the world" (小艺看世界) | HarmonyOS | Cloud large model | Chinese, cloud, China only |
| Google Lookout (Find mode) | Android | Find mode with direction and distance for general categories; generative features in the cloud | Not on HarmonyOS |
| Seeing AI | iOS, Android | Text, scenes, colour, light | Not on HarmonyOS |
| Be My Eyes | iOS, Android | Sighted volunteers and an AI assistant | Not on HarmonyOS; needs a connection |

- Gap: no offline-first assistant for HarmonyOS outside China

Speaker notes: be fair. Lookout already has a find mode; our difference is the platform, offline first, and finding any named object with spoken guidance.

Criteria: originality.

## 4. Find an object

- Pick from the list or say any object (dictation through the system keyboard)
- Follow spoken guidance: "Keys in view, on the left", "Turn left.", "Hold steady.", "Move the phone closer slowly."
- "Keys are right in front of you, within reach"
- Also in the app: Describe surroundings (objects, colours, text read aloud, light status) and Find a word (EXIT, WC, PHARMACY or any typed word)

Criteria: usefulness, originality.

## 5. How it plugs into HarmonyOS (concept)

- Intents Kit: a voice entry through Xiaoyi ("find my keys")
- AccessibilityExtensionAbility: next to ScreenReader, available from any app
- Live View: search progress on the lock screen
- Same kits as today: the app is built on public kits only

Speaker notes: not implemented; today it is an ordinary app.

Criteria: platform capabilities, originality.

## 6. Phone sees, watch guides, NPU thinks (concept)

- Phone: camera and recognition
- Watch: guidance on the wrist through Wear Engine (concept)
- NPU through NNRt: the app already tries the NPU first. Real finding on a Kirin 9000S phone: both NNRt drivers return a model without inputs for our float32 graphs, so the app falls back to fp16 on the CPU (about 55 to 190 ms per frame). An NPU-ready conversion is next.

Criteria: technical execution, platform capabilities.

## 7. Demo

- Video: https://youtu.be/c6YDpCh5tAw
- Blindfold walkthrough on a real phone (see `docs/DEMO_SCRIPT.md`)

Speaker notes: let the video speak; only say what is not visible.

Criteria: demo quality, usefulness.

## 8. One search, two brains

| | Cloud | On device |
|---|---|---|
| Model | SAM 3 text-prompt segmentation (Roboflow Serverless) | YOLOv8s Open Images V7, 194 classes, MindSpore Lite |
| Finds | Any named object, keys included | 194 everyday classes, no keys or wallets |
| When | Online, Auto mode, key present | Offline, on-device only chosen, or 20 s after a failed cloud request |

- Switches mid-search without a restart and says so ("Offline. Using the on-device model.")
- A chip shows the engine; double tap to keep everything on the phone

Criteria: technical execution, originality.

## 9. Kits used

| Kit | Use |
|---|---|
| Camera Kit | Live frames, front and back camera |
| MindSpore Lite Kit | On-device detector and OCR fallback |
| Core Vision Kit | System text recognition |
| Core Speech Kit | Offline speech output |
| Accessibility Kit | Screen reader detection and announcements |
| Sensor Service Kit | Ambient light sensor only (light status in Describe) |
| Network Kit | Network state and the cloud search request |

Criteria: platform capabilities.

## 10. What works, known limits

- Works: Describe, Find an object (cloud and on-device), Find a word; tested on a Kirin 9000S phone and the emulator
- 155 unit tests for guidance, the find state machine, matching, scene sentences, colours and OCR geometry
- Known limits: keys offline not supported; distance is relative, not metric; English only; the NPU is not used yet; cloud search needs a key in the app; full screen reader walkthrough still to do
- MIT code, AGPL model, decision log and AI workflow published

Criteria: technical execution, reproducibility and transparency.

## 11. Next steps and close

- Keys offline: fine-tune the on-device detector
- NPU-ready model conversion
- System integration: accessibility extension, Intents Kit, Live View, watch through Wear Engine
- Cloud calls through our own backend instead of a key in the app
- Testing with blind users
- Repository link and QR code

Criteria: usefulness, reproducibility.

## Mapping to criteria

| Criterion | Weight | Slides |
|---|---|---|
| Originality | 20 | 3, 4, 5, 8 |
| Demonstrated usefulness | 20 | 1, 2, 4, 7, 11 |
| Technical execution | 20 | 6, 8, 10 |
| Platform capabilities | 20 | 5, 6, 9 |
| Demo quality | 10 | 7 |
| Reproducibility and transparency | 10 | 10, 11 |

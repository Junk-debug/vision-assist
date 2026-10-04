# TODO

## Submission (required by the challenge)

- [ ] `AI_WORKFLOW.md`: tools used, workflow, how output was reviewed and tested, limitations (mandatory deliverable, decide the wording)
- [ ] `docs/DECISIONS.md`: key decisions and why (offline only, YOLOv8 Open Images instead of open-vocabulary detectors, own OCR fallback, no voice input, no LLM)
- [ ] `docs/DEMO_SCRIPT.md`: blindfold demo scenario, scene by scene
- [ ] `docs/ARCHITECTURE.md`: short architecture description (also required)
- [ ] Slides
- [ ] Demo video
- [ ] Release `.hap` attached to the submission
- [ ] Replace screenshot placeholders in README with camera screenshots that show objects, not faces

## Features

- [x] Full text result screen: scrollable full OCR text and a "Read again" button (status card cuts at 4 lines)
- [x] Pick a photo from the gallery as input (Describe and Read text)
- [x] One catalogue of failure sentences, each says what happened and what to do next, with tests
- [x] Short haptic feedback on button press and when a result is ready
- [x] Vibration usage type that is not muted by "touch feedback off"

## Testing

- [ ] Debug-only frame source that feeds images from the Mac instead of the camera (no network permission in release)
- [ ] Real phone: frame rotation, front camera, system OCR, vibration, English voice, screen reader (see `docs/DEVICE.md`)
- [ ] Turn on the real screen reader and walk through every screen with swipes and double tap

## Later

- [ ] Optional cloud assist (SAM 3 or a VLM) behind a provider switch, off by default
- [ ] Rotated text support in the on-device OCR
- [ ] Fine-tune the detector on keys and wallets

# AI workflow

Vision Assist was built during HackYeah 2026 (3–4 October 2026) with heavy use of AI coding agents, and the app itself contains AI features. This file follows the "Use of AI" section of the Huawei challenge:

- **Part A**: how AI tools were used to build the app.
- **Part B**: a summary of the AI features inside the app. The full documentation (models, inference flow, data handling, failure handling, limitations, validation, privacy) is in [`docs/AI_FEATURES.md`](docs/AI_FEATURES.md).

No API keys, credentials or personal data are included here or anywhere in the repository. The only secret, the Roboflow key for cloud search, lives in a git-ignored file.

---

## Part A. AI-assisted development

### A1. Tools, models, agents, MCP servers and skills

| Kind | Name | Used for |
|---|---|---|
| Coding agent | **Claude Code** (Anthropic), CLI and the Code tab of the Claude desktop app | Most of the code, tests, documentation, model spikes, on-device debugging |
| Model | **Claude** models by Anthropic; the final session (the hybrid engine, the 640 model fix, release and documents) ran on Claude Opus 5.5 | Reasoning, code generation, review |
| Sub-agents | Claude Code sub-agents, several of them in isolated git worktrees | Parallel spikes (detector benchmarks, OCR port), documentation sweeps, reviews, while the main session kept building |
| Agent Skills (HarmonyOS) | `deveco-cli`, `ohos-app-dev`, `ohos-app-scaffold`, `hmos-arkts-knowledge-retriever`, `hmos-arkui-develop-skill`, `hmos-arkui-mvvm-pattern`, `hmos-arkui-scenario-development` | ArkTS and ArkUI API lookup in the official docs instead of guessing from memory, scaffold, build, install and logs |
| CLI driven by the agent | `devecocli` 1.3.4, `hvigorw`, `hdc` | Build, unit tests, install on the emulator and on the phone, `hilog` reading, screenshots (`snapshot_display`), UI taps (`uitest uiInput`) |
| Web tools of the agent | Web search and fetch | SAM 3 hosting options, Roboflow API schema and pricing, HarmonyOS API details |
| Artifacts | Claude artifacts | The pitch deck |
| MCP servers | None were needed for the app itself | |

Non-AI tools in the loop: DevEco Studio 6.1.1, HarmonyOS SDK API 20–24, Python 3.12 with Ultralytics, onnxruntime and onnxslim, the MindSpore Lite 2.7.0 converter in Docker under qemu, GitHub.

### A2. Main prompts, reusable instructions and configuration

Reusable instructions given to the agents in every session:

- Plain English, sentence case, concise; no marketing language and no emoji in code, UI or documents.
- One logical change per commit with a plain imperative message.
- Be honest about what is verified: anything not checked on a real phone is marked as such; facts in documents must come from the code, logs or measured numbers.
- Use the HarmonyOS skills and `devecocli` for API lookup, build and run; do not invent APIs.
- Never commit secrets; keep keys in git-ignored files.
- Accessibility first: every control must work with the system screen reader.

Representative prompts. Rows marked * are from the final sessions and close to verbatim (translated from Russian, shortened); the other rows summarise the task given in earlier sessions.

| Phase | Prompt or task | What the agent did |
|---|---|---|
| Idea | "Read the challenge PDFs and criteria, summarise them, and check which competitors exist for blind users." | Brief with the requirements, a competitor table (Xiaoyi, Lookout, Seeing AI, Be My Eyes) and a criteria mapping |
| Spike | "Benchmark open-vocabulary detectors for keys, wallet, phone, glasses on these photos and recommend one configuration." | Benchmarks of YOLO-World, YOLOE, OWLv2, LW-DETR and YOLOv8 (COCO, Open Images V7); recommended the Open Images model |
| Port | "Port the PP-OCRv4 pipeline to ArkTS following io_spec.md." | Python reference first, then the ArkTS port with numeric comparison |
| Feature | "Add find-a-word using the OCR word boxes and the existing guidance coach, with unit tests." | `FindWordFeature`, word matcher and tests |
| Debugging on the phone * | "It does not find the bottle. I took screenshots, they are on the phone." | Pulled the screenshots with `hdc`, saw that the bottle was in plain view but never detected, traced it to the 416 model plus half-resolution frames from a commit 20 minutes earlier, and proposed three fixes |
| Hybrid engine * | "Do both: the 640 model and SAM 3, switchable; find a hosting that is quick to connect." Then: "If there is internet use the cloud, if not switch to the device, and show it properly in the UI." | Picked Roboflow Serverless, wrote `Sam3Detector` and `FindEngine` with network watching, timeout and fallback, and added the engine chip with screen reader text |
| Tuning from field feedback * | "SAM 3 says 'right in front of you' while it is still about 70 cm away." | Found that box growth since acquisition fired too early for far-away SAM 3 acquisitions and raised the cloud arrival thresholds |
| Submission * | "Read all requirement documents and make a table of where we pass and where we need to improve." | The checklist that led to this file, `docs/AI_FEATURES.md`, the public repository and the release `.hap` |

Configuration: HarmonyOS skills installed in `~/.claude/skills`; DevEco SDK path through `DEVECO_SDK_HOME` for `hvigorw test`; signing material in the git-ignored `signatures/` folder.

### A3. Workflow from idea to release

1. **Ideation.** The agent read the challenge PDFs, the owner chose the idea (an offline assistant for blind users with spoken guidance to the object), and "where did I last see it" was dropped as unrealistic.
2. **Feasibility spikes.** A spike app checked camera, Core Vision Kit and text-to-speech on the emulator. Parallel spikes benchmarked detectors and prepared the PaddleOCR conversion.
3. **Architecture.** Camera source, frame normalizer, detector, tracker and narrator first; then one class per feature with shared services; text recognition behind a provider interface. Every decision went into `docs/DECISIONS.md`.
4. **Implementation.** Small steps, each built with `devecocli build`, run on the emulator with the Mac webcam and committed when it worked. The commit history shows the order (first commit Saturday 20:44, the last ones Sunday morning).
5. **Real phone (Sunday morning).** On a Kirin 9000S phone the agent installed with `hdc`, read `hilog`, measured fp16 vs fp32 (55 vs 119 ms), found that the NPU drivers load our graph without inputs, and fixed the detection regression from the 416 model.
6. **Hybrid search.** SAM 3 in the cloud for anything the user names, with automatic fallback to the on-device model.
7. **Submission.** Requirements checklist, documentation, screenshots taken from the phone with `hdc`, the demo video link, the pitch deck and the GitHub release.

### A4. How generated output was reviewed, tested and validated

- **Build and run every change.** Nothing was committed without a successful build; most changes were also run on the emulator or the phone, and failures were fixed from the logs, not by guessing.
- **Unit tests.** Hypium tests for the pure logic (`entry/src/test`, 155 test cases): guidance state machine, word matching, scene sentences, frame geometry, accessibility helpers, haptic plans, colour naming. Run with `hvigorw test`.
- **Numbers over descriptions.** Model choices were made from measured recall, scores on the owner's own photos and milliseconds on the device, not from model cards.
- **Numeric checks of converted models.** Pruned YOLO scores bit-identical to the full model; OCR recognizer 0.0018 % mean bias against onnxruntime; OCR detector cosine similarity 0.99982; OCR pipeline character accuracy 0.886 on 8 samples before the port.
- **Field check by the owner.** The owner tested Find an object with the screen reader on the phone and reported problems back as plain sentences and screenshots; the agent read those screenshots and logs before changing code.
- **Secrets check before publishing.** Before the repository was made public the agent scanned the full git history for the Roboflow key, signing files and key-like strings; none were found.
- **Honest marking.** Claims not checked on a device are marked as not verified in the README and the docs.

### A5. Known limitations, unsuccessful approaches and lessons learned

Unsuccessful or abandoned approaches:

- **Open-vocabulary detection on the device for personal items.** YOLO-World, YOLOE and OWLv2 did not find keys (0 of 12 web photos, best 0.33 on a real key photo). Watch, coin and earbuds were 0 for every YOLO open-vocabulary configuration. We switched to YOLOv8s Open Images V7 and later added SAM 3 in the cloud for keys and free text.
- **LW-DETR on Objects365** (has key and wallet classes): unusable output within the time box.
- **416x416 detector for speed.** Missed a bottle in the middle of a table on the phone and was not faster in practice; reverted to 640.
- **NPU.** Both NNRt accelerators on the Kirin 9000S return a model without usable inputs for our float32 graph; the app falls back to the CPU in fp16.
- **Phone vibration.** The haptic code exists, but on the test phone the guidance vibration could not be confirmed, so guidance is spoken and the docs do not promise vibration.
- **Core Vision Kit on the emulator.** `objectDetection` fails with 1011000002 and `textRecognition` times out; this led to our own PaddleOCR fallback.
- **English voice on the emulator.** The `en-US` voice download fails with 1002300008; the app falls back to the Chinese voice.
- **MindSpore Lite converter.** Needed graph patches (Einsum to MatMul, the DFL conv to softmax-sum, 28 HardSwish nodes rewritten as `x * clip(x + 3, 0, 6) / 6`). Without the last one the converter reported success but produced a model that ignored its input. The converter only ships for Linux x86-64 with AVX, so it ran under qemu in Docker.
- **System speech recognition for voice entry.** Not used; we rely on the system keyboard's dictation, which was faster to ship.

Lessons learned:

- Run a time-boxed spike on the target runtime before committing to a model or a system service; desk research about "supported" features was wrong twice (Core Vision on the emulator, converter op support).
- Test on the real phone early: the 416 regression and the NPU behaviour only showed up there.
- A converter "success" message is not a check; compare outputs numerically.
- Field feedback from a blind-user scenario ("it says right in front of you at 70 cm") is more useful than any synthetic test for tuning guidance.
- Keep AI-written claims tied to logs or numbers, and mark the rest as unverified.
- When a performance change lands, re-check the core scenario before moving on; the regression was found only because the owner tried the real task.

---

## Part B. AI features in the app (summary)

| Feature | Model or service | Where it runs |
|---|---|---|
| Describe surroundings, Find an object offline | YOLOv8s Open Images V7, 194 classes, MindSpore Lite, about 55 to 190 ms per frame on a Kirin 9000S CPU | Phone |
| Find an object online (any named object, keys) | SAM 3 text-prompt segmentation on Roboflow Serverless | Cloud, only when online and a key is configured |
| Text in Describe, Find a word | Core Vision Kit text recognition, or PaddleOCR PP-OCRv4 in MindSpore Lite | Phone |
| Speech | Core Speech Kit text-to-speech or the system screen reader | Phone |

- **Inference flow.** Camera frame → crop and rotate → on-device detector or SAM 3 → best match for the target → spoken guidance state machine → overlay and speech.
- **Data handling.** On the device by default and whenever offline. In cloud mode only Find an object sends frames (JPEG, about 640x360) and the target word to Roboflow over HTTPS. Nothing is stored by the app.
- **User control.** A chip on the Find screen shows and speaks the active engine; one double tap switches to on-device only.
- **Failure handling.** Timeouts, HTTP errors and invalid responses fall back to the device for the same frame; a lost network switches back without restarting the search.
- **Limitations.** No key class on the device; cloud latency depends on the network; distance is relative; English only.
- **Validation.** Device runs, numeric model checks and unit tests.

Full details: [`docs/AI_FEATURES.md`](docs/AI_FEATURES.md).

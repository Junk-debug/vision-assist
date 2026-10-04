# Demo script: blindfold walkthrough

Target length: 2 to 2.5 minutes. One presenter wears a blindfold and uses only the phone, the screen reader and the app. Everything shown must really happen; no edits inside a scene.

## Scenes

| # | Time | Scene | What the presenter does | What the phone says or does | Caption / note |
|---|---|---|---|---|---|
| 0 | 0:00-0:10 | Hook | Faces the camera: "43 million people are blind. Close your eyes." | - | Source caption: WHO / Lancet Global Health, 2020 estimate |
| 1 | 0:10-0:18 | Offline proof, then blindfold | Still without the blindfold, opens the control panel and turns on airplane mode (Wi-Fi and mobile data off), holds the phone to the camera. Then puts on the blindfold. | Airplane icon visible | "Airplane mode on. No network." |
| 2 | 0:18-0:35 | Open the app by screen reader | Screen reader already on. Swipes to the Vision Assist icon, double taps. Swipes through the tiles. | Screen reader reads "Describe surroundings, button, Hear what is in front of you, live" | "Screen reader only: swipe and double tap" |
| 3 | 0:35-0:55 | Describe surroundings | Sits at a table with a chair and a bottle. Opens Describe surroundings, double taps Start, pans slowly. | "Chair ahead, bottle on the left" (actual wording depends on the scene) | Subtitles of the spoken output |
| 4 | 0:55-1:30 | Find an object (climax) | Back, opens Find an object, picks Bottle. Moves the phone slowly, follows the vibration and the hints, reaches out and grabs the bottle. | Pulse speeds up, "Warmer. turn left", then a long vibration and "Bottle is right in front of you." | "Vibration gets faster as the bottle gets closer" |
| 5 | 1:30-1:50 | Find a word | Opens Find a word, picks EXIT, turns toward the wall, walks to the printed EXIT sign. | "Searching for exit, move the phone slowly", then "Warmer...", "EXIT is right in front of you." | Spotter walks beside the presenter |
| 6 | 1:50-2:05 | Describe surroundings (text) | Holds a letter or a parcel label, opens Describe surroundings, double taps. | Reads the printed text aloud | Use a prepared letter with no real names or addresses |
| 7 | 2:05-2:15 | Light check and colour | Light check: "The light is on. Normal indoor lighting. About N lux." Then What color is this? on a coloured object: "red" (or the actual colour). | | Quick cuts between the two are fine; no cuts inside each |
| 8 | 2:15-2:30 | Reveal | Removes the blindfold: "Everything you saw runs on the phone. No cloud." | - | Then 20-30 s technical screen (below) |

Technical screen (20-30 s, can be over the end of scene 8 or right after it):

- Diagram: Camera Kit -> frame normalizer -> YOLOv8s in MindSpore Lite / OCR -> guidance -> screen reader, speech, vibration.
- "No network permission. Frames never stored or sent."
- Kits used: Camera Kit, MindSpore Lite Kit, Core Vision Kit, Core Speech Kit, Accessibility Kit, Sensor Service Kit.
- "Detector: YOLOv8s Open Images V7, 194 classes, on device."
- Repository link.

Permanent caption during scenes 2 to 7: "Real device, airplane mode, no edits within scenes".

## Production notes

### Device

- **Plan A:** a real HarmonyOS 5 or later phone (API 20+), for example a mentor's device. Install with `docs/DEVICE.md`. Needs a Huawei debug certificate for that phone.
- **Plan B:** if no phone is available, the presenter sits at the laptop with the blindfold and holds objects up to the Mac webcam; record the emulator screen. Scenes 1 (airplane mode), 4 (vibration) and 5 (walking) change: show the status line and spoken guidance instead of vibration, say clearly that vibration is shown on screen because the emulator has no vibrator, and replace walking with holding the EXIT sheet toward the camera. Drop the "Real device" caption and write "DevEco emulator, Mac webcam, no edits within scenes".

### Objects

- Use only objects the detector finds reliably: person, bottle, mug, laptop, mobile phone, watch, chair, door.
- Do not use keys or a wallet. The model has no key or wallet class.
- Print EXIT in large letters (5 to 10 cm high), black on white paper, flat on the wall at chest height. Check that Find a word finds it from the starting position.
- Prepare the letter or parcel label with invented text only: no real names, addresses or barcodes.

### Set and safety

- Good, even light. Avoid strong backlight from a window.
- A clear path to the EXIT sign, no steps or cables.
- A spotter stays next to the presenter during every scene with the blindfold.
- No other people's faces in the shot; if a person is needed for Describe, it is a team member who agreed.

### Recording

- Two recordings at the same time: a wide camera on the presenter, and the phone's own screen recording (it records the screen reader and app speech).
- Add subtitles for all spoken output from the phone.
- Keep one honest take per scene. Cuts are only between scenes.
- Rehearse each scene 3 to 5 times before recording. Note which wording the phone actually says and use that in the subtitles.

### Things to check on the real phone before recording [verify on device]

These have not been verified on a phone yet; if one fails, adapt the scene and do not claim it:

- vibration pattern is noticeable (scene 4, 5);
- `en-US` voice is installed (download it before turning on airplane mode); otherwise rely on the screen reader voice;
- frame rotation and boxes land on objects with the back camera;
- system OCR runs (timing line shows `system`), or the on-device fallback is fast enough for scene 6;
- the screen reader reads the tiles and buttons as expected and announcements are not cut off.

## Pre-flight checklist

- [ ] Latest build installed on the demo phone; app opens to the feature list
- [ ] Camera permission already granted (no dialog during the take)
- [ ] `en-US` voice downloaded while online, then airplane mode on
- [ ] Screen reader on, speech rate set so subtitles can keep up
- [ ] Vibration on in sound and vibration settings; "touch feedback" not muted
- [ ] Phone charged above 60 %, Do Not Disturb on, notifications hidden
- [ ] Screen recording tested with audio
- [ ] Wide camera framed, focus and audio checked
- [ ] Table set: chair, bottle (and mug or laptop) in known positions
- [ ] EXIT sheet on the wall, path clear, spotter briefed
- [ ] Letter or parcel label with invented text ready
- [ ] Coloured object for the colour check ready
- [ ] Each scene rehearsed 3 to 5 times, failed setups changed
- [ ] Caption and source slide prepared (43 million: WHO / Lancet Global Health 2020)
- [ ] Technical screen ready (diagram, kits, "no network permission", repo link)

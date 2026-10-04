# Blindfold test on a real phone

One tester wears a blindfold and uses only the screen reader and speech. One sighted helper sets up each task, keeps the path safe and writes down what happens. The same run is the rehearsal for the demo video.

Plan about 30 minutes: 10 minutes of setup, 20 minutes of tasks.

## Before the blindfold (helper and tester together)

| Check | How |
|---|---|
| App installed, opens | See `docs/DEVICE.md` |
| Camera permission granted | Open any feature once and allow the camera |
| English voice available | Settings, Accessibility, text-to-speech: English voice installed. If the app speaks with a Chinese voice, note it as a finding |
| Volume | Media volume high, phone not in silent mode |
| Screen reader on and understood | Settings, Accessibility, ScreenReader. Practise for 2 minutes on the home screen: swipe right and left to move, double tap to activate, two-finger swipe to scroll |
| Offline | Turn on airplane mode. Every task below must work in airplane mode (Find an object then uses the on-device model) |
| Recording | Start the phone's screen recording; a second phone films the tester from the side |

## Props

- A wristwatch on a table with a plain surface
- A plain single-colour mug (for example blue)
- Keys (optional task 9, needs Wi-Fi and a build with cloud search)
- A printed letter: 3 to 4 lines in a large font, for example "Dear Anna, your appointment is on Monday at 10:00. Please bring your ID."
- A sheet of A4 with EXIT in letters 5 to 10 cm high, taped to a door or wall at eye level
- A bottle and a mug
- A photo of a printed label in the phone's gallery

## Tasks

The helper reads the instruction aloud, then stays silent and does not touch the phone. Start a stopwatch when the tester says "go". Stop at success or after the time limit.

| # | Instruction to the tester | Feature | Success | Time limit |
|---|---|---|---|---|
| 1 | "Open the app and find out what it can do." | Start screen, screen reader | Tester hears the app name first, then can name the three features | 1 min |
| 2 | "Is the light on in this room?" (helper sets the light) | Describe surroundings (light status at the end) | Correct answer, once with the light on and once off | 1 min |
| 3 | "Your watch is somewhere on this table. Pick it up." (helper places it off-centre) | Find an object, Watch | Tester's hand touches the watch | 2 min |
| 4 | "What colour is the mug in front of you?" (helper places the plain mug alone) | Describe surroundings (object colour) | Correct colour named | 1 min |
| 5 | "A letter came. What day is the appointment?" (helper places the letter) | Describe surroundings reads the letter, full text screen | Tester says the right day and time | 2 min |
| 6 | "Find the exit." (tester stands 3 to 4 m from the EXIT sign, facing away) | Find a word, EXIT | Tester points the phone at the sign and walks to within 1 m | 3 min |
| 7 | "What is on the table in front of you?" (helper puts a bottle and a mug) | Describe surroundings | Tester names both objects and which side each is on | 1 min |
| 8 | "Read the label in the photo in your gallery." | Describe surroundings, Use a photo instead | Tester repeats the main words of the label | 2 min |
| 9 | Optional, airplane mode off: "Your keys are on this table. Pick them up." | Find an object, Keys, cloud search | Tester hears "Online. Using cloud search." and touches the keys | 2 min |

Optional, helper only, no blindfold: switch to the front camera in Describe and check that the boxes still sit on the objects.

## What the helper writes down for each task

| Field | Notes |
|---|---|
| Result | Success, partial, failed, or stopped for safety |
| Time | Seconds to success |
| Confusing moments | Where the tester hesitated or asked "where am I?" |
| Speech | Wrong, too fast, too frequent, cut off, or in the wrong language |
| Guidance | Directions clear or confusing, too frequent or too rare, "within reach" said too early or too late |
| Screen reader | Focus started in the wrong place, element read twice, unlabelled element, could not reach a button |
| Recognition | Wrong object, missed object, misread text, boxes not on the objects |

## After the run

- Ask the tester: what was the hardest moment, what would you change first, would you use this at home?
- Copy the findings into GitHub issues.
- Mark in `docs/DEVICE.md` which of the "things to check on a real phone" are now confirmed.
- Pick the best take of each task for the demo video (`docs/DEMO_SCRIPT.md`).

## If something is wrong

| Symptom | Likely cause | Fix |
|---|---|---|
| Boxes are rotated or offset from the objects | Frame rotation differs on this phone | Change the per-camera rotation in `entry/src/main/ets/common/Config.ets`, rebuild |
| Find an object says "can only be found with cloud search" | The name is not one of the 194 on-device classes and the phone is offline or on on-device only | Pick a listed object, or go online and set the chip to Auto |
| Describe says text reading is not available, or is slow | System OCR missing; the on-device fallback is used | Note it; the fallback still works, it is just slower |
| Speech in a Chinese voice | English voice not installed | Install the English voice in the system text-to-speech settings (needs network once, before airplane mode) |
| First thing the screen reader says is not the screen title | Default focus not applied on this system version | Note the screen; it is a known risk in the Accessibility section of the README |

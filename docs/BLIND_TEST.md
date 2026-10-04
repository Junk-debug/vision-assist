# Blindfold test on a real phone

One tester wears a blindfold and uses only the screen reader, speech and vibration. One sighted helper sets up each task, keeps the path safe and writes down what happens. The same run is the rehearsal for the demo video.

Plan about 30 minutes: 10 minutes of setup, 20 minutes of tasks.

## Before the blindfold (helper and tester together)

| Check | How |
|---|---|
| App installed, opens | See `docs/DEVICE.md` |
| Camera permission granted | Open any feature once and allow the camera |
| English voice available | Settings, Accessibility, text-to-speech: English voice installed. If the app speaks with a Chinese voice, note it as a finding |
| Volume | Media volume high, phone not in silent mode (silent mode also mutes guidance vibration) |
| Screen reader on and understood | Settings, Accessibility, ScreenReader. Practise for 2 minutes on the home screen: swipe right and left to move, double tap to activate, two-finger swipe to scroll |
| Offline | Turn on airplane mode. Every task below must work in airplane mode |
| Recording | Start the phone's screen recording; a second phone films the tester from the side |

## Props

- A wristwatch on a table with a plain surface
- Two plain T-shirts in clearly different colours (for example blue and black)
- A printed letter: 3 to 4 lines in a large font, for example "Dear Anna, your appointment is on Monday at 10:00. Please bring your ID."
- A sheet of A4 with EXIT in letters 5 to 10 cm high, taped to a door or wall at eye level
- A bottle and a mug
- A photo of a printed label in the phone's gallery

## Tasks

The helper reads the instruction aloud, then stays silent and does not touch the phone. Start a stopwatch when the tester says "go". Stop at success or after the time limit.

| # | Instruction to the tester | Feature | Success | Time limit |
|---|---|---|---|---|
| 1 | "Open the app and find out what it can do." | Start screen, screen reader | Tester hears the app name first, then can name at least four features | 1 min |
| 2 | "Is the light on in this room?" (helper sets the light) | Light check | Correct answer, once with the light on and once off | 1 min |
| 3 | "Your watch is somewhere on this table. Pick it up." (helper places it off-centre) | Find an object, Watch | Tester's hand touches the watch | 2 min |
| 4 | "Which of these two T-shirts is the blue one?" (helper holds them up in turn) | Color | Correct shirt named | 1 min |
| 5 | "A letter came. What day is the appointment?" (helper places the letter) | Describe surroundings reads the letter, full text screen | Tester says the right day and time | 2 min |
| 6 | "Find the exit." (tester stands 3 to 4 m from the EXIT sign, facing away) | Find a word, EXIT | Tester points the phone at the sign and walks to within 1 m | 3 min |
| 7 | "What is on the table in front of you?" (helper puts a bottle and a mug) | Describe surroundings | Tester names both objects and which side each is on | 1 min |
| 8 | "Read the label in the photo in your gallery." | Describe surroundings, Use a photo instead | Tester repeats the main words of the label | 2 min |

Optional, helper only, no blindfold: switch to the front camera in Describe and check that the boxes still sit on the objects.

## What the helper writes down for each task

| Field | Notes |
|---|---|
| Result | Success, partial, failed, or stopped for safety |
| Time | Seconds to success |
| Confusing moments | Where the tester hesitated or asked "where am I?" |
| Speech | Wrong, too fast, too frequent, cut off, or in the wrong language |
| Vibration | Felt or not, too weak, pulses merging into one buzz near the target |
| Screen reader | Focus started in the wrong place, element read twice, unlabelled element, could not reach a button |
| Recognition | Wrong object, missed object, misread text, boxes not on the objects |

## After the run

- Ask the tester: what was the hardest moment, what would you change first, would you use this at home?
- Copy the findings into GitHub issues or `TODO.md`.
- Mark in `docs/DEVICE.md` which of the "things to check on a real phone" are now confirmed.
- Pick the best take of each task for the demo video (`docs/DEMO_SCRIPT.md`).

## If something is wrong

| Symptom | Likely cause | Fix |
|---|---|---|
| Boxes are rotated or offset from the objects | Frame rotation differs on this phone | Change the per-camera rotation in `entry/src/main/ets/common/Config.ets`, rebuild |
| No vibration in find modes | Silent mode, or the phone's vibration is off | Turn off silent mode; check Settings, Sounds and vibration |
| Describe says text reading is not available, or is slow | System OCR missing; the on-device fallback is used | Note it; the fallback still works, it is just slower |
| Speech in a Chinese voice | English voice not installed | Install the English voice in the system text-to-speech settings (needs network once, before airplane mode) |
| First thing the screen reader says is not the screen title | Default focus not applied on this system version | Note the screen; it is a known risk in the Accessibility section of the README |

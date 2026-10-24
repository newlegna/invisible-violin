# Invisible Violin — iPhone app

A native Swift iPhone app based on your browser experiment. Hold two hands in front of the front camera: one bows sideways and selects strings by height; the other bends fingers to change notes. Tracking runs on the phone through Google's MediaPipe Hand Landmarker. Audio is generated locally with AVAudioEngine.

## Open and run

1. Open **InvisibleViolin.xcodeproj** in Xcode. Let Swift Package Manager finish downloading MediaPipe.
2. Select the **InvisibleViolin** target, then **Signing & Capabilities**, and choose your Apple development team. Change the bundle identifier if Xcode requires a unique one.
3. Connect an iPhone running **iOS 16 or later**, choose it as the run destination, and press Run. Enable Developer Mode on the phone if prompted.
4. Tap **Start playing** and allow camera access. Prop the phone upright at chest height in a well-lit room; keep both hands in the image.

The simulator can show the interface, but a physical iPhone is required to evaluate camera tracking and playing latency. Internet is needed to obtain build dependencies; the built app bundles its model and requires no network connection to play.

## Playing

- The hand on the **left of the mirrored screen** controls the bow by default. **Swap bow hand** reverses the roles.
- Move the bow sideways for sound. Faster movement increases volume.
- Raise/lower the bow through the colored E, A, D, and G regions to change strings.
- Bend fingers on the other hand to choose notes. The highest bent finger wins; straighten all fingers for an open string.
- Keep hands apart. Ambiguous, crossed, or missing hands mute the instrument.
- Natural-note fingering, as requested: G string = G3 A3 B3 C4 D4; D string = D4 E4 F4 G4 A4; A string = A4 B4 C5 D5 E5; E string = E5 F5 G5 A5 B5. These are open string followed by fingers 1–4. In particular, F is natural on the D and E strings. Other violin keys/finger placements are not modeled by this preset.
- The selected note uses equal-tempered tuning with A4 = 440 Hz. There is no automatic pitch glide or vibrato. A missing hand fades the current pitch without changing it to A4.
- Finger presses use three-dimensional joint angles, with separate press/release thresholds and a 45 ms stable-pose requirement to reject brief tracking errors. Straighten unused fingers; a deliberate curl selects a finger. The screen shows the selected finger and the five notes for the active string.
- Sound fades if updates stop for more than 250 ms. Pausing, leaving the app, camera interruptions, audio interruptions, or output changes stop the session.
- Use the phone speaker or a wired audio connection when judging responsiveness; wireless audio can add delay.

## What is included

- Native UIKit interface written in Swift, portrait iPhone layout, mirrored preview and hand overlay.
- Front-camera permission flow, recovery messages, hand-swap control, current string/note display.
- Two-hand tracking using MediaPipeTasksVision and a bundled hand_landmarker.task model.
- Background serial camera processing with late-frame dropping; tracking never runs on the UI thread.
- Smoothed bow dynamics, string-boundary hysteresis, stabilized finger selection, and a monophonic natural-note map.
- A synthesized string tone, exact note pitches, attack/release smoothing and audio-thread timeout.
- A small C audio kernel with atomic parameters to keep allocation and locking out of the audio render callback; app and interaction code are Swift.
- Standalone checks for gesture behavior and the audio timeout.

## Purchase model and interface

Version 1.0 build 6 is a paid App Store download. The planned US base price is $4.99, with regional prices managed in App Store Connect. Once installed, the app includes unlimited playing. There is no demo timer, subscription, in-app unlock, or second purchase. App Store payment happens before download; development and TestFlight installations run without a payment screen.

The app includes the supplied violin logo, a three-step animated motion guide (available again through How to play), and Full Screen mode with Start/Pause and Exit controls. Privacy details are available inside the app and on the support website.

## Validation and remaining release work

See VERIFICATION.md for actual checks and submission status. The sound is synthesized. Test real-camera tracking on physical iPhones, including different lighting, hands, finger occlusion, interruption recovery and audio latency before release. The app uses a natural-note layout and is not a violin technique assessment tool. Portrait iPhone is the supported layout.

Keep the working project fully downloaded on your Mac. Opening offloaded iCloud source or dependency folders can stall Xcode; unpack this ZIP into a local development folder.

## Project structure

- `GestureInstrument.swift`: platform-independent gesture-to-note mapping.
- `CameraTracker.swift`: AVFoundation capture and MediaPipe inference.
- `ViolinAudio.swift` / `ViolinDSP.c`: audio session, source node, and synthesis.
- `ViolinViewController.swift`: interface, preview, controls, and lifecycle.
- `Resources/hand_landmarker.task`: Google's model, bundled for offline use.

Run local behavioral checks with `sh Tests/check.sh` from this folder. They don't require an iPhone or the MediaPipe dependency.

## Dependency references

The Xcode project pins the official [MediaPipe repository](https://github.com/google-ai-edge/mediapipe) at revision `fac6a4fba2ae2371e94caecfbb14dbcc25a420e8`. Its package manifest references MediaPipe Tasks 1.0.1 binary frameworks. The current [iOS setup guide](https://ai.google.dev/edge/mediapipe/solutions/setup_ios) supports Swift Package Manager; the individual [Hand Landmarker guide](https://ai.google.dev/edge/mediapipe/solutions/vision/hand_landmarker/ios) still describes CocoaPods.

The model is downloaded from [Google's versioned model storage](https://storage.googleapis.com/mediapipe-models/hand_landmarker/hand_landmarker/float16/1/hand_landmarker.task). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md) for upstream references.

## App Store archive preparation

The pinned MediaPipe Tasks 1.0.1 binaries omit CFBundleShortVersionString and CFBundleVersion. After archiving, run `sh Scripts/prepare-archive.sh /path/to/InvisibleViolin.xcarchive YOUR_SIGNING_IDENTITY` before exporting/uploading. It adds only missing version fields to the four embedded MediaPipe frameworks, re-signs the frameworks and app with your existing development identity, and verifies signatures. This changes the archive, not the package cache. Xcode applies distribution signing when exporting.

The upstream binaries do not include matching dSYM debug symbols. Apple may warn about their missing symbols; crash reports inside these libraries will have limited symbol information. Do not fabricate dSYMs.

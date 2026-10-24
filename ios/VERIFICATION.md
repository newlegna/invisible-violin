# Verification — September 21, 2026

Version 1.0 build 6 changes the purchase model to a paid download. The free allowance and all in-app purchase UI/code/tests were removed. The App Store controls payment before download; installed copies play without a time limit.

Existing behavioral checks pass for natural notes on all strings, ascending and descending finger selection, independent fingers, highest held finger, tracking jitter, hand rotation, missing hands, stale updates, sensitivity and index calibration. Audio checks measure all 17 distinct pitches at 44.1 and 48 kHz within 0.12 Hz, with direct note changes, bounded output and fadeout.

The animated guide and Full Screen enter/exit controls were visually inspected in the iPhone 17 Pro Max simulator. The simulator does not establish physical-camera accuracy or playing latency.

Build 6 passed both the signed device archive and simulator build. Its interface was inspected with no timer or purchase controls. The app's UIDeviceFamily is [1] (iPhone only).

Apple initially rejected the embedded MediaPipe Tasks 1.0.1 frameworks because they omit CFBundleShortVersionString and CFBundleVersion. Scripts/prepare-archive.sh adds those missing fields to the archive and re-signs its frameworks and app. All signatures passed strict verification. The subsequent upload completed with EXPORT SUCCEEDED / Uploaded InvisibleViolin. Apple warned that the upstream frameworks have no matching dSYM debug symbols; this was not an upload blocker.

Before launch: test the final build on a physical iPhone for camera tracking, calibration, bowing, full screen, denied camera access, and interruptions.

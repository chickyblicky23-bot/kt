# Key Trainer

A practice tool for 4-key rhythm games. You play every note yourself on D F J K.

- Patterns: streams, jumpstream, trills, random, or your own (type steps like `d f j k dj fk`)
- Adjustable BPM, note spacing (quarter/8th/16th), length and scroll speed
- Results show per-judgment counts, accuracy, max combo, and whether you tend to hit early or late

The game is silent: it shows the patterns but plays no music or clicks.
To change keys, edit `laneKeys` and `laneNames` at the top of `qml/Main.qml`.

## Getting the .exe
Push this folder to a GitHub repo (keep the `.github` and `qml` folders). The workflow builds on
Windows; download the **KeyTrainer-windows** artifact from the Actions tab and run `KeyTrainer.exe`.

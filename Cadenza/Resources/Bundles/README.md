# Bundled PDFs

PDFs here are bundled into the iOS app. This folder is gitignored.

## Setup

Set `CADENZA_BUNDLES` to your PDF directory and run the simulator:

```bash
export CADENZA_BUNDLES=~/Music/SheetMusic
python dev.py simulator
```

PDFs are synced automatically before each build. Nested directories are supported.

## Expected files for seed scenarios

- Suzuki - Cello School - Volume 1.pdf
- Suzuki - Cello School - Volume 2.pdf
- Suzuki - Cello School - Volume 3.pdf
- Essential Elements for Strings.pdf
- Cello Time Joggers.pdf
- Konzert - Joseph Haydn.pdf
- Sonata in G major.pdf

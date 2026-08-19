# concat_media

Deploy concat tooling into media library folders, then standardize and randomly concatenate clips into long combo files for playback.

## Layout

```
concat_media/
├── setup_script_files.py   # copies `concat/` into media folders
└── concat/
    ├── stdize_rand_concat.ps1
    ├── filter_complex_fhd.txt
    ├── filter_complex_fhd_nula.txt
    └── ign/                  # alternate filter presets (VR, etc.)
```

## Requirements

- Python 3
- PowerShell
- `ffmpeg.exe` on `PATH` (uses Intel QSV / D3D11VA when available)

## Deploy concat scripts

From this repo root, run:

```powershell
python setup_script_files.py
```

The script walks each configured root directory and copies the local `concat` folder into every subdirectory that contains `.mp4` files. Directories already inside a `concat` path are skipped.

Copy `root_dirs.local.example.py` to `root_dirs.local.py` (gitignored) and set your media roots:

```python
root_dirs = [
    r'X:\media\library_a',
    r'X:\media\library_b',
]
```

After deployment, a typical creator folder looks like:

```
creator_name/
├── *.mp4
├── latest/
│   ├── *.mp4
│   └── concat/          # deployed scripts
└── concat/              # deployed scripts (parent folder)
```

## Run concat pipeline

Inside a deployed `concat` folder (next to the media you want to process):

```powershell
cd X:\media\library_a\creator_name\latest\concat
.\stdize_rand_concat.ps1
```

What it does:

1. Re-encodes sibling media (`..\*`) into `standardized/` using the FHD filter graph.
2. Retries with a null-audio filter if ffmpeg produces a 0-byte file.
3. Randomly selects clips until total duration exceeds 60 minutes or 360 files (whichever comes first).
4. Writes `stdzd_file_seq.txt` and concatenates into `<parent-folder>_rand_combo.mkv` in the `concat` folder.

## Filter presets

| File | Use |
|------|-----|
| `filter_complex_fhd.txt` | Default FHD transcode |
| `filter_complex_fhd_nula.txt` | FHD transcode with null audio fallback |
| `ign/filter_complex_vr.txt` | VR variant (commented swap in script) |
| `ign/filter_complex.txt` | Legacy filter graph |

To use a VR filter, swap the `-/filter_complex` argument in `stdize_rand_concat.ps1` to point at the desired preset under `ign/`.

## Notes

- Run `setup_script_files.py` again after updating scripts in this repo; `copytree(..., dirs_exist_ok=True)` merges changes into existing deployments.
- Subfolders like `latest/` and `latest/duped/` each get their own `concat` copy when they contain `.mp4` files.
- The concat step requires Windows shell metadata for duration (property index 27); files without a duration tag are skipped from the random selection.

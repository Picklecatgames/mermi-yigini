"""Brings one of the user's recordings into the game by the PS1 sound rules (docs/ayrintilar.md
"PS1 ses düzeni", data/ses_duzeni.json). Recordings only: this cuts, repairs and shapes what the
user gave, it never makes a sound.

  python tools/ses_ekle.py <file> <kind> <name> [options]
  python tools/ses_ekle.py ~/Downloads/zombie_moans.wav zombi groan --bol
  python tools/ses_ekle.py ruzgar.wav ortam_yatak wind_day
  python tools/ses_ekle.py kurek.wav dunya shovel --vurus 0.03 --sure 0.9

What it does, in order:
  1. repair: clicks out (adeclick), clipped peaks rebuilt (adeclip), DC and rumble off (high-pass)
  2. --bol: split at silences into separate takes (each one a variant: name_01, name_02, ...);
     otherwise the leading and trailing silence is cut
  3. --vurus S: the hit (first transient) lands S seconds into the file, so a sound started on an
     animation's frame lands on it; --sure S: stretched (0.8x-1.25x, pitch kept) to S seconds
  4. mono, or a narrow stereo for beds; beds get their seam closed with a crossfade (seamless loop)
  5. PS1 colour: down to the kind's sample rate (22.05 kHz, guns 32 kHz, music 37.8 kHz like the
     PS1's XA streams; --kaba: 11.025 kHz), the kind's low-pass if it has one, and a light 12-bit
     crush (none for music); short fades in and out
  6. level: to the kind's LUFS (clips under a second: to its peak), peaks held under -1 dBFS
  7. written as ogg into the kind's folder, numbered after what is already there; a line for the
     asset list in docs/ayrintilar.md is printed (fill in the source and licence)
Needs ffmpeg on PATH.
"""
import argparse
import json
import re
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TABLE = json.loads((ROOT / "data" / "ses_duzeni.json").read_text(encoding="utf-8"))
MIN_TAKE = 0.12  # s: anything shorter after a split is a click, not a take


def ff(*args, capture=False):
    r = subprocess.run(["ffmpeg", "-hide_banner", "-nostdin", "-y", *args], capture_output=True, text=True, encoding="utf-8", errors="replace")
    if r.returncode != 0:
        sys.exit("ffmpeg failed:\n" + r.stderr[-2000:])
    return r.stderr if capture else None


def duration(path):
    r = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", str(path)], capture_output=True, text=True)
    return float(r.stdout.strip() or 0)


def loudness(path):
    """(integrated LUFS, true peak dBFS); LUFS is None when the clip is too short to gate."""
    out = ff("-i", str(path), "-af", "ebur128=peak=true", "-f", "null", "-", capture=True)
    summary = out[out.rfind("Summary:"):]
    i = re.search(r"I:\s+(-?[\d.]+) LUFS", summary)
    p = re.search(r"Peak:\s+(-?[\d.inf]+) dBFS", summary)
    lufs = float(i.group(1)) if i else None
    peak = float(p.group(1)) if p and "inf" not in p.group(1) else -90.0
    return (lufs if lufs is not None and lufs > -60 else None), peak


def takes(path, gap, floor):
    """[(start, end)] of the sound between silences."""
    out = ff("-i", str(path), "-af", f"silencedetect=n={floor}dB:d={gap}", "-f", "null", "-", capture=True)
    starts = [float(x) for x in re.findall(r"silence_start: (-?[\d.]+)", out)]
    ends = [float(x) for x in re.findall(r"silence_end: (-?[\d.]+)", out)]
    total = duration(path)
    edges, cur = [], 0.0
    for s, e in zip(starts, ends + [total]):
        if s > cur:
            edges.append((cur, s))
        cur = e
    if cur < total and len(starts) == len(ends):
        edges.append((cur, total))
    pad = 0.04  # keep the breath before and the tail after
    return [(max(a - pad, 0.0), min(b + pad, total)) for a, b in edges if b - a >= MIN_TAKE]


def onset(path, floor):
    """Seconds to the first moment above floor dB (the hit)."""
    out = ff("-i", str(path), "-af", f"silencedetect=n={floor}dB:d=0.005", "-f", "null", "-", capture=True)
    m = re.search(r"silence_start: (-?[\d.]+)\s.*?silence_end: (-?[\d.]+)", out, re.S)
    return float(m.group(2)) if m and float(m.group(1)) <= 0.001 else 0.0


def next_index(folder, name):
    used = [int(m.group(1)) for f in folder.glob(f"{name}_*.*") if (m := re.fullmatch(re.escape(name) + r"_(\d+)", f.stem))]
    return max(used, default=0) + 1


def main():
    sys.stdout.reconfigure(encoding="utf-8")  # the Turkish asset line on a Windows console
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("file")
    ap.add_argument("kind", choices=sorted(TABLE["kinds"]))
    ap.add_argument("name", help="file name in English, lower case: groan, sheet_rattle, wind_day")
    ap.add_argument("--bol", action="store_true", help="split at silences into variants")
    ap.add_argument("--sessizlik", type=float, default=0.25, help="s of silence that splits (--bol)")
    ap.add_argument("--esik", type=float, default=-45.0, help="dB under which it counts as silence")
    ap.add_argument("--en-cok", type=int, default=8, help="keep at most this many variants (the loudest)")
    ap.add_argument("--bas", type=float, default=0.0, help="use the recording from this second")
    ap.add_argument("--son", type=float, default=0.0, help="... up to this second (0: the end)")
    ap.add_argument("--vurus", type=float, default=None, help="s: put the hit this far into the file")
    ap.add_argument("--sure", type=float, default=None, help="s: stretch each take to this length")
    ap.add_argument("--kaba", action="store_true", help="11.025 kHz: rougher, for far or radio sounds")
    ap.add_argument("--ham", action="store_true", help="no 12-bit crush (keeps the rate drop)")
    ap.add_argument("--capraz", type=float, default=3.0, help="s of crossfade closing a bed's loop")
    ap.add_argument("--dene", action="store_true", help="show what would be written, write nothing")
    a = ap.parse_args()

    kind = TABLE["kinds"][a.kind]
    src = Path(a.file).expanduser()
    if not src.exists():
        sys.exit(f"no such file: {src}")
    if not re.fullmatch(r"[a-z][a-z0-9_]*", a.name):
        sys.exit("name: lower case English letters, digits and _ only (groan, sheet_rattle)")
    folder = ROOT / "assets" / kind["dir"]
    loop = kind.get("dongu", False)
    rate = 11025 if a.kaba else kind["hz"]
    work = Path(tempfile.mkdtemp(prefix="ses_ekle_"))

    # 1. repair, on the whole recording, at its own rate, 32-bit float
    cut = ["-ss", str(a.bas)] + (["-to", str(a.son)] if a.son > 0 else [])
    clean = work / "clean.wav"
    ff(*cut, "-i", str(src), "-af", "highpass=f=40,adeclick,adeclip", "-c:a", "pcm_f32le", str(clean))

    # 2. the takes
    if a.bol and not loop:
        spans = takes(clean, a.sessizlik, a.esik)
        if len(spans) > a.en_cok:  # the loudest ones
            scored = []
            for s, e in spans:
                t = work / "probe.wav"
                ff("-ss", str(s), "-to", str(e), "-i", str(clean), str(t))
                scored.append((loudness(t)[1], (s, e)))
            spans = sorted(sp for _, sp in sorted(scored, reverse=True)[: a.en_cok])
    elif loop:
        spans = [(0.0, duration(clean))]
    else:
        found = takes(clean, 0.05, a.esik)  # one take: from the first sound to the end of the last
        spans = [(found[0][0], found[-1][1])] if found else []
    if not spans:
        sys.exit("nothing above the silence threshold; try a lower --esik")

    first = next_index(folder, a.name) if not loop else 0
    written = []
    for n, (s, e) in enumerate(spans):
        take = work / f"take{n}.wav"
        chain = []
        # 3. timing
        if a.sure:
            r = (e - s) / a.sure
            if not 0.8 <= r <= 1.25:
                print(f"  take {n + 1}: {e - s:.2f} s won't stretch to {a.sure} s without sounding wrong; left as is")
            else:
                chain.append(f"atempo={r:.4f}")
        # 4. width
        chain.append("aformat=channel_layouts=mono" if kind["stereo"] == 0 else f"aformat=channel_layouts=stereo,extrastereo=m={kind['stereo']}")
        ff("-ss", str(s), "-to", str(e), "-i", str(clean), "-af", ",".join(chain), "-c:a", "pcm_f32le", str(take))
        if a.vurus is not None and not loop:
            hit = onset(take, a.esik + 15)
            shift = work / f"shift{n}.wav"
            if hit > a.vurus:
                ff("-ss", f"{hit - a.vurus:.4f}", "-i", str(take), "-c:a", "pcm_f32le", str(shift))
            else:
                ff("-i", str(take), "-af", f"adelay={int((a.vurus - hit) * 1000)}:all=1", "-c:a", "pcm_f32le", str(shift))
            take = shift
        length = duration(take)
        if loop:
            x = min(a.capraz, length / 4)
            seam = work / "seam.wav"
            ff("-i", str(take), "-filter_complex",
               f"[0]atrim=start={x},asetpts=PTS-STARTPTS[a];[0]atrim=end={x},asetpts=PTS-STARTPTS[b];[a][b]acrossfade=d={x}:c1=qsin:c2=qsin",
               "-c:a", "pcm_f32le", str(seam))
            take = seam
            length = duration(take)
        # 5. PS1 colour and fades
        fade = min(0.01, length / 10)
        colour = [f"aresample={rate}:resampler=soxr"]
        if kind.get("alcak"):
            colour.append(f"lowpass=f={kind['alcak']}:p=1")
        bits = kind.get("bit", 12)
        if bits and not a.ham:
            colour.append(f"acrusher=bits={bits}:mix=1:mode=lin:aa=1")
        if not loop:
            colour += [f"afade=t=in:d={fade:.3f}", f"afade=t=out:st={max(length - 0.06, 0):.3f}:d={min(0.06, length / 4):.3f}"]
        coloured = work / f"col{n}.wav"
        ff("-i", str(take), "-af", ",".join(colour), "-c:a", "pcm_f32le", str(coloured))
        # 6. level
        lufs, peak = loudness(coloured)
        gain = (kind["lufs"] - lufs) if lufs is not None and length >= 1.0 else (kind["tepe"] - peak)
        name = a.name if loop else f"{a.name}_{first + n:02d}"
        out = folder / f"{name}.ogg"
        if a.dene:
            print(f"  {out.relative_to(ROOT)}: {length:.2f} s, {'%.1f LUFS' % lufs if lufs else 'peak %.1f' % peak} -> {gain:+.1f} dB")
            continue
        folder.mkdir(parents=True, exist_ok=True)
        ff("-i", str(coloured), "-af", f"volume={gain:.2f}dB,alimiter=limit=0.89:level=false:attack=1:release=40",
           "-ar", str(rate), "-c:a", "libvorbis", "-q:a", "4", str(out))
        written.append(out)
        print(f"  {out.relative_to(ROOT).as_posix()}: {length:.2f} s, {gain:+.1f} dB")

    if written:
        what = f"{a.kind}/{a.name}"
        call = f'Ps1Sound.bed("{what}", self)' if loop else f'Ps1Sound.play("{what}", self)'
        print(f"\n{len(written)} file(s) into {folder.relative_to(ROOT).as_posix()}, bus {kind['bus']}. In code: {call}")
        print("Godot imports them on the next --import or editor focus. For the asset list (docs/ayrintilar.md):")
        print(f"- `{folder.relative_to(ROOT).as_posix()}/{a.name}{'' if loop else '_NN'}.ogg` ({src.name}): KAYNAK, LİSANS. "
              f"{'Döngü' if loop else str(len(written)) + ' çeşit'}, {rate} Hz, {kind['lufs']} LUFS, `{kind['bus']}`.")


if __name__ == "__main__":
    main()

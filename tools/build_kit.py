"""Build kit.bin for JamByrd from Versilian Community Sample Library (CC0) drum samples.
Usage: python3 build_kit.py <vcsl_dir> <out_file>"""
import json, struct, subprocess, sys, glob, os
import numpy as np
SR = 32000
src, out = sys.argv[1], sys.argv[2]
G = {  # group: (glob patterns, max length s)
  'kick':   (['BDrumNew_hit_v3_rr1', 'BDrumNew_hit_v5_rr*', 'BDrumNew_hit_v7_rr*'], 0.7),
  'snare':  (['Snare2_HitSN_v3_rr1', 'Snare2_HitSN_v5_rr1', 'Snare2_HitSN_v7_rr*', 'Snare2_HitSN_v9_rr*'], 0.55),
  'rim':    (['Snare3M_Xstick_v2_rr*'], 0.3),
  'hat':    (['HiHat_HitC_v*'], 0.35),
  'hatloose': (['HiHat_HitLoose_rr*'], 0.9),
  'hatopen':  (['HiHat_HitO_rr1'], 1.3),
  'ride':   (['susCymb1_hit_stick_*'], 2.0),
  'crash':  (['cymbal_crash2_*'], 3.0),
  'tomhi':  (['TomH_HitS_v*'], 0.9),
  'tomlo':  (['TomL_HitS_v*'], 1.1),
  'shaker': (['Mid_ShakerDouble_*'], 0.27),
  'tamb':   (['Tamb1_Hit_v*'], 0.7),
}
def load(path):
    raw = subprocess.run(['ffmpeg', '-v', 'error', '-i', path, '-ac', '1', '-ar', str(SR), '-f', 'f32le', '-'], capture_output=True, check=True).stdout
    return np.frombuffer(raw, dtype=np.float32).copy()
entries, pcm, off = [], [], 0
for g, (pats, maxlen) in G.items():
    files = sorted({f for p in pats for f in glob.glob(os.path.join(src, '**', p + '*.wav'), recursive=True)})
    assert files, g
    clips = []
    for f in files:
        d = load(f)
        pk = np.abs(d).max()
        on = int(np.argmax(np.abs(d) > pk * 0.05))
        d = d[max(0, on - int(SR * 0.002)):]
        n = min(len(d), int(maxlen * SR))
        d = d[:n]
        fade = min(n // 3, int(SR * 0.08))
        d[n - fade:] *= np.linspace(1, 0, fade)
        clips.append((os.path.basename(f), d, float(np.abs(d).max())))
    gmax = max(c[2] for c in clips)
    for name, d, pk in clips:
        q = np.clip(d / gmax * 0.97, -1, 1)
        i16 = (q * 32767).astype('<i2')
        entries.append({'g': g, 'vel': round(pk / gmax, 3), 'off': off, 'len': len(i16), 'src': name})
        pcm.append(i16.tobytes()); off += len(i16)
hdr = json.dumps({'sr': SR, 'license': 'CC0 - Versilian Community Sample Library (github.com/sgossner/VCSL)', 'samples': entries}).encode()
hdr += b' ' * ((8 + len(hdr)) % 2)
with open(out, 'wb') as fh:
    fh.write(b'JBKT'); fh.write(struct.pack('<I', len(hdr))); fh.write(hdr)
    for p in pcm: fh.write(p)
print(len(entries), 'samples', os.path.getsize(out) // 1024, 'KB')
for e in entries: print(e['g'], e['vel'], round(e['len'] / SR, 2), e['src'])

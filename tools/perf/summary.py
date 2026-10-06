"""Per-screen averages from a [perf] log: frames/s, UI and raster ms (avg/p90/max), and the share of frames over budget."""
import re, sys
from collections import defaultdict

rows = defaultdict(list)
pat = re.compile(r'(\d+) fps · ui avg ([\d.]+) p90 ([\d.]+) max ([\d.]+) · raster avg ([\d.]+) p90 ([\d.]+) max ([\d.]+) · slow (\d+)/(\d+) @(\d+)Hz · at (.+)')
for line in open(sys.argv[1]):
    m = pat.search(line)
    if m:
        v = list(map(float, m.groups()[:10]))
        rows[m.group(11).strip()].append(v)
print(f"{'screen':<16}{'fps':>5}{'Hz':>5}{'ui avg':>8}{'ui p90':>8}{'ui max':>8}{'ras avg':>9}{'ras p90':>9}{'ras max':>9}{'slow%':>7}")
for k, vs in rows.items():
    n = len(vs)
    a = lambda i: sum(v[i] for v in vs) / n
    mx = lambda i: max(v[i] for v in vs)
    slow = 100 * sum(v[7] for v in vs) / max(1, sum(v[8] for v in vs))
    print(f"{k:<16}{a(0):>5.0f}{a(9):>5.0f}{a(1):>8.1f}{a(2):>8.1f}{mx(3):>8.1f}{a(4):>9.1f}{a(5):>9.1f}{mx(6):>9.1f}{slow:>7.0f}")

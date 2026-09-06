"""Regenerate the static, accessible comparison from the testable sequence data."""
from pathlib import Path
import json,re,html
root=Path(__file__).resolve().parents[1]
rows=json.loads((root/'data/compound-comparison.json').read_text())
esc=html.escape
x=lambda i:85+i*99
y=lambda n:295-n*28
chart='<svg viewBox="0 0 1060 365" role="img" aria-labelledby="compound-chart-title compound-chart-desc"><title id="compound-chart-title">Operation counts: ties, a RISC-V advantage, and compound-work advantages for Tomato.</title><desc id="compound-chart-desc">Vertical axis starts at zero. Each expression has one point per architecture. Exact sequences and counts appear in the expandable rows below.</desc><text x="48" y="30" class="axis-title">Operation count · lower is fewer</text>'
for n in range(9):chart+=f'<line class="chart-grid" x1="60" x2="1010" y1="{y(n)}" y2="{y(n)}"/><text x="45" y="{y(n)+4}" text-anchor="end">{n}</text>'
for key,css in [('rv','rv'),('tomato','tomato')]:
 chart+=f'<polyline class="{css}-line" points="'+ ' '.join(f'{x(i)},{y(len(r[key]))}' for i,r in enumerate(rows))+'"/>'
 for i,r in enumerate(rows):
  n=len(r[key]); other=len(r["tomato" if key=="rv" else "rv"])
  label_offset = -14 if n>other or (n==other and key=="rv") else 21
  chart+=f'<circle class="{css}-dot" cx="{x(i)}" cy="{y(n)}" r="5"/><text x="{x(i)}" y="{y(n)+label_offset}" text-anchor="middle">{n}</text>'
labels=[['Add'],['Signed','less-than'],['Mask','+ add'],['Mask','− subtract'],['Choose'],['Majority'],['XOR3','+ AND3'],['Two','selections'],['Vote, mask','+ add'],['Two-stage','vote']]
for i,lines in enumerate(labels):
 chart+=f'<text class="expression-label" x="{x(i)}" y="325" text-anchor="middle">'+''.join(f'<tspan x="{x(i)}" dy="{0 if j==0 else 15}">{esc(line)}</tspan>' for j,line in enumerate(lines))+'</text>'
chart+='</svg>'
body='''<div class="section-label"><span>WHERE THE DATAPATH MAKES A DIFFERENCE</span><span>Base RV32I vs Tomato Dual-LUT</span></div><div class="section-heading"><h2>If I can’t win on frequency,<br/><em>I want to win on expressiveness.</em></h2><p>I want simple and complex work to take fewer steps—more useful work per ALU pass. I built the computer around a short ALU path: programmable logic muxes feed the adder directly. Simple arithmetic and compound Boolean work share that path, without a final arithmetic-versus-logic output mux. The examples below show where that saves steps—and where RV32I is more direct.</p></div><div class="comparison-takeaways"><p><strong>1 vs 1</strong><span>Addition · a tie</span></p><p><strong>1 vs 2</strong><span>Signed comparison · RV32I advantage</span></p><p><strong>8 vs 2</strong><span>Two-stage vote · Tomato advantage</span></p></div><figure class="compound-trend"><figcaption><span class="rv-key">RISC-V RV32I · instructions</span><span class="tomato-key">Tomato · ALU evaluations</span></figcaption><div class="compound-chart-scroll" tabindex="0" role="region" aria-label="Operation comparison chart; scroll horizontally on small screens">'''+chart+'''</div><p class="chart-reading-note">Expressions run left to right. Lines connect discrete examples; this is not a scaling or timing curve.</p></figure><div class="compound-compact"><div class="compound-columns"><span>Expression · expand for the steps</span><span>RV32I / Tomato</span></div>'''
for i,r in enumerate(rows):
 rv=len(r['rv']);tm=len(r['tomato']);seq=[]
 for j,t in enumerate(r['tomato'],1):
  seq.append(f"{j}. ({', '.join(t['inputs'])}) → {t['dest']}\n   F=0x{t['lutF']:02X}; G=0x{t['lutG']:02X}; carry={t['carry']}"+ ('; latch flags' if t['latchFlags'] else ''))
 body+=f'''<details class="compound-row" data-comparison="{r['id']}"><summary><span><small>{i+1:02}</small>{esc(r['label'])}</span><span><b class="rv-count">{rv}</b><i>/</i><b class="tomato-count">{tm}</b></span></summary><div class="compound-row-body"><code>{esc(r['formula'])}</code><div><p><strong>RV32I · {rv} instruction{'s' if rv!=1 else ''}</strong><code>{esc(chr(10).join(r['rv']))}</code></p><p><strong>Tomato · {tm} ALU evaluation{'s' if tm!=1 else ''}</strong><code>{esc(chr(10).join(seq))}</code></p></div><p class="sequence-explanation">{esc(r['explain'])}</p></div></details>'''
body+='''</div><p class="comparison-note">Counts are for the sequences shown—not proven minima, CPU cycles, measured speed, or compiled benchmarks. Inputs and temporary registers are assumed available; arithmetic wraps to 32 bits. Tomato rows model the Dual-LUT and flag latch, not guaranteed installed instruction-ROM entries. Register-bank setup and instruction mapping are excluded. Base RV32I excludes extensions; adding extensions can change these comparisons.</p><div class="builder-links"><a class="text-link" href="https://docs.riscv.org/reference/isa/v20260120/unpriv/rv32.html">RV32I integer operations</a><a class="text-link" href="https://github.com/tmarhguy/tomato/blob/main/hardware/fpga/core/rtl/alu.v">Tomato ALU and flags</a><a class="text-link" href="playground.html">Try the compound logic</a></div>'''
p=root/'index.html';s=p.read_text();s=re.sub(r'(<section\b[^>]*\bid="compound-work"[^>]*>).*?</section>',lambda m:m.group(1)+body+'</section>',s,count=1,flags=re.S);p.write_text(s)

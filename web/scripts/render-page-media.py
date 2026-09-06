"""Render curated interior-page media from data/page-media.json. Homepage is excluded."""
from pathlib import Path
from html import escape
import json,re,struct
ROOT=Path(__file__).resolve().parents[1]
data=json.loads((ROOT/'data/page-media.json').read_text())
for page,keys in data['pages'].items():
 if page=='index.html':raise ValueError('Homepage media is intentionally excluded')
 p=ROOT/page;s=p.read_text();prefix='../' if '/' in page else ''
 s=re.sub(r'<!-- page-media:start -->.*?<!-- page-media:end -->','',s,flags=re.S)
 cards=[]
 for key in keys:
  a=data['assets'][key];src=a['src']
  if not (ROOT/src).exists():raise FileNotFoundError(src)
  # Existing page content already illustrates this exact asset.
  if src in s:continue
  if src.endswith('.mp4'):
   media=f'<video controls muted playsinline preload="none" poster="{prefix}{a["poster"]}" aria-label="{escape(a["alt"])}"><source src="{prefix}{src}" type="video/mp4"/></video>'
  else:
   srcset=''
   if '-1280w.webp' in src and (ROOT/src.replace('-1280w','-640w')).exists():
    srcset=f' srcset="{prefix}{src.replace("-1280w","-640w")} 640w, {prefix}{src} 1280w" sizes="(max-width: 650px) 90vw, 45vw"'
   media=f'<a class="media-evidence-image" href="{prefix}{src}" aria-label="View larger: {escape(a["alt"])}"><img src="{prefix}{src}"{srcset} alt="{escape(a["alt"])}" loading="lazy" decoding="async"/></a>'
  cards.append(f'<figure>{media}<figcaption><a href="{prefix}{a["link"]}">{escape(a["title"])}</a><p>{escape(a["caption"])}</p></figcaption></figure>')
 if not cards:continue
 block='<!-- page-media:start --><section class="media-evidence project-frame" aria-labelledby="media-evidence-title"><header><p class="kicker">From the build</p><h2 id="media-evidence-title">The work behind the words.</h2></header><div class="media-evidence-grid">'+''.join(cards)+'</div></section><!-- page-media:end -->'
 s=s.replace('</main>',block+'\n</main>',1)
 if 'css/page-media.css' not in s:s=s.replace('</head>',f'<link rel="stylesheet" href="{prefix}css/page-media.css?v=1"/>\n</head>')
 p.write_text(s)
print(f'Rendered curated media for {len(data["pages"])} interior pages')

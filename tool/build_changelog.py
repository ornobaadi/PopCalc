"""Builds website/changelog.html from RELEASE_NOTES.md.

Every release's "What's new" bullets become a card; the Play Store text and
code blocks are left out. Re-run after adding a release to RELEASE_NOTES.md:

    python tool/build_changelog.py
"""

import html
import os
import re

ROOT = os.path.join(os.path.dirname(__file__), '..')
NOTES = os.path.join(ROOT, 'RELEASE_NOTES.md')
OUT = os.path.join(ROOT, 'website', 'changelog.html')

HEAD = re.compile(r'^# PopCalc v(\S+) \(build (\d+)\)(?:\s+[—-]\s+(.*))?$')


def inline(text):
    text = html.escape(text, quote=False)
    return re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', text)


def releases():
    out, cur, in_code, in_play = [], None, False, False
    for line in open(NOTES, encoding='utf-8').read().splitlines():
        m = HEAD.match(line)
        if m:
            cur = {'version': m.group(1), 'build': m.group(2),
                   'title': m.group(3) or '', 'items': []}
            out.append(cur)
            in_code = in_play = False
            continue
        if cur is None:
            continue
        if line.startswith('```'):
            in_code = not in_code
            continue
        if line.startswith('### '):
            in_play = 'play' in line.lower()
            continue
        if line.startswith('## '):
            in_play = False
            continue
        if in_code or in_play:
            continue
        if line.startswith('- '):
            cur['items'].append(inline(line[2:].strip()))
    return out


PAGE = '''<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>PopCalc · What's new</title>
<meta name="description" content="Every PopCalc release so far, newest first.">
<link rel="icon" href="assets/img/icon.svg" type="image/svg+xml">
<style>
@font-face{font-family:Bebas;src:url(assets/fonts/BebasNeue-Regular.ttf);font-display:swap}
@font-face{font-family:Inter;src:url(assets/fonts/Inter.ttf);font-weight:100 900;font-display:swap}
:root{--marigold:#FFAE00;--ink:#1F1A17;--side:#4A3A2C;--red:#E0220F;--paper:#F4F1EA;--soft:rgba(31,26,23,.68)}
*{box-sizing:border-box;margin:0}
body{background:var(--marigold);color:var(--ink);font:400 16px/1.6 Inter,system-ui,sans-serif;-webkit-font-smoothing:antialiased}
a{color:inherit}
.wrap{max-width:820px;margin:0 auto;padding:0 20px}
nav{display:flex;align-items:center;justify-content:space-between;padding:22px 0}
.brand{display:flex;align-items:center;gap:12px;text-decoration:none}
.brand img{width:36px;height:36px;border-radius:9px}
.brand span{font-family:Bebas,Impact,sans-serif;font-size:28px;letter-spacing:.04em}
nav .back{font-size:15px;font-weight:600;text-decoration:none}
h1{font-family:Bebas,Impact,sans-serif;font-weight:400;font-size:clamp(56px,12vw,110px);line-height:.9;margin:24px 0 10px;
  text-shadow:1px 1px 0 var(--side),2px 3px 0 var(--side),3px 4px 0 var(--side),4px 6px 0 var(--side),5px 7px 0 var(--side),6px 9px 0 var(--side)}
.lede{color:var(--soft);max-width:560px;margin-bottom:36px}
.release{background:var(--paper);border-radius:22px;padding:26px 26px 22px;margin-bottom:18px;box-shadow:0 6px 0 var(--side)}
.release header{display:flex;flex-wrap:wrap;align-items:baseline;gap:4px 14px;margin-bottom:12px}
.ver{font-family:Bebas,Impact,sans-serif;font-size:40px;line-height:1}
.build{font-size:13px;font-weight:600;color:var(--soft);letter-spacing:.06em;text-transform:uppercase}
.latest{background:var(--red);color:#fff;border-radius:999px;padding:2px 10px;font-size:12px;font-weight:700;letter-spacing:.08em}
.title{width:100%;font-weight:600}
ul{padding-left:20px}
li{margin:6px 0}
footer{padding:30px 0 50px;font-size:14px;color:var(--soft);display:flex;flex-wrap:wrap;gap:8px 20px;justify-content:space-between}
</style>
</head>
<body>
<div class="wrap">
  <nav>
    <a class="brand" href="index.html"><img src="assets/img/icon.svg" alt=""><span>PopCalc</span></a>
    <a class="back" href="index.html">&larr; Back to PopCalc</a>
  </nav>
  <h1>What's new</h1>
  <p class="lede">Every release since the first, newest first. {count} versions and counting.</p>
{cards}
  <footer>
    <span>PopCalc by <a href="https://ornobaadi.tech" target="_blank" rel="noopener">Ornob Aadi</a></span>
    <span><a href="privacy-policy.html">Privacy policy</a></span>
  </footer>
</div>
</body>
</html>
'''


def main():
    rs = releases()
    cards = []
    for i, r in enumerate(rs):
        items = '\n'.join(f'      <li>{it}</li>' for it in r['items'])
        latest = '<span class="latest">LATEST</span>' if i == 0 else ''
        title = f'<span class="title">{inline(r["title"])}</span>' if r['title'] else ''
        cards.append(f'''  <article class="release" id="v{r["version"]}">
    <header><span class="ver">v{r["version"]}</span><span class="build">Build {r["build"]}</span>{latest}{title}</header>
    <ul>
{items}
    </ul>
  </article>''')
    page = PAGE.replace('{count}', str(len(rs))).replace('{cards}', '\n'.join(cards))
    open(OUT, 'w', encoding='utf-8', newline='\n').write(page)
    print(f'{len(rs)} releases -> {OUT}')


if __name__ == '__main__':
    main()

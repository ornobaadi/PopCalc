"""Refreshes the currency rates that ship inside the app.

Downloads today's rates and rewrites the "bundled rates" block in
lib/core/units/currency.dart, so a fresh install converts currency with
recent numbers before it has ever been online. Run before each release:

    python tool/update_rates.py

The currencies come from the `Currency.all` list in that same file.
"""

import json
import os
import re
import sys
import urllib.request

SOURCES = [
    'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.min.json',
    'https://latest.currency-api.pages.dev/v1/currencies/usd.min.json',
]
TARGET = os.path.join(os.path.dirname(__file__), '..', 'lib', 'core', 'units', 'currency.dart')
BEGIN = '// BEGIN bundled rates'
END = '// END bundled rates'


def fetch():
    for url in SOURCES:
        try:
            request = urllib.request.Request(url, headers={'User-Agent': 'popcalc-update-rates'})
            with urllib.request.urlopen(request, timeout=20) as response:
                return json.loads(response.read().decode('utf-8'))
        except Exception as error:  # try the mirror
            print(f'  {url}: {error}')
    sys.exit('Could not download rates from any source.')


def main():
    with open(TARGET, encoding='utf-8') as f:
        source = f.read()
    codes = re.findall(r"Currency\('([A-Z]{3})',", source)
    if not codes:
        sys.exit('No currencies found in currency.dart.')

    data = fetch()
    rates = data['usd']
    missing = [c for c in codes if not isinstance(rates.get(c.lower()), (int, float)) or rates[c.lower()] <= 0]
    if missing:
        sys.exit(f'The service has no rate for: {", ".join(missing)}')

    lines = [f"{BEGIN} (written by tool/update_rates.py; do not edit by hand)",
             f"const _bundledDate = '{data['date']}';",
             'const _bundledPerUsd = <String, String>{']
    for code in codes:
        value = '1' if code == 'USD' else repr(rates[code.lower()])
        if 'e' in value.lower():
            sys.exit(f'Rate for {code} is in exponent form ({value}); handle it first.')
        lines.append(f"  '{code}': '{value}',")
    lines.append('};')
    block = '\n'.join(lines) + '\n'

    start = source.index(BEGIN)
    end = source.index(END)
    with open(TARGET, 'w', encoding='utf-8', newline='') as f:
        f.write(source[:start] + block + source[end:])
    print(f'Bundled {len(codes)} rates dated {data["date"]}.')


if __name__ == '__main__':
    main()

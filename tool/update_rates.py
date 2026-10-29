"""Refreshes the currency rates that ship inside the app.

Downloads today's rates and rewrites the "bundled rates" block in
lib/core/units/currency.dart, so a fresh install converts currency with
recent numbers before it has ever been online. Run before each release:

    python tool/update_rates.py

The currencies come from the `Currency.all` list in that same file.
"""

import datetime
import json
import os
import re
import sys
import urllib.request

SOURCES = [
    'https://open.er-api.com/v6/latest/USD',
    'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.min.json',
    'https://latest.currency-api.pages.dev/v1/currencies/usd.min.json',
]
TARGET = os.path.join(os.path.dirname(__file__), '..', 'lib', 'core', 'units', 'currency.dart')
BEGIN = '// BEGIN bundled rates'
END = '// END bundled rates'


def normalise(data):
    """Either service's response as (ISO timestamp in UTC, {code: rate})."""
    if 'rates' in data:  # open.er-api, with the hour
        if data.get('result') != 'success':
            raise ValueError('not a success response')
        at = datetime.datetime.fromtimestamp(data['time_last_update_unix'], datetime.timezone.utc)
        return at.strftime('%Y-%m-%dT%H:%M:%SZ'), {k.lower(): v for k, v in data['rates'].items()}
    return data['date'], data['usd']


def fetch():
    """Asks every source and keeps the newest, like the app does."""
    best = None
    for url in SOURCES:
        try:
            request = urllib.request.Request(url, headers={'User-Agent': 'popcalc-update-rates'})
            with urllib.request.urlopen(request, timeout=20) as response:
                date, rates = normalise(json.loads(response.read().decode('utf-8')))
            print(f'  {url}: {date}')
            if best is None or date > best[0]:
                best = (date, rates)
        except Exception as error:
            print(f'  {url}: {error}')
    if best is None:
        sys.exit('Could not download rates from any source.')
    return best


def main():
    with open(TARGET, encoding='utf-8') as f:
        source = f.read()
    codes = re.findall(r"Currency\('([A-Z]{3})',", source)
    if not codes:
        sys.exit('No currencies found in currency.dart.')

    date, rates = fetch()
    missing = [c for c in codes if not isinstance(rates.get(c.lower()), (int, float)) or rates[c.lower()] <= 0]
    if missing:
        sys.exit(f'The service has no rate for: {", ".join(missing)}')

    lines = [f"{BEGIN} (written by tool/update_rates.py; do not edit by hand)",
             f"const _bundledDate = '{date}';",
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
    print(f'Bundled {len(codes)} rates dated {date}.')


if __name__ == '__main__':
    main()

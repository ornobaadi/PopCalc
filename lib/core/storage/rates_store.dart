import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:popcalc/core/units/currency.dart';
import 'package:popcalc/core/units/units.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The only network client in the app. Overridden in tests.
final httpClientProvider = Provider<http.Client>((ref) {
  final client = http.Client();
  ref.onDispose(client.close);
  return client;
});

enum RatesStatus { idle, refreshing, updated, failed }

class RatesState {
  /// The rates currently used by the converter.
  final CurrencyRates rates;
  final RatesStatus status;

  const RatesState(this.rates, [this.status = RatesStatus.idle]);
}

final ratesProvider = StateNotifierProvider<RatesNotifier, RatesState>((ref) {
  return RatesNotifier(ref.watch(httpClientProvider));
});

/// Currency rates: the snapshot that ships with the app, replaced by newer
/// ones saved on the device. The app only goes online in [refresh], and
/// only when the user asks for it.
class RatesNotifier extends StateNotifier<RatesState> {
  RatesNotifier(this._client) : super(RatesState(CurrencyRates.bundled)) {
    _load();
  }

  final http.Client _client;

  static const _kRates = 'currency_rates_json';
  static const _timeout = Duration(seconds: 8);

  /// A public daily rates file on a CDN, and its mirror. No key, no
  /// account, and nothing about the user is sent.
  static const sources = [
    'https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/usd.min.json',
    'https://latest.currency-api.pages.dev/v1/currencies/usd.min.json',
  ];

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final saved = CurrencyRates.tryParse(prefs.getString(_kRates) ?? '');
      // After an app update the bundled snapshot may be the newer one.
      if (saved != null && saved.date.isAfter(CurrencyRates.bundled.date)) {
        _apply(saved, RatesStatus.idle);
      }
    } catch (_) {}
  }

  void _apply(CurrencyRates rates, RatesStatus status) {
    Units.setCurrencyRates(rates);
    if (mounted) state = RatesState(rates, status);
  }

  /// Downloads today's rates. On any failure the current rates stay in use.
  Future<bool> refresh() async {
    if (state.status == RatesStatus.refreshing) return false;
    state = RatesState(state.rates, RatesStatus.refreshing);

    for (final url in sources) {
      try {
        final response = await _client.get(Uri.parse(url)).timeout(_timeout);
        if (response.statusCode != 200) continue;
        final rates = CurrencyRates.tryParse(response.body);
        // Never step back to older rates than the ones in use.
        if (rates == null || rates.date.isBefore(state.rates.date)) continue;
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString(_kRates, rates.toJson());
        } catch (_) {
          // Not saved: still use them for this session.
        }
        _apply(rates, RatesStatus.updated);
        return true;
      } catch (_) {
        // Offline, timed out or blocked: try the mirror.
      }
    }
    if (mounted) state = RatesState(state.rates, RatesStatus.failed);
    return false;
  }
}

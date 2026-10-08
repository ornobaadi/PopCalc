import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:popcalc/core/haptics/app_haptics.dart';
import 'package:popcalc/core/theme/theme_tokens.dart';

const signatureAsset = 'assets/ornob-aadi-signature.png';

/// "1.2.0 (5)", read from the installed package so it never drifts from
/// `pubspec.yaml`.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  final build = info.buildNumber;
  return build.isEmpty ? info.version : '${info.version} ($build)';
});

/// Maker's mark at the bottom of the settings sheet: "handcrafted by",
/// the signature inked in the skin's accent, then the version and licences.
class SignatureFooter extends ConsumerWidget {
  final ThemeColors colors;

  const SignatureFooter({super.key, required this.colors});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final version = ref.watch(appVersionProvider).value;
    final soft = colors.inkSoft.withValues(alpha: 0.75);

    return Padding(
      padding: const EdgeInsets.fromLTRB(24.0, 36.0, 24.0, 8.0),
      child: Column(
        children: [
          Text(
            'HANDCRAFTED BY',
            style: TextStyle(
              fontFamily: 'BebasNeue',
              fontSize: 14.0,
              letterSpacing: 4.0,
              color: soft,
            ),
          ),
          const SizedBox(height: 6.0),
          _Signature(color: colors.accent),
          const SizedBox(height: 18.0),
          Text(
            version == null ? 'POPCALC' : 'POPCALC  ·  v$version',
            style: TextStyle(
              fontFamily: 'BebasNeue',
              fontSize: 16.0,
              letterSpacing: 1.5,
              color: colors.ink.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 2.0),
          Text(
            'Offline. No ads. No tracking.',
            style: TextStyle(fontFamily: 'Antonio', fontSize: 12.0, color: soft),
          ),
          TextButton(
            onPressed: () {
              AppHaptics.selectionClick();
              showLicensePage(
                context: context,
                applicationName: 'PopCalc',
                applicationVersion: version,
              );
            },
            style: TextButton.styleFrom(
              foregroundColor: soft,
              textStyle: const TextStyle(
                fontFamily: 'BebasNeue',
                fontSize: 13.0,
                letterSpacing: 1.5,
              ),
            ),
            child: const Text('LICENSES'),
          ),
        ],
      ),
    );
  }
}

/// The signature, tinted to [color]. Tapping it gives a little wiggle.
class _Signature extends StatefulWidget {
  final Color color;

  const _Signature({required this.color});

  @override
  State<_Signature> createState() => _SignatureState();
}

class _SignatureState extends State<_Signature>
    with SingleTickerProviderStateMixin {
  late final _wiggle = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  @override
  void dispose() {
    _wiggle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: 'Ornob Aadi signature',
      child: GestureDetector(
        onTap: () {
          AppHaptics.lightImpact();
          _wiggle.forward(from: 0);
        },
        child: AnimatedBuilder(
          animation: _wiggle,
          builder: (context, child) {
            // Damped swing that settles back to the resting tilt.
            final t = _wiggle.value;
            final swing = math.sin(t * math.pi * 3) * (1 - t) * 0.12;
            final pop = 1 + math.sin(t * math.pi) * 0.06;
            return Transform.rotate(
              angle: -0.05 + swing,
              child: Transform.scale(scale: pop, child: child),
            );
          },
          child: ColorFiltered(
            colorFilter: ColorFilter.mode(widget.color, BlendMode.srcIn),
            child: Image.asset(
              signatureAsset,
              height: 72.0,
              fit: BoxFit.contain,
              filterQuality: FilterQuality.medium,
            ),
          ),
        ),
      ),
    );
  }
}

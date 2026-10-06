import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:qabas/core/design_system/design_system.dart';
import 'package:qabas/core/l10n/failure_messages.dart';
import 'package:qabas/core/l10n/l10n_x.dart';
import 'package:qabas/features/auth/presentation/bloc/app_session_bloc.dart';
import 'package:qabas/features/auth/presentation/painters/splash_path_painter.dart';
import 'package:qabas/shared/presentation/brand/brand.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key, required this.warmup});
  final Future<void> warmup;
  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(vsync: this, duration: QMotion.splash);
  Timer? _minimum;
  bool _warm = false, _elapsed = false;
  @override
  void initState() {
    super.initState();
    _controller.forward();
    _minimum = Timer(QMotion.splashMinimum, () {
      _elapsed = true;
      _proceed();
    });
    unawaited(
      widget.warmup.then((_) {
        _warm = true;
        _proceed();
      }),
    );
  }

  void _proceed() {
    if (mounted && _warm && _elapsed) context.read<AppSessionBloc>().add(const SplashMinimumElapsed());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (context.reduceMotion) {
      _controller.stop();
      _controller.value = 1;
    }
  }

  @override
  void dispose() {
    _minimum?.cancel();
    _controller.dispose();
    super.dispose();
  }

  double _seg(double a, double b, [Curve curve = QMotion.emphasized]) => curve.transform(((_controller.value - a) / (b - a)).clamp(0, 1));
  @override
  Widget build(BuildContext context) => AnnotatedRegion<SystemUiOverlayStyle>(
    value: SystemUiOverlayStyle.light,
    child: Scaffold(
      backgroundColor: QColors.night950,
      body: NightSky(
        density: 1.2,
        child: BlocBuilder<AppSessionBloc, AppSessionState>(
          builder: (context, state) => AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final path = _seg(0, 0.45, Curves.easeInOutCubic);
              final flame = _seg(0.32, 0.6, QMotion.settle);
              final word = _seg(0.5, 0.78), latin = _seg(0.62, 0.88), tag = _seg(0.72, 1);
              return LayoutBuilder(
                builder: (context, box) {
                  final height = math.max(box.maxHeight, QSplash.minimumHeight);
                  final flameY = height * QSplash.flameY;
                  return SingleChildScrollView(
                    child: SizedBox(
                      height: height,
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: QBreakpoints.readingWidth),
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              Positioned.fill(child: CustomPaint(painter: SplashPathPainter(path, flameY + QSplash.pathEnd))),
                              Positioned(
                                top: flameY - QSplash.glowOffset,
                                child: Opacity(
                                  opacity: flame.clamp(0, 1),
                                  child: Glow(size: QSplash.glowSize, opacity: 0.4 * flame.clamp(0, 1)),
                                ),
                              ),
                              Positioned(
                                top: flameY - QSplash.flameOffset,
                                child: Transform.scale(
                                  scale: flame,
                                  child: const FlameMark(size: QSplash.flameSize, glow: 1.6),
                                ),
                              ),
                              Positioned(
                                top: flameY + QSplash.brandOffset,
                                left: QSpace.xl,
                                right: QSpace.xl,
                                child: Column(
                                  children: [
                                    Opacity(
                                      opacity: word,
                                      child: Transform.translate(
                                        offset: Offset(0, QSplash.wordOffset * (1 - word)),
                                        child: Text(
                                          context.l10n.commonBrandArabic,
                                          textDirection: TextDirection.rtl,
                                          style: QBrandText.splashArabic,
                                        ),
                                      ),
                                    ),
                                    Opacity(
                                      opacity: latin,
                                      child: Text(context.l10n.commonBrandLatin.toUpperCase(), style: QBrandText.splashLatin(latin)),
                                    ),
                                    const SizedBox(height: QSpace.xl),
                                    Opacity(
                                      opacity: tag,
                                      child: Text(
                                        context.l10n.commonTagline,
                                        textAlign: TextAlign.center,
                                        style: context.text.bodyMedium?.copyWith(color: QColors.softEmber.withValues(alpha: 0.7)),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (state.status == SessionStatus.failure)
                                Positioned(
                                  bottom: QSpace.xl,
                                  left: QSpace.page,
                                  right: QSpace.page,
                                  child: SafeArea(
                                    child: QCard(
                                      child: QInlineError(
                                        message: failureBody(state.failure!, context.l10n),
                                        onRetry: () => context.read<AppSessionBloc>().add(const BootstrapRetried()),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    ),
  );
}

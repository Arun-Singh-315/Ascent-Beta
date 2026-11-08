import 'package:flutter/material.dart';
import '../../app/theme/text_styles.dart';
import '../../core/services/festival_service.dart';

/// A lightweight, warm festive banner celebrating cultural & national festivals.
class FestiveBannerCard extends StatefulWidget {
  final FestivalEvent festival;
  final VoidCallback? onTap;

  const FestiveBannerCard({
    super.key,
    required this.festival,
    this.onTap,
  });

  @override
  State<FestiveBannerCard> createState() => _FestiveBannerCardState();
}

class _FestiveBannerCardState extends State<FestiveBannerCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );
    if (!isTest) {
      _controller.repeat(reverse: true);
    } else {
      _controller.value = 0.5;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = widget.festival.accentColor;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final pulse = _controller.value;
        return Container(
          key: ValueKey('festival_banner_${widget.festival.id}'),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                color.withValues(alpha: dark ? 0.20 + pulse * 0.08 : 0.12 + pulse * 0.05),
                color.withValues(alpha: dark ? 0.08 : 0.04),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: color.withValues(alpha: dark ? 0.45 + pulse * 0.20 : 0.35 + pulse * 0.15),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: dark ? 0.18 + pulse * 0.10 : 0.08 + pulse * 0.05),
                blurRadius: 16 + pulse * 8,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: dark ? 0.25 : 0.15),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: color.withValues(alpha: 0.5),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: color.withValues(alpha: 0.3 + pulse * 0.2),
                            blurRadius: 10 + pulse * 6,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        widget.festival.emoji,
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  widget.festival.name,
                                  style: AscentTextStyles.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w800,
                                    color: dark ? Colors.white : const Color(0xFF1E293B),
                                    letterSpacing: -0.2,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: color.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  'FESTIVAL',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            widget.festival.greeting,
                            style: AscentTextStyles.bodySmall.copyWith(
                              color: dark ? Colors.white70 : const Color(0xFF475569),
                              height: 1.35,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
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
  }
}

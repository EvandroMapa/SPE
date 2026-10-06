part of '../dashboard_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Card de Aba Compacto (Dividindo todo o espaço, altura: 38px)
// ─────────────────────────────────────────────────────────────────────────────
class _StageTabCard extends StatefulWidget {
  final int index;
  final int currentIndex;
  final Color badgeColor;
  final IconData icon;
  final String title;
  final int count;
  final VoidCallback onTap;

  const _StageTabCard({
    required this.index,
    required this.currentIndex,
    required this.badgeColor,
    required this.icon,
    required this.title,
    required this.count,
    required this.onTap,
  });

  @override
  State<_StageTabCard> createState() => _StageTabCardState();
}

class _StageTabCardState extends State<_StageTabCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final isSelected = widget.index == widget.currentIndex;

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          height: 38,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected
                  ? const Color(0xFF0F172A)
                  : (_isHovered
                        ? widget.badgeColor.withValues(alpha: 0.5)
                        : const Color(0xFFCBD5E1)),
              width: 1.0,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: const Color(0xFF0F172A).withValues(alpha: 0.12),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          // Sem espaço para o nome (tela estreita): só ícone e contador,
          // com o nome na dica
          child: LayoutBuilder(
            builder: (context, cons) {
              final compacto = cons.maxWidth < 120;
              final conteudo = Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.icon,
                    size: 16,
                    color: isSelected ? Colors.white : widget.badgeColor,
                  ),
                  if (!compacto) ...[
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        widget.title,
                        style: AppCss.smallBold
                            .setSize(13)
                            .setColor(
                              isSelected
                                  ? Colors.white
                                  : const Color(0xFF0F172A),
                            ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? widget.badgeColor
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      widget.count.toString(),
                      style: AppCss.minimumBold
                          .setSize(11)
                          .setColor(
                            isSelected ? Colors.white : const Color(0xFF475569),
                          ),
                    ),
                  ),
                ],
              );
              return compacto
                  ? Tooltip(message: widget.title, child: conteudo)
                  : conteudo;
            },
          ),
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Bộ thành phần giao diện dùng chung cho khu quản trị: phẳng, nhất quán, ít hiệu ứng.
class AdminUi {
  // Màu nền & bề mặt
  static const bg = Color(0xFF0A1020);
  static const sidebar = Color(0xFF0D1427);
  static const surface = Color(0xFF111A2E);
  static const surfaceAlt = Color(0xFF16213A);
  static const border = Color(0xFF223052);

  // Chữ
  static const text = Color(0xFFE8EDF5);
  static const muted = Color(0xFF9AA8C0);
  static const faint = Color(0xFF6B7A96);

  // Ngữ nghĩa
  static const accent = Color(0xFF0EA5E9);
  /// Xanh lá dành riêng cho trạng thái thành công/đã duyệt/đã xác nhận (màu chủ đạo là xanh biển).
  static const success = Color(0xFF10B981);
  static const info = Color(0xFF3B82F6);
  static const warn = Color(0xFFF59E0B);
  static const danger = Color(0xFFEF4444);
  static const violet = Color(0xFF8B5CF6);

  /// Màu cố định cho từng môn để biểu đồ luôn đồng nhất.
  static Color sportColor(String sport) {
    switch (sport) {
      case 'Pickleball':
        return info;
      case 'Cầu lông':
        return success;
      case 'Bóng đá':
        return const Color(0xFFF97316);
      case 'Tennis':
        return const Color(0xFFEAB308);
      case 'Bóng rổ':
        return const Color(0xFFEC4899);
      default:
        return faint;
    }
  }

  static BoxDecoration card({Color? color, Color? borderColor}) => BoxDecoration(
        color: color ?? surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor ?? border),
      );

  static const TextStyle title = TextStyle(color: text, fontSize: 15, fontWeight: FontWeight.w600);
  static const TextStyle subtitle = TextStyle(color: muted, fontSize: 12.5);
  static const TextStyle caption = TextStyle(color: faint, fontSize: 11.5);
}

/// Thẻ có tiêu đề (nền phẳng, viền mảnh).
class AdminCard extends StatelessWidget {
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const AdminCard({
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    required this.child,
    this.padding = const EdgeInsets.all(20),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: AdminUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title!, style: AdminUi.title),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(subtitle!, style: AdminUi.subtitle),
                      ],
                    ],
                  ),
                ),
                if (trailing != null) trailing!,
              ],
            ),
            const SizedBox(height: 18),
          ],
          child,
        ],
      ),
    );
  }
}

/// Nhãn trạng thái nhỏ.
class StatusPill extends StatelessWidget {
  final String text;
  final Color color;
  const StatusPill(this.text, this.color, {super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w600)),
    );
  }
}

/// Ô chỉ số (KPI): tên, số lớn, thay đổi so với kỳ trước (chỉ hiện khi có cơ sở so sánh).
class KpiTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  /// % thay đổi so với kỳ trước; null = không có dữ liệu kỳ trước.
  final double? change;

  /// true nếu tăng là điều xấu (ví dụ tỉ lệ hủy).
  final bool invertGood;
  final String? footnote;

  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.change,
    this.invertGood = false,
    this.footnote,
  });

  @override
  Widget build(BuildContext context) {
    final c = change;
    final up = c != null && c >= 0;
    final good = c == null ? true : (invertGood ? !up : up);
    final deltaColor = c == null || c.abs() < 0.05 ? AdminUi.faint : (good ? AdminUi.accent : AdminUi.danger);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: AdminUi.card(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(label, style: AdminUi.subtitle, maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            ],
          ),
          const SizedBox(height: 14),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: const TextStyle(
                color: AdminUi.text,
                fontSize: 26,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (c != null) ...[
                Icon(up ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded, size: 13, color: deltaColor),
                const SizedBox(width: 2),
                Text('${c.abs().toStringAsFixed(1)}%',
                    style: TextStyle(color: deltaColor, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                const Flexible(
                  child: Text('so với kỳ trước', style: AdminUi.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
              ] else
                Flexible(
                  child: Text(footnote ?? 'Chưa có kỳ trước để so sánh',
                      style: AdminUi.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Biểu đồ cột đơn giản có tooltip, nhãn thưa để không chồng chữ.
class MiniBarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final List<String> tooltips;
  final Color color;
  final double height;

  const MiniBarChart({
    super.key,
    required this.values,
    required this.labels,
    required this.tooltips,
    this.color = AdminUi.accent,
    this.height = 190,
  });

  @override
  Widget build(BuildContext context) {
    final maxV = values.isEmpty ? 0.0 : values.reduce((a, b) => a > b ? a : b);
    final n = values.length;
    final step = n <= 12 ? 1 : (n <= 24 ? 2 : 5);
    return SizedBox(
      height: height,
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (var i = 0; i < n; i++)
                  Expanded(
                    child: Tooltip(
                      message: tooltips[i],
                      child: Padding(
                        padding: EdgeInsets.symmetric(horizontal: n > 20 ? 1 : 3),
                        child: FractionallySizedBox(
                          heightFactor: maxV <= 0 ? 0.02 : (values[i] / maxV).clamp(0.02, 1.0),
                          alignment: Alignment.bottomCenter,
                          child: Container(
                            decoration: BoxDecoration(
                              color: values[i] <= 0 ? AdminUi.border : color,
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: (i % step == 0 || i == n - 1)
                      ? FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(labels[i], style: const TextStyle(color: AdminUi.faint, fontSize: 10.5)),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Dòng thanh ngang: nhãn, giá trị, tỉ lệ.
class HBarRow extends StatelessWidget {
  final String label;
  final String valueText;
  final double ratio;
  final Color color;
  final String? note;

  const HBarRow({
    super.key,
    required this.label,
    required this.valueText,
    required this.ratio,
    required this.color,
    this.note,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: const TextStyle(color: AdminUi.text, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 8),
              Text(valueText,
                  style: const TextStyle(color: AdminUi.text, fontSize: 13, fontWeight: FontWeight.w600)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.isNaN ? 0 : ratio.clamp(0.0, 1.0),
              minHeight: 6,
              backgroundColor: AdminUi.border,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          if (note != null) ...[
            const SizedBox(height: 3),
            Text(note!, style: AdminUi.caption),
          ],
        ],
      ),
    );
  }
}

/// Trạng thái rỗng: nói rõ vì sao chưa có số liệu.
class EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyHint({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AdminUi.faint, size: 28),
            const SizedBox(height: 10),
            Text(text, textAlign: TextAlign.center, style: AdminUi.subtitle),
          ],
        ),
      ),
    );
  }
}

/// Bộ chọn phân đoạn (thay cho nút gradient phát sáng).
class SegmentedTabs extends StatelessWidget {
  final List<(String key, String label)> items;
  final String selected;
  final ValueChanged<String> onChanged;
  const SegmentedTabs({super.key, required this.items, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: AdminUi.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AdminUi.border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final it in items)
            InkWell(
              onTap: () => onChanged(it.$1),
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: selected == it.$1 ? AdminUi.surfaceAlt : Colors.transparent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  it.$2,
                  style: TextStyle(
                    color: selected == it.$1 ? AdminUi.text : AdminUi.muted,
                    fontSize: 12.5,
                    fontWeight: selected == it.$1 ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

/// Emoji labels are deliberately stored as text: they work offline on Android,
/// web and desktop without adding a large image bundle to the application.
class CategoryIconCatalog {
  const CategoryIconCatalog._();

  static const groups = <String, List<String>>{
    'Food': [
      '🍲',
      '🍔',
      '🍕',
      '🍟',
      '🌯',
      '🍗',
      '🥗',
      '🍎',
      '🍓',
      '🥤',
      '☕',
      '🍰',
    ],
    'Shopping': [
      '🛍️',
      '👕',
      '👗',
      '👟',
      '💄',
      '💍',
      '🎁',
      '🧴',
      '⌚',
      '💎',
      '🧢',
      '🩳',
    ],
    'Home & life': [
      '🏠',
      '🛋️',
      '🛏️',
      '🛁',
      '🧹',
      '🪴',
      '🔑',
      '🧺',
      '📷',
      '🎮',
      '🎹',
      '🛠️',
    ],
    'Personal': [
      '👤',
      '❤️',
      '🌹',
      '🧸',
      '👨‍👩‍👧',
      '🎸',
      '🕯️',
      '💐',
      '🎯',
      '💬',
    ],
    'Education': ['🎒', '🏫', '📚', '🎓', '🧪', '🔬', '🎨', '✒️', '📐', '🤖'],
    'Transport': ['🚗', '🛵', '🏍️', '🚌', '🚕', '🚆', '✈️', '🚁', '🚢', '⛽'],
    'Health': ['💊', '🩺', '🏥', '🧠', '🦷', '💉', '❤️‍🩹', '🩹', '🏃', '🧘'],
    'Travel': ['🧳', '🏖️', '🏨', '🗺️', '📸', '🛒', '🌴', '🪂', '🚢', '🛎️'],
    'Finance': ['💵', '💰', '📈', '📊', '🏦', '💳', '💱', '🧾', '📩', '💼'],
    'Entertainment': [
      '🎬',
      '🎧',
      '🎮',
      '⚽',
      '🎳',
      '🎤',
      '🎨',
      '🎲',
      '🎟️',
      '🏆',
    ],
    'Office': ['💻', '🖥️', '📱', '🖨️', '⌨️', '📎', '📞', '🗄️', '📡', '📝'],
    'Others': ['📦', '🔎', '⚙️', '🎯', '🦋', '🚚', '📫', '⚖️', '🏅', '✨'],
  };

  static const defaults = <String, String>{
    'home & groceries': '🏠',
    'personal care': '🧴',
    'transportation & delivery': '🚗',
    'dining & hospitality': '🍲',
    'utilities & bills': '💡',
    'subscriptions': '📱',
    'inventory & supplies': '📦',
    'shop maintenance': '🛠️',
    'fees & commissions': '🧾',
    'debt payments': '💸',
    'other expense': '📌',
    'product sales': '🛍️',
    'recharge & telecom': '📱',
    'repair services': '🛠️',
    'perfume sales': '🌸',
    'service income': '💼',
    'salary & other income': '💰',
    'wallet funding': '👛',
    'other income': '💵',
    'customer receivables': '📥',
    'supplier payables': '📤',
    'wallet transfers': '🔄',
  };

  static String iconFor(String category, {String? savedIcon}) =>
      savedIcon?.trim().isNotEmpty == true
      ? savedIcon!.trim()
      : defaults[category.trim().toLowerCase()] ?? '🏷️';
}

class CategoryIconPicker extends StatelessWidget {
  const CategoryIconPicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  final String selected;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => DraggableScrollableSheet(
    expand: false,
    initialChildSize: .84,
    minChildSize: .55,
    maxChildSize: .94,
    builder: (context, scrollController) => Material(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: ListView(
        controller: scrollController,
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 32),
        children: [
          Center(
            child: Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(9),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Choose an icon',
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          const Text('Optional — choose any icon for this category.'),
          const SizedBox(height: 18),
          for (final group in CategoryIconCatalog.groups.entries) ...[
            Text(
              group.key.toUpperCase(),
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                letterSpacing: 1.1,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 6,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
              ),
              itemCount: group.value.length,
              itemBuilder: (context, index) {
                final icon = group.value[index];
                final active = icon == selected;
                return InkWell(
                  onTap: () => onSelected(icon),
                  borderRadius: BorderRadius.circular(14),
                  child: Ink(
                    decoration: BoxDecoration(
                      color: active
                          ? Theme.of(context).colorScheme.primaryContainer
                          : Theme.of(
                              context,
                            ).colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: active
                          ? Border.all(
                              color: Theme.of(context).colorScheme.primary,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Center(
                      child: Text(icon, style: const TextStyle(fontSize: 27)),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 22),
          ],
        ],
      ),
    ),
  );
}

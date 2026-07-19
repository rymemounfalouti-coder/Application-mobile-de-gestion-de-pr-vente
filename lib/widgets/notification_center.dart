import 'package:flutter/material.dart';

const notificationCenterSurface = Color(0xFFF8FAFC);
const notificationCenterCard = Colors.white;
const notificationCenterInk = Color(0xFF0F172A);
const notificationCenterMuted = Color(0xFF6F7A90);
const notificationCenterBorder = Color(0xFFE2E8F0);
const notificationCenterAccent = Color(0xFF1B7F4B);

class NotificationFilterOption<T> {
  const NotificationFilterOption({required this.value, required this.label});

  final T value;
  final String label;
}

/// Shared notification header, matching the commercial notification center.
class NotificationCenterHeader extends StatelessWidget {
  const NotificationCenterHeader({
    super.key,
    required this.onBack,
    required this.onMarkAllRead,
    required this.unreadCount,
    this.title = 'Notifications',
    this.accentColor = notificationCenterAccent,
  });

  final VoidCallback onBack;
  final VoidCallback onMarkAllRead;
  final int unreadCount;
  final String title;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 42,
          height: 42,
          child: IconButton(
            onPressed: onBack,
            padding: EdgeInsets.zero,
            icon: const Icon(Icons.arrow_back_rounded, size: 28),
            color: notificationCenterInk,
            tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: notificationCenterInk,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        TextButton(
          onPressed: unreadCount == 0 ? null : onMarkAllRead,
          style: TextButton.styleFrom(
            foregroundColor: accentColor,
            disabledForegroundColor: notificationCenterMuted,
            padding: const EdgeInsets.symmetric(horizontal: 8),
          ),
          child: const Text(
            'Tout marquer lu',
            style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

/// Shared horizontal filters used by every role's notification center.
class NotificationFilterBar<T> extends StatelessWidget {
  const NotificationFilterBar({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.accentColor = notificationCenterAccent,
  });

  final List<NotificationFilterOption<T>> options;
  final T selected;
  final ValueChanged<T> onChanged;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: options.length,
        separatorBuilder: (_, _) => const SizedBox(width: 9),
        itemBuilder: (context, index) {
          final option = options[index];
          final isSelected = option.value == selected;
          return Semantics(
            button: true,
            selected: isSelected,
            child: InkWell(
              onTap: () => onChanged(option.value),
              borderRadius: BorderRadius.circular(14),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.center,
                padding: const EdgeInsets.symmetric(horizontal: 17),
                decoration: BoxDecoration(
                  color: isSelected ? accentColor : notificationCenterCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? accentColor : notificationCenterBorder,
                  ),
                  boxShadow: [
                    if (isSelected)
                      BoxShadow(
                        color: accentColor.withValues(alpha: .18),
                        blurRadius: 16,
                        offset: const Offset(0, 8),
                      ),
                  ],
                ),
                child: Text(
                  option.label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : notificationCenterMuted,
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// A single card containing notification rows and separators, like commercial.
class NotificationCenterCardList extends StatelessWidget {
  const NotificationCenterCardList({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: notificationCenterCardDecoration(),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1)
              const Divider(height: 1, color: notificationCenterBorder),
          ],
        ],
      ),
    );
  }
}

class NotificationCenterRow extends StatelessWidget {
  const NotificationCenterRow({
    super.key,
    required this.title,
    required this.message,
    required this.timeLabel,
    required this.icon,
    required this.iconColor,
    required this.isRead,
    required this.onTap,
  });

  final String title;
  final String message;
  final String timeLabel;
  final IconData icon;
  final Color iconColor;
  final bool isRead;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$title. $message',
      hint: 'Ouvrir la notification',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                SizedBox(
                  width: 11,
                  child: isRead
                      ? const SizedBox.shrink()
                      : Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: notificationCenterAccent,
                            shape: BoxShape.circle,
                          ),
                        ),
                ),
                const SizedBox(width: 9),
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: iconColor.withValues(alpha: .11),
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(icon, color: iconColor, size: 29),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: notificationCenterInk,
                                fontSize: 15,
                                fontWeight: isRead
                                    ? FontWeight.w600
                                    : FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            timeLabel,
                            style: const TextStyle(
                              color: notificationCenterMuted,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 7),
                      Text(
                        message,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: notificationCenterMuted,
                          fontSize: 13,
                          height: 1.28,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.chevron_right_rounded,
                  color: notificationCenterMuted,
                  size: 26,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class NotificationCenterEmpty extends StatelessWidget {
  const NotificationCenterEmpty({
    super.key,
    this.title = 'Aucune notification',
    required this.message,
    this.icon = Icons.notifications_none_rounded,
    this.accentColor = notificationCenterAccent,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(24, 38, 24, 30),
      decoration: notificationCenterCardDecoration(radius: 22),
      child: Column(
        children: [
          Container(
            width: 84,
            height: 84,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: .08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accentColor, size: 42),
          ),
          const SizedBox(height: 20),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: notificationCenterInk,
              fontSize: 19,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: notificationCenterMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class NotificationDetailsSheet extends StatelessWidget {
  const NotificationDetailsSheet({
    super.key,
    required this.title,
    required this.message,
    required this.typeLabel,
    required this.timeLabel,
    required this.icon,
    required this.iconColor,
    this.action,
  });

  final String title;
  final String message;
  final String typeLabel;
  final String timeLabel;
  final IconData icon;
  final Color iconColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(22, 10, 22, 28),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 4,
                margin: const EdgeInsets.only(bottom: 18),
                decoration: BoxDecoration(
                  color: notificationCenterBorder,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(icon, color: iconColor, size: 30),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: notificationCenterInk,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: const TextStyle(
                color: notificationCenterMuted,
                fontSize: 14,
                height: 1.45,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '$typeLabel \u2022 $timeLabel',
              style: TextStyle(color: iconColor, fontWeight: FontWeight.w800),
            ),
            if (action != null) ...[
              const SizedBox(height: 22),
              SizedBox(width: double.infinity, child: action!),
            ],
          ],
        ),
      ),
    );
  }
}

BoxDecoration notificationCenterCardDecoration({double radius = 20}) {
  return BoxDecoration(
    color: notificationCenterCard,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: notificationCenterBorder),
    boxShadow: [
      BoxShadow(
        color: notificationCenterInk.withValues(alpha: .045),
        blurRadius: 18,
        offset: const Offset(0, 8),
      ),
    ],
  );
}

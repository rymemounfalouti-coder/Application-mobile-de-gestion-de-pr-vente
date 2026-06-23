import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../auth/current_user_session.dart';
import '../../l10n/app_localizations.dart';

Color _primaryBlue = Color(0xFF2563EB);
Color _textDark = Color(0xFF0F172A);
Color _textMuted = Color(0xFF64748B);
Color _surfaceBg = Color(0xFFF8FAFC);
Color _successGreen = Color(0xFF22C55E);
Color _dangerRed = Color(0xFFEF4444);
Color _warningOrange = Color(0xFFF59E0B);
Color _borderColor = Color(0xFFE2E8F0);

class NotificationPreferencesScreen extends StatefulWidget {
  NotificationPreferencesScreen({super.key});

  @override
  State<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends State<NotificationPreferencesScreen> {
  _NotificationSettings _settings = _NotificationSettings.defaults();
  bool _isLoading = true;

  String get _userKey {
    final user = CurrentUserSession.currentUser;
    if (user == null) return 'anonymous';
    return '${user.id}-${user.email.toLowerCase()}';
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final settings = await _NotificationSettingsStore.load(_userKey);
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _isLoading = false;
    });
  }

  Future<void> _updateSettings(
    _NotificationSettings Function(_NotificationSettings settings) update,
  ) async {
    final next = update(_settings);
    setState(() => _settings = next);
    await _NotificationSettingsStore.save(_userKey, next);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(context.l10n.preferencesUpdated),
          behavior: SnackBarBehavior.floating,
          duration: Duration(milliseconds: 1300),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: _surfaceBg,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final phoneWidth = constraints.maxWidth > 428
                ? 428.0
                : constraints.maxWidth;

            return Center(
              child: SizedBox(
                width: phoneWidth,
                height: constraints.maxHeight,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Color(0xFF18315E).withValues(alpha: 0.08),
                        blurRadius: 28,
                        offset: Offset(0, 14),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(28),
                    child: Column(
                      children: [
                        Expanded(
                          child: _isLoading
                              ? Center(
                                  child: CircularProgressIndicator(
                                    color: _primaryBlue,
                                  ),
                                )
                              : CustomScrollView(
                                  physics: BouncingScrollPhysics(),
                                  slivers: [
                                    SliverPadding(
                                      padding: EdgeInsets.fromLTRB(
                                        20,
                                        14,
                                        20,
                                        22,
                                      ),
                                      sliver: SliverList(
                                        delegate: SliverChildListDelegate([
                                          _buildHeader(l10n),
                                          SizedBox(height: 22),
                                          _buildIntroCard(l10n),
                                          SizedBox(height: 26),
                                          _buildSectionTitle(
                                            Icons.grid_view_rounded,
                                            l10n.notificationPreferences,
                                          ),
                                          SizedBox(height: 14),
                                          _buildSettingsCard([
                                            _PreferenceRow(
                                              icon:
                                                  Icons.shopping_cart_outlined,
                                              iconColor: _primaryBlue,
                                              iconBg: Color(0xFFEFF6FF),
                                              title: l10n.orderNotifications,
                                              subtitle: l10n
                                                  .orderNotificationsSubtitle,
                                              value:
                                                  _settings.orderNotifications,
                                              onChanged: (value) =>
                                                  _updateSettings(
                                                    (s) => s.copyWith(
                                                      orderNotifications: value,
                                                    ),
                                                  ),
                                            ),
                                            _PreferenceRow(
                                              icon: Icons.groups_2_outlined,
                                              iconColor: Color(0xFF16A34A),
                                              iconBg: Color(0xFFECFDF5),
                                              title: l10n.clientNotifications,
                                              subtitle: l10n
                                                  .clientNotificationsSubtitle,
                                              value:
                                                  _settings.clientNotifications,
                                              onChanged: (value) =>
                                                  _updateSettings(
                                                    (s) => s.copyWith(
                                                      clientNotifications:
                                                          value,
                                                    ),
                                                  ),
                                            ),
                                            _PreferenceRow(
                                              icon: Icons.settings_outlined,
                                              iconColor: Color(0xFF7C3AED),
                                              iconBg: Color(0xFFF5F3FF),
                                              title: l10n.systemNotifications,
                                              subtitle: l10n
                                                  .systemNotificationsSubtitle,
                                              value:
                                                  _settings.systemNotifications,
                                              onChanged: (value) =>
                                                  _updateSettings(
                                                    (s) => s.copyWith(
                                                      systemNotifications:
                                                          value,
                                                    ),
                                                  ),
                                            ),
                                          ]),
                                          SizedBox(height: 26),
                                          _buildSectionTitle(
                                            Icons.volume_up_outlined,
                                            l10n.audioSettings,
                                          ),
                                          SizedBox(height: 14),
                                          _buildSettingsCard([
                                            _PreferenceRow(
                                              icon: Icons.volume_up_outlined,
                                              iconColor: _warningOrange,
                                              iconBg: Color(0xFFFFF7ED),
                                              title: l10n.sounds,
                                              subtitle: l10n.soundsSubtitle,
                                              value: _settings.soundEnabled,
                                              onChanged: (value) =>
                                                  _updateSettings(
                                                    (s) => s.copyWith(
                                                      soundEnabled: value,
                                                    ),
                                                  ),
                                            ),
                                            _PreferenceRow(
                                              icon: Icons.vibration_rounded,
                                              iconColor: _dangerRed,
                                              iconBg: Color(0xFFFEF2F2),
                                              title: l10n.vibration,
                                              subtitle: l10n.vibrationSubtitle,
                                              value: _settings.vibrationEnabled,
                                              onChanged: (value) =>
                                                  _updateSettings(
                                                    (s) => s.copyWith(
                                                      vibrationEnabled: value,
                                                    ),
                                                  ),
                                            ),
                                          ]),
                                          SizedBox(height: 26),
                                          _buildSectionTitle(
                                            Icons.schedule_rounded,
                                            l10n.receiptsAndReminders,
                                          ),
                                          SizedBox(height: 14),
                                          _buildSettingsCard([
                                            _ActionRow(
                                              icon: Icons.schedule_rounded,
                                              iconColor: _primaryBlue,
                                              iconBg: Color(0xFFEFF6FF),
                                              title: l10n.quietHours,
                                              subtitle: l10n.quietHoursSubtitle,
                                              value:
                                                  '${_settings.quietHoursStart} - ${_settings.quietHoursEnd}',
                                              onTap: _openQuietHoursSheet,
                                            ),
                                            _PreferenceRow(
                                              icon:
                                                  Icons.calendar_month_outlined,
                                              iconColor: Color(0xFFD97706),
                                              iconBg: Color(0xFFFFFBEB),
                                              title: l10n.activityReminders,
                                              subtitle: l10n
                                                  .activityRemindersSubtitle,
                                              value:
                                                  _settings.activityReminders,
                                              onChanged: (value) =>
                                                  _updateSettings(
                                                    (s) => s.copyWith(
                                                      activityReminders: value,
                                                    ),
                                                  ),
                                            ),
                                          ]),
                                          SizedBox(height: 26),
                                          _buildSectionTitle(
                                            Icons.mail_outline_rounded,
                                            l10n.notificationChannels,
                                          ),
                                          SizedBox(height: 14),
                                          _buildChannels(),
                                          SizedBox(height: 20),
                                        ]),
                                      ),
                                    ),
                                  ],
                                ),
                        ),
                        _NotificationsBottomNav(onChanged: _navigateHome),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(AppLocalizations l10n) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IconButton(
          onPressed: () => Navigator.pop(context),
          icon: Icon(Icons.arrow_back_rounded),
          color: _textDark,
          style: IconButton.styleFrom(
            backgroundColor: Colors.white,
            shadowColor: Colors.black.withValues(alpha: 0.08),
            elevation: 4,
          ),
        ),
        SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.notifications,
                style: TextStyle(
                  color: _textDark,
                  fontSize: 31,
                  fontWeight: FontWeight.w900,
                  height: 1.08,
                ),
              ),
              SizedBox(height: 7),
              Text(
                l10n.notificationsSubtitle,
                style: TextStyle(
                  color: _textMuted,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildIntroCard(AppLocalizations l10n) {
    return Container(
      padding: EdgeInsets.fromLTRB(18, 18, 18, 18),
      decoration: _cardDecoration(24),
      child: Row(
        children: [
          _circleIcon(
            Icons.notifications_none_rounded,
            _primaryBlue,
            Color(0xFFEFF6FF),
            size: 62,
            iconSize: 31,
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.stayInformed,
                  style: TextStyle(
                    color: _textDark,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                SizedBox(height: 7),
                Text(
                  l10n.notificationsIntro,
                  style: TextStyle(
                    color: _textMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(width: 10),
          SizedBox(
            width: 66,
            height: 70,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 40,
                  height: 54,
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: _primaryBlue.withValues(alpha: 0.65),
                      width: 2,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                Positioned(
                  right: 8,
                  bottom: 12,
                  child: Icon(
                    Icons.notifications_active_rounded,
                    color: _primaryBlue.withValues(alpha: 0.9),
                    size: 30,
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 8,
                  child: Container(
                    width: 20,
                    height: 20,
                    decoration: BoxDecoration(
                      color: _successGreen,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, color: _primaryBlue, size: 23),
        SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              color: _textDark,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(List<Object> rows) {
    return Container(
      decoration: _cardDecoration(18),
      child: Column(
        children: List.generate(rows.length, (index) {
          final row = rows[index];
          return Column(
            children: [
              if (row is _PreferenceRow) _buildSwitchRow(row),
              if (row is _ActionRow) _buildActionRow(row),
              if (index != rows.length - 1)
                Padding(
                  padding: EdgeInsets.only(left: 82, right: 18),
                  child: Divider(
                    height: 1,
                    color: _borderColor.withValues(alpha: 0.8),
                  ),
                ),
            ],
          );
        }),
      ),
    );
  }

  Widget _buildSwitchRow(_PreferenceRow row) {
    return Padding(
      padding: EdgeInsets.fromLTRB(18, 16, 14, 16),
      child: Row(
        children: [
          _circleIcon(row.icon, row.iconColor, row.iconBg),
          SizedBox(width: 14),
          Expanded(child: _rowText(row.title, row.subtitle)),
          Switch(
            value: row.value,
            onChanged: row.onChanged,
            activeThumbColor: Colors.white,
            activeTrackColor: _primaryBlue,
            inactiveThumbColor: Colors.white,
            inactiveTrackColor: Color(0xFFCBD5E1),
          ),
          Icon(Icons.chevron_right_rounded, color: _textDark, size: 25),
        ],
      ),
    );
  }

  Widget _buildActionRow(_ActionRow row) {
    return InkWell(
      onTap: row.onTap,
      borderRadius: BorderRadius.circular(18),
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 16, 14, 16),
        child: Row(
          children: [
            _circleIcon(row.icon, row.iconColor, row.iconBg),
            SizedBox(width: 14),
            Expanded(child: _rowText(row.title, row.subtitle)),
            SizedBox(width: 10),
            Text(
              row.value,
              style: TextStyle(
                color: _primaryBlue,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.chevron_right_rounded, color: _textDark, size: 25),
          ],
        ),
      ),
    );
  }

  Widget _rowText(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: _textDark,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(
            color: _textMuted,
            fontSize: 13,
            fontWeight: FontWeight.w600,
            height: 1.35,
          ),
        ),
      ],
    );
  }

  Widget _buildChannels() {
    final channels = [
      _ChannelRow(
        title: context.l10n.push,
        icon: Icons.phone_iphone_rounded,
        enabled: _settings.pushEnabled,
        onTap: () => _openChannelSheet(
          title: context.l10n.push,
          enabled: _settings.pushEnabled,
          onChanged: (value) =>
              _updateSettings((s) => s.copyWith(pushEnabled: value)),
        ),
      ),
      _ChannelRow(
        title: context.l10n.email,
        icon: Icons.mail_outline_rounded,
        enabled: _settings.emailEnabled,
        onTap: () => _openChannelSheet(
          title: context.l10n.email,
          enabled: _settings.emailEnabled,
          onChanged: (value) =>
              _updateSettings((s) => s.copyWith(emailEnabled: value)),
        ),
      ),
      _ChannelRow(
        title: context.l10n.sms,
        icon: Icons.sms_outlined,
        enabled: _settings.smsEnabled,
        onTap: () => _openChannelSheet(
          title: context.l10n.sms,
          enabled: _settings.smsEnabled,
          onChanged: (value) =>
              _updateSettings((s) => s.copyWith(smsEnabled: value)),
        ),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 350) {
          return Column(
            children: [
              for (var i = 0; i < channels.length; i++) ...[
                _buildChannelCard(channels[i]),
                if (i != channels.length - 1) SizedBox(height: 12),
              ],
            ],
          );
        }

        return Row(
          children: [
            for (var i = 0; i < channels.length; i++) ...[
              Expanded(child: _buildChannelCard(channels[i])),
              if (i != channels.length - 1) SizedBox(width: 12),
            ],
          ],
        );
      },
    );
  }

  Widget _buildChannelCard(_ChannelRow channel) {
    return InkWell(
      onTap: channel.onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: BoxConstraints(minHeight: 112),
        padding: EdgeInsets.fromLTRB(12, 15, 10, 15),
        decoration: _cardDecoration(14),
        child: Row(
          children: [
            _circleIcon(
              channel.icon,
              _primaryBlue,
              Color(0xFFEFF6FF),
              size: 42,
              iconSize: 22,
            ),
            SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    channel.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: _textDark,
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  SizedBox(height: 5),
                  Text(
                    channel.enabled
                        ? context.l10n.enabled
                        : context.l10n.disabled,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: channel.enabled ? _successGreen : _dangerRed,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: _textDark, size: 22),
          ],
        ),
      ),
    );
  }

  Future<void> _openQuietHoursSheet() async {
    TimeOfDay start = _parseTime(_settings.quietHoursStart);
    TimeOfDay end = _parseTime(_settings.quietHoursEnd);

    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            Future<void> pickStart() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: start,
              );
              if (picked != null) setModalState(() => start = picked);
            }

            Future<void> pickEnd() async {
              final picked = await showTimePicker(
                context: context,
                initialTime: end,
              );
              if (picked != null) setModalState(() => end = picked);
            }

            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(22, 18, 22, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      context.l10n.quietHours,
                      style: TextStyle(
                        color: _textDark,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 16),
                    _timeTile(
                      context.l10n.startTime,
                      _formatTime(start),
                      pickStart,
                    ),
                    SizedBox(height: 10),
                    _timeTile(context.l10n.endTime, _formatTime(end), pickEnd),
                    SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          _updateSettings(
                            (s) => s.copyWith(
                              quietHoursStart: _formatTime(start),
                              quietHoursEnd: _formatTime(end),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          context.l10n.save,
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _timeTile(String label, String value, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: _surfaceBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _borderColor),
        ),
        child: Row(
          children: [
            Icon(Icons.schedule_rounded, color: _primaryBlue),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: _textDark,
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                color: _primaryBlue,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openChannelSheet({
    required String title,
    required bool enabled,
    required ValueChanged<bool> onChanged,
  }) {
    bool selected = enabled;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return SafeArea(
              child: Padding(
                padding: EdgeInsets.fromLTRB(22, 18, 22, 24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${context.l10n.channel} $title',
                      style: TextStyle(
                        color: _textDark,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      value: selected,
                      onChanged: (value) =>
                          setModalState(() => selected = value),
                      activeThumbColor: Colors.white,
                      activeTrackColor: _primaryBlue,
                      title: Text(
                        selected ? context.l10n.enabled : context.l10n.disabled,
                        style: TextStyle(
                          color: _textDark,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      subtitle: Text(
                        selected
                            ? '${context.l10n.receiveNotificationsBy} $title'
                            : '${context.l10n.doNotReceiveNotificationsBy} $title',
                        style: TextStyle(
                          color: _textMuted,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    SizedBox(height: 14),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          onChanged(selected);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _primaryBlue,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          context.l10n.apply,
                          style: TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    if (parts.length != 2) return TimeOfDay(hour: 22, minute: 0);
    return TimeOfDay(
      hour: int.tryParse(parts[0])?.clamp(0, 23) ?? 22,
      minute: int.tryParse(parts[1])?.clamp(0, 59) ?? 0,
    );
  }

  String _formatTime(TimeOfDay time) {
    final hour = time.hour.toString().padLeft(2, '0');
    final minute = time.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  void _navigateHome(int index) {
    if (index == 4) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushNamedAndRemoveUntil(
      context,
      '/home-commercial',
      (route) => false,
      arguments: {'initialIndex': index},
    );
  }
}

class _NotificationSettings {
  _NotificationSettings({
    required this.orderNotifications,
    required this.clientNotifications,
    required this.systemNotifications,
    required this.soundEnabled,
    required this.vibrationEnabled,
    required this.quietHoursStart,
    required this.quietHoursEnd,
    required this.activityReminders,
    required this.pushEnabled,
    required this.emailEnabled,
    required this.smsEnabled,
  });

  factory _NotificationSettings.defaults() {
    return _NotificationSettings(
      orderNotifications: true,
      clientNotifications: true,
      systemNotifications: true,
      soundEnabled: true,
      vibrationEnabled: true,
      quietHoursStart: '22:00',
      quietHoursEnd: '07:00',
      activityReminders: true,
      pushEnabled: true,
      emailEnabled: true,
      smsEnabled: false,
    );
  }

  factory _NotificationSettings.fromJson(Map<String, dynamic> json) {
    final defaults = _NotificationSettings.defaults();
    return _NotificationSettings(
      orderNotifications:
          json['orderNotifications'] as bool? ?? defaults.orderNotifications,
      clientNotifications:
          json['clientNotifications'] as bool? ?? defaults.clientNotifications,
      systemNotifications:
          json['systemNotifications'] as bool? ?? defaults.systemNotifications,
      soundEnabled: json['soundEnabled'] as bool? ?? defaults.soundEnabled,
      vibrationEnabled:
          json['vibrationEnabled'] as bool? ?? defaults.vibrationEnabled,
      quietHoursStart:
          json['quietHoursStart'] as String? ?? defaults.quietHoursStart,
      quietHoursEnd: json['quietHoursEnd'] as String? ?? defaults.quietHoursEnd,
      activityReminders:
          json['activityReminders'] as bool? ?? defaults.activityReminders,
      pushEnabled: json['pushEnabled'] as bool? ?? defaults.pushEnabled,
      emailEnabled: json['emailEnabled'] as bool? ?? defaults.emailEnabled,
      smsEnabled: json['smsEnabled'] as bool? ?? defaults.smsEnabled,
    );
  }

  final bool orderNotifications;
  final bool clientNotifications;
  final bool systemNotifications;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final String quietHoursStart;
  final String quietHoursEnd;
  final bool activityReminders;
  final bool pushEnabled;
  final bool emailEnabled;
  final bool smsEnabled;

  Map<String, dynamic> toJson() {
    return {
      'orderNotifications': orderNotifications,
      'clientNotifications': clientNotifications,
      'systemNotifications': systemNotifications,
      'soundEnabled': soundEnabled,
      'vibrationEnabled': vibrationEnabled,
      'quietHoursStart': quietHoursStart,
      'quietHoursEnd': quietHoursEnd,
      'activityReminders': activityReminders,
      'pushEnabled': pushEnabled,
      'emailEnabled': emailEnabled,
      'smsEnabled': smsEnabled,
    };
  }

  _NotificationSettings copyWith({
    bool? orderNotifications,
    bool? clientNotifications,
    bool? systemNotifications,
    bool? soundEnabled,
    bool? vibrationEnabled,
    String? quietHoursStart,
    String? quietHoursEnd,
    bool? activityReminders,
    bool? pushEnabled,
    bool? emailEnabled,
    bool? smsEnabled,
  }) {
    return _NotificationSettings(
      orderNotifications: orderNotifications ?? this.orderNotifications,
      clientNotifications: clientNotifications ?? this.clientNotifications,
      systemNotifications: systemNotifications ?? this.systemNotifications,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      quietHoursStart: quietHoursStart ?? this.quietHoursStart,
      quietHoursEnd: quietHoursEnd ?? this.quietHoursEnd,
      activityReminders: activityReminders ?? this.activityReminders,
      pushEnabled: pushEnabled ?? this.pushEnabled,
      emailEnabled: emailEnabled ?? this.emailEnabled,
      smsEnabled: smsEnabled ?? this.smsEnabled,
    );
  }
}

class _NotificationSettingsStore {
  _NotificationSettingsStore._();

  static Future<_NotificationSettings> load(String userKey) async {
    try {
      final file = await _file();
      if (!await file.exists()) return _NotificationSettings.defaults();
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, dynamic>) {
        return _NotificationSettings.defaults();
      }
      final userSettings = decoded[userKey];
      if (userSettings is! Map<String, dynamic>) {
        return _NotificationSettings.defaults();
      }
      return _NotificationSettings.fromJson(userSettings);
    } catch (_) {
      return _NotificationSettings.defaults();
    }
  }

  static Future<void> save(
    String userKey,
    _NotificationSettings settings,
  ) async {
    final file = await _file();
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }

    var allSettings = <String, dynamic>{};
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, dynamic>) allSettings = decoded;
      } catch (_) {
        allSettings = <String, dynamic>{};
      }
    }

    allSettings[userKey] = settings.toJson();
    await file.writeAsString(JsonEncoder.withIndent('  ').convert(allSettings));
  }

  static Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File(
      '${directory.path}${Platform.pathSeparator}notification_settings.json',
    );
  }
}

class _PreferenceRow {
  _PreferenceRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;
}

class _ActionRow {
  _ActionRow({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final String value;
  final VoidCallback onTap;
}

class _ChannelRow {
  _ChannelRow({
    required this.title,
    required this.icon,
    required this.enabled,
    required this.onTap,
  });

  final String title;
  final IconData icon;
  final bool enabled;
  final VoidCallback onTap;
}

class _NotificationsBottomNav extends StatelessWidget {
  _NotificationsBottomNav({required this.onChanged});

  final ValueChanged<int> onChanged;

  static final _icons = [
    Icons.home_outlined,
    Icons.groups_outlined,
    Icons.receipt_long_outlined,
    Icons.pie_chart_outline_rounded,
    Icons.person_outline_rounded,
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = [
      l10n.home,
      l10n.clients,
      l10n.orders,
      l10n.activities,
      l10n.profile,
    ];

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        boxShadow: [
          BoxShadow(
            color: Color(0xFF18315E).withValues(alpha: 0.09),
            blurRadius: 20,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 72,
          child: Row(
            children: [
              for (var i = 0; i < labels.length; i++)
                Expanded(
                  child: InkWell(
                    onTap: () => onChanged(i),
                    child: Padding(
                      padding: EdgeInsets.only(top: 9),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _icons[i],
                            color: i == 4 ? _primaryBlue : _textMuted,
                            size: 24,
                          ),
                          SizedBox(height: 4),
                          Text(
                            labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: i == 4 ? _primaryBlue : _textMuted,
                              fontSize: 11,
                              fontWeight: i == 4
                                  ? FontWeight.w900
                                  : FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

BoxDecoration _cardDecoration(double radius) {
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: _borderColor.withValues(alpha: 0.55)),
    boxShadow: [
      BoxShadow(
        color: _textDark.withValues(alpha: 0.06),
        blurRadius: 18,
        offset: Offset(0, 8),
      ),
    ],
  );
}

Widget _circleIcon(
  IconData icon,
  Color color,
  Color background, {
  double size = 52,
  double iconSize = 26,
}) {
  return Container(
    width: size,
    height: size,
    decoration: BoxDecoration(color: background, shape: BoxShape.circle),
    child: Icon(icon, color: color, size: iconSize),
  );
}

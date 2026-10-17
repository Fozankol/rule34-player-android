import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/settings_provider.dart';
import '../providers/feed_provider.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _blacklistController = TextEditingController();
  late TextEditingController _userIdController;
  late TextEditingController _apiKeyController;
  bool _isInit = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInit) {
      final settings = context.read<SettingsProvider>().settings;
      _userIdController = TextEditingController(text: settings.r34UserId);
      _apiKeyController = TextEditingController(text: settings.r34ApiKey);
      _isInit = true;
    }
  }

  @override
  void dispose() {
    _blacklistController.dispose();
    _userIdController.dispose();
    _apiKeyController.dispose();
    super.dispose();
  }

  void _addBlacklistTag() {
    final text = _blacklistController.text.trim();
    if (text.isNotEmpty) {
      context.read<SettingsProvider>().addBlacklistTag(text);
      context.read<FeedProvider>().updateBlacklist(
            context.read<SettingsProvider>().settings.blacklistedTags,
          );
      _blacklistController.clear();
    }
  }

  void _saveApiKeys() {
    final provider = context.read<SettingsProvider>();
    final newSettings = provider.settings.copyWith(
      r34UserId: _userIdController.text.trim(),
      r34ApiKey: _apiKeyController.text.trim(),
    );
    provider.updateSettings(newSettings);
    context.read<FeedProvider>().loadInitial();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ключи сохранены! Лента обновлена.'),
        backgroundColor: Color(0xFF00C853),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final settings = settingsProvider.settings;

    return Scaffold(
      backgroundColor: const Color(0xFF141419),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1F1F28),
        title: const Text(
          'Настройки',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(vertical: 16),
        children: [
          // Section: Source Selector
          _buildSectionHeader('ИСТОЧНИК КАТАЛОГА (SOURCE)'),
          Container(
            color: const Color(0xFF1B1B24),
            child: Column(
              children: [
                _buildRadioTile(
                  title: 'Rule34.xxx',
                  subtitle: 'Основной сайт (требуется бесплатный API-ключ)',
                  value: 'rule34',
                  groupValue: settings.booruSource,
                  onChanged: (val) {
                    settingsProvider.updateSettings(
                      settings.copyWith(booruSource: val),
                    );
                    context.read<FeedProvider>().loadInitial();
                  },
                ),
                _buildRadioTile(
                  title: 'Realbooru',
                  subtitle: 'Работает БЕЗ ключа (видео и фото, встроенный обход хотлинка)',
                  value: 'realbooru',
                  groupValue: settings.booruSource,
                  onChanged: (val) {
                    settingsProvider.updateSettings(
                      settings.copyWith(booruSource: val),
                    );
                    context.read<FeedProvider>().loadInitial();
                  },
                ),
                _buildRadioTile(
                  title: 'TBIB (The "Big Idols" Booru)',
                  subtitle: 'Работает сразу БЕЗ ключа (видео и анимации)',
                  value: 'tbib',
                  groupValue: settings.booruSource,
                  onChanged: (val) {
                    settingsProvider.updateSettings(
                      settings.copyWith(booruSource: val),
                    );
                    context.read<FeedProvider>().loadInitial();
                  },
                ),
                _buildRadioTile(
                  title: 'Safebooru',
                  subtitle: 'Работает сразу БЕЗ ключа (безопасный контент)',
                  value: 'safebooru',
                  groupValue: settings.booruSource,
                  onChanged: (val) {
                    settingsProvider.updateSettings(
                      settings.copyWith(booruSource: val),
                    );
                    context.read<FeedProvider>().loadInitial();
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Rule34 API Authentication
          _buildSectionHeader('АВТОРИЗАЦИЯ RULE34.XXX API'),
          Container(
            color: const Color(0xFF1B1B24),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF282834),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.amberAccent.withOpacity(0.4)),
                  ),
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Зачем нужен API-ключ?',
                        style: TextStyle(
                          color: Colors.amberAccent,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Сайт rule34.xxx закрыл публичный доступ к API и требует личный бесплатный ключ для каждого пользователя.\n\n'
                        'Как получить ключ за 10 секунд:\n'
                        '1. Зайдите на сайт rule34.xxx и создайте аккаунт (почта не нужна, только логин и пароль).\n'
                        '2. Перейдите в раздел Account -> Options.\n'
                        '3. Скопируйте свой User ID и API Key и вставьте в поля ниже.',
                        style: TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: _userIdController,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'User ID (например: 1234567)',
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: const Color(0xFF282834),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _apiKeyController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'API Key (длинный код из Options)',
                    labelStyle: const TextStyle(color: Colors.white60),
                    filled: true,
                    fillColor: const Color(0xFF282834),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00C853),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    icon: const Icon(Icons.save_rounded, color: Colors.white),
                    label: const Text(
                      'Сохранить ключи и обновить ленту',
                      style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                    onPressed: _saveApiKeys,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Duration Filter Defaults
          _buildSectionHeader('ФИЛЬТР ДЛИТЕЛЬНОСТИ ПО УМОЛЧАНИЮ'),
          Container(
            color: const Color(0xFF1B1B24),
            child: Column(
              children: [
                _buildRadioTile(
                  title: 'Больше 2 минут (> 2m)',
                  subtitle: 'Рекомендуется: скрывает короткие нарезки',
                  value: 'gt2min',
                  groupValue: settings.defaultDurationFilter,
                  onChanged: (val) {
                    settingsProvider.updateSettings(
                      settings.copyWith(defaultDurationFilter: val),
                    );
                  },
                ),
                _buildRadioTile(
                  title: 'Больше 5 минут (> 5m)',
                  subtitle: 'Показывать только длинные ролики',
                  value: 'gt5min',
                  groupValue: settings.defaultDurationFilter,
                  onChanged: (val) {
                    settingsProvider.updateSettings(
                      settings.copyWith(defaultDurationFilter: val),
                    );
                  },
                ),
                _buildRadioTile(
                  title: 'Больше 10 минут (> 10m)',
                  subtitle: 'Полноформатные видео',
                  value: 'gt10min',
                  groupValue: settings.defaultDurationFilter,
                  onChanged: (val) {
                    settingsProvider.updateSettings(
                      settings.copyWith(defaultDurationFilter: val),
                    );
                  },
                ),
                _buildRadioTile(
                  title: 'Все видео',
                  subtitle: 'Без фильтрации по длительности',
                  value: 'all',
                  groupValue: settings.defaultDurationFilter,
                  onChanged: (val) {
                    settingsProvider.updateSettings(
                      settings.copyWith(defaultDurationFilter: val),
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Tag Blacklist
          _buildSectionHeader('ЧЕРНЫЙ СПИСОК ТЕГОВ (BLACKLIST)'),
          Container(
            color: const Color(0xFF1B1B24),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ролики с этими тегами будут скрыты автоматически:',
                  style: TextStyle(color: Colors.white70, fontSize: 13),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _blacklistController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Введите тег (например: guro)',
                          hintStyle: const TextStyle(color: Colors.white38),
                          filled: true,
                          fillColor: const Color(0xFF282834),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onSubmitted: (_) => _addBlacklistTag(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00C853),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      onPressed: _addBlacklistTag,
                      child: const Text('Добавить'),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: settings.blacklistedTags.map((tag) {
                    return Chip(
                      backgroundColor: const Color(0xFFB71C1C).withOpacity(0.3),
                      side: const BorderSide(color: Colors.redAccent, width: 0.8),
                      label: Text(
                        tag,
                        style: const TextStyle(color: Colors.white, fontSize: 12),
                      ),
                      deleteIcon: const Icon(Icons.close, size: 14, color: Colors.white70),
                      onDeleted: () {
                        settingsProvider.removeBlacklistTag(tag);
                        context.read<FeedProvider>().updateBlacklist(
                              context.read<SettingsProvider>().settings.blacklistedTags,
                            );
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Network & Privacy (DoH & Proxy)
          _buildSectionHeader('СЕТЬ И ПРИВАТНОСТЬ (ОБХОД БЛОКИРОВОК)'),
          Container(
            color: const Color(0xFF1B1B24),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text('DNS-over-HTTPS (DoH)', style: TextStyle(color: Colors.white)),
                  subtitle: const Text(
                    'Помогает обойти блокировки провайдеров через Cloudflare/Google DNS',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                  value: settings.enableDoh,
                  activeColor: Colors.greenAccent,
                  onChanged: (val) {
                    settingsProvider.updateSettings(settings.copyWith(enableDoh: val));
                  },
                ),
                if (settings.enableDoh) ...[
                  ListTile(
                    title: const Text('Провайдер DoH', style: TextStyle(color: Colors.white)),
                    trailing: DropdownButton<String>(
                      value: settings.dohProvider,
                      dropdownColor: const Color(0xFF282834),
                      style: const TextStyle(color: Colors.greenAccent),
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(value: 'cloudflare', child: Text('Cloudflare (1.1.1.1)')),
                        DropdownMenuItem(value: 'google', child: Text('Google (8.8.8.8)')),
                      ],
                      onChanged: (newVal) {
                        if (newVal != null) {
                          settingsProvider.updateSettings(settings.copyWith(dohProvider: newVal));
                        }
                      },
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Section: Storage & Cache
          _buildSectionHeader('ПАМЯТЬ И КЭШ'),
          Container(
            color: const Color(0xFF1B1B24),
            child: ListTile(
              leading: const Icon(Icons.delete_sweep_outlined, color: Colors.amberAccent),
              title: const Text('Очистить кэш метаданных', style: TextStyle(color: Colors.white)),
              subtitle: const Text(
                'Сбросить сохраненные длительности роликов в базе данных',
                style: TextStyle(color: Colors.white54, fontSize: 12),
              ),
              onTap: () async {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    backgroundColor: const Color(0xFF1F1F28),
                    title: const Text('Очистить кэш?', style: TextStyle(color: Colors.white)),
                    content: const Text(
                      'Все предварительно полученные данные о длительности видео будут удалены из локальной базы данных.',
                      style: TextStyle(color: Colors.white70),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Отмена', style: TextStyle(color: Colors.white54)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Очистить', style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  ),
                );

                if (confirm == true) {
                  await settingsProvider.clearAllCache();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Кэш метаданных успешно очищен'),
                        backgroundColor: Color(0xFF00C853),
                      ),
                    );
                  }
                }
              },
            ),
          ),
          const SizedBox(height: 30),

          // About
          Center(
            child: Column(
              children: const [
                Text(
                  'Rule34 & Realbooru Player v2.0',
                  style: TextStyle(color: Colors.white38, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 4),
                Text(
                  'Быстрый парсер заголовков (MP4/WebM) + SQLite кэш',
                  style: TextStyle(color: Colors.white24, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Text(
        title,
        style: const TextStyle(
          color: Color(0xFF00C853),
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.0,
        ),
      ),
    );
  }

  Widget _buildRadioTile({
    required String title,
    required String subtitle,
    required String value,
    required String groupValue,
    required ValueChanged<String> onChanged,
  }) {
    return RadioListTile<String>(
      title: Text(title, style: const TextStyle(color: Colors.white, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: Colors.white54, fontSize: 12)),
      value: value,
      groupValue: groupValue,
      activeColor: const Color(0xFF00C853),
      onChanged: (val) {
        if (val != null) onChanged(val);
      },
    );
  }
}

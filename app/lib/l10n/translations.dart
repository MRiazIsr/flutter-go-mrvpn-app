/// Simple localization class for MRVPN.
///
/// Supports English (`en`) and Russian (`ru`). Use [S.of] to look up
/// translated strings by key.
class S {
  S._();

  static String of(String locale, String key) {
    final map = _translations[locale] ?? _translations['en']!;
    return map[key] ?? key;
  }

  static const Map<String, Map<String, String>> _translations = {
    'en': _en,
    'ru': _ru,
  };

  // -------------------------------------------------------------------------
  // English
  // -------------------------------------------------------------------------
  static const Map<String, String> _en = {
    // Home
    'connect': 'Connect',
    'connected': 'Connected',
    'connecting': 'Connecting...',
    'disconnecting': 'Disconnecting...',
    'error': 'Error',
    'noServerSelected': 'No server selected',
    'selectServerFirst': 'Please select a server first',
    'status': 'Status',
    'server': 'Server',
    'protocol': 'Protocol',
    'selectServer': 'Select server',

    // Servers
    'servers': 'Servers',
    'addServer': 'Add Server',
    'noServersTitle': 'No servers added',
    'noServersSubtitle': 'Add your first server to get started',
    'addFirstServer': 'Add Server',
    'serverLink': 'Paste vless:// or hysteria2:// link',
    'importClipboard': 'Import from Clipboard',
    'add': 'Add',
    'cancel': 'Cancel',
    'editName': 'Edit Server',
    'newName': 'Server name',
    'save': 'Save',
    'deleteServer': 'Delete Server',
    'deleteConfirm': 'Remove "\$name" from your servers?',
    'delete': 'Delete',

    // Split Tunnel
    'splitTunnel': 'Split Tunnel',
    'off': 'Off',
    'app': 'App',
    'domain': 'Domain',
    'splitDisabled': 'Split tunneling is disabled',
    'splitDisabledDesc':
        'Choose App or Domain mode to route specific\ntraffic through or outside the VPN.',
    'invertSelection': 'Invert selection',
    'appsBypassVpn': 'Selected apps bypass the VPN',
    'appsUseVpn': 'Only selected apps use the VPN',
    'domainsBypassVpn': 'Listed domains bypass the VPN',
    'domainsUseVpn': 'Only listed domains use the VPN',
    'searchApps': 'Search apps...',
    'noApps': 'No apps found',
    'noMatchingApps': 'No matching apps',
    'failedLoadApps': 'Failed to load apps',
    'retry': 'Retry',

    // Settings
    'settings': 'Settings',
    'appearance': 'Appearance',
    'theme': 'Theme',
    'dark': 'Dark',
    'light': 'Light',
    'system': 'System',
    'language': 'Language',
    'general': 'General',
    'autoConnect': 'Auto-connect on startup',
    'autoConnectDesc':
        'Automatically connect to the last server when the app starts',
    'startMinimized': 'Start minimized to tray',
    'startMinimizedDesc': 'Minimize to system tray on launch',
    'killSwitch': 'Kill switch',
    'killSwitchDesc': 'Block internet if VPN connection drops',
    'network': 'Network',
    'dns': 'DNS',
    'mtu': 'MTU',
    'about': 'About',
    'version': 'Version 1.0.0',
    'aboutDesc':
        'A lightweight Windows VPN client powered by sing-box with VLESS and Hysteria2 support.',

    // Sidebar
    'home': 'Home',
    'collapse': 'Collapse',
    'expand': 'Expand',
    'disconnected': 'Disconnected',
  };

  // -------------------------------------------------------------------------
  // Russian
  // -------------------------------------------------------------------------
  static const Map<String, String> _ru = {
    // Home
    'connect': 'Подключить',
    'connected': 'Подключено',
    'connecting': 'Подключение...',
    'disconnecting': 'Отключение...',
    'error': 'Ошибка',
    'noServerSelected': 'Сервер не выбран',
    'selectServerFirst': 'Сначала выберите сервер',
    'status': 'Статус',
    'server': 'Сервер',
    'protocol': 'Протокол',
    'selectServer': 'Выбрать сервер',

    // Servers
    'servers': 'Серверы',
    'addServer': 'Добавить сервер',
    'noServersTitle': 'Серверов нет',
    'noServersSubtitle': 'Добавьте первый сервер, чтобы начать',
    'addFirstServer': 'Добавить сервер',
    'serverLink': 'Вставьте ссылку vless:// или hysteria2://',
    'importClipboard': 'Вставить из буфера обмена',
    'add': 'Добавить',
    'cancel': 'Отмена',
    'editName': 'Редактировать сервер',
    'newName': 'Имя сервера',
    'save': 'Сохранить',
    'deleteServer': 'Удалить сервер',
    'deleteConfirm': 'Удалить "\$name" из списка серверов?',
    'delete': 'Удалить',

    // Split Tunnel
    'splitTunnel': 'Раздельное\nтуннелирование',
    'off': 'Выкл',
    'app': 'Прилож.',
    'domain': 'Домен',
    'splitDisabled': 'Раздельное туннелирование отключено',
    'splitDisabledDesc':
        'Выберите режим Прилож. или Домен для маршрутизации\nтрафика через VPN или в обход.',
    'invertSelection': 'Инвертировать выбор',
    'appsBypassVpn': 'Выбранные приложения обходят VPN',
    'appsUseVpn': 'Только выбранные приложения используют VPN',
    'domainsBypassVpn': 'Указанные домены обходят VPN',
    'domainsUseVpn': 'Только указанные домены используют VPN',
    'searchApps': 'Поиск приложений...',
    'noApps': 'Приложения не найдены',
    'noMatchingApps': 'Нет совпадений',
    'failedLoadApps': 'Не удалось загрузить приложения',
    'retry': 'Повторить',

    // Settings
    'settings': 'Настройки',
    'appearance': 'Внешний вид',
    'theme': 'Тема',
    'dark': 'Тёмная',
    'light': 'Светлая',
    'system': 'Системная',
    'language': 'Язык',
    'general': 'Основные',
    'autoConnect': 'Автоподключение при запуске',
    'autoConnectDesc':
        'Автоматически подключаться к последнему серверу при запуске',
    'startMinimized': 'Запуск в свёрнутом виде',
    'startMinimizedDesc': 'Сворачивать в трей при запуске',
    'killSwitch': 'Аварийный выключатель',
    'killSwitchDesc': 'Блокировать интернет при разрыве VPN-соединения',
    'network': 'Сеть',
    'dns': 'DNS',
    'mtu': 'MTU',
    'about': 'О приложении',
    'version': 'Версия 1.0.0',
    'aboutDesc':
        'Лёгкий VPN-клиент для Windows на базе sing-box с поддержкой VLESS и Hysteria2.',

    // Sidebar
    'home': 'Главная',
    'collapse': 'Свернуть',
    'expand': 'Развернуть',
    'disconnected': 'Отключено',
  };
}

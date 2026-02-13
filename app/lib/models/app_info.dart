/// Application info model for split tunneling.
///
/// Represents an installed application that can be included or excluded
/// from the VPN tunnel.
class AppInfo {
  final String name;
  final String exeName;
  final String? installPath;
  final bool isUwp;
  final bool isSelected;
  final String? icon;

  const AppInfo({
    required this.name,
    required this.exeName,
    this.installPath,
    this.isUwp = false,
    this.isSelected = false,
    this.icon,
  });

  factory AppInfo.fromJson(Map<String, dynamic> json) {
    return AppInfo(
      name: json['name'] as String,
      exeName: json['exeName'] as String,
      installPath: json['installPath'] as String?,
      isUwp: json['isUwp'] as bool? ?? false,
      isSelected: json['isSelected'] as bool? ?? false,
      icon: json['icon'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'exeName': exeName,
      'installPath': installPath,
      'isUwp': isUwp,
      'isSelected': isSelected,
      if (icon != null) 'icon': icon,
    };
  }

  AppInfo copyWith({
    String? name,
    String? exeName,
    String? Function()? installPath,
    bool? isUwp,
    bool? isSelected,
    String? Function()? icon,
  }) {
    return AppInfo(
      name: name ?? this.name,
      exeName: exeName ?? this.exeName,
      installPath: installPath != null ? installPath() : this.installPath,
      isUwp: isUwp ?? this.isUwp,
      isSelected: isSelected ?? this.isSelected,
      icon: icon != null ? icon() : this.icon,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AppInfo &&
        other.name == name &&
        other.exeName == exeName &&
        other.installPath == installPath &&
        other.isUwp == isUwp &&
        other.isSelected == isSelected &&
        other.icon == icon;
  }

  @override
  int get hashCode {
    return Object.hash(name, exeName, installPath, isUwp, isSelected, icon);
  }

  @override
  String toString() {
    return 'AppInfo(name: $name, exeName: $exeName, isUwp: $isUwp, '
        'isSelected: $isSelected)';
  }
}

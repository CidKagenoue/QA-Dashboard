class AccountAccess {
  final bool basis;
  final bool whsTours;
  final bool ova;
  final bool japGpp;
  final bool maintenanceInspections;

  const AccountAccess({
    this.basis = false,
    this.whsTours = false,
    this.ova = false,
    this.japGpp = false,
    this.maintenanceInspections = false,
  });

  bool get hasAnyModuleAccess =>
      basis || whsTours || ova || japGpp || maintenanceInspections;

  AccountAccess copyWith({
    bool? basis,
    bool? whsTours,
    bool? ova,
    bool? japGpp,
    bool? maintenanceInspections,
  }) {
    return AccountAccess(
      basis: basis ?? this.basis,
      whsTours: whsTours ?? this.whsTours,
      ova: ova ?? this.ova,
      japGpp: japGpp ?? this.japGpp,
      maintenanceInspections:
          maintenanceInspections ?? this.maintenanceInspections,
    );
  }

  factory AccountAccess.fromJson(Map<String, dynamic> json) {
    final nestedAccess = json['access'];
    final accessMap = nestedAccess is Map<String, dynamic>
        ? nestedAccess
        : nestedAccess is Map
        ? Map<String, dynamic>.from(nestedAccess)
        : <String, dynamic>{};

    return AccountAccess(
      basis: _readBool(accessMap['basis'] ?? json['basisAccess']),
      whsTours: _readBool(accessMap['whsTours'] ?? json['whsToursAccess']),
      ova: _readBool(accessMap['ova'] ?? json['ovaAccess']),
      japGpp: _readBool(accessMap['japGpp'] ?? json['japGppAccess']),
      maintenanceInspections: _readBool(
        accessMap['maintenanceInspections'] ??
            json['maintenanceInspectionsAccess'],
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'basis': basis,
      'whsTours': whsTours,
      'ova': ova,
      'japGpp': japGpp,
      'maintenanceInspections': maintenanceInspections,
    };
  }
}

class User {
  final int id;
  final String email;
  final String? name;
  final bool isAdmin;
  final AccountAccess access;

  const User({
    required this.id,
    required this.email,
    this.name,
    this.isAdmin = false,
    this.access = const AccountAccess(),
  });

  String get displayName {
    final trimmedName = name?.trim();
    if (trimmedName != null && trimmedName.isNotEmpty) {
      return trimmedName;
    }

    return email;
  }

  bool get hasAnyAccess => isAdmin || access.hasAnyModuleAccess;

  User copyWith({
    int? id,
    String? email,
    String? name,
    bool? isAdmin,
    AccountAccess? access,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      isAdmin: isAdmin ?? this.isAdmin,
      access: access ?? this.access,
    );
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: (json['id'] as num).toInt(),
      email: json['email'] as String,
      name: json['name'] as String?,
      isAdmin: _readBool(json['isAdmin']),
      access: AccountAccess.fromJson(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'isAdmin': isAdmin,
      'access': access.toJson(),
      'hasAnyAccess': hasAnyAccess,
    };
  }
}

bool _readBool(dynamic value) => value == true;

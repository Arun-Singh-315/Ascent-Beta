// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $UserProfileTableTable extends UserProfileTable
    with TableInfo<$UserProfileTableTable, UserProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfileTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetRoleMeta = const VerificationMeta(
    'targetRole',
  );
  @override
  late final GeneratedColumn<String> targetRole = GeneratedColumn<String>(
    'target_role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _targetCompaniesMeta = const VerificationMeta(
    'targetCompanies',
  );
  @override
  late final GeneratedColumn<String> targetCompanies = GeneratedColumn<String>(
    'target_companies',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _interviewDateMeta = const VerificationMeta(
    'interviewDate',
  );
  @override
  late final GeneratedColumn<DateTime> interviewDate =
      GeneratedColumn<DateTime>(
        'interview_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _weeklyHoursAvailableMeta =
      const VerificationMeta('weeklyHoursAvailable');
  @override
  late final GeneratedColumn<int> weeklyHoursAvailable = GeneratedColumn<int>(
    'weekly_hours_available',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(10),
  );
  static const VerificationMeta _preferredStudyWindowMeta =
      const VerificationMeta('preferredStudyWindow');
  @override
  late final GeneratedColumn<String> preferredStudyWindow =
      GeneratedColumn<String>(
        'preferred_study_window',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('morning'),
      );
  static const VerificationMeta _skillSelfRatingsMeta = const VerificationMeta(
    'skillSelfRatings',
  );
  @override
  late final GeneratedColumn<String> skillSelfRatings = GeneratedColumn<String>(
    'skill_self_ratings',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{"dsa":3,"systemDesign":2,"coreStack":3}'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastOpenedAtMeta = const VerificationMeta(
    'lastOpenedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastOpenedAt = GeneratedColumn<DateTime>(
    'last_opened_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _onboardingCompleteMeta =
      const VerificationMeta('onboardingComplete');
  @override
  late final GeneratedColumn<bool> onboardingComplete = GeneratedColumn<bool>(
    'onboarding_complete',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("onboarding_complete" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    targetRole,
    targetCompanies,
    interviewDate,
    weeklyHoursAvailable,
    preferredStudyWindow,
    skillSelfRatings,
    createdAt,
    updatedAt,
    lastOpenedAt,
    onboardingComplete,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profiles';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfile> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('target_role')) {
      context.handle(
        _targetRoleMeta,
        targetRole.isAcceptableOrUnknown(data['target_role']!, _targetRoleMeta),
      );
    }
    if (data.containsKey('target_companies')) {
      context.handle(
        _targetCompaniesMeta,
        targetCompanies.isAcceptableOrUnknown(
          data['target_companies']!,
          _targetCompaniesMeta,
        ),
      );
    }
    if (data.containsKey('interview_date')) {
      context.handle(
        _interviewDateMeta,
        interviewDate.isAcceptableOrUnknown(
          data['interview_date']!,
          _interviewDateMeta,
        ),
      );
    }
    if (data.containsKey('weekly_hours_available')) {
      context.handle(
        _weeklyHoursAvailableMeta,
        weeklyHoursAvailable.isAcceptableOrUnknown(
          data['weekly_hours_available']!,
          _weeklyHoursAvailableMeta,
        ),
      );
    }
    if (data.containsKey('preferred_study_window')) {
      context.handle(
        _preferredStudyWindowMeta,
        preferredStudyWindow.isAcceptableOrUnknown(
          data['preferred_study_window']!,
          _preferredStudyWindowMeta,
        ),
      );
    }
    if (data.containsKey('skill_self_ratings')) {
      context.handle(
        _skillSelfRatingsMeta,
        skillSelfRatings.isAcceptableOrUnknown(
          data['skill_self_ratings']!,
          _skillSelfRatingsMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('last_opened_at')) {
      context.handle(
        _lastOpenedAtMeta,
        lastOpenedAt.isAcceptableOrUnknown(
          data['last_opened_at']!,
          _lastOpenedAtMeta,
        ),
      );
    }
    if (data.containsKey('onboarding_complete')) {
      context.handle(
        _onboardingCompleteMeta,
        onboardingComplete.isAcceptableOrUnknown(
          data['onboarding_complete']!,
          _onboardingCompleteMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfile(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      targetRole: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_role'],
      )!,
      targetCompanies: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}target_companies'],
      )!,
      interviewDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}interview_date'],
      ),
      weeklyHoursAvailable: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}weekly_hours_available'],
      )!,
      preferredStudyWindow: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}preferred_study_window'],
      )!,
      skillSelfRatings: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}skill_self_ratings'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      lastOpenedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_opened_at'],
      ),
      onboardingComplete: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}onboarding_complete'],
      )!,
    );
  }

  @override
  $UserProfileTableTable createAlias(String alias) {
    return $UserProfileTableTable(attachedDatabase, alias);
  }
}

class UserProfile extends DataClass implements Insertable<UserProfile> {
  final int id;

  /// Full name of the user.
  final String name;

  /// Target role the user is preparing for (e.g. "SDE-2").
  final String targetRole;

  /// JSON-encoded list of target companies (e.g. '["Google","Meta"]').
  final String targetCompanies;

  /// Planned date of the interview (can be null if unknown).
  final DateTime? interviewDate;

  /// How many hours per week the user plans to study.
  final int weeklyHoursAvailable;

  /// Preferred study window: 'morning' | 'afternoon' | 'evening' | 'flexible'.
  final String preferredStudyWindow;

  /// JSON map of self-rated skill levels
  /// e.g. '{"dsa":3,"systemDesign":2,"coreStack":3}' (scale 1–5).
  final String skillSelfRatings;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// Timestamp of the last time the user opened the app.
  final DateTime? lastOpenedAt;

  /// Whether the user has completed the onboarding flow.
  final bool onboardingComplete;
  const UserProfile({
    required this.id,
    required this.name,
    required this.targetRole,
    required this.targetCompanies,
    this.interviewDate,
    required this.weeklyHoursAvailable,
    required this.preferredStudyWindow,
    required this.skillSelfRatings,
    required this.createdAt,
    required this.updatedAt,
    this.lastOpenedAt,
    required this.onboardingComplete,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['target_role'] = Variable<String>(targetRole);
    map['target_companies'] = Variable<String>(targetCompanies);
    if (!nullToAbsent || interviewDate != null) {
      map['interview_date'] = Variable<DateTime>(interviewDate);
    }
    map['weekly_hours_available'] = Variable<int>(weeklyHoursAvailable);
    map['preferred_study_window'] = Variable<String>(preferredStudyWindow);
    map['skill_self_ratings'] = Variable<String>(skillSelfRatings);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || lastOpenedAt != null) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt);
    }
    map['onboarding_complete'] = Variable<bool>(onboardingComplete);
    return map;
  }

  UserProfileTableCompanion toCompanion(bool nullToAbsent) {
    return UserProfileTableCompanion(
      id: Value(id),
      name: Value(name),
      targetRole: Value(targetRole),
      targetCompanies: Value(targetCompanies),
      interviewDate: interviewDate == null && nullToAbsent
          ? const Value.absent()
          : Value(interviewDate),
      weeklyHoursAvailable: Value(weeklyHoursAvailable),
      preferredStudyWindow: Value(preferredStudyWindow),
      skillSelfRatings: Value(skillSelfRatings),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      lastOpenedAt: lastOpenedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastOpenedAt),
      onboardingComplete: Value(onboardingComplete),
    );
  }

  factory UserProfile.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfile(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      targetRole: serializer.fromJson<String>(json['targetRole']),
      targetCompanies: serializer.fromJson<String>(json['targetCompanies']),
      interviewDate: serializer.fromJson<DateTime?>(json['interviewDate']),
      weeklyHoursAvailable: serializer.fromJson<int>(
        json['weeklyHoursAvailable'],
      ),
      preferredStudyWindow: serializer.fromJson<String>(
        json['preferredStudyWindow'],
      ),
      skillSelfRatings: serializer.fromJson<String>(json['skillSelfRatings']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      lastOpenedAt: serializer.fromJson<DateTime?>(json['lastOpenedAt']),
      onboardingComplete: serializer.fromJson<bool>(json['onboardingComplete']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'targetRole': serializer.toJson<String>(targetRole),
      'targetCompanies': serializer.toJson<String>(targetCompanies),
      'interviewDate': serializer.toJson<DateTime?>(interviewDate),
      'weeklyHoursAvailable': serializer.toJson<int>(weeklyHoursAvailable),
      'preferredStudyWindow': serializer.toJson<String>(preferredStudyWindow),
      'skillSelfRatings': serializer.toJson<String>(skillSelfRatings),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'lastOpenedAt': serializer.toJson<DateTime?>(lastOpenedAt),
      'onboardingComplete': serializer.toJson<bool>(onboardingComplete),
    };
  }

  UserProfile copyWith({
    int? id,
    String? name,
    String? targetRole,
    String? targetCompanies,
    Value<DateTime?> interviewDate = const Value.absent(),
    int? weeklyHoursAvailable,
    String? preferredStudyWindow,
    String? skillSelfRatings,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> lastOpenedAt = const Value.absent(),
    bool? onboardingComplete,
  }) => UserProfile(
    id: id ?? this.id,
    name: name ?? this.name,
    targetRole: targetRole ?? this.targetRole,
    targetCompanies: targetCompanies ?? this.targetCompanies,
    interviewDate: interviewDate.present
        ? interviewDate.value
        : this.interviewDate,
    weeklyHoursAvailable: weeklyHoursAvailable ?? this.weeklyHoursAvailable,
    preferredStudyWindow: preferredStudyWindow ?? this.preferredStudyWindow,
    skillSelfRatings: skillSelfRatings ?? this.skillSelfRatings,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    lastOpenedAt: lastOpenedAt.present ? lastOpenedAt.value : this.lastOpenedAt,
    onboardingComplete: onboardingComplete ?? this.onboardingComplete,
  );
  UserProfile copyWithCompanion(UserProfileTableCompanion data) {
    return UserProfile(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      targetRole: data.targetRole.present
          ? data.targetRole.value
          : this.targetRole,
      targetCompanies: data.targetCompanies.present
          ? data.targetCompanies.value
          : this.targetCompanies,
      interviewDate: data.interviewDate.present
          ? data.interviewDate.value
          : this.interviewDate,
      weeklyHoursAvailable: data.weeklyHoursAvailable.present
          ? data.weeklyHoursAvailable.value
          : this.weeklyHoursAvailable,
      preferredStudyWindow: data.preferredStudyWindow.present
          ? data.preferredStudyWindow.value
          : this.preferredStudyWindow,
      skillSelfRatings: data.skillSelfRatings.present
          ? data.skillSelfRatings.value
          : this.skillSelfRatings,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      lastOpenedAt: data.lastOpenedAt.present
          ? data.lastOpenedAt.value
          : this.lastOpenedAt,
      onboardingComplete: data.onboardingComplete.present
          ? data.onboardingComplete.value
          : this.onboardingComplete,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfile(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('targetRole: $targetRole, ')
          ..write('targetCompanies: $targetCompanies, ')
          ..write('interviewDate: $interviewDate, ')
          ..write('weeklyHoursAvailable: $weeklyHoursAvailable, ')
          ..write('preferredStudyWindow: $preferredStudyWindow, ')
          ..write('skillSelfRatings: $skillSelfRatings, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('onboardingComplete: $onboardingComplete')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    targetRole,
    targetCompanies,
    interviewDate,
    weeklyHoursAvailable,
    preferredStudyWindow,
    skillSelfRatings,
    createdAt,
    updatedAt,
    lastOpenedAt,
    onboardingComplete,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfile &&
          other.id == this.id &&
          other.name == this.name &&
          other.targetRole == this.targetRole &&
          other.targetCompanies == this.targetCompanies &&
          other.interviewDate == this.interviewDate &&
          other.weeklyHoursAvailable == this.weeklyHoursAvailable &&
          other.preferredStudyWindow == this.preferredStudyWindow &&
          other.skillSelfRatings == this.skillSelfRatings &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.lastOpenedAt == this.lastOpenedAt &&
          other.onboardingComplete == this.onboardingComplete);
}

class UserProfileTableCompanion extends UpdateCompanion<UserProfile> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> targetRole;
  final Value<String> targetCompanies;
  final Value<DateTime?> interviewDate;
  final Value<int> weeklyHoursAvailable;
  final Value<String> preferredStudyWindow;
  final Value<String> skillSelfRatings;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> lastOpenedAt;
  final Value<bool> onboardingComplete;
  const UserProfileTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.targetRole = const Value.absent(),
    this.targetCompanies = const Value.absent(),
    this.interviewDate = const Value.absent(),
    this.weeklyHoursAvailable = const Value.absent(),
    this.preferredStudyWindow = const Value.absent(),
    this.skillSelfRatings = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.onboardingComplete = const Value.absent(),
  });
  UserProfileTableCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.targetRole = const Value.absent(),
    this.targetCompanies = const Value.absent(),
    this.interviewDate = const Value.absent(),
    this.weeklyHoursAvailable = const Value.absent(),
    this.preferredStudyWindow = const Value.absent(),
    this.skillSelfRatings = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.lastOpenedAt = const Value.absent(),
    this.onboardingComplete = const Value.absent(),
  }) : name = Value(name);
  static Insertable<UserProfile> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? targetRole,
    Expression<String>? targetCompanies,
    Expression<DateTime>? interviewDate,
    Expression<int>? weeklyHoursAvailable,
    Expression<String>? preferredStudyWindow,
    Expression<String>? skillSelfRatings,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? lastOpenedAt,
    Expression<bool>? onboardingComplete,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (targetRole != null) 'target_role': targetRole,
      if (targetCompanies != null) 'target_companies': targetCompanies,
      if (interviewDate != null) 'interview_date': interviewDate,
      if (weeklyHoursAvailable != null)
        'weekly_hours_available': weeklyHoursAvailable,
      if (preferredStudyWindow != null)
        'preferred_study_window': preferredStudyWindow,
      if (skillSelfRatings != null) 'skill_self_ratings': skillSelfRatings,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (lastOpenedAt != null) 'last_opened_at': lastOpenedAt,
      if (onboardingComplete != null) 'onboarding_complete': onboardingComplete,
    });
  }

  UserProfileTableCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? targetRole,
    Value<String>? targetCompanies,
    Value<DateTime?>? interviewDate,
    Value<int>? weeklyHoursAvailable,
    Value<String>? preferredStudyWindow,
    Value<String>? skillSelfRatings,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? lastOpenedAt,
    Value<bool>? onboardingComplete,
  }) {
    return UserProfileTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      targetRole: targetRole ?? this.targetRole,
      targetCompanies: targetCompanies ?? this.targetCompanies,
      interviewDate: interviewDate ?? this.interviewDate,
      weeklyHoursAvailable: weeklyHoursAvailable ?? this.weeklyHoursAvailable,
      preferredStudyWindow: preferredStudyWindow ?? this.preferredStudyWindow,
      skillSelfRatings: skillSelfRatings ?? this.skillSelfRatings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (targetRole.present) {
      map['target_role'] = Variable<String>(targetRole.value);
    }
    if (targetCompanies.present) {
      map['target_companies'] = Variable<String>(targetCompanies.value);
    }
    if (interviewDate.present) {
      map['interview_date'] = Variable<DateTime>(interviewDate.value);
    }
    if (weeklyHoursAvailable.present) {
      map['weekly_hours_available'] = Variable<int>(weeklyHoursAvailable.value);
    }
    if (preferredStudyWindow.present) {
      map['preferred_study_window'] = Variable<String>(
        preferredStudyWindow.value,
      );
    }
    if (skillSelfRatings.present) {
      map['skill_self_ratings'] = Variable<String>(skillSelfRatings.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (lastOpenedAt.present) {
      map['last_opened_at'] = Variable<DateTime>(lastOpenedAt.value);
    }
    if (onboardingComplete.present) {
      map['onboarding_complete'] = Variable<bool>(onboardingComplete.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('targetRole: $targetRole, ')
          ..write('targetCompanies: $targetCompanies, ')
          ..write('interviewDate: $interviewDate, ')
          ..write('weeklyHoursAvailable: $weeklyHoursAvailable, ')
          ..write('preferredStudyWindow: $preferredStudyWindow, ')
          ..write('skillSelfRatings: $skillSelfRatings, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('lastOpenedAt: $lastOpenedAt, ')
          ..write('onboardingComplete: $onboardingComplete')
          ..write(')'))
        .toString();
  }
}

class $StudyPhaseTableTable extends StudyPhaseTable
    with TableInfo<$StudyPhaseTableTable, StudyPhase> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StudyPhaseTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _descriptionMeta = const VerificationMeta(
    'description',
  );
  @override
  late final GeneratedColumn<String> description = GeneratedColumn<String>(
    'description',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _orderIndexMeta = const VerificationMeta(
    'orderIndex',
  );
  @override
  late final GeneratedColumn<int> orderIndex = GeneratedColumn<int>(
    'order_index',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _startDateMeta = const VerificationMeta(
    'startDate',
  );
  @override
  late final GeneratedColumn<DateTime> startDate = GeneratedColumn<DateTime>(
    'start_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('#7FA88A'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    description,
    orderIndex,
    startDate,
    endDate,
    colorHex,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'study_phases';
  @override
  VerificationContext validateIntegrity(
    Insertable<StudyPhase> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('description')) {
      context.handle(
        _descriptionMeta,
        description.isAcceptableOrUnknown(
          data['description']!,
          _descriptionMeta,
        ),
      );
    }
    if (data.containsKey('order_index')) {
      context.handle(
        _orderIndexMeta,
        orderIndex.isAcceptableOrUnknown(data['order_index']!, _orderIndexMeta),
      );
    }
    if (data.containsKey('start_date')) {
      context.handle(
        _startDateMeta,
        startDate.isAcceptableOrUnknown(data['start_date']!, _startDateMeta),
      );
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StudyPhase map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StudyPhase(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      description: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}description'],
      ),
      orderIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}order_index'],
      )!,
      startDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}start_date'],
      ),
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      ),
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $StudyPhaseTableTable createAlias(String alias) {
    return $StudyPhaseTableTable(attachedDatabase, alias);
  }
}

class StudyPhase extends DataClass implements Insertable<StudyPhase> {
  final int id;

  /// Display title of the phase (e.g. "Phase 1: Fundamentals").
  final String title;

  /// Optional description / goal for this phase.
  final String? description;

  /// Zero-based ordering index used to sort phases in the UI.
  final int orderIndex;

  /// When this phase is scheduled to begin.
  final DateTime? startDate;

  /// When this phase is scheduled to end.
  final DateTime? endDate;

  /// Hex color string used for the phase chip in the UI (e.g. '#7FA88A').
  final String colorHex;
  final DateTime createdAt;
  const StudyPhase({
    required this.id,
    required this.title,
    this.description,
    required this.orderIndex,
    this.startDate,
    this.endDate,
    required this.colorHex,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || description != null) {
      map['description'] = Variable<String>(description);
    }
    map['order_index'] = Variable<int>(orderIndex);
    if (!nullToAbsent || startDate != null) {
      map['start_date'] = Variable<DateTime>(startDate);
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    map['color_hex'] = Variable<String>(colorHex);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  StudyPhaseTableCompanion toCompanion(bool nullToAbsent) {
    return StudyPhaseTableCompanion(
      id: Value(id),
      title: Value(title),
      description: description == null && nullToAbsent
          ? const Value.absent()
          : Value(description),
      orderIndex: Value(orderIndex),
      startDate: startDate == null && nullToAbsent
          ? const Value.absent()
          : Value(startDate),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      colorHex: Value(colorHex),
      createdAt: Value(createdAt),
    );
  }

  factory StudyPhase.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StudyPhase(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      description: serializer.fromJson<String?>(json['description']),
      orderIndex: serializer.fromJson<int>(json['orderIndex']),
      startDate: serializer.fromJson<DateTime?>(json['startDate']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      colorHex: serializer.fromJson<String>(json['colorHex']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'description': serializer.toJson<String?>(description),
      'orderIndex': serializer.toJson<int>(orderIndex),
      'startDate': serializer.toJson<DateTime?>(startDate),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'colorHex': serializer.toJson<String>(colorHex),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  StudyPhase copyWith({
    int? id,
    String? title,
    Value<String?> description = const Value.absent(),
    int? orderIndex,
    Value<DateTime?> startDate = const Value.absent(),
    Value<DateTime?> endDate = const Value.absent(),
    String? colorHex,
    DateTime? createdAt,
  }) => StudyPhase(
    id: id ?? this.id,
    title: title ?? this.title,
    description: description.present ? description.value : this.description,
    orderIndex: orderIndex ?? this.orderIndex,
    startDate: startDate.present ? startDate.value : this.startDate,
    endDate: endDate.present ? endDate.value : this.endDate,
    colorHex: colorHex ?? this.colorHex,
    createdAt: createdAt ?? this.createdAt,
  );
  StudyPhase copyWithCompanion(StudyPhaseTableCompanion data) {
    return StudyPhase(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      description: data.description.present
          ? data.description.value
          : this.description,
      orderIndex: data.orderIndex.present
          ? data.orderIndex.value
          : this.orderIndex,
      startDate: data.startDate.present ? data.startDate.value : this.startDate,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StudyPhase(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('colorHex: $colorHex, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    description,
    orderIndex,
    startDate,
    endDate,
    colorHex,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StudyPhase &&
          other.id == this.id &&
          other.title == this.title &&
          other.description == this.description &&
          other.orderIndex == this.orderIndex &&
          other.startDate == this.startDate &&
          other.endDate == this.endDate &&
          other.colorHex == this.colorHex &&
          other.createdAt == this.createdAt);
}

class StudyPhaseTableCompanion extends UpdateCompanion<StudyPhase> {
  final Value<int> id;
  final Value<String> title;
  final Value<String?> description;
  final Value<int> orderIndex;
  final Value<DateTime?> startDate;
  final Value<DateTime?> endDate;
  final Value<String> colorHex;
  final Value<DateTime> createdAt;
  const StudyPhaseTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.description = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  StudyPhaseTableCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.description = const Value.absent(),
    this.orderIndex = const Value.absent(),
    this.startDate = const Value.absent(),
    this.endDate = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : title = Value(title);
  static Insertable<StudyPhase> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? description,
    Expression<int>? orderIndex,
    Expression<DateTime>? startDate,
    Expression<DateTime>? endDate,
    Expression<String>? colorHex,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (description != null) 'description': description,
      if (orderIndex != null) 'order_index': orderIndex,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      if (colorHex != null) 'color_hex': colorHex,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  StudyPhaseTableCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String?>? description,
    Value<int>? orderIndex,
    Value<DateTime?>? startDate,
    Value<DateTime?>? endDate,
    Value<String>? colorHex,
    Value<DateTime>? createdAt,
  }) {
    return StudyPhaseTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      orderIndex: orderIndex ?? this.orderIndex,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      colorHex: colorHex ?? this.colorHex,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (description.present) {
      map['description'] = Variable<String>(description.value);
    }
    if (orderIndex.present) {
      map['order_index'] = Variable<int>(orderIndex.value);
    }
    if (startDate.present) {
      map['start_date'] = Variable<DateTime>(startDate.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StudyPhaseTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('description: $description, ')
          ..write('orderIndex: $orderIndex, ')
          ..write('startDate: $startDate, ')
          ..write('endDate: $endDate, ')
          ..write('colorHex: $colorHex, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $SeriesTableTable extends SeriesTable
    with TableInfo<$SeriesTableTable, Series> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SeriesTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _totalItemsMeta = const VerificationMeta(
    'totalItems',
  );
  @override
  late final GeneratedColumn<int> totalItems = GeneratedColumn<int>(
    'total_items',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pacingRuleMeta = const VerificationMeta(
    'pacingRule',
  );
  @override
  late final GeneratedColumn<String> pacingRule = GeneratedColumn<String>(
    'pacing_rule',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('fixedInterval'),
  );
  static const VerificationMeta _fixedIntervalDaysMeta = const VerificationMeta(
    'fixedIntervalDays',
  );
  @override
  late final GeneratedColumn<int> fixedIntervalDays = GeneratedColumn<int>(
    'fixed_interval_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _endDateMeta = const VerificationMeta(
    'endDate',
  );
  @override
  late final GeneratedColumn<DateTime> endDate = GeneratedColumn<DateTime>(
    'end_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkedPhaseIdMeta = const VerificationMeta(
    'linkedPhaseId',
  );
  @override
  late final GeneratedColumn<int> linkedPhaseId = GeneratedColumn<int>(
    'linked_phase_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES study_phases (id)',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    totalItems,
    pacingRule,
    fixedIntervalDays,
    endDate,
    linkedPhaseId,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'series';
  @override
  VerificationContext validateIntegrity(
    Insertable<Series> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('total_items')) {
      context.handle(
        _totalItemsMeta,
        totalItems.isAcceptableOrUnknown(data['total_items']!, _totalItemsMeta),
      );
    }
    if (data.containsKey('pacing_rule')) {
      context.handle(
        _pacingRuleMeta,
        pacingRule.isAcceptableOrUnknown(data['pacing_rule']!, _pacingRuleMeta),
      );
    }
    if (data.containsKey('fixed_interval_days')) {
      context.handle(
        _fixedIntervalDaysMeta,
        fixedIntervalDays.isAcceptableOrUnknown(
          data['fixed_interval_days']!,
          _fixedIntervalDaysMeta,
        ),
      );
    }
    if (data.containsKey('end_date')) {
      context.handle(
        _endDateMeta,
        endDate.isAcceptableOrUnknown(data['end_date']!, _endDateMeta),
      );
    }
    if (data.containsKey('linked_phase_id')) {
      context.handle(
        _linkedPhaseIdMeta,
        linkedPhaseId.isAcceptableOrUnknown(
          data['linked_phase_id']!,
          _linkedPhaseIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Series map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Series(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      totalItems: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}total_items'],
      ),
      pacingRule: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}pacing_rule'],
      )!,
      fixedIntervalDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fixed_interval_days'],
      ),
      endDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}end_date'],
      ),
      linkedPhaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}linked_phase_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SeriesTableTable createAlias(String alias) {
    return $SeriesTableTable(attachedDatabase, alias);
  }
}

class Series extends DataClass implements Insertable<Series> {
  final int id;

  /// Display title of the series (e.g. "Blind 75 DSA").
  final String title;

  /// Total number of items in the series.  Null = open-ended series.
  final int? totalItems;

  /// Stores the [PacingRule] enum name (e.g. 'fixedInterval').
  final String pacingRule;

  /// For [PacingRule.fixedInterval]: one item every N days.
  final int? fixedIntervalDays;

  /// Hard deadline for completing the series.  Null = no deadline.
  final DateTime? endDate;

  /// Optional FK to [StudyPhaseTable].
  final int? linkedPhaseId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Series({
    required this.id,
    required this.title,
    this.totalItems,
    required this.pacingRule,
    this.fixedIntervalDays,
    this.endDate,
    this.linkedPhaseId,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || totalItems != null) {
      map['total_items'] = Variable<int>(totalItems);
    }
    map['pacing_rule'] = Variable<String>(pacingRule);
    if (!nullToAbsent || fixedIntervalDays != null) {
      map['fixed_interval_days'] = Variable<int>(fixedIntervalDays);
    }
    if (!nullToAbsent || endDate != null) {
      map['end_date'] = Variable<DateTime>(endDate);
    }
    if (!nullToAbsent || linkedPhaseId != null) {
      map['linked_phase_id'] = Variable<int>(linkedPhaseId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  SeriesTableCompanion toCompanion(bool nullToAbsent) {
    return SeriesTableCompanion(
      id: Value(id),
      title: Value(title),
      totalItems: totalItems == null && nullToAbsent
          ? const Value.absent()
          : Value(totalItems),
      pacingRule: Value(pacingRule),
      fixedIntervalDays: fixedIntervalDays == null && nullToAbsent
          ? const Value.absent()
          : Value(fixedIntervalDays),
      endDate: endDate == null && nullToAbsent
          ? const Value.absent()
          : Value(endDate),
      linkedPhaseId: linkedPhaseId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedPhaseId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Series.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Series(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      totalItems: serializer.fromJson<int?>(json['totalItems']),
      pacingRule: serializer.fromJson<String>(json['pacingRule']),
      fixedIntervalDays: serializer.fromJson<int?>(json['fixedIntervalDays']),
      endDate: serializer.fromJson<DateTime?>(json['endDate']),
      linkedPhaseId: serializer.fromJson<int?>(json['linkedPhaseId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'totalItems': serializer.toJson<int?>(totalItems),
      'pacingRule': serializer.toJson<String>(pacingRule),
      'fixedIntervalDays': serializer.toJson<int?>(fixedIntervalDays),
      'endDate': serializer.toJson<DateTime?>(endDate),
      'linkedPhaseId': serializer.toJson<int?>(linkedPhaseId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Series copyWith({
    int? id,
    String? title,
    Value<int?> totalItems = const Value.absent(),
    String? pacingRule,
    Value<int?> fixedIntervalDays = const Value.absent(),
    Value<DateTime?> endDate = const Value.absent(),
    Value<int?> linkedPhaseId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Series(
    id: id ?? this.id,
    title: title ?? this.title,
    totalItems: totalItems.present ? totalItems.value : this.totalItems,
    pacingRule: pacingRule ?? this.pacingRule,
    fixedIntervalDays: fixedIntervalDays.present
        ? fixedIntervalDays.value
        : this.fixedIntervalDays,
    endDate: endDate.present ? endDate.value : this.endDate,
    linkedPhaseId: linkedPhaseId.present
        ? linkedPhaseId.value
        : this.linkedPhaseId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Series copyWithCompanion(SeriesTableCompanion data) {
    return Series(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      totalItems: data.totalItems.present
          ? data.totalItems.value
          : this.totalItems,
      pacingRule: data.pacingRule.present
          ? data.pacingRule.value
          : this.pacingRule,
      fixedIntervalDays: data.fixedIntervalDays.present
          ? data.fixedIntervalDays.value
          : this.fixedIntervalDays,
      endDate: data.endDate.present ? data.endDate.value : this.endDate,
      linkedPhaseId: data.linkedPhaseId.present
          ? data.linkedPhaseId.value
          : this.linkedPhaseId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Series(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('totalItems: $totalItems, ')
          ..write('pacingRule: $pacingRule, ')
          ..write('fixedIntervalDays: $fixedIntervalDays, ')
          ..write('endDate: $endDate, ')
          ..write('linkedPhaseId: $linkedPhaseId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    totalItems,
    pacingRule,
    fixedIntervalDays,
    endDate,
    linkedPhaseId,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Series &&
          other.id == this.id &&
          other.title == this.title &&
          other.totalItems == this.totalItems &&
          other.pacingRule == this.pacingRule &&
          other.fixedIntervalDays == this.fixedIntervalDays &&
          other.endDate == this.endDate &&
          other.linkedPhaseId == this.linkedPhaseId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class SeriesTableCompanion extends UpdateCompanion<Series> {
  final Value<int> id;
  final Value<String> title;
  final Value<int?> totalItems;
  final Value<String> pacingRule;
  final Value<int?> fixedIntervalDays;
  final Value<DateTime?> endDate;
  final Value<int?> linkedPhaseId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const SeriesTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.totalItems = const Value.absent(),
    this.pacingRule = const Value.absent(),
    this.fixedIntervalDays = const Value.absent(),
    this.endDate = const Value.absent(),
    this.linkedPhaseId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  SeriesTableCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.totalItems = const Value.absent(),
    this.pacingRule = const Value.absent(),
    this.fixedIntervalDays = const Value.absent(),
    this.endDate = const Value.absent(),
    this.linkedPhaseId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : title = Value(title);
  static Insertable<Series> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<int>? totalItems,
    Expression<String>? pacingRule,
    Expression<int>? fixedIntervalDays,
    Expression<DateTime>? endDate,
    Expression<int>? linkedPhaseId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (totalItems != null) 'total_items': totalItems,
      if (pacingRule != null) 'pacing_rule': pacingRule,
      if (fixedIntervalDays != null) 'fixed_interval_days': fixedIntervalDays,
      if (endDate != null) 'end_date': endDate,
      if (linkedPhaseId != null) 'linked_phase_id': linkedPhaseId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  SeriesTableCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<int?>? totalItems,
    Value<String>? pacingRule,
    Value<int?>? fixedIntervalDays,
    Value<DateTime?>? endDate,
    Value<int?>? linkedPhaseId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return SeriesTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      totalItems: totalItems ?? this.totalItems,
      pacingRule: pacingRule ?? this.pacingRule,
      fixedIntervalDays: fixedIntervalDays ?? this.fixedIntervalDays,
      endDate: endDate ?? this.endDate,
      linkedPhaseId: linkedPhaseId ?? this.linkedPhaseId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (totalItems.present) {
      map['total_items'] = Variable<int>(totalItems.value);
    }
    if (pacingRule.present) {
      map['pacing_rule'] = Variable<String>(pacingRule.value);
    }
    if (fixedIntervalDays.present) {
      map['fixed_interval_days'] = Variable<int>(fixedIntervalDays.value);
    }
    if (endDate.present) {
      map['end_date'] = Variable<DateTime>(endDate.value);
    }
    if (linkedPhaseId.present) {
      map['linked_phase_id'] = Variable<int>(linkedPhaseId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SeriesTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('totalItems: $totalItems, ')
          ..write('pacingRule: $pacingRule, ')
          ..write('fixedIntervalDays: $fixedIntervalDays, ')
          ..write('endDate: $endDate, ')
          ..write('linkedPhaseId: $linkedPhaseId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $ApplicationTableTable extends ApplicationTable
    with TableInfo<$ApplicationTableTable, ApplicationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ApplicationTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _companyMeta = const VerificationMeta(
    'company',
  );
  @override
  late final GeneratedColumn<String> company = GeneratedColumn<String>(
    'company',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentStageMeta = const VerificationMeta(
    'currentStage',
  );
  @override
  late final GeneratedColumn<String> currentStage = GeneratedColumn<String>(
    'current_stage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('wishlist'),
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextActionDateMeta = const VerificationMeta(
    'nextActionDate',
  );
  @override
  late final GeneratedColumn<DateTime> nextActionDate =
      GeneratedColumn<DateTime>(
        'next_action_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _jobUrlMeta = const VerificationMeta('jobUrl');
  @override
  late final GeneratedColumn<String> jobUrl = GeneratedColumn<String>(
    'job_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _salaryMeta = const VerificationMeta('salary');
  @override
  late final GeneratedColumn<String> salary = GeneratedColumn<String>(
    'salary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lastInteractedAtMeta = const VerificationMeta(
    'lastInteractedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastInteractedAt =
      GeneratedColumn<DateTime>(
        'last_interacted_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    company,
    role,
    currentStage,
    notes,
    nextActionDate,
    jobUrl,
    salary,
    lastInteractedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'applications';
  @override
  VerificationContext validateIntegrity(
    Insertable<ApplicationRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('company')) {
      context.handle(
        _companyMeta,
        company.isAcceptableOrUnknown(data['company']!, _companyMeta),
      );
    } else if (isInserting) {
      context.missing(_companyMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('current_stage')) {
      context.handle(
        _currentStageMeta,
        currentStage.isAcceptableOrUnknown(
          data['current_stage']!,
          _currentStageMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('next_action_date')) {
      context.handle(
        _nextActionDateMeta,
        nextActionDate.isAcceptableOrUnknown(
          data['next_action_date']!,
          _nextActionDateMeta,
        ),
      );
    }
    if (data.containsKey('job_url')) {
      context.handle(
        _jobUrlMeta,
        jobUrl.isAcceptableOrUnknown(data['job_url']!, _jobUrlMeta),
      );
    }
    if (data.containsKey('salary')) {
      context.handle(
        _salaryMeta,
        salary.isAcceptableOrUnknown(data['salary']!, _salaryMeta),
      );
    }
    if (data.containsKey('last_interacted_at')) {
      context.handle(
        _lastInteractedAtMeta,
        lastInteractedAt.isAcceptableOrUnknown(
          data['last_interacted_at']!,
          _lastInteractedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ApplicationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ApplicationRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      company: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      currentStage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_stage'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      nextActionDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}next_action_date'],
      ),
      jobUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}job_url'],
      ),
      salary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}salary'],
      ),
      lastInteractedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_interacted_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $ApplicationTableTable createAlias(String alias) {
    return $ApplicationTableTable(attachedDatabase, alias);
  }
}

class ApplicationRow extends DataClass implements Insertable<ApplicationRow> {
  final int id;
  final String company;
  final String role;

  /// Stores the [ApplicationStage] enum name.  Defaults to 'wishlist'.
  final String currentStage;
  final String? notes;

  /// Date by which the user wants to take the next action.
  final DateTime? nextActionDate;

  /// Link to the job posting.
  final String? jobUrl;

  /// Free-text salary range / CTC (e.g. '18–22 LPA').
  final String? salary;

  /// Last time the user opened or edited this application.
  final DateTime? lastInteractedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const ApplicationRow({
    required this.id,
    required this.company,
    required this.role,
    required this.currentStage,
    this.notes,
    this.nextActionDate,
    this.jobUrl,
    this.salary,
    this.lastInteractedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['company'] = Variable<String>(company);
    map['role'] = Variable<String>(role);
    map['current_stage'] = Variable<String>(currentStage);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || nextActionDate != null) {
      map['next_action_date'] = Variable<DateTime>(nextActionDate);
    }
    if (!nullToAbsent || jobUrl != null) {
      map['job_url'] = Variable<String>(jobUrl);
    }
    if (!nullToAbsent || salary != null) {
      map['salary'] = Variable<String>(salary);
    }
    if (!nullToAbsent || lastInteractedAt != null) {
      map['last_interacted_at'] = Variable<DateTime>(lastInteractedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ApplicationTableCompanion toCompanion(bool nullToAbsent) {
    return ApplicationTableCompanion(
      id: Value(id),
      company: Value(company),
      role: Value(role),
      currentStage: Value(currentStage),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      nextActionDate: nextActionDate == null && nullToAbsent
          ? const Value.absent()
          : Value(nextActionDate),
      jobUrl: jobUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(jobUrl),
      salary: salary == null && nullToAbsent
          ? const Value.absent()
          : Value(salary),
      lastInteractedAt: lastInteractedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastInteractedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory ApplicationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ApplicationRow(
      id: serializer.fromJson<int>(json['id']),
      company: serializer.fromJson<String>(json['company']),
      role: serializer.fromJson<String>(json['role']),
      currentStage: serializer.fromJson<String>(json['currentStage']),
      notes: serializer.fromJson<String?>(json['notes']),
      nextActionDate: serializer.fromJson<DateTime?>(json['nextActionDate']),
      jobUrl: serializer.fromJson<String?>(json['jobUrl']),
      salary: serializer.fromJson<String?>(json['salary']),
      lastInteractedAt: serializer.fromJson<DateTime?>(
        json['lastInteractedAt'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'company': serializer.toJson<String>(company),
      'role': serializer.toJson<String>(role),
      'currentStage': serializer.toJson<String>(currentStage),
      'notes': serializer.toJson<String?>(notes),
      'nextActionDate': serializer.toJson<DateTime?>(nextActionDate),
      'jobUrl': serializer.toJson<String?>(jobUrl),
      'salary': serializer.toJson<String?>(salary),
      'lastInteractedAt': serializer.toJson<DateTime?>(lastInteractedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  ApplicationRow copyWith({
    int? id,
    String? company,
    String? role,
    String? currentStage,
    Value<String?> notes = const Value.absent(),
    Value<DateTime?> nextActionDate = const Value.absent(),
    Value<String?> jobUrl = const Value.absent(),
    Value<String?> salary = const Value.absent(),
    Value<DateTime?> lastInteractedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => ApplicationRow(
    id: id ?? this.id,
    company: company ?? this.company,
    role: role ?? this.role,
    currentStage: currentStage ?? this.currentStage,
    notes: notes.present ? notes.value : this.notes,
    nextActionDate: nextActionDate.present
        ? nextActionDate.value
        : this.nextActionDate,
    jobUrl: jobUrl.present ? jobUrl.value : this.jobUrl,
    salary: salary.present ? salary.value : this.salary,
    lastInteractedAt: lastInteractedAt.present
        ? lastInteractedAt.value
        : this.lastInteractedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  ApplicationRow copyWithCompanion(ApplicationTableCompanion data) {
    return ApplicationRow(
      id: data.id.present ? data.id.value : this.id,
      company: data.company.present ? data.company.value : this.company,
      role: data.role.present ? data.role.value : this.role,
      currentStage: data.currentStage.present
          ? data.currentStage.value
          : this.currentStage,
      notes: data.notes.present ? data.notes.value : this.notes,
      nextActionDate: data.nextActionDate.present
          ? data.nextActionDate.value
          : this.nextActionDate,
      jobUrl: data.jobUrl.present ? data.jobUrl.value : this.jobUrl,
      salary: data.salary.present ? data.salary.value : this.salary,
      lastInteractedAt: data.lastInteractedAt.present
          ? data.lastInteractedAt.value
          : this.lastInteractedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ApplicationRow(')
          ..write('id: $id, ')
          ..write('company: $company, ')
          ..write('role: $role, ')
          ..write('currentStage: $currentStage, ')
          ..write('notes: $notes, ')
          ..write('nextActionDate: $nextActionDate, ')
          ..write('jobUrl: $jobUrl, ')
          ..write('salary: $salary, ')
          ..write('lastInteractedAt: $lastInteractedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    company,
    role,
    currentStage,
    notes,
    nextActionDate,
    jobUrl,
    salary,
    lastInteractedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ApplicationRow &&
          other.id == this.id &&
          other.company == this.company &&
          other.role == this.role &&
          other.currentStage == this.currentStage &&
          other.notes == this.notes &&
          other.nextActionDate == this.nextActionDate &&
          other.jobUrl == this.jobUrl &&
          other.salary == this.salary &&
          other.lastInteractedAt == this.lastInteractedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ApplicationTableCompanion extends UpdateCompanion<ApplicationRow> {
  final Value<int> id;
  final Value<String> company;
  final Value<String> role;
  final Value<String> currentStage;
  final Value<String?> notes;
  final Value<DateTime?> nextActionDate;
  final Value<String?> jobUrl;
  final Value<String?> salary;
  final Value<DateTime?> lastInteractedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const ApplicationTableCompanion({
    this.id = const Value.absent(),
    this.company = const Value.absent(),
    this.role = const Value.absent(),
    this.currentStage = const Value.absent(),
    this.notes = const Value.absent(),
    this.nextActionDate = const Value.absent(),
    this.jobUrl = const Value.absent(),
    this.salary = const Value.absent(),
    this.lastInteractedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  ApplicationTableCompanion.insert({
    this.id = const Value.absent(),
    required String company,
    required String role,
    this.currentStage = const Value.absent(),
    this.notes = const Value.absent(),
    this.nextActionDate = const Value.absent(),
    this.jobUrl = const Value.absent(),
    this.salary = const Value.absent(),
    this.lastInteractedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : company = Value(company),
       role = Value(role);
  static Insertable<ApplicationRow> custom({
    Expression<int>? id,
    Expression<String>? company,
    Expression<String>? role,
    Expression<String>? currentStage,
    Expression<String>? notes,
    Expression<DateTime>? nextActionDate,
    Expression<String>? jobUrl,
    Expression<String>? salary,
    Expression<DateTime>? lastInteractedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (company != null) 'company': company,
      if (role != null) 'role': role,
      if (currentStage != null) 'current_stage': currentStage,
      if (notes != null) 'notes': notes,
      if (nextActionDate != null) 'next_action_date': nextActionDate,
      if (jobUrl != null) 'job_url': jobUrl,
      if (salary != null) 'salary': salary,
      if (lastInteractedAt != null) 'last_interacted_at': lastInteractedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  ApplicationTableCompanion copyWith({
    Value<int>? id,
    Value<String>? company,
    Value<String>? role,
    Value<String>? currentStage,
    Value<String?>? notes,
    Value<DateTime?>? nextActionDate,
    Value<String?>? jobUrl,
    Value<String?>? salary,
    Value<DateTime?>? lastInteractedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return ApplicationTableCompanion(
      id: id ?? this.id,
      company: company ?? this.company,
      role: role ?? this.role,
      currentStage: currentStage ?? this.currentStage,
      notes: notes ?? this.notes,
      nextActionDate: nextActionDate ?? this.nextActionDate,
      jobUrl: jobUrl ?? this.jobUrl,
      salary: salary ?? this.salary,
      lastInteractedAt: lastInteractedAt ?? this.lastInteractedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (company.present) {
      map['company'] = Variable<String>(company.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (currentStage.present) {
      map['current_stage'] = Variable<String>(currentStage.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (nextActionDate.present) {
      map['next_action_date'] = Variable<DateTime>(nextActionDate.value);
    }
    if (jobUrl.present) {
      map['job_url'] = Variable<String>(jobUrl.value);
    }
    if (salary.present) {
      map['salary'] = Variable<String>(salary.value);
    }
    if (lastInteractedAt.present) {
      map['last_interacted_at'] = Variable<DateTime>(lastInteractedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ApplicationTableCompanion(')
          ..write('id: $id, ')
          ..write('company: $company, ')
          ..write('role: $role, ')
          ..write('currentStage: $currentStage, ')
          ..write('notes: $notes, ')
          ..write('nextActionDate: $nextActionDate, ')
          ..write('jobUrl: $jobUrl, ')
          ..write('salary: $salary, ')
          ..write('lastInteractedAt: $lastInteractedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $TaskTableTable extends TaskTable with TableInfo<$TaskTableTable, Task> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TaskTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 300,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _plannedDateMeta = const VerificationMeta(
    'plannedDate',
  );
  @override
  late final GeneratedColumn<DateTime> plannedDate = GeneratedColumn<DateTime>(
    'planned_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actualCompletedDateMeta =
      const VerificationMeta('actualCompletedDate');
  @override
  late final GeneratedColumn<DateTime> actualCompletedDate =
      GeneratedColumn<DateTime>(
        'actual_completed_date',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<String> priority = GeneratedColumn<String>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('medium'),
  );
  static const VerificationMeta _linkedPhaseIdMeta = const VerificationMeta(
    'linkedPhaseId',
  );
  @override
  late final GeneratedColumn<int> linkedPhaseId = GeneratedColumn<int>(
    'linked_phase_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES study_phases (id)',
    ),
  );
  static const VerificationMeta _seriesIdMeta = const VerificationMeta(
    'seriesId',
  );
  @override
  late final GeneratedColumn<int> seriesId = GeneratedColumn<int>(
    'series_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES series (id)',
    ),
  );
  static const VerificationMeta _seriesItemIndexMeta = const VerificationMeta(
    'seriesItemIndex',
  );
  @override
  late final GeneratedColumn<int> seriesItemIndex = GeneratedColumn<int>(
    'series_item_index',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _parentTaskIdMeta = const VerificationMeta(
    'parentTaskId',
  );
  @override
  late final GeneratedColumn<int> parentTaskId = GeneratedColumn<int>(
    'parent_task_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id)',
    ),
  );
  static const VerificationMeta _linkedApplicationIdMeta =
      const VerificationMeta('linkedApplicationId');
  @override
  late final GeneratedColumn<int> linkedApplicationId = GeneratedColumn<int>(
    'linked_application_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES applications (id)',
    ),
  );
  static const VerificationMeta _estimatedMinutesMeta = const VerificationMeta(
    'estimatedMinutes',
  );
  @override
  late final GeneratedColumn<int> estimatedMinutes = GeneratedColumn<int>(
    'estimated_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _actualMinutesMeta = const VerificationMeta(
    'actualMinutes',
  );
  @override
  late final GeneratedColumn<int> actualMinutes = GeneratedColumn<int>(
    'actual_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisitFlagMeta = const VerificationMeta(
    'revisitFlag',
  );
  @override
  late final GeneratedColumn<bool> revisitFlag = GeneratedColumn<bool>(
    'revisit_flag',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("revisit_flag" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _lastInteractedAtMeta = const VerificationMeta(
    'lastInteractedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastInteractedAt =
      GeneratedColumn<DateTime>(
        'last_interacted_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    notes,
    plannedDate,
    actualCompletedDate,
    priority,
    linkedPhaseId,
    seriesId,
    seriesItemIndex,
    parentTaskId,
    linkedApplicationId,
    estimatedMinutes,
    actualMinutes,
    revisitFlag,
    lastInteractedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'tasks';
  @override
  VerificationContext validateIntegrity(
    Insertable<Task> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('planned_date')) {
      context.handle(
        _plannedDateMeta,
        plannedDate.isAcceptableOrUnknown(
          data['planned_date']!,
          _plannedDateMeta,
        ),
      );
    }
    if (data.containsKey('actual_completed_date')) {
      context.handle(
        _actualCompletedDateMeta,
        actualCompletedDate.isAcceptableOrUnknown(
          data['actual_completed_date']!,
          _actualCompletedDateMeta,
        ),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('linked_phase_id')) {
      context.handle(
        _linkedPhaseIdMeta,
        linkedPhaseId.isAcceptableOrUnknown(
          data['linked_phase_id']!,
          _linkedPhaseIdMeta,
        ),
      );
    }
    if (data.containsKey('series_id')) {
      context.handle(
        _seriesIdMeta,
        seriesId.isAcceptableOrUnknown(data['series_id']!, _seriesIdMeta),
      );
    }
    if (data.containsKey('series_item_index')) {
      context.handle(
        _seriesItemIndexMeta,
        seriesItemIndex.isAcceptableOrUnknown(
          data['series_item_index']!,
          _seriesItemIndexMeta,
        ),
      );
    }
    if (data.containsKey('parent_task_id')) {
      context.handle(
        _parentTaskIdMeta,
        parentTaskId.isAcceptableOrUnknown(
          data['parent_task_id']!,
          _parentTaskIdMeta,
        ),
      );
    }
    if (data.containsKey('linked_application_id')) {
      context.handle(
        _linkedApplicationIdMeta,
        linkedApplicationId.isAcceptableOrUnknown(
          data['linked_application_id']!,
          _linkedApplicationIdMeta,
        ),
      );
    }
    if (data.containsKey('estimated_minutes')) {
      context.handle(
        _estimatedMinutesMeta,
        estimatedMinutes.isAcceptableOrUnknown(
          data['estimated_minutes']!,
          _estimatedMinutesMeta,
        ),
      );
    }
    if (data.containsKey('actual_minutes')) {
      context.handle(
        _actualMinutesMeta,
        actualMinutes.isAcceptableOrUnknown(
          data['actual_minutes']!,
          _actualMinutesMeta,
        ),
      );
    }
    if (data.containsKey('revisit_flag')) {
      context.handle(
        _revisitFlagMeta,
        revisitFlag.isAcceptableOrUnknown(
          data['revisit_flag']!,
          _revisitFlagMeta,
        ),
      );
    }
    if (data.containsKey('last_interacted_at')) {
      context.handle(
        _lastInteractedAtMeta,
        lastInteractedAt.isAcceptableOrUnknown(
          data['last_interacted_at']!,
          _lastInteractedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Task map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Task(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      plannedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}planned_date'],
      ),
      actualCompletedDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}actual_completed_date'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}priority'],
      )!,
      linkedPhaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}linked_phase_id'],
      ),
      seriesId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}series_id'],
      ),
      seriesItemIndex: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}series_item_index'],
      ),
      parentTaskId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}parent_task_id'],
      ),
      linkedApplicationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}linked_application_id'],
      ),
      estimatedMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}estimated_minutes'],
      ),
      actualMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}actual_minutes'],
      ),
      revisitFlag: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}revisit_flag'],
      )!,
      lastInteractedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_interacted_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TaskTableTable createAlias(String alias) {
    return $TaskTableTable(attachedDatabase, alias);
  }
}

class Task extends DataClass implements Insertable<Task> {
  final int id;
  final String title;

  /// Optional free-text notes about the task.
  final String? notes;

  /// The calendar date on which the user plans to work on this task.
  final DateTime? plannedDate;

  /// Set when the user marks the task complete.
  final DateTime? actualCompletedDate;

  /// Stores the [TaskPriority] enum name.  Defaults to 'medium'.
  final String priority;

  /// Optional FK to [StudyPhaseTable].
  final int? linkedPhaseId;

  /// Optional FK to [SeriesTable].  Null = standalone to-do.
  final int? seriesId;

  /// 1-based position of this task within its parent series.
  final int? seriesItemIndex;

  /// Optional FK to a parent [TaskTable] for sub-entries/sub-items.
  final int? parentTaskId;

  /// Optional FK to [ApplicationTable] for tying tasks to job pipeline entries.
  final int? linkedApplicationId;

  /// Estimated duration for the Focus Timer (minutes).
  final int? estimatedMinutes;

  /// Actual time logged by the Focus Timer (minutes).
  final int? actualMinutes;

  /// DSA-style revisit flag — marks a problem to revisit later.
  final bool revisitFlag;

  /// Last time the user opened / interacted with this task.
  /// Used as a freshness signal by the Insight Engine.
  final DateTime? lastInteractedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Task({
    required this.id,
    required this.title,
    this.notes,
    this.plannedDate,
    this.actualCompletedDate,
    required this.priority,
    this.linkedPhaseId,
    this.seriesId,
    this.seriesItemIndex,
    this.parentTaskId,
    this.linkedApplicationId,
    this.estimatedMinutes,
    this.actualMinutes,
    required this.revisitFlag,
    this.lastInteractedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || plannedDate != null) {
      map['planned_date'] = Variable<DateTime>(plannedDate);
    }
    if (!nullToAbsent || actualCompletedDate != null) {
      map['actual_completed_date'] = Variable<DateTime>(actualCompletedDate);
    }
    map['priority'] = Variable<String>(priority);
    if (!nullToAbsent || linkedPhaseId != null) {
      map['linked_phase_id'] = Variable<int>(linkedPhaseId);
    }
    if (!nullToAbsent || seriesId != null) {
      map['series_id'] = Variable<int>(seriesId);
    }
    if (!nullToAbsent || seriesItemIndex != null) {
      map['series_item_index'] = Variable<int>(seriesItemIndex);
    }
    if (!nullToAbsent || parentTaskId != null) {
      map['parent_task_id'] = Variable<int>(parentTaskId);
    }
    if (!nullToAbsent || linkedApplicationId != null) {
      map['linked_application_id'] = Variable<int>(linkedApplicationId);
    }
    if (!nullToAbsent || estimatedMinutes != null) {
      map['estimated_minutes'] = Variable<int>(estimatedMinutes);
    }
    if (!nullToAbsent || actualMinutes != null) {
      map['actual_minutes'] = Variable<int>(actualMinutes);
    }
    map['revisit_flag'] = Variable<bool>(revisitFlag);
    if (!nullToAbsent || lastInteractedAt != null) {
      map['last_interacted_at'] = Variable<DateTime>(lastInteractedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TaskTableCompanion toCompanion(bool nullToAbsent) {
    return TaskTableCompanion(
      id: Value(id),
      title: Value(title),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      plannedDate: plannedDate == null && nullToAbsent
          ? const Value.absent()
          : Value(plannedDate),
      actualCompletedDate: actualCompletedDate == null && nullToAbsent
          ? const Value.absent()
          : Value(actualCompletedDate),
      priority: Value(priority),
      linkedPhaseId: linkedPhaseId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedPhaseId),
      seriesId: seriesId == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesId),
      seriesItemIndex: seriesItemIndex == null && nullToAbsent
          ? const Value.absent()
          : Value(seriesItemIndex),
      parentTaskId: parentTaskId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentTaskId),
      linkedApplicationId: linkedApplicationId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedApplicationId),
      estimatedMinutes: estimatedMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(estimatedMinutes),
      actualMinutes: actualMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(actualMinutes),
      revisitFlag: Value(revisitFlag),
      lastInteractedAt: lastInteractedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastInteractedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Task.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Task(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      notes: serializer.fromJson<String?>(json['notes']),
      plannedDate: serializer.fromJson<DateTime?>(json['plannedDate']),
      actualCompletedDate: serializer.fromJson<DateTime?>(
        json['actualCompletedDate'],
      ),
      priority: serializer.fromJson<String>(json['priority']),
      linkedPhaseId: serializer.fromJson<int?>(json['linkedPhaseId']),
      seriesId: serializer.fromJson<int?>(json['seriesId']),
      seriesItemIndex: serializer.fromJson<int?>(json['seriesItemIndex']),
      parentTaskId: serializer.fromJson<int?>(json['parentTaskId']),
      linkedApplicationId: serializer.fromJson<int?>(
        json['linkedApplicationId'],
      ),
      estimatedMinutes: serializer.fromJson<int?>(json['estimatedMinutes']),
      actualMinutes: serializer.fromJson<int?>(json['actualMinutes']),
      revisitFlag: serializer.fromJson<bool>(json['revisitFlag']),
      lastInteractedAt: serializer.fromJson<DateTime?>(
        json['lastInteractedAt'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'notes': serializer.toJson<String?>(notes),
      'plannedDate': serializer.toJson<DateTime?>(plannedDate),
      'actualCompletedDate': serializer.toJson<DateTime?>(actualCompletedDate),
      'priority': serializer.toJson<String>(priority),
      'linkedPhaseId': serializer.toJson<int?>(linkedPhaseId),
      'seriesId': serializer.toJson<int?>(seriesId),
      'seriesItemIndex': serializer.toJson<int?>(seriesItemIndex),
      'parentTaskId': serializer.toJson<int?>(parentTaskId),
      'linkedApplicationId': serializer.toJson<int?>(linkedApplicationId),
      'estimatedMinutes': serializer.toJson<int?>(estimatedMinutes),
      'actualMinutes': serializer.toJson<int?>(actualMinutes),
      'revisitFlag': serializer.toJson<bool>(revisitFlag),
      'lastInteractedAt': serializer.toJson<DateTime?>(lastInteractedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Task copyWith({
    int? id,
    String? title,
    Value<String?> notes = const Value.absent(),
    Value<DateTime?> plannedDate = const Value.absent(),
    Value<DateTime?> actualCompletedDate = const Value.absent(),
    String? priority,
    Value<int?> linkedPhaseId = const Value.absent(),
    Value<int?> seriesId = const Value.absent(),
    Value<int?> seriesItemIndex = const Value.absent(),
    Value<int?> parentTaskId = const Value.absent(),
    Value<int?> linkedApplicationId = const Value.absent(),
    Value<int?> estimatedMinutes = const Value.absent(),
    Value<int?> actualMinutes = const Value.absent(),
    bool? revisitFlag,
    Value<DateTime?> lastInteractedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Task(
    id: id ?? this.id,
    title: title ?? this.title,
    notes: notes.present ? notes.value : this.notes,
    plannedDate: plannedDate.present ? plannedDate.value : this.plannedDate,
    actualCompletedDate: actualCompletedDate.present
        ? actualCompletedDate.value
        : this.actualCompletedDate,
    priority: priority ?? this.priority,
    linkedPhaseId: linkedPhaseId.present
        ? linkedPhaseId.value
        : this.linkedPhaseId,
    seriesId: seriesId.present ? seriesId.value : this.seriesId,
    seriesItemIndex: seriesItemIndex.present
        ? seriesItemIndex.value
        : this.seriesItemIndex,
    parentTaskId: parentTaskId.present ? parentTaskId.value : this.parentTaskId,
    linkedApplicationId: linkedApplicationId.present
        ? linkedApplicationId.value
        : this.linkedApplicationId,
    estimatedMinutes: estimatedMinutes.present
        ? estimatedMinutes.value
        : this.estimatedMinutes,
    actualMinutes: actualMinutes.present
        ? actualMinutes.value
        : this.actualMinutes,
    revisitFlag: revisitFlag ?? this.revisitFlag,
    lastInteractedAt: lastInteractedAt.present
        ? lastInteractedAt.value
        : this.lastInteractedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Task copyWithCompanion(TaskTableCompanion data) {
    return Task(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      notes: data.notes.present ? data.notes.value : this.notes,
      plannedDate: data.plannedDate.present
          ? data.plannedDate.value
          : this.plannedDate,
      actualCompletedDate: data.actualCompletedDate.present
          ? data.actualCompletedDate.value
          : this.actualCompletedDate,
      priority: data.priority.present ? data.priority.value : this.priority,
      linkedPhaseId: data.linkedPhaseId.present
          ? data.linkedPhaseId.value
          : this.linkedPhaseId,
      seriesId: data.seriesId.present ? data.seriesId.value : this.seriesId,
      seriesItemIndex: data.seriesItemIndex.present
          ? data.seriesItemIndex.value
          : this.seriesItemIndex,
      parentTaskId: data.parentTaskId.present
          ? data.parentTaskId.value
          : this.parentTaskId,
      linkedApplicationId: data.linkedApplicationId.present
          ? data.linkedApplicationId.value
          : this.linkedApplicationId,
      estimatedMinutes: data.estimatedMinutes.present
          ? data.estimatedMinutes.value
          : this.estimatedMinutes,
      actualMinutes: data.actualMinutes.present
          ? data.actualMinutes.value
          : this.actualMinutes,
      revisitFlag: data.revisitFlag.present
          ? data.revisitFlag.value
          : this.revisitFlag,
      lastInteractedAt: data.lastInteractedAt.present
          ? data.lastInteractedAt.value
          : this.lastInteractedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Task(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('plannedDate: $plannedDate, ')
          ..write('actualCompletedDate: $actualCompletedDate, ')
          ..write('priority: $priority, ')
          ..write('linkedPhaseId: $linkedPhaseId, ')
          ..write('seriesId: $seriesId, ')
          ..write('seriesItemIndex: $seriesItemIndex, ')
          ..write('parentTaskId: $parentTaskId, ')
          ..write('linkedApplicationId: $linkedApplicationId, ')
          ..write('estimatedMinutes: $estimatedMinutes, ')
          ..write('actualMinutes: $actualMinutes, ')
          ..write('revisitFlag: $revisitFlag, ')
          ..write('lastInteractedAt: $lastInteractedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    notes,
    plannedDate,
    actualCompletedDate,
    priority,
    linkedPhaseId,
    seriesId,
    seriesItemIndex,
    parentTaskId,
    linkedApplicationId,
    estimatedMinutes,
    actualMinutes,
    revisitFlag,
    lastInteractedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Task &&
          other.id == this.id &&
          other.title == this.title &&
          other.notes == this.notes &&
          other.plannedDate == this.plannedDate &&
          other.actualCompletedDate == this.actualCompletedDate &&
          other.priority == this.priority &&
          other.linkedPhaseId == this.linkedPhaseId &&
          other.seriesId == this.seriesId &&
          other.seriesItemIndex == this.seriesItemIndex &&
          other.parentTaskId == this.parentTaskId &&
          other.linkedApplicationId == this.linkedApplicationId &&
          other.estimatedMinutes == this.estimatedMinutes &&
          other.actualMinutes == this.actualMinutes &&
          other.revisitFlag == this.revisitFlag &&
          other.lastInteractedAt == this.lastInteractedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TaskTableCompanion extends UpdateCompanion<Task> {
  final Value<int> id;
  final Value<String> title;
  final Value<String?> notes;
  final Value<DateTime?> plannedDate;
  final Value<DateTime?> actualCompletedDate;
  final Value<String> priority;
  final Value<int?> linkedPhaseId;
  final Value<int?> seriesId;
  final Value<int?> seriesItemIndex;
  final Value<int?> parentTaskId;
  final Value<int?> linkedApplicationId;
  final Value<int?> estimatedMinutes;
  final Value<int?> actualMinutes;
  final Value<bool> revisitFlag;
  final Value<DateTime?> lastInteractedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const TaskTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.notes = const Value.absent(),
    this.plannedDate = const Value.absent(),
    this.actualCompletedDate = const Value.absent(),
    this.priority = const Value.absent(),
    this.linkedPhaseId = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.seriesItemIndex = const Value.absent(),
    this.parentTaskId = const Value.absent(),
    this.linkedApplicationId = const Value.absent(),
    this.estimatedMinutes = const Value.absent(),
    this.actualMinutes = const Value.absent(),
    this.revisitFlag = const Value.absent(),
    this.lastInteractedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TaskTableCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    this.notes = const Value.absent(),
    this.plannedDate = const Value.absent(),
    this.actualCompletedDate = const Value.absent(),
    this.priority = const Value.absent(),
    this.linkedPhaseId = const Value.absent(),
    this.seriesId = const Value.absent(),
    this.seriesItemIndex = const Value.absent(),
    this.parentTaskId = const Value.absent(),
    this.linkedApplicationId = const Value.absent(),
    this.estimatedMinutes = const Value.absent(),
    this.actualMinutes = const Value.absent(),
    this.revisitFlag = const Value.absent(),
    this.lastInteractedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : title = Value(title);
  static Insertable<Task> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? notes,
    Expression<DateTime>? plannedDate,
    Expression<DateTime>? actualCompletedDate,
    Expression<String>? priority,
    Expression<int>? linkedPhaseId,
    Expression<int>? seriesId,
    Expression<int>? seriesItemIndex,
    Expression<int>? parentTaskId,
    Expression<int>? linkedApplicationId,
    Expression<int>? estimatedMinutes,
    Expression<int>? actualMinutes,
    Expression<bool>? revisitFlag,
    Expression<DateTime>? lastInteractedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (notes != null) 'notes': notes,
      if (plannedDate != null) 'planned_date': plannedDate,
      if (actualCompletedDate != null)
        'actual_completed_date': actualCompletedDate,
      if (priority != null) 'priority': priority,
      if (linkedPhaseId != null) 'linked_phase_id': linkedPhaseId,
      if (seriesId != null) 'series_id': seriesId,
      if (seriesItemIndex != null) 'series_item_index': seriesItemIndex,
      if (parentTaskId != null) 'parent_task_id': parentTaskId,
      if (linkedApplicationId != null)
        'linked_application_id': linkedApplicationId,
      if (estimatedMinutes != null) 'estimated_minutes': estimatedMinutes,
      if (actualMinutes != null) 'actual_minutes': actualMinutes,
      if (revisitFlag != null) 'revisit_flag': revisitFlag,
      if (lastInteractedAt != null) 'last_interacted_at': lastInteractedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TaskTableCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<String?>? notes,
    Value<DateTime?>? plannedDate,
    Value<DateTime?>? actualCompletedDate,
    Value<String>? priority,
    Value<int?>? linkedPhaseId,
    Value<int?>? seriesId,
    Value<int?>? seriesItemIndex,
    Value<int?>? parentTaskId,
    Value<int?>? linkedApplicationId,
    Value<int?>? estimatedMinutes,
    Value<int?>? actualMinutes,
    Value<bool>? revisitFlag,
    Value<DateTime?>? lastInteractedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return TaskTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      notes: notes ?? this.notes,
      plannedDate: plannedDate ?? this.plannedDate,
      actualCompletedDate: actualCompletedDate ?? this.actualCompletedDate,
      priority: priority ?? this.priority,
      linkedPhaseId: linkedPhaseId ?? this.linkedPhaseId,
      seriesId: seriesId ?? this.seriesId,
      seriesItemIndex: seriesItemIndex ?? this.seriesItemIndex,
      parentTaskId: parentTaskId ?? this.parentTaskId,
      linkedApplicationId: linkedApplicationId ?? this.linkedApplicationId,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      actualMinutes: actualMinutes ?? this.actualMinutes,
      revisitFlag: revisitFlag ?? this.revisitFlag,
      lastInteractedAt: lastInteractedAt ?? this.lastInteractedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (plannedDate.present) {
      map['planned_date'] = Variable<DateTime>(plannedDate.value);
    }
    if (actualCompletedDate.present) {
      map['actual_completed_date'] = Variable<DateTime>(
        actualCompletedDate.value,
      );
    }
    if (priority.present) {
      map['priority'] = Variable<String>(priority.value);
    }
    if (linkedPhaseId.present) {
      map['linked_phase_id'] = Variable<int>(linkedPhaseId.value);
    }
    if (seriesId.present) {
      map['series_id'] = Variable<int>(seriesId.value);
    }
    if (seriesItemIndex.present) {
      map['series_item_index'] = Variable<int>(seriesItemIndex.value);
    }
    if (parentTaskId.present) {
      map['parent_task_id'] = Variable<int>(parentTaskId.value);
    }
    if (linkedApplicationId.present) {
      map['linked_application_id'] = Variable<int>(linkedApplicationId.value);
    }
    if (estimatedMinutes.present) {
      map['estimated_minutes'] = Variable<int>(estimatedMinutes.value);
    }
    if (actualMinutes.present) {
      map['actual_minutes'] = Variable<int>(actualMinutes.value);
    }
    if (revisitFlag.present) {
      map['revisit_flag'] = Variable<bool>(revisitFlag.value);
    }
    if (lastInteractedAt.present) {
      map['last_interacted_at'] = Variable<DateTime>(lastInteractedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TaskTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('notes: $notes, ')
          ..write('plannedDate: $plannedDate, ')
          ..write('actualCompletedDate: $actualCompletedDate, ')
          ..write('priority: $priority, ')
          ..write('linkedPhaseId: $linkedPhaseId, ')
          ..write('seriesId: $seriesId, ')
          ..write('seriesItemIndex: $seriesItemIndex, ')
          ..write('parentTaskId: $parentTaskId, ')
          ..write('linkedApplicationId: $linkedApplicationId, ')
          ..write('estimatedMinutes: $estimatedMinutes, ')
          ..write('actualMinutes: $actualMinutes, ')
          ..write('revisitFlag: $revisitFlag, ')
          ..write('lastInteractedAt: $lastInteractedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $DsaLogTableTable extends DsaLogTable
    with TableInfo<$DsaLogTableTable, DsaLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DsaLogTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _problemNameMeta = const VerificationMeta(
    'problemName',
  );
  @override
  late final GeneratedColumn<String> problemName = GeneratedColumn<String>(
    'problem_name',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 300,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _topicMeta = const VerificationMeta('topic');
  @override
  late final GeneratedColumn<String> topic = GeneratedColumn<String>(
    'topic',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _difficultyMeta = const VerificationMeta(
    'difficulty',
  );
  @override
  late final GeneratedColumn<String> difficulty = GeneratedColumn<String>(
    'difficulty',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dateSolvedMeta = const VerificationMeta(
    'dateSolved',
  );
  @override
  late final GeneratedColumn<DateTime> dateSolved = GeneratedColumn<DateTime>(
    'date_solved',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _revisitFlagMeta = const VerificationMeta(
    'revisitFlag',
  );
  @override
  late final GeneratedColumn<bool> revisitFlag = GeneratedColumn<bool>(
    'revisit_flag',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("revisit_flag" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _timeTakenMinutesMeta = const VerificationMeta(
    'timeTakenMinutes',
  );
  @override
  late final GeneratedColumn<int> timeTakenMinutes = GeneratedColumn<int>(
    'time_taken_minutes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _problemUrlMeta = const VerificationMeta(
    'problemUrl',
  );
  @override
  late final GeneratedColumn<String> problemUrl = GeneratedColumn<String>(
    'problem_url',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    problemName,
    topic,
    difficulty,
    dateSolved,
    revisitFlag,
    timeTakenMinutes,
    notes,
    problemUrl,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'dsa_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<DsaLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('problem_name')) {
      context.handle(
        _problemNameMeta,
        problemName.isAcceptableOrUnknown(
          data['problem_name']!,
          _problemNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_problemNameMeta);
    }
    if (data.containsKey('topic')) {
      context.handle(
        _topicMeta,
        topic.isAcceptableOrUnknown(data['topic']!, _topicMeta),
      );
    } else if (isInserting) {
      context.missing(_topicMeta);
    }
    if (data.containsKey('difficulty')) {
      context.handle(
        _difficultyMeta,
        difficulty.isAcceptableOrUnknown(data['difficulty']!, _difficultyMeta),
      );
    } else if (isInserting) {
      context.missing(_difficultyMeta);
    }
    if (data.containsKey('date_solved')) {
      context.handle(
        _dateSolvedMeta,
        dateSolved.isAcceptableOrUnknown(data['date_solved']!, _dateSolvedMeta),
      );
    } else if (isInserting) {
      context.missing(_dateSolvedMeta);
    }
    if (data.containsKey('revisit_flag')) {
      context.handle(
        _revisitFlagMeta,
        revisitFlag.isAcceptableOrUnknown(
          data['revisit_flag']!,
          _revisitFlagMeta,
        ),
      );
    }
    if (data.containsKey('time_taken_minutes')) {
      context.handle(
        _timeTakenMinutesMeta,
        timeTakenMinutes.isAcceptableOrUnknown(
          data['time_taken_minutes']!,
          _timeTakenMinutesMeta,
        ),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('problem_url')) {
      context.handle(
        _problemUrlMeta,
        problemUrl.isAcceptableOrUnknown(data['problem_url']!, _problemUrlMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DsaLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DsaLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      problemName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}problem_name'],
      )!,
      topic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}topic'],
      )!,
      difficulty: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}difficulty'],
      )!,
      dateSolved: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date_solved'],
      )!,
      revisitFlag: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}revisit_flag'],
      )!,
      timeTakenMinutes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}time_taken_minutes'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      problemUrl: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}problem_url'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $DsaLogTableTable createAlias(String alias) {
    return $DsaLogTableTable(attachedDatabase, alias);
  }
}

class DsaLog extends DataClass implements Insertable<DsaLog> {
  final int id;

  /// Name of the problem (e.g. "Two Sum").
  final String problemName;

  /// Stores the [DsaTopic] enum name (e.g. 'arrays').
  final String topic;

  /// Stores the [DsaDifficulty] enum name (e.g. 'medium').
  final String difficulty;

  /// The date on which the problem was solved.
  final DateTime dateSolved;

  /// Marks the problem for future revisit.
  final bool revisitFlag;

  /// How long the user spent on the problem, in minutes.
  final int? timeTakenMinutes;

  /// Free-text notes, approach, or learnings.
  final String? notes;

  /// Link to the problem on LeetCode, Codeforces, etc.
  final String? problemUrl;
  final DateTime createdAt;
  const DsaLog({
    required this.id,
    required this.problemName,
    required this.topic,
    required this.difficulty,
    required this.dateSolved,
    required this.revisitFlag,
    this.timeTakenMinutes,
    this.notes,
    this.problemUrl,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['problem_name'] = Variable<String>(problemName);
    map['topic'] = Variable<String>(topic);
    map['difficulty'] = Variable<String>(difficulty);
    map['date_solved'] = Variable<DateTime>(dateSolved);
    map['revisit_flag'] = Variable<bool>(revisitFlag);
    if (!nullToAbsent || timeTakenMinutes != null) {
      map['time_taken_minutes'] = Variable<int>(timeTakenMinutes);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || problemUrl != null) {
      map['problem_url'] = Variable<String>(problemUrl);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  DsaLogTableCompanion toCompanion(bool nullToAbsent) {
    return DsaLogTableCompanion(
      id: Value(id),
      problemName: Value(problemName),
      topic: Value(topic),
      difficulty: Value(difficulty),
      dateSolved: Value(dateSolved),
      revisitFlag: Value(revisitFlag),
      timeTakenMinutes: timeTakenMinutes == null && nullToAbsent
          ? const Value.absent()
          : Value(timeTakenMinutes),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      problemUrl: problemUrl == null && nullToAbsent
          ? const Value.absent()
          : Value(problemUrl),
      createdAt: Value(createdAt),
    );
  }

  factory DsaLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DsaLog(
      id: serializer.fromJson<int>(json['id']),
      problemName: serializer.fromJson<String>(json['problemName']),
      topic: serializer.fromJson<String>(json['topic']),
      difficulty: serializer.fromJson<String>(json['difficulty']),
      dateSolved: serializer.fromJson<DateTime>(json['dateSolved']),
      revisitFlag: serializer.fromJson<bool>(json['revisitFlag']),
      timeTakenMinutes: serializer.fromJson<int?>(json['timeTakenMinutes']),
      notes: serializer.fromJson<String?>(json['notes']),
      problemUrl: serializer.fromJson<String?>(json['problemUrl']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'problemName': serializer.toJson<String>(problemName),
      'topic': serializer.toJson<String>(topic),
      'difficulty': serializer.toJson<String>(difficulty),
      'dateSolved': serializer.toJson<DateTime>(dateSolved),
      'revisitFlag': serializer.toJson<bool>(revisitFlag),
      'timeTakenMinutes': serializer.toJson<int?>(timeTakenMinutes),
      'notes': serializer.toJson<String?>(notes),
      'problemUrl': serializer.toJson<String?>(problemUrl),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  DsaLog copyWith({
    int? id,
    String? problemName,
    String? topic,
    String? difficulty,
    DateTime? dateSolved,
    bool? revisitFlag,
    Value<int?> timeTakenMinutes = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<String?> problemUrl = const Value.absent(),
    DateTime? createdAt,
  }) => DsaLog(
    id: id ?? this.id,
    problemName: problemName ?? this.problemName,
    topic: topic ?? this.topic,
    difficulty: difficulty ?? this.difficulty,
    dateSolved: dateSolved ?? this.dateSolved,
    revisitFlag: revisitFlag ?? this.revisitFlag,
    timeTakenMinutes: timeTakenMinutes.present
        ? timeTakenMinutes.value
        : this.timeTakenMinutes,
    notes: notes.present ? notes.value : this.notes,
    problemUrl: problemUrl.present ? problemUrl.value : this.problemUrl,
    createdAt: createdAt ?? this.createdAt,
  );
  DsaLog copyWithCompanion(DsaLogTableCompanion data) {
    return DsaLog(
      id: data.id.present ? data.id.value : this.id,
      problemName: data.problemName.present
          ? data.problemName.value
          : this.problemName,
      topic: data.topic.present ? data.topic.value : this.topic,
      difficulty: data.difficulty.present
          ? data.difficulty.value
          : this.difficulty,
      dateSolved: data.dateSolved.present
          ? data.dateSolved.value
          : this.dateSolved,
      revisitFlag: data.revisitFlag.present
          ? data.revisitFlag.value
          : this.revisitFlag,
      timeTakenMinutes: data.timeTakenMinutes.present
          ? data.timeTakenMinutes.value
          : this.timeTakenMinutes,
      notes: data.notes.present ? data.notes.value : this.notes,
      problemUrl: data.problemUrl.present
          ? data.problemUrl.value
          : this.problemUrl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DsaLog(')
          ..write('id: $id, ')
          ..write('problemName: $problemName, ')
          ..write('topic: $topic, ')
          ..write('difficulty: $difficulty, ')
          ..write('dateSolved: $dateSolved, ')
          ..write('revisitFlag: $revisitFlag, ')
          ..write('timeTakenMinutes: $timeTakenMinutes, ')
          ..write('notes: $notes, ')
          ..write('problemUrl: $problemUrl, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    problemName,
    topic,
    difficulty,
    dateSolved,
    revisitFlag,
    timeTakenMinutes,
    notes,
    problemUrl,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DsaLog &&
          other.id == this.id &&
          other.problemName == this.problemName &&
          other.topic == this.topic &&
          other.difficulty == this.difficulty &&
          other.dateSolved == this.dateSolved &&
          other.revisitFlag == this.revisitFlag &&
          other.timeTakenMinutes == this.timeTakenMinutes &&
          other.notes == this.notes &&
          other.problemUrl == this.problemUrl &&
          other.createdAt == this.createdAt);
}

class DsaLogTableCompanion extends UpdateCompanion<DsaLog> {
  final Value<int> id;
  final Value<String> problemName;
  final Value<String> topic;
  final Value<String> difficulty;
  final Value<DateTime> dateSolved;
  final Value<bool> revisitFlag;
  final Value<int?> timeTakenMinutes;
  final Value<String?> notes;
  final Value<String?> problemUrl;
  final Value<DateTime> createdAt;
  const DsaLogTableCompanion({
    this.id = const Value.absent(),
    this.problemName = const Value.absent(),
    this.topic = const Value.absent(),
    this.difficulty = const Value.absent(),
    this.dateSolved = const Value.absent(),
    this.revisitFlag = const Value.absent(),
    this.timeTakenMinutes = const Value.absent(),
    this.notes = const Value.absent(),
    this.problemUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  DsaLogTableCompanion.insert({
    this.id = const Value.absent(),
    required String problemName,
    required String topic,
    required String difficulty,
    required DateTime dateSolved,
    this.revisitFlag = const Value.absent(),
    this.timeTakenMinutes = const Value.absent(),
    this.notes = const Value.absent(),
    this.problemUrl = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : problemName = Value(problemName),
       topic = Value(topic),
       difficulty = Value(difficulty),
       dateSolved = Value(dateSolved);
  static Insertable<DsaLog> custom({
    Expression<int>? id,
    Expression<String>? problemName,
    Expression<String>? topic,
    Expression<String>? difficulty,
    Expression<DateTime>? dateSolved,
    Expression<bool>? revisitFlag,
    Expression<int>? timeTakenMinutes,
    Expression<String>? notes,
    Expression<String>? problemUrl,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (problemName != null) 'problem_name': problemName,
      if (topic != null) 'topic': topic,
      if (difficulty != null) 'difficulty': difficulty,
      if (dateSolved != null) 'date_solved': dateSolved,
      if (revisitFlag != null) 'revisit_flag': revisitFlag,
      if (timeTakenMinutes != null) 'time_taken_minutes': timeTakenMinutes,
      if (notes != null) 'notes': notes,
      if (problemUrl != null) 'problem_url': problemUrl,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  DsaLogTableCompanion copyWith({
    Value<int>? id,
    Value<String>? problemName,
    Value<String>? topic,
    Value<String>? difficulty,
    Value<DateTime>? dateSolved,
    Value<bool>? revisitFlag,
    Value<int?>? timeTakenMinutes,
    Value<String?>? notes,
    Value<String?>? problemUrl,
    Value<DateTime>? createdAt,
  }) {
    return DsaLogTableCompanion(
      id: id ?? this.id,
      problemName: problemName ?? this.problemName,
      topic: topic ?? this.topic,
      difficulty: difficulty ?? this.difficulty,
      dateSolved: dateSolved ?? this.dateSolved,
      revisitFlag: revisitFlag ?? this.revisitFlag,
      timeTakenMinutes: timeTakenMinutes ?? this.timeTakenMinutes,
      notes: notes ?? this.notes,
      problemUrl: problemUrl ?? this.problemUrl,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (problemName.present) {
      map['problem_name'] = Variable<String>(problemName.value);
    }
    if (topic.present) {
      map['topic'] = Variable<String>(topic.value);
    }
    if (difficulty.present) {
      map['difficulty'] = Variable<String>(difficulty.value);
    }
    if (dateSolved.present) {
      map['date_solved'] = Variable<DateTime>(dateSolved.value);
    }
    if (revisitFlag.present) {
      map['revisit_flag'] = Variable<bool>(revisitFlag.value);
    }
    if (timeTakenMinutes.present) {
      map['time_taken_minutes'] = Variable<int>(timeTakenMinutes.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (problemUrl.present) {
      map['problem_url'] = Variable<String>(problemUrl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DsaLogTableCompanion(')
          ..write('id: $id, ')
          ..write('problemName: $problemName, ')
          ..write('topic: $topic, ')
          ..write('difficulty: $difficulty, ')
          ..write('dateSolved: $dateSolved, ')
          ..write('revisitFlag: $revisitFlag, ')
          ..write('timeTakenMinutes: $timeTakenMinutes, ')
          ..write('notes: $notes, ')
          ..write('problemUrl: $problemUrl, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ApplicationStatusHistoryTableTable extends ApplicationStatusHistoryTable
    with
        TableInfo<
          $ApplicationStatusHistoryTableTable,
          ApplicationStatusHistory
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ApplicationStatusHistoryTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _applicationIdMeta = const VerificationMeta(
    'applicationId',
  );
  @override
  late final GeneratedColumn<int> applicationId = GeneratedColumn<int>(
    'application_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES applications (id)',
    ),
  );
  static const VerificationMeta _stageMeta = const VerificationMeta('stage');
  @override
  late final GeneratedColumn<String> stage = GeneratedColumn<String>(
    'stage',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    applicationId,
    stage,
    notes,
    occurredAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'application_status_history';
  @override
  VerificationContext validateIntegrity(
    Insertable<ApplicationStatusHistory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('application_id')) {
      context.handle(
        _applicationIdMeta,
        applicationId.isAcceptableOrUnknown(
          data['application_id']!,
          _applicationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_applicationIdMeta);
    }
    if (data.containsKey('stage')) {
      context.handle(
        _stageMeta,
        stage.isAcceptableOrUnknown(data['stage']!, _stageMeta),
      );
    } else if (isInserting) {
      context.missing(_stageMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ApplicationStatusHistory map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ApplicationStatusHistory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      applicationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}application_id'],
      )!,
      stage: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}stage'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
    );
  }

  @override
  $ApplicationStatusHistoryTableTable createAlias(String alias) {
    return $ApplicationStatusHistoryTableTable(attachedDatabase, alias);
  }
}

class ApplicationStatusHistory extends DataClass
    implements Insertable<ApplicationStatusHistory> {
  final int id;

  /// FK to [ApplicationTable].
  final int applicationId;

  /// Stores the [ApplicationStage] enum name.
  final String stage;
  final String? notes;
  final DateTime occurredAt;
  const ApplicationStatusHistory({
    required this.id,
    required this.applicationId,
    required this.stage,
    this.notes,
    required this.occurredAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['application_id'] = Variable<int>(applicationId);
    map['stage'] = Variable<String>(stage);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    return map;
  }

  ApplicationStatusHistoryTableCompanion toCompanion(bool nullToAbsent) {
    return ApplicationStatusHistoryTableCompanion(
      id: Value(id),
      applicationId: Value(applicationId),
      stage: Value(stage),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      occurredAt: Value(occurredAt),
    );
  }

  factory ApplicationStatusHistory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ApplicationStatusHistory(
      id: serializer.fromJson<int>(json['id']),
      applicationId: serializer.fromJson<int>(json['applicationId']),
      stage: serializer.fromJson<String>(json['stage']),
      notes: serializer.fromJson<String?>(json['notes']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'applicationId': serializer.toJson<int>(applicationId),
      'stage': serializer.toJson<String>(stage),
      'notes': serializer.toJson<String?>(notes),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
    };
  }

  ApplicationStatusHistory copyWith({
    int? id,
    int? applicationId,
    String? stage,
    Value<String?> notes = const Value.absent(),
    DateTime? occurredAt,
  }) => ApplicationStatusHistory(
    id: id ?? this.id,
    applicationId: applicationId ?? this.applicationId,
    stage: stage ?? this.stage,
    notes: notes.present ? notes.value : this.notes,
    occurredAt: occurredAt ?? this.occurredAt,
  );
  ApplicationStatusHistory copyWithCompanion(
    ApplicationStatusHistoryTableCompanion data,
  ) {
    return ApplicationStatusHistory(
      id: data.id.present ? data.id.value : this.id,
      applicationId: data.applicationId.present
          ? data.applicationId.value
          : this.applicationId,
      stage: data.stage.present ? data.stage.value : this.stage,
      notes: data.notes.present ? data.notes.value : this.notes,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ApplicationStatusHistory(')
          ..write('id: $id, ')
          ..write('applicationId: $applicationId, ')
          ..write('stage: $stage, ')
          ..write('notes: $notes, ')
          ..write('occurredAt: $occurredAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, applicationId, stage, notes, occurredAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ApplicationStatusHistory &&
          other.id == this.id &&
          other.applicationId == this.applicationId &&
          other.stage == this.stage &&
          other.notes == this.notes &&
          other.occurredAt == this.occurredAt);
}

class ApplicationStatusHistoryTableCompanion
    extends UpdateCompanion<ApplicationStatusHistory> {
  final Value<int> id;
  final Value<int> applicationId;
  final Value<String> stage;
  final Value<String?> notes;
  final Value<DateTime> occurredAt;
  const ApplicationStatusHistoryTableCompanion({
    this.id = const Value.absent(),
    this.applicationId = const Value.absent(),
    this.stage = const Value.absent(),
    this.notes = const Value.absent(),
    this.occurredAt = const Value.absent(),
  });
  ApplicationStatusHistoryTableCompanion.insert({
    this.id = const Value.absent(),
    required int applicationId,
    required String stage,
    this.notes = const Value.absent(),
    this.occurredAt = const Value.absent(),
  }) : applicationId = Value(applicationId),
       stage = Value(stage);
  static Insertable<ApplicationStatusHistory> custom({
    Expression<int>? id,
    Expression<int>? applicationId,
    Expression<String>? stage,
    Expression<String>? notes,
    Expression<DateTime>? occurredAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (applicationId != null) 'application_id': applicationId,
      if (stage != null) 'stage': stage,
      if (notes != null) 'notes': notes,
      if (occurredAt != null) 'occurred_at': occurredAt,
    });
  }

  ApplicationStatusHistoryTableCompanion copyWith({
    Value<int>? id,
    Value<int>? applicationId,
    Value<String>? stage,
    Value<String?>? notes,
    Value<DateTime>? occurredAt,
  }) {
    return ApplicationStatusHistoryTableCompanion(
      id: id ?? this.id,
      applicationId: applicationId ?? this.applicationId,
      stage: stage ?? this.stage,
      notes: notes ?? this.notes,
      occurredAt: occurredAt ?? this.occurredAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (applicationId.present) {
      map['application_id'] = Variable<int>(applicationId.value);
    }
    if (stage.present) {
      map['stage'] = Variable<String>(stage.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ApplicationStatusHistoryTableCompanion(')
          ..write('id: $id, ')
          ..write('applicationId: $applicationId, ')
          ..write('stage: $stage, ')
          ..write('notes: $notes, ')
          ..write('occurredAt: $occurredAt')
          ..write(')'))
        .toString();
  }
}

class $ConsistencyLogTableTable extends ConsistencyLogTable
    with TableInfo<$ConsistencyLogTableTable, ConsistencyLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ConsistencyLogTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _presentMeta = const VerificationMeta(
    'present',
  );
  @override
  late final GeneratedColumn<bool> present = GeneratedColumn<bool>(
    'present',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("present" IN (0, 1))',
    ),
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _hoursStudiedMeta = const VerificationMeta(
    'hoursStudied',
  );
  @override
  late final GeneratedColumn<double> hoursStudied = GeneratedColumn<double>(
    'hours_studied',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [id, date, present, note, hoursStudied];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'consistency_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<ConsistencyLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('present')) {
      context.handle(
        _presentMeta,
        present.isAcceptableOrUnknown(data['present']!, _presentMeta),
      );
    } else if (isInserting) {
      context.missing(_presentMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('hours_studied')) {
      context.handle(
        _hoursStudiedMeta,
        hoursStudied.isAcceptableOrUnknown(
          data['hours_studied']!,
          _hoursStudiedMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {date},
  ];
  @override
  ConsistencyLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ConsistencyLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      present: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}present'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      hoursStudied: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}hours_studied'],
      ),
    );
  }

  @override
  $ConsistencyLogTableTable createAlias(String alias) {
    return $ConsistencyLogTableTable(attachedDatabase, alias);
  }
}

class ConsistencyLog extends DataClass implements Insertable<ConsistencyLog> {
  final int id;

  /// Store as midnight UTC to represent a calendar date (e.g. 2024-01-15 00:00:00Z).
  final DateTime date;

  /// true = user showed up and studied; false = absent day.
  final bool present;

  /// Optional note about the day.
  final String? note;

  /// Actual hours studied that day (logged manually or from focus timer).
  final double? hoursStudied;
  const ConsistencyLog({
    required this.id,
    required this.date,
    required this.present,
    this.note,
    this.hoursStudied,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date'] = Variable<DateTime>(date);
    map['present'] = Variable<bool>(present);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    if (!nullToAbsent || hoursStudied != null) {
      map['hours_studied'] = Variable<double>(hoursStudied);
    }
    return map;
  }

  ConsistencyLogTableCompanion toCompanion(bool nullToAbsent) {
    return ConsistencyLogTableCompanion(
      id: Value(id),
      date: Value(date),
      present: Value(present),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      hoursStudied: hoursStudied == null && nullToAbsent
          ? const Value.absent()
          : Value(hoursStudied),
    );
  }

  factory ConsistencyLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ConsistencyLog(
      id: serializer.fromJson<int>(json['id']),
      date: serializer.fromJson<DateTime>(json['date']),
      present: serializer.fromJson<bool>(json['present']),
      note: serializer.fromJson<String?>(json['note']),
      hoursStudied: serializer.fromJson<double?>(json['hoursStudied']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'date': serializer.toJson<DateTime>(date),
      'present': serializer.toJson<bool>(present),
      'note': serializer.toJson<String?>(note),
      'hoursStudied': serializer.toJson<double?>(hoursStudied),
    };
  }

  ConsistencyLog copyWith({
    int? id,
    DateTime? date,
    bool? present,
    Value<String?> note = const Value.absent(),
    Value<double?> hoursStudied = const Value.absent(),
  }) => ConsistencyLog(
    id: id ?? this.id,
    date: date ?? this.date,
    present: present ?? this.present,
    note: note.present ? note.value : this.note,
    hoursStudied: hoursStudied.present ? hoursStudied.value : this.hoursStudied,
  );
  ConsistencyLog copyWithCompanion(ConsistencyLogTableCompanion data) {
    return ConsistencyLog(
      id: data.id.present ? data.id.value : this.id,
      date: data.date.present ? data.date.value : this.date,
      present: data.present.present ? data.present.value : this.present,
      note: data.note.present ? data.note.value : this.note,
      hoursStudied: data.hoursStudied.present
          ? data.hoursStudied.value
          : this.hoursStudied,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ConsistencyLog(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('present: $present, ')
          ..write('note: $note, ')
          ..write('hoursStudied: $hoursStudied')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, date, present, note, hoursStudied);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ConsistencyLog &&
          other.id == this.id &&
          other.date == this.date &&
          other.present == this.present &&
          other.note == this.note &&
          other.hoursStudied == this.hoursStudied);
}

class ConsistencyLogTableCompanion extends UpdateCompanion<ConsistencyLog> {
  final Value<int> id;
  final Value<DateTime> date;
  final Value<bool> present;
  final Value<String?> note;
  final Value<double?> hoursStudied;
  const ConsistencyLogTableCompanion({
    this.id = const Value.absent(),
    this.date = const Value.absent(),
    this.present = const Value.absent(),
    this.note = const Value.absent(),
    this.hoursStudied = const Value.absent(),
  });
  ConsistencyLogTableCompanion.insert({
    this.id = const Value.absent(),
    required DateTime date,
    required bool present,
    this.note = const Value.absent(),
    this.hoursStudied = const Value.absent(),
  }) : date = Value(date),
       present = Value(present);
  static Insertable<ConsistencyLog> custom({
    Expression<int>? id,
    Expression<DateTime>? date,
    Expression<bool>? present,
    Expression<String>? note,
    Expression<double>? hoursStudied,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (date != null) 'date': date,
      if (present != null) 'present': present,
      if (note != null) 'note': note,
      if (hoursStudied != null) 'hours_studied': hoursStudied,
    });
  }

  ConsistencyLogTableCompanion copyWith({
    Value<int>? id,
    Value<DateTime>? date,
    Value<bool>? present,
    Value<String?>? note,
    Value<double?>? hoursStudied,
  }) {
    return ConsistencyLogTableCompanion(
      id: id ?? this.id,
      date: date ?? this.date,
      present: present ?? this.present,
      note: note ?? this.note,
      hoursStudied: hoursStudied ?? this.hoursStudied,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (present.present) {
      map['present'] = Variable<bool>(present.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (hoursStudied.present) {
      map['hours_studied'] = Variable<double>(hoursStudied.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ConsistencyLogTableCompanion(')
          ..write('id: $id, ')
          ..write('date: $date, ')
          ..write('present: $present, ')
          ..write('note: $note, ')
          ..write('hoursStudied: $hoursStudied')
          ..write(')'))
        .toString();
  }
}

class $ResumeTableTable extends ResumeTable
    with TableInfo<$ResumeTableTable, Resume> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ResumeTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _versionLabelMeta = const VerificationMeta(
    'versionLabel',
  );
  @override
  late final GeneratedColumn<String> versionLabel = GeneratedColumn<String>(
    'version_label',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 200,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _filePathMeta = const VerificationMeta(
    'filePath',
  );
  @override
  late final GeneratedColumn<String> filePath = GeneratedColumn<String>(
    'file_path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileSizeMeta = const VerificationMeta(
    'fileSize',
  );
  @override
  late final GeneratedColumn<int> fileSize = GeneratedColumn<int>(
    'file_size',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _tailoredForCompanyMeta =
      const VerificationMeta('tailoredForCompany');
  @override
  late final GeneratedColumn<String> tailoredForCompany =
      GeneratedColumn<String>(
        'tailored_for_company',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _linkedApplicationIdMeta =
      const VerificationMeta('linkedApplicationId');
  @override
  late final GeneratedColumn<int> linkedApplicationId = GeneratedColumn<int>(
    'linked_application_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES applications (id)',
    ),
  );
  static const VerificationMeta _uploadedAtMeta = const VerificationMeta(
    'uploadedAt',
  );
  @override
  late final GeneratedColumn<DateTime> uploadedAt = GeneratedColumn<DateTime>(
    'uploaded_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    versionLabel,
    filePath,
    fileSize,
    tailoredForCompany,
    linkedApplicationId,
    uploadedAt,
    notes,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'resumes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Resume> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('version_label')) {
      context.handle(
        _versionLabelMeta,
        versionLabel.isAcceptableOrUnknown(
          data['version_label']!,
          _versionLabelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_versionLabelMeta);
    }
    if (data.containsKey('file_path')) {
      context.handle(
        _filePathMeta,
        filePath.isAcceptableOrUnknown(data['file_path']!, _filePathMeta),
      );
    } else if (isInserting) {
      context.missing(_filePathMeta);
    }
    if (data.containsKey('file_size')) {
      context.handle(
        _fileSizeMeta,
        fileSize.isAcceptableOrUnknown(data['file_size']!, _fileSizeMeta),
      );
    }
    if (data.containsKey('tailored_for_company')) {
      context.handle(
        _tailoredForCompanyMeta,
        tailoredForCompany.isAcceptableOrUnknown(
          data['tailored_for_company']!,
          _tailoredForCompanyMeta,
        ),
      );
    }
    if (data.containsKey('linked_application_id')) {
      context.handle(
        _linkedApplicationIdMeta,
        linkedApplicationId.isAcceptableOrUnknown(
          data['linked_application_id']!,
          _linkedApplicationIdMeta,
        ),
      );
    }
    if (data.containsKey('uploaded_at')) {
      context.handle(
        _uploadedAtMeta,
        uploadedAt.isAcceptableOrUnknown(data['uploaded_at']!, _uploadedAtMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Resume map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Resume(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      versionLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}version_label'],
      )!,
      filePath: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}file_path'],
      )!,
      fileSize: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}file_size'],
      ),
      tailoredForCompany: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tailored_for_company'],
      ),
      linkedApplicationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}linked_application_id'],
      ),
      uploadedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}uploaded_at'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
    );
  }

  @override
  $ResumeTableTable createAlias(String alias) {
    return $ResumeTableTable(attachedDatabase, alias);
  }
}

class Resume extends DataClass implements Insertable<Resume> {
  final int id;

  /// Human-readable version label (e.g. 'v2 - SDE roles', 'Backend specific').
  final String versionLabel;

  /// Absolute path to the file in the app's documents directory.
  final String filePath;

  /// File size in bytes (populated after upload).
  final int? fileSize;

  /// If this resume is tailored for a specific company.
  final String? tailoredForCompany;

  /// Optional FK linking to an [ApplicationTable] entry.
  final int? linkedApplicationId;
  final DateTime uploadedAt;
  final String? notes;
  const Resume({
    required this.id,
    required this.versionLabel,
    required this.filePath,
    this.fileSize,
    this.tailoredForCompany,
    this.linkedApplicationId,
    required this.uploadedAt,
    this.notes,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['version_label'] = Variable<String>(versionLabel);
    map['file_path'] = Variable<String>(filePath);
    if (!nullToAbsent || fileSize != null) {
      map['file_size'] = Variable<int>(fileSize);
    }
    if (!nullToAbsent || tailoredForCompany != null) {
      map['tailored_for_company'] = Variable<String>(tailoredForCompany);
    }
    if (!nullToAbsent || linkedApplicationId != null) {
      map['linked_application_id'] = Variable<int>(linkedApplicationId);
    }
    map['uploaded_at'] = Variable<DateTime>(uploadedAt);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    return map;
  }

  ResumeTableCompanion toCompanion(bool nullToAbsent) {
    return ResumeTableCompanion(
      id: Value(id),
      versionLabel: Value(versionLabel),
      filePath: Value(filePath),
      fileSize: fileSize == null && nullToAbsent
          ? const Value.absent()
          : Value(fileSize),
      tailoredForCompany: tailoredForCompany == null && nullToAbsent
          ? const Value.absent()
          : Value(tailoredForCompany),
      linkedApplicationId: linkedApplicationId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedApplicationId),
      uploadedAt: Value(uploadedAt),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
    );
  }

  factory Resume.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Resume(
      id: serializer.fromJson<int>(json['id']),
      versionLabel: serializer.fromJson<String>(json['versionLabel']),
      filePath: serializer.fromJson<String>(json['filePath']),
      fileSize: serializer.fromJson<int?>(json['fileSize']),
      tailoredForCompany: serializer.fromJson<String?>(
        json['tailoredForCompany'],
      ),
      linkedApplicationId: serializer.fromJson<int?>(
        json['linkedApplicationId'],
      ),
      uploadedAt: serializer.fromJson<DateTime>(json['uploadedAt']),
      notes: serializer.fromJson<String?>(json['notes']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'versionLabel': serializer.toJson<String>(versionLabel),
      'filePath': serializer.toJson<String>(filePath),
      'fileSize': serializer.toJson<int?>(fileSize),
      'tailoredForCompany': serializer.toJson<String?>(tailoredForCompany),
      'linkedApplicationId': serializer.toJson<int?>(linkedApplicationId),
      'uploadedAt': serializer.toJson<DateTime>(uploadedAt),
      'notes': serializer.toJson<String?>(notes),
    };
  }

  Resume copyWith({
    int? id,
    String? versionLabel,
    String? filePath,
    Value<int?> fileSize = const Value.absent(),
    Value<String?> tailoredForCompany = const Value.absent(),
    Value<int?> linkedApplicationId = const Value.absent(),
    DateTime? uploadedAt,
    Value<String?> notes = const Value.absent(),
  }) => Resume(
    id: id ?? this.id,
    versionLabel: versionLabel ?? this.versionLabel,
    filePath: filePath ?? this.filePath,
    fileSize: fileSize.present ? fileSize.value : this.fileSize,
    tailoredForCompany: tailoredForCompany.present
        ? tailoredForCompany.value
        : this.tailoredForCompany,
    linkedApplicationId: linkedApplicationId.present
        ? linkedApplicationId.value
        : this.linkedApplicationId,
    uploadedAt: uploadedAt ?? this.uploadedAt,
    notes: notes.present ? notes.value : this.notes,
  );
  Resume copyWithCompanion(ResumeTableCompanion data) {
    return Resume(
      id: data.id.present ? data.id.value : this.id,
      versionLabel: data.versionLabel.present
          ? data.versionLabel.value
          : this.versionLabel,
      filePath: data.filePath.present ? data.filePath.value : this.filePath,
      fileSize: data.fileSize.present ? data.fileSize.value : this.fileSize,
      tailoredForCompany: data.tailoredForCompany.present
          ? data.tailoredForCompany.value
          : this.tailoredForCompany,
      linkedApplicationId: data.linkedApplicationId.present
          ? data.linkedApplicationId.value
          : this.linkedApplicationId,
      uploadedAt: data.uploadedAt.present
          ? data.uploadedAt.value
          : this.uploadedAt,
      notes: data.notes.present ? data.notes.value : this.notes,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Resume(')
          ..write('id: $id, ')
          ..write('versionLabel: $versionLabel, ')
          ..write('filePath: $filePath, ')
          ..write('fileSize: $fileSize, ')
          ..write('tailoredForCompany: $tailoredForCompany, ')
          ..write('linkedApplicationId: $linkedApplicationId, ')
          ..write('uploadedAt: $uploadedAt, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    versionLabel,
    filePath,
    fileSize,
    tailoredForCompany,
    linkedApplicationId,
    uploadedAt,
    notes,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Resume &&
          other.id == this.id &&
          other.versionLabel == this.versionLabel &&
          other.filePath == this.filePath &&
          other.fileSize == this.fileSize &&
          other.tailoredForCompany == this.tailoredForCompany &&
          other.linkedApplicationId == this.linkedApplicationId &&
          other.uploadedAt == this.uploadedAt &&
          other.notes == this.notes);
}

class ResumeTableCompanion extends UpdateCompanion<Resume> {
  final Value<int> id;
  final Value<String> versionLabel;
  final Value<String> filePath;
  final Value<int?> fileSize;
  final Value<String?> tailoredForCompany;
  final Value<int?> linkedApplicationId;
  final Value<DateTime> uploadedAt;
  final Value<String?> notes;
  const ResumeTableCompanion({
    this.id = const Value.absent(),
    this.versionLabel = const Value.absent(),
    this.filePath = const Value.absent(),
    this.fileSize = const Value.absent(),
    this.tailoredForCompany = const Value.absent(),
    this.linkedApplicationId = const Value.absent(),
    this.uploadedAt = const Value.absent(),
    this.notes = const Value.absent(),
  });
  ResumeTableCompanion.insert({
    this.id = const Value.absent(),
    required String versionLabel,
    required String filePath,
    this.fileSize = const Value.absent(),
    this.tailoredForCompany = const Value.absent(),
    this.linkedApplicationId = const Value.absent(),
    this.uploadedAt = const Value.absent(),
    this.notes = const Value.absent(),
  }) : versionLabel = Value(versionLabel),
       filePath = Value(filePath);
  static Insertable<Resume> custom({
    Expression<int>? id,
    Expression<String>? versionLabel,
    Expression<String>? filePath,
    Expression<int>? fileSize,
    Expression<String>? tailoredForCompany,
    Expression<int>? linkedApplicationId,
    Expression<DateTime>? uploadedAt,
    Expression<String>? notes,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (versionLabel != null) 'version_label': versionLabel,
      if (filePath != null) 'file_path': filePath,
      if (fileSize != null) 'file_size': fileSize,
      if (tailoredForCompany != null)
        'tailored_for_company': tailoredForCompany,
      if (linkedApplicationId != null)
        'linked_application_id': linkedApplicationId,
      if (uploadedAt != null) 'uploaded_at': uploadedAt,
      if (notes != null) 'notes': notes,
    });
  }

  ResumeTableCompanion copyWith({
    Value<int>? id,
    Value<String>? versionLabel,
    Value<String>? filePath,
    Value<int?>? fileSize,
    Value<String?>? tailoredForCompany,
    Value<int?>? linkedApplicationId,
    Value<DateTime>? uploadedAt,
    Value<String?>? notes,
  }) {
    return ResumeTableCompanion(
      id: id ?? this.id,
      versionLabel: versionLabel ?? this.versionLabel,
      filePath: filePath ?? this.filePath,
      fileSize: fileSize ?? this.fileSize,
      tailoredForCompany: tailoredForCompany ?? this.tailoredForCompany,
      linkedApplicationId: linkedApplicationId ?? this.linkedApplicationId,
      uploadedAt: uploadedAt ?? this.uploadedAt,
      notes: notes ?? this.notes,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (versionLabel.present) {
      map['version_label'] = Variable<String>(versionLabel.value);
    }
    if (filePath.present) {
      map['file_path'] = Variable<String>(filePath.value);
    }
    if (fileSize.present) {
      map['file_size'] = Variable<int>(fileSize.value);
    }
    if (tailoredForCompany.present) {
      map['tailored_for_company'] = Variable<String>(tailoredForCompany.value);
    }
    if (linkedApplicationId.present) {
      map['linked_application_id'] = Variable<int>(linkedApplicationId.value);
    }
    if (uploadedAt.present) {
      map['uploaded_at'] = Variable<DateTime>(uploadedAt.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ResumeTableCompanion(')
          ..write('id: $id, ')
          ..write('versionLabel: $versionLabel, ')
          ..write('filePath: $filePath, ')
          ..write('fileSize: $fileSize, ')
          ..write('tailoredForCompany: $tailoredForCompany, ')
          ..write('linkedApplicationId: $linkedApplicationId, ')
          ..write('uploadedAt: $uploadedAt, ')
          ..write('notes: $notes')
          ..write(')'))
        .toString();
  }
}

class $InterviewPrepTableTable extends InterviewPrepTable
    with TableInfo<$InterviewPrepTableTable, InterviewPrep> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InterviewPrepTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _companyMeta = const VerificationMeta(
    'company',
  );
  @override
  late final GeneratedColumn<String> company = GeneratedColumn<String>(
    'company',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkedApplicationIdMeta =
      const VerificationMeta('linkedApplicationId');
  @override
  late final GeneratedColumn<int> linkedApplicationId = GeneratedColumn<int>(
    'linked_application_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES applications (id)',
    ),
  );
  static const VerificationMeta _questionAskedMeta = const VerificationMeta(
    'questionAsked',
  );
  @override
  late final GeneratedColumn<String> questionAsked = GeneratedColumn<String>(
    'question_asked',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _answerNotesMeta = const VerificationMeta(
    'answerNotes',
  );
  @override
  late final GeneratedColumn<String> answerNotes = GeneratedColumn<String>(
    'answer_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outcomeMeta = const VerificationMeta(
    'outcome',
  );
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _preparedAtMeta = const VerificationMeta(
    'preparedAt',
  );
  @override
  late final GeneratedColumn<DateTime> preparedAt = GeneratedColumn<DateTime>(
    'prepared_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _lastInteractedAtMeta = const VerificationMeta(
    'lastInteractedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastInteractedAt =
      GeneratedColumn<DateTime>(
        'last_interacted_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    company,
    role,
    linkedApplicationId,
    questionAsked,
    answerNotes,
    outcome,
    category,
    preparedAt,
    lastInteractedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'interview_prep';
  @override
  VerificationContext validateIntegrity(
    Insertable<InterviewPrep> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('company')) {
      context.handle(
        _companyMeta,
        company.isAcceptableOrUnknown(data['company']!, _companyMeta),
      );
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    }
    if (data.containsKey('linked_application_id')) {
      context.handle(
        _linkedApplicationIdMeta,
        linkedApplicationId.isAcceptableOrUnknown(
          data['linked_application_id']!,
          _linkedApplicationIdMeta,
        ),
      );
    }
    if (data.containsKey('question_asked')) {
      context.handle(
        _questionAskedMeta,
        questionAsked.isAcceptableOrUnknown(
          data['question_asked']!,
          _questionAskedMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_questionAskedMeta);
    }
    if (data.containsKey('answer_notes')) {
      context.handle(
        _answerNotesMeta,
        answerNotes.isAcceptableOrUnknown(
          data['answer_notes']!,
          _answerNotesMeta,
        ),
      );
    }
    if (data.containsKey('outcome')) {
      context.handle(
        _outcomeMeta,
        outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('prepared_at')) {
      context.handle(
        _preparedAtMeta,
        preparedAt.isAcceptableOrUnknown(data['prepared_at']!, _preparedAtMeta),
      );
    }
    if (data.containsKey('last_interacted_at')) {
      context.handle(
        _lastInteractedAtMeta,
        lastInteractedAt.isAcceptableOrUnknown(
          data['last_interacted_at']!,
          _lastInteractedAtMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InterviewPrep map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InterviewPrep(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      company: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company'],
      ),
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      ),
      linkedApplicationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}linked_application_id'],
      ),
      questionAsked: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}question_asked'],
      )!,
      answerNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}answer_notes'],
      ),
      outcome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      preparedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}prepared_at'],
      )!,
      lastInteractedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_interacted_at'],
      ),
    );
  }

  @override
  $InterviewPrepTableTable createAlias(String alias) {
    return $InterviewPrepTableTable(attachedDatabase, alias);
  }
}

class InterviewPrep extends DataClass implements Insertable<InterviewPrep> {
  final int id;

  /// Company the interview is / was with.
  final String? company;

  /// Role being interviewed for.
  final String? role;

  /// Optional FK to [ApplicationTable].
  final int? linkedApplicationId;

  /// The actual interview question.
  final String questionAsked;

  /// User's answer notes / approach.
  final String? answerNotes;

  /// Self-assessment of the answer (e.g. 'Good', 'Needs work', 'Stumped').
  final String? outcome;

  /// Question category (e.g. 'Behavioral', 'DSA', 'System Design').
  final String? category;
  final DateTime preparedAt;

  /// Last time the user opened or reviewed this prep entry.
  final DateTime? lastInteractedAt;
  const InterviewPrep({
    required this.id,
    this.company,
    this.role,
    this.linkedApplicationId,
    required this.questionAsked,
    this.answerNotes,
    this.outcome,
    this.category,
    required this.preparedAt,
    this.lastInteractedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || company != null) {
      map['company'] = Variable<String>(company);
    }
    if (!nullToAbsent || role != null) {
      map['role'] = Variable<String>(role);
    }
    if (!nullToAbsent || linkedApplicationId != null) {
      map['linked_application_id'] = Variable<int>(linkedApplicationId);
    }
    map['question_asked'] = Variable<String>(questionAsked);
    if (!nullToAbsent || answerNotes != null) {
      map['answer_notes'] = Variable<String>(answerNotes);
    }
    if (!nullToAbsent || outcome != null) {
      map['outcome'] = Variable<String>(outcome);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['prepared_at'] = Variable<DateTime>(preparedAt);
    if (!nullToAbsent || lastInteractedAt != null) {
      map['last_interacted_at'] = Variable<DateTime>(lastInteractedAt);
    }
    return map;
  }

  InterviewPrepTableCompanion toCompanion(bool nullToAbsent) {
    return InterviewPrepTableCompanion(
      id: Value(id),
      company: company == null && nullToAbsent
          ? const Value.absent()
          : Value(company),
      role: role == null && nullToAbsent ? const Value.absent() : Value(role),
      linkedApplicationId: linkedApplicationId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedApplicationId),
      questionAsked: Value(questionAsked),
      answerNotes: answerNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(answerNotes),
      outcome: outcome == null && nullToAbsent
          ? const Value.absent()
          : Value(outcome),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      preparedAt: Value(preparedAt),
      lastInteractedAt: lastInteractedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastInteractedAt),
    );
  }

  factory InterviewPrep.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InterviewPrep(
      id: serializer.fromJson<int>(json['id']),
      company: serializer.fromJson<String?>(json['company']),
      role: serializer.fromJson<String?>(json['role']),
      linkedApplicationId: serializer.fromJson<int?>(
        json['linkedApplicationId'],
      ),
      questionAsked: serializer.fromJson<String>(json['questionAsked']),
      answerNotes: serializer.fromJson<String?>(json['answerNotes']),
      outcome: serializer.fromJson<String?>(json['outcome']),
      category: serializer.fromJson<String?>(json['category']),
      preparedAt: serializer.fromJson<DateTime>(json['preparedAt']),
      lastInteractedAt: serializer.fromJson<DateTime?>(
        json['lastInteractedAt'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'company': serializer.toJson<String?>(company),
      'role': serializer.toJson<String?>(role),
      'linkedApplicationId': serializer.toJson<int?>(linkedApplicationId),
      'questionAsked': serializer.toJson<String>(questionAsked),
      'answerNotes': serializer.toJson<String?>(answerNotes),
      'outcome': serializer.toJson<String?>(outcome),
      'category': serializer.toJson<String?>(category),
      'preparedAt': serializer.toJson<DateTime>(preparedAt),
      'lastInteractedAt': serializer.toJson<DateTime?>(lastInteractedAt),
    };
  }

  InterviewPrep copyWith({
    int? id,
    Value<String?> company = const Value.absent(),
    Value<String?> role = const Value.absent(),
    Value<int?> linkedApplicationId = const Value.absent(),
    String? questionAsked,
    Value<String?> answerNotes = const Value.absent(),
    Value<String?> outcome = const Value.absent(),
    Value<String?> category = const Value.absent(),
    DateTime? preparedAt,
    Value<DateTime?> lastInteractedAt = const Value.absent(),
  }) => InterviewPrep(
    id: id ?? this.id,
    company: company.present ? company.value : this.company,
    role: role.present ? role.value : this.role,
    linkedApplicationId: linkedApplicationId.present
        ? linkedApplicationId.value
        : this.linkedApplicationId,
    questionAsked: questionAsked ?? this.questionAsked,
    answerNotes: answerNotes.present ? answerNotes.value : this.answerNotes,
    outcome: outcome.present ? outcome.value : this.outcome,
    category: category.present ? category.value : this.category,
    preparedAt: preparedAt ?? this.preparedAt,
    lastInteractedAt: lastInteractedAt.present
        ? lastInteractedAt.value
        : this.lastInteractedAt,
  );
  InterviewPrep copyWithCompanion(InterviewPrepTableCompanion data) {
    return InterviewPrep(
      id: data.id.present ? data.id.value : this.id,
      company: data.company.present ? data.company.value : this.company,
      role: data.role.present ? data.role.value : this.role,
      linkedApplicationId: data.linkedApplicationId.present
          ? data.linkedApplicationId.value
          : this.linkedApplicationId,
      questionAsked: data.questionAsked.present
          ? data.questionAsked.value
          : this.questionAsked,
      answerNotes: data.answerNotes.present
          ? data.answerNotes.value
          : this.answerNotes,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      category: data.category.present ? data.category.value : this.category,
      preparedAt: data.preparedAt.present
          ? data.preparedAt.value
          : this.preparedAt,
      lastInteractedAt: data.lastInteractedAt.present
          ? data.lastInteractedAt.value
          : this.lastInteractedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InterviewPrep(')
          ..write('id: $id, ')
          ..write('company: $company, ')
          ..write('role: $role, ')
          ..write('linkedApplicationId: $linkedApplicationId, ')
          ..write('questionAsked: $questionAsked, ')
          ..write('answerNotes: $answerNotes, ')
          ..write('outcome: $outcome, ')
          ..write('category: $category, ')
          ..write('preparedAt: $preparedAt, ')
          ..write('lastInteractedAt: $lastInteractedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    company,
    role,
    linkedApplicationId,
    questionAsked,
    answerNotes,
    outcome,
    category,
    preparedAt,
    lastInteractedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InterviewPrep &&
          other.id == this.id &&
          other.company == this.company &&
          other.role == this.role &&
          other.linkedApplicationId == this.linkedApplicationId &&
          other.questionAsked == this.questionAsked &&
          other.answerNotes == this.answerNotes &&
          other.outcome == this.outcome &&
          other.category == this.category &&
          other.preparedAt == this.preparedAt &&
          other.lastInteractedAt == this.lastInteractedAt);
}

class InterviewPrepTableCompanion extends UpdateCompanion<InterviewPrep> {
  final Value<int> id;
  final Value<String?> company;
  final Value<String?> role;
  final Value<int?> linkedApplicationId;
  final Value<String> questionAsked;
  final Value<String?> answerNotes;
  final Value<String?> outcome;
  final Value<String?> category;
  final Value<DateTime> preparedAt;
  final Value<DateTime?> lastInteractedAt;
  const InterviewPrepTableCompanion({
    this.id = const Value.absent(),
    this.company = const Value.absent(),
    this.role = const Value.absent(),
    this.linkedApplicationId = const Value.absent(),
    this.questionAsked = const Value.absent(),
    this.answerNotes = const Value.absent(),
    this.outcome = const Value.absent(),
    this.category = const Value.absent(),
    this.preparedAt = const Value.absent(),
    this.lastInteractedAt = const Value.absent(),
  });
  InterviewPrepTableCompanion.insert({
    this.id = const Value.absent(),
    this.company = const Value.absent(),
    this.role = const Value.absent(),
    this.linkedApplicationId = const Value.absent(),
    required String questionAsked,
    this.answerNotes = const Value.absent(),
    this.outcome = const Value.absent(),
    this.category = const Value.absent(),
    this.preparedAt = const Value.absent(),
    this.lastInteractedAt = const Value.absent(),
  }) : questionAsked = Value(questionAsked);
  static Insertable<InterviewPrep> custom({
    Expression<int>? id,
    Expression<String>? company,
    Expression<String>? role,
    Expression<int>? linkedApplicationId,
    Expression<String>? questionAsked,
    Expression<String>? answerNotes,
    Expression<String>? outcome,
    Expression<String>? category,
    Expression<DateTime>? preparedAt,
    Expression<DateTime>? lastInteractedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (company != null) 'company': company,
      if (role != null) 'role': role,
      if (linkedApplicationId != null)
        'linked_application_id': linkedApplicationId,
      if (questionAsked != null) 'question_asked': questionAsked,
      if (answerNotes != null) 'answer_notes': answerNotes,
      if (outcome != null) 'outcome': outcome,
      if (category != null) 'category': category,
      if (preparedAt != null) 'prepared_at': preparedAt,
      if (lastInteractedAt != null) 'last_interacted_at': lastInteractedAt,
    });
  }

  InterviewPrepTableCompanion copyWith({
    Value<int>? id,
    Value<String?>? company,
    Value<String?>? role,
    Value<int?>? linkedApplicationId,
    Value<String>? questionAsked,
    Value<String?>? answerNotes,
    Value<String?>? outcome,
    Value<String?>? category,
    Value<DateTime>? preparedAt,
    Value<DateTime?>? lastInteractedAt,
  }) {
    return InterviewPrepTableCompanion(
      id: id ?? this.id,
      company: company ?? this.company,
      role: role ?? this.role,
      linkedApplicationId: linkedApplicationId ?? this.linkedApplicationId,
      questionAsked: questionAsked ?? this.questionAsked,
      answerNotes: answerNotes ?? this.answerNotes,
      outcome: outcome ?? this.outcome,
      category: category ?? this.category,
      preparedAt: preparedAt ?? this.preparedAt,
      lastInteractedAt: lastInteractedAt ?? this.lastInteractedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (company.present) {
      map['company'] = Variable<String>(company.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (linkedApplicationId.present) {
      map['linked_application_id'] = Variable<int>(linkedApplicationId.value);
    }
    if (questionAsked.present) {
      map['question_asked'] = Variable<String>(questionAsked.value);
    }
    if (answerNotes.present) {
      map['answer_notes'] = Variable<String>(answerNotes.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (preparedAt.present) {
      map['prepared_at'] = Variable<DateTime>(preparedAt.value);
    }
    if (lastInteractedAt.present) {
      map['last_interacted_at'] = Variable<DateTime>(lastInteractedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InterviewPrepTableCompanion(')
          ..write('id: $id, ')
          ..write('company: $company, ')
          ..write('role: $role, ')
          ..write('linkedApplicationId: $linkedApplicationId, ')
          ..write('questionAsked: $questionAsked, ')
          ..write('answerNotes: $answerNotes, ')
          ..write('outcome: $outcome, ')
          ..write('category: $category, ')
          ..write('preparedAt: $preparedAt, ')
          ..write('lastInteractedAt: $lastInteractedAt')
          ..write(')'))
        .toString();
  }
}

class $NoteTableTable extends NoteTable with TableInfo<$NoteTableTable, Note> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _contentMeta = const VerificationMeta(
    'content',
  );
  @override
  late final GeneratedColumn<String> content = GeneratedColumn<String>(
    'content',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _linkedCompanyMeta = const VerificationMeta(
    'linkedCompany',
  );
  @override
  late final GeneratedColumn<String> linkedCompany = GeneratedColumn<String>(
    'linked_company',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkedTopicMeta = const VerificationMeta(
    'linkedTopic',
  );
  @override
  late final GeneratedColumn<String> linkedTopic = GeneratedColumn<String>(
    'linked_topic',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _linkedApplicationIdMeta =
      const VerificationMeta('linkedApplicationId');
  @override
  late final GeneratedColumn<int> linkedApplicationId = GeneratedColumn<int>(
    'linked_application_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES applications (id)',
    ),
  );
  static const VerificationMeta _linkedPhaseIdMeta = const VerificationMeta(
    'linkedPhaseId',
  );
  @override
  late final GeneratedColumn<int> linkedPhaseId = GeneratedColumn<int>(
    'linked_phase_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES study_phases (id)',
    ),
  );
  static const VerificationMeta _lastInteractedAtMeta = const VerificationMeta(
    'lastInteractedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastInteractedAt =
      GeneratedColumn<DateTime>(
        'last_interacted_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    content,
    linkedCompany,
    linkedTopic,
    linkedApplicationId,
    linkedPhaseId,
    lastInteractedAt,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notes';
  @override
  VerificationContext validateIntegrity(
    Insertable<Note> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    }
    if (data.containsKey('content')) {
      context.handle(
        _contentMeta,
        content.isAcceptableOrUnknown(data['content']!, _contentMeta),
      );
    } else if (isInserting) {
      context.missing(_contentMeta);
    }
    if (data.containsKey('linked_company')) {
      context.handle(
        _linkedCompanyMeta,
        linkedCompany.isAcceptableOrUnknown(
          data['linked_company']!,
          _linkedCompanyMeta,
        ),
      );
    }
    if (data.containsKey('linked_topic')) {
      context.handle(
        _linkedTopicMeta,
        linkedTopic.isAcceptableOrUnknown(
          data['linked_topic']!,
          _linkedTopicMeta,
        ),
      );
    }
    if (data.containsKey('linked_application_id')) {
      context.handle(
        _linkedApplicationIdMeta,
        linkedApplicationId.isAcceptableOrUnknown(
          data['linked_application_id']!,
          _linkedApplicationIdMeta,
        ),
      );
    }
    if (data.containsKey('linked_phase_id')) {
      context.handle(
        _linkedPhaseIdMeta,
        linkedPhaseId.isAcceptableOrUnknown(
          data['linked_phase_id']!,
          _linkedPhaseIdMeta,
        ),
      );
    }
    if (data.containsKey('last_interacted_at')) {
      context.handle(
        _lastInteractedAtMeta,
        lastInteractedAt.isAcceptableOrUnknown(
          data['last_interacted_at']!,
          _lastInteractedAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Note map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Note(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      ),
      content: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}content'],
      )!,
      linkedCompany: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_company'],
      ),
      linkedTopic: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}linked_topic'],
      ),
      linkedApplicationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}linked_application_id'],
      ),
      linkedPhaseId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}linked_phase_id'],
      ),
      lastInteractedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_interacted_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $NoteTableTable createAlias(String alias) {
    return $NoteTableTable(attachedDatabase, alias);
  }
}

class Note extends DataClass implements Insertable<Note> {
  final int id;

  /// Optional title for the note.
  final String? title;

  /// The main body of the note.
  final String content;

  /// Company this note is about (free text).
  final String? linkedCompany;

  /// Topic this note is about (free text, e.g. 'System Design').
  final String? linkedTopic;

  /// Optional FK to [ApplicationTable].
  final int? linkedApplicationId;

  /// Optional FK to [StudyPhaseTable].
  final int? linkedPhaseId;

  /// Freshness signal used by the Insight Engine to detect stale notes.
  final DateTime? lastInteractedAt;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Note({
    required this.id,
    this.title,
    required this.content,
    this.linkedCompany,
    this.linkedTopic,
    this.linkedApplicationId,
    this.linkedPhaseId,
    this.lastInteractedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || title != null) {
      map['title'] = Variable<String>(title);
    }
    map['content'] = Variable<String>(content);
    if (!nullToAbsent || linkedCompany != null) {
      map['linked_company'] = Variable<String>(linkedCompany);
    }
    if (!nullToAbsent || linkedTopic != null) {
      map['linked_topic'] = Variable<String>(linkedTopic);
    }
    if (!nullToAbsent || linkedApplicationId != null) {
      map['linked_application_id'] = Variable<int>(linkedApplicationId);
    }
    if (!nullToAbsent || linkedPhaseId != null) {
      map['linked_phase_id'] = Variable<int>(linkedPhaseId);
    }
    if (!nullToAbsent || lastInteractedAt != null) {
      map['last_interacted_at'] = Variable<DateTime>(lastInteractedAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  NoteTableCompanion toCompanion(bool nullToAbsent) {
    return NoteTableCompanion(
      id: Value(id),
      title: title == null && nullToAbsent
          ? const Value.absent()
          : Value(title),
      content: Value(content),
      linkedCompany: linkedCompany == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedCompany),
      linkedTopic: linkedTopic == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedTopic),
      linkedApplicationId: linkedApplicationId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedApplicationId),
      linkedPhaseId: linkedPhaseId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedPhaseId),
      lastInteractedAt: lastInteractedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastInteractedAt),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Note.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Note(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String?>(json['title']),
      content: serializer.fromJson<String>(json['content']),
      linkedCompany: serializer.fromJson<String?>(json['linkedCompany']),
      linkedTopic: serializer.fromJson<String?>(json['linkedTopic']),
      linkedApplicationId: serializer.fromJson<int?>(
        json['linkedApplicationId'],
      ),
      linkedPhaseId: serializer.fromJson<int?>(json['linkedPhaseId']),
      lastInteractedAt: serializer.fromJson<DateTime?>(
        json['lastInteractedAt'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String?>(title),
      'content': serializer.toJson<String>(content),
      'linkedCompany': serializer.toJson<String?>(linkedCompany),
      'linkedTopic': serializer.toJson<String?>(linkedTopic),
      'linkedApplicationId': serializer.toJson<int?>(linkedApplicationId),
      'linkedPhaseId': serializer.toJson<int?>(linkedPhaseId),
      'lastInteractedAt': serializer.toJson<DateTime?>(lastInteractedAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Note copyWith({
    int? id,
    Value<String?> title = const Value.absent(),
    String? content,
    Value<String?> linkedCompany = const Value.absent(),
    Value<String?> linkedTopic = const Value.absent(),
    Value<int?> linkedApplicationId = const Value.absent(),
    Value<int?> linkedPhaseId = const Value.absent(),
    Value<DateTime?> lastInteractedAt = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Note(
    id: id ?? this.id,
    title: title.present ? title.value : this.title,
    content: content ?? this.content,
    linkedCompany: linkedCompany.present
        ? linkedCompany.value
        : this.linkedCompany,
    linkedTopic: linkedTopic.present ? linkedTopic.value : this.linkedTopic,
    linkedApplicationId: linkedApplicationId.present
        ? linkedApplicationId.value
        : this.linkedApplicationId,
    linkedPhaseId: linkedPhaseId.present
        ? linkedPhaseId.value
        : this.linkedPhaseId,
    lastInteractedAt: lastInteractedAt.present
        ? lastInteractedAt.value
        : this.lastInteractedAt,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Note copyWithCompanion(NoteTableCompanion data) {
    return Note(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      content: data.content.present ? data.content.value : this.content,
      linkedCompany: data.linkedCompany.present
          ? data.linkedCompany.value
          : this.linkedCompany,
      linkedTopic: data.linkedTopic.present
          ? data.linkedTopic.value
          : this.linkedTopic,
      linkedApplicationId: data.linkedApplicationId.present
          ? data.linkedApplicationId.value
          : this.linkedApplicationId,
      linkedPhaseId: data.linkedPhaseId.present
          ? data.linkedPhaseId.value
          : this.linkedPhaseId,
      lastInteractedAt: data.lastInteractedAt.present
          ? data.lastInteractedAt.value
          : this.lastInteractedAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Note(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('linkedCompany: $linkedCompany, ')
          ..write('linkedTopic: $linkedTopic, ')
          ..write('linkedApplicationId: $linkedApplicationId, ')
          ..write('linkedPhaseId: $linkedPhaseId, ')
          ..write('lastInteractedAt: $lastInteractedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    title,
    content,
    linkedCompany,
    linkedTopic,
    linkedApplicationId,
    linkedPhaseId,
    lastInteractedAt,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Note &&
          other.id == this.id &&
          other.title == this.title &&
          other.content == this.content &&
          other.linkedCompany == this.linkedCompany &&
          other.linkedTopic == this.linkedTopic &&
          other.linkedApplicationId == this.linkedApplicationId &&
          other.linkedPhaseId == this.linkedPhaseId &&
          other.lastInteractedAt == this.lastInteractedAt &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class NoteTableCompanion extends UpdateCompanion<Note> {
  final Value<int> id;
  final Value<String?> title;
  final Value<String> content;
  final Value<String?> linkedCompany;
  final Value<String?> linkedTopic;
  final Value<int?> linkedApplicationId;
  final Value<int?> linkedPhaseId;
  final Value<DateTime?> lastInteractedAt;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const NoteTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.content = const Value.absent(),
    this.linkedCompany = const Value.absent(),
    this.linkedTopic = const Value.absent(),
    this.linkedApplicationId = const Value.absent(),
    this.linkedPhaseId = const Value.absent(),
    this.lastInteractedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  NoteTableCompanion.insert({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    required String content,
    this.linkedCompany = const Value.absent(),
    this.linkedTopic = const Value.absent(),
    this.linkedApplicationId = const Value.absent(),
    this.linkedPhaseId = const Value.absent(),
    this.lastInteractedAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : content = Value(content);
  static Insertable<Note> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<String>? content,
    Expression<String>? linkedCompany,
    Expression<String>? linkedTopic,
    Expression<int>? linkedApplicationId,
    Expression<int>? linkedPhaseId,
    Expression<DateTime>? lastInteractedAt,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (content != null) 'content': content,
      if (linkedCompany != null) 'linked_company': linkedCompany,
      if (linkedTopic != null) 'linked_topic': linkedTopic,
      if (linkedApplicationId != null)
        'linked_application_id': linkedApplicationId,
      if (linkedPhaseId != null) 'linked_phase_id': linkedPhaseId,
      if (lastInteractedAt != null) 'last_interacted_at': lastInteractedAt,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  NoteTableCompanion copyWith({
    Value<int>? id,
    Value<String?>? title,
    Value<String>? content,
    Value<String?>? linkedCompany,
    Value<String?>? linkedTopic,
    Value<int?>? linkedApplicationId,
    Value<int?>? linkedPhaseId,
    Value<DateTime?>? lastInteractedAt,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return NoteTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      linkedCompany: linkedCompany ?? this.linkedCompany,
      linkedTopic: linkedTopic ?? this.linkedTopic,
      linkedApplicationId: linkedApplicationId ?? this.linkedApplicationId,
      linkedPhaseId: linkedPhaseId ?? this.linkedPhaseId,
      lastInteractedAt: lastInteractedAt ?? this.lastInteractedAt,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (content.present) {
      map['content'] = Variable<String>(content.value);
    }
    if (linkedCompany.present) {
      map['linked_company'] = Variable<String>(linkedCompany.value);
    }
    if (linkedTopic.present) {
      map['linked_topic'] = Variable<String>(linkedTopic.value);
    }
    if (linkedApplicationId.present) {
      map['linked_application_id'] = Variable<int>(linkedApplicationId.value);
    }
    if (linkedPhaseId.present) {
      map['linked_phase_id'] = Variable<int>(linkedPhaseId.value);
    }
    if (lastInteractedAt.present) {
      map['last_interacted_at'] = Variable<DateTime>(lastInteractedAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('content: $content, ')
          ..write('linkedCompany: $linkedCompany, ')
          ..write('linkedTopic: $linkedTopic, ')
          ..write('linkedApplicationId: $linkedApplicationId, ')
          ..write('linkedPhaseId: $linkedPhaseId, ')
          ..write('lastInteractedAt: $lastInteractedAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $NoteTagTableTable extends NoteTagTable
    with TableInfo<$NoteTagTableTable, NoteTag> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NoteTagTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _noteIdMeta = const VerificationMeta('noteId');
  @override
  late final GeneratedColumn<int> noteId = GeneratedColumn<int>(
    'note_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES notes (id)',
    ),
  );
  static const VerificationMeta _tagMeta = const VerificationMeta('tag');
  @override
  late final GeneratedColumn<String> tag = GeneratedColumn<String>(
    'tag',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 100,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, noteId, tag];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'note_tags';
  @override
  VerificationContext validateIntegrity(
    Insertable<NoteTag> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('note_id')) {
      context.handle(
        _noteIdMeta,
        noteId.isAcceptableOrUnknown(data['note_id']!, _noteIdMeta),
      );
    } else if (isInserting) {
      context.missing(_noteIdMeta);
    }
    if (data.containsKey('tag')) {
      context.handle(
        _tagMeta,
        tag.isAcceptableOrUnknown(data['tag']!, _tagMeta),
      );
    } else if (isInserting) {
      context.missing(_tagMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NoteTag map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NoteTag(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      noteId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}note_id'],
      )!,
      tag: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}tag'],
      )!,
    );
  }

  @override
  $NoteTagTableTable createAlias(String alias) {
    return $NoteTagTableTable(attachedDatabase, alias);
  }
}

class NoteTag extends DataClass implements Insertable<NoteTag> {
  final int id;

  /// FK to [NoteTable].
  final int noteId;

  /// The tag text (e.g. 'system-design', 'behavioral').
  final String tag;
  const NoteTag({required this.id, required this.noteId, required this.tag});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['note_id'] = Variable<int>(noteId);
    map['tag'] = Variable<String>(tag);
    return map;
  }

  NoteTagTableCompanion toCompanion(bool nullToAbsent) {
    return NoteTagTableCompanion(
      id: Value(id),
      noteId: Value(noteId),
      tag: Value(tag),
    );
  }

  factory NoteTag.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NoteTag(
      id: serializer.fromJson<int>(json['id']),
      noteId: serializer.fromJson<int>(json['noteId']),
      tag: serializer.fromJson<String>(json['tag']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'noteId': serializer.toJson<int>(noteId),
      'tag': serializer.toJson<String>(tag),
    };
  }

  NoteTag copyWith({int? id, int? noteId, String? tag}) => NoteTag(
    id: id ?? this.id,
    noteId: noteId ?? this.noteId,
    tag: tag ?? this.tag,
  );
  NoteTag copyWithCompanion(NoteTagTableCompanion data) {
    return NoteTag(
      id: data.id.present ? data.id.value : this.id,
      noteId: data.noteId.present ? data.noteId.value : this.noteId,
      tag: data.tag.present ? data.tag.value : this.tag,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NoteTag(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, noteId, tag);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NoteTag &&
          other.id == this.id &&
          other.noteId == this.noteId &&
          other.tag == this.tag);
}

class NoteTagTableCompanion extends UpdateCompanion<NoteTag> {
  final Value<int> id;
  final Value<int> noteId;
  final Value<String> tag;
  const NoteTagTableCompanion({
    this.id = const Value.absent(),
    this.noteId = const Value.absent(),
    this.tag = const Value.absent(),
  });
  NoteTagTableCompanion.insert({
    this.id = const Value.absent(),
    required int noteId,
    required String tag,
  }) : noteId = Value(noteId),
       tag = Value(tag);
  static Insertable<NoteTag> custom({
    Expression<int>? id,
    Expression<int>? noteId,
    Expression<String>? tag,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (noteId != null) 'note_id': noteId,
      if (tag != null) 'tag': tag,
    });
  }

  NoteTagTableCompanion copyWith({
    Value<int>? id,
    Value<int>? noteId,
    Value<String>? tag,
  }) {
    return NoteTagTableCompanion(
      id: id ?? this.id,
      noteId: noteId ?? this.noteId,
      tag: tag ?? this.tag,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (noteId.present) {
      map['note_id'] = Variable<int>(noteId.value);
    }
    if (tag.present) {
      map['tag'] = Variable<String>(tag.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NoteTagTableCompanion(')
          ..write('id: $id, ')
          ..write('noteId: $noteId, ')
          ..write('tag: $tag')
          ..write(')'))
        .toString();
  }
}

class $InsightDismissalTableTable extends InsightDismissalTable
    with TableInfo<$InsightDismissalTableTable, InsightDismissal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $InsightDismissalTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _insightTypeMeta = const VerificationMeta(
    'insightType',
  );
  @override
  late final GeneratedColumn<String> insightType = GeneratedColumn<String>(
    'insight_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dismissedAtMeta = const VerificationMeta(
    'dismissedAt',
  );
  @override
  late final GeneratedColumn<DateTime> dismissedAt = GeneratedColumn<DateTime>(
    'dismissed_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _snoozedUntilMeta = const VerificationMeta(
    'snoozedUntil',
  );
  @override
  late final GeneratedColumn<DateTime> snoozedUntil = GeneratedColumn<DateTime>(
    'snoozed_until',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _dismissalCountMeta = const VerificationMeta(
    'dismissalCount',
  );
  @override
  late final GeneratedColumn<int> dismissalCount = GeneratedColumn<int>(
    'dismissal_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    insightType,
    dismissedAt,
    snoozedUntil,
    dismissalCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'insight_dismissals';
  @override
  VerificationContext validateIntegrity(
    Insertable<InsightDismissal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('insight_type')) {
      context.handle(
        _insightTypeMeta,
        insightType.isAcceptableOrUnknown(
          data['insight_type']!,
          _insightTypeMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_insightTypeMeta);
    }
    if (data.containsKey('dismissed_at')) {
      context.handle(
        _dismissedAtMeta,
        dismissedAt.isAcceptableOrUnknown(
          data['dismissed_at']!,
          _dismissedAtMeta,
        ),
      );
    }
    if (data.containsKey('snoozed_until')) {
      context.handle(
        _snoozedUntilMeta,
        snoozedUntil.isAcceptableOrUnknown(
          data['snoozed_until']!,
          _snoozedUntilMeta,
        ),
      );
    }
    if (data.containsKey('dismissal_count')) {
      context.handle(
        _dismissalCountMeta,
        dismissalCount.isAcceptableOrUnknown(
          data['dismissal_count']!,
          _dismissalCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  InsightDismissal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return InsightDismissal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      insightType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}insight_type'],
      )!,
      dismissedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}dismissed_at'],
      )!,
      snoozedUntil: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}snoozed_until'],
      ),
      dismissalCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}dismissal_count'],
      )!,
    );
  }

  @override
  $InsightDismissalTableTable createAlias(String alias) {
    return $InsightDismissalTableTable(attachedDatabase, alias);
  }
}

class InsightDismissal extends DataClass
    implements Insertable<InsightDismissal> {
  final int id;

  /// Type of insight nudge that was dismissed.
  /// Known values: 'stale_note', 'pipeline_stale', 'skill_imbalance',
  /// 'consistency_dip', 'series_lagging', 'revisit_due'.
  final String insightType;
  final DateTime dismissedAt;

  /// When null = dismissed indefinitely for now.
  /// When set = temporarily snoozed until this timestamp.
  final DateTime? snoozedUntil;

  /// Cumulative dismissal count for this type.
  /// The engine uses this to back off frequency exponentially.
  final int dismissalCount;
  const InsightDismissal({
    required this.id,
    required this.insightType,
    required this.dismissedAt,
    this.snoozedUntil,
    required this.dismissalCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['insight_type'] = Variable<String>(insightType);
    map['dismissed_at'] = Variable<DateTime>(dismissedAt);
    if (!nullToAbsent || snoozedUntil != null) {
      map['snoozed_until'] = Variable<DateTime>(snoozedUntil);
    }
    map['dismissal_count'] = Variable<int>(dismissalCount);
    return map;
  }

  InsightDismissalTableCompanion toCompanion(bool nullToAbsent) {
    return InsightDismissalTableCompanion(
      id: Value(id),
      insightType: Value(insightType),
      dismissedAt: Value(dismissedAt),
      snoozedUntil: snoozedUntil == null && nullToAbsent
          ? const Value.absent()
          : Value(snoozedUntil),
      dismissalCount: Value(dismissalCount),
    );
  }

  factory InsightDismissal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return InsightDismissal(
      id: serializer.fromJson<int>(json['id']),
      insightType: serializer.fromJson<String>(json['insightType']),
      dismissedAt: serializer.fromJson<DateTime>(json['dismissedAt']),
      snoozedUntil: serializer.fromJson<DateTime?>(json['snoozedUntil']),
      dismissalCount: serializer.fromJson<int>(json['dismissalCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'insightType': serializer.toJson<String>(insightType),
      'dismissedAt': serializer.toJson<DateTime>(dismissedAt),
      'snoozedUntil': serializer.toJson<DateTime?>(snoozedUntil),
      'dismissalCount': serializer.toJson<int>(dismissalCount),
    };
  }

  InsightDismissal copyWith({
    int? id,
    String? insightType,
    DateTime? dismissedAt,
    Value<DateTime?> snoozedUntil = const Value.absent(),
    int? dismissalCount,
  }) => InsightDismissal(
    id: id ?? this.id,
    insightType: insightType ?? this.insightType,
    dismissedAt: dismissedAt ?? this.dismissedAt,
    snoozedUntil: snoozedUntil.present ? snoozedUntil.value : this.snoozedUntil,
    dismissalCount: dismissalCount ?? this.dismissalCount,
  );
  InsightDismissal copyWithCompanion(InsightDismissalTableCompanion data) {
    return InsightDismissal(
      id: data.id.present ? data.id.value : this.id,
      insightType: data.insightType.present
          ? data.insightType.value
          : this.insightType,
      dismissedAt: data.dismissedAt.present
          ? data.dismissedAt.value
          : this.dismissedAt,
      snoozedUntil: data.snoozedUntil.present
          ? data.snoozedUntil.value
          : this.snoozedUntil,
      dismissalCount: data.dismissalCount.present
          ? data.dismissalCount.value
          : this.dismissalCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('InsightDismissal(')
          ..write('id: $id, ')
          ..write('insightType: $insightType, ')
          ..write('dismissedAt: $dismissedAt, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('dismissalCount: $dismissalCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, insightType, dismissedAt, snoozedUntil, dismissalCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is InsightDismissal &&
          other.id == this.id &&
          other.insightType == this.insightType &&
          other.dismissedAt == this.dismissedAt &&
          other.snoozedUntil == this.snoozedUntil &&
          other.dismissalCount == this.dismissalCount);
}

class InsightDismissalTableCompanion extends UpdateCompanion<InsightDismissal> {
  final Value<int> id;
  final Value<String> insightType;
  final Value<DateTime> dismissedAt;
  final Value<DateTime?> snoozedUntil;
  final Value<int> dismissalCount;
  const InsightDismissalTableCompanion({
    this.id = const Value.absent(),
    this.insightType = const Value.absent(),
    this.dismissedAt = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.dismissalCount = const Value.absent(),
  });
  InsightDismissalTableCompanion.insert({
    this.id = const Value.absent(),
    required String insightType,
    this.dismissedAt = const Value.absent(),
    this.snoozedUntil = const Value.absent(),
    this.dismissalCount = const Value.absent(),
  }) : insightType = Value(insightType);
  static Insertable<InsightDismissal> custom({
    Expression<int>? id,
    Expression<String>? insightType,
    Expression<DateTime>? dismissedAt,
    Expression<DateTime>? snoozedUntil,
    Expression<int>? dismissalCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (insightType != null) 'insight_type': insightType,
      if (dismissedAt != null) 'dismissed_at': dismissedAt,
      if (snoozedUntil != null) 'snoozed_until': snoozedUntil,
      if (dismissalCount != null) 'dismissal_count': dismissalCount,
    });
  }

  InsightDismissalTableCompanion copyWith({
    Value<int>? id,
    Value<String>? insightType,
    Value<DateTime>? dismissedAt,
    Value<DateTime?>? snoozedUntil,
    Value<int>? dismissalCount,
  }) {
    return InsightDismissalTableCompanion(
      id: id ?? this.id,
      insightType: insightType ?? this.insightType,
      dismissedAt: dismissedAt ?? this.dismissedAt,
      snoozedUntil: snoozedUntil ?? this.snoozedUntil,
      dismissalCount: dismissalCount ?? this.dismissalCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (insightType.present) {
      map['insight_type'] = Variable<String>(insightType.value);
    }
    if (dismissedAt.present) {
      map['dismissed_at'] = Variable<DateTime>(dismissedAt.value);
    }
    if (snoozedUntil.present) {
      map['snoozed_until'] = Variable<DateTime>(snoozedUntil.value);
    }
    if (dismissalCount.present) {
      map['dismissal_count'] = Variable<int>(dismissalCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('InsightDismissalTableCompanion(')
          ..write('id: $id, ')
          ..write('insightType: $insightType, ')
          ..write('dismissedAt: $dismissedAt, ')
          ..write('snoozedUntil: $snoozedUntil, ')
          ..write('dismissalCount: $dismissalCount')
          ..write(')'))
        .toString();
  }
}

class $SessionCategoryTableTable extends SessionCategoryTable
    with TableInfo<$SessionCategoryTableTable, SessionCategory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SessionCategoryTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _colorHexMeta = const VerificationMeta(
    'colorHex',
  );
  @override
  late final GeneratedColumn<String> colorHex = GeneratedColumn<String>(
    'color_hex',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isBuiltInMeta = const VerificationMeta(
    'isBuiltIn',
  );
  @override
  late final GeneratedColumn<bool> isBuiltIn = GeneratedColumn<bool>(
    'is_built_in',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_built_in" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  @override
  List<GeneratedColumn> get $columns => [id, name, colorHex, isBuiltIn];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'session_categories';
  @override
  VerificationContext validateIntegrity(
    Insertable<SessionCategory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('color_hex')) {
      context.handle(
        _colorHexMeta,
        colorHex.isAcceptableOrUnknown(data['color_hex']!, _colorHexMeta),
      );
    } else if (isInserting) {
      context.missing(_colorHexMeta);
    }
    if (data.containsKey('is_built_in')) {
      context.handle(
        _isBuiltInMeta,
        isBuiltIn.isAcceptableOrUnknown(data['is_built_in']!, _isBuiltInMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SessionCategory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SessionCategory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      colorHex: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}color_hex'],
      )!,
      isBuiltIn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_built_in'],
      )!,
    );
  }

  @override
  $SessionCategoryTableTable createAlias(String alias) {
    return $SessionCategoryTableTable(attachedDatabase, alias);
  }
}

class SessionCategory extends DataClass implements Insertable<SessionCategory> {
  final int id;

  /// Display name of the category (e.g. "Study", "Entertainment", "Freelance").
  final String name;

  /// Hex color string for badges and live-timer bar (e.g. "#5FA070").
  final String colorHex;

  /// Built-in categories (Study, Entertainment) cannot be deleted.
  final bool isBuiltIn;
  const SessionCategory({
    required this.id,
    required this.name,
    required this.colorHex,
    required this.isBuiltIn,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    map['color_hex'] = Variable<String>(colorHex);
    map['is_built_in'] = Variable<bool>(isBuiltIn);
    return map;
  }

  SessionCategoryTableCompanion toCompanion(bool nullToAbsent) {
    return SessionCategoryTableCompanion(
      id: Value(id),
      name: Value(name),
      colorHex: Value(colorHex),
      isBuiltIn: Value(isBuiltIn),
    );
  }

  factory SessionCategory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SessionCategory(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      colorHex: serializer.fromJson<String>(json['colorHex']),
      isBuiltIn: serializer.fromJson<bool>(json['isBuiltIn']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'colorHex': serializer.toJson<String>(colorHex),
      'isBuiltIn': serializer.toJson<bool>(isBuiltIn),
    };
  }

  SessionCategory copyWith({
    int? id,
    String? name,
    String? colorHex,
    bool? isBuiltIn,
  }) => SessionCategory(
    id: id ?? this.id,
    name: name ?? this.name,
    colorHex: colorHex ?? this.colorHex,
    isBuiltIn: isBuiltIn ?? this.isBuiltIn,
  );
  SessionCategory copyWithCompanion(SessionCategoryTableCompanion data) {
    return SessionCategory(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      colorHex: data.colorHex.present ? data.colorHex.value : this.colorHex,
      isBuiltIn: data.isBuiltIn.present ? data.isBuiltIn.value : this.isBuiltIn,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SessionCategory(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorHex: $colorHex, ')
          ..write('isBuiltIn: $isBuiltIn')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, colorHex, isBuiltIn);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SessionCategory &&
          other.id == this.id &&
          other.name == this.name &&
          other.colorHex == this.colorHex &&
          other.isBuiltIn == this.isBuiltIn);
}

class SessionCategoryTableCompanion extends UpdateCompanion<SessionCategory> {
  final Value<int> id;
  final Value<String> name;
  final Value<String> colorHex;
  final Value<bool> isBuiltIn;
  const SessionCategoryTableCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.colorHex = const Value.absent(),
    this.isBuiltIn = const Value.absent(),
  });
  SessionCategoryTableCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    required String colorHex,
    this.isBuiltIn = const Value.absent(),
  }) : name = Value(name),
       colorHex = Value(colorHex);
  static Insertable<SessionCategory> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? colorHex,
    Expression<bool>? isBuiltIn,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (colorHex != null) 'color_hex': colorHex,
      if (isBuiltIn != null) 'is_built_in': isBuiltIn,
    });
  }

  SessionCategoryTableCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String>? colorHex,
    Value<bool>? isBuiltIn,
  }) {
    return SessionCategoryTableCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      colorHex: colorHex ?? this.colorHex,
      isBuiltIn: isBuiltIn ?? this.isBuiltIn,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (colorHex.present) {
      map['color_hex'] = Variable<String>(colorHex.value);
    }
    if (isBuiltIn.present) {
      map['is_built_in'] = Variable<bool>(isBuiltIn.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SessionCategoryTableCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('colorHex: $colorHex, ')
          ..write('isBuiltIn: $isBuiltIn')
          ..write(')'))
        .toString();
  }
}

class $TimeSessionTableTable extends TimeSessionTable
    with TableInfo<$TimeSessionTableTable, TimeSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TimeSessionTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _labelMeta = const VerificationMeta('label');
  @override
  late final GeneratedColumn<String> label = GeneratedColumn<String>(
    'label',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityTypeMeta = const VerificationMeta(
    'activityType',
  );
  @override
  late final GeneratedColumn<String> activityType = GeneratedColumn<String>(
    'activity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('study'),
  );
  static const VerificationMeta _categoryIdMeta = const VerificationMeta(
    'categoryId',
  );
  @override
  late final GeneratedColumn<int> categoryId = GeneratedColumn<int>(
    'category_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES session_categories (id)',
    ),
  );
  static const VerificationMeta _linkedTaskIdMeta = const VerificationMeta(
    'linkedTaskId',
  );
  @override
  late final GeneratedColumn<int> linkedTaskId = GeneratedColumn<int>(
    'linked_task_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES tasks (id)',
    ),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<DateTime> startedAt = GeneratedColumn<DateTime>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _endedAtMeta = const VerificationMeta(
    'endedAt',
  );
  @override
  late final GeneratedColumn<DateTime> endedAt = GeneratedColumn<DateTime>(
    'ended_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _pausedIntervalsMeta = const VerificationMeta(
    'pausedIntervals',
  );
  @override
  late final GeneratedColumn<String> pausedIntervals = GeneratedColumn<String>(
    'paused_intervals',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('running'),
  );
  static const VerificationMeta _durationSecondsMeta = const VerificationMeta(
    'durationSeconds',
  );
  @override
  late final GeneratedColumn<int> durationSeconds = GeneratedColumn<int>(
    'duration_seconds',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _activityRefTypeMeta = const VerificationMeta(
    'activityRefType',
  );
  @override
  late final GeneratedColumn<String> activityRefType = GeneratedColumn<String>(
    'activity_ref_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('task'),
  );
  static const VerificationMeta _lastHeartbeatAtMeta = const VerificationMeta(
    'lastHeartbeatAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastHeartbeatAt =
      GeneratedColumn<DateTime>(
        'last_heartbeat_at',
        aliasedName,
        true,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    label,
    activityType,
    categoryId,
    linkedTaskId,
    startedAt,
    endedAt,
    pausedIntervals,
    status,
    durationSeconds,
    activityRefType,
    lastHeartbeatAt,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'time_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<TimeSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('label')) {
      context.handle(
        _labelMeta,
        label.isAcceptableOrUnknown(data['label']!, _labelMeta),
      );
    } else if (isInserting) {
      context.missing(_labelMeta);
    }
    if (data.containsKey('activity_type')) {
      context.handle(
        _activityTypeMeta,
        activityType.isAcceptableOrUnknown(
          data['activity_type']!,
          _activityTypeMeta,
        ),
      );
    }
    if (data.containsKey('category_id')) {
      context.handle(
        _categoryIdMeta,
        categoryId.isAcceptableOrUnknown(data['category_id']!, _categoryIdMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryIdMeta);
    }
    if (data.containsKey('linked_task_id')) {
      context.handle(
        _linkedTaskIdMeta,
        linkedTaskId.isAcceptableOrUnknown(
          data['linked_task_id']!,
          _linkedTaskIdMeta,
        ),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('ended_at')) {
      context.handle(
        _endedAtMeta,
        endedAt.isAcceptableOrUnknown(data['ended_at']!, _endedAtMeta),
      );
    }
    if (data.containsKey('paused_intervals')) {
      context.handle(
        _pausedIntervalsMeta,
        pausedIntervals.isAcceptableOrUnknown(
          data['paused_intervals']!,
          _pausedIntervalsMeta,
        ),
      );
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('duration_seconds')) {
      context.handle(
        _durationSecondsMeta,
        durationSeconds.isAcceptableOrUnknown(
          data['duration_seconds']!,
          _durationSecondsMeta,
        ),
      );
    }
    if (data.containsKey('activity_ref_type')) {
      context.handle(
        _activityRefTypeMeta,
        activityRefType.isAcceptableOrUnknown(
          data['activity_ref_type']!,
          _activityRefTypeMeta,
        ),
      );
    }
    if (data.containsKey('last_heartbeat_at')) {
      context.handle(
        _lastHeartbeatAtMeta,
        lastHeartbeatAt.isAcceptableOrUnknown(
          data['last_heartbeat_at']!,
          _lastHeartbeatAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  TimeSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TimeSession(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      label: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}label'],
      )!,
      activityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_type'],
      )!,
      categoryId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}category_id'],
      )!,
      linkedTaskId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}linked_task_id'],
      ),
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}started_at'],
      )!,
      endedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}ended_at'],
      ),
      pausedIntervals: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}paused_intervals'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      durationSeconds: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}duration_seconds'],
      )!,
      activityRefType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_ref_type'],
      )!,
      lastHeartbeatAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_heartbeat_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $TimeSessionTableTable createAlias(String alias) {
    return $TimeSessionTableTable(attachedDatabase, alias);
  }
}

class TimeSession extends DataClass implements Insertable<TimeSession> {
  final int id;

  /// User-entered label, e.g. "DSA Module 1", "Watched a movie".
  final String label;

  /// Activity label convenience (study | entertainment | custom).
  final String activityType;

  /// Authoritative FK to [SessionCategoryTable].
  final int categoryId;

  /// Optional FK to [TaskTable].
  final int? linkedTaskId;

  /// Start timestamp of the session.
  final DateTime startedAt;

  /// End timestamp (null while running or paused).
  final DateTime? endedAt;

  /// JSON array of paused intervals: `[{"pausedAt":"...","resumedAt":"..."}]`.
  final String pausedIntervals;

  /// Session status: 'running' | 'paused' | 'completed' | 'discarded'.
  final String status;

  /// Accumulated active duration in seconds.
  final int durationSeconds;

  /// Reference type: 'task' | 'dsa_log' | 'interview_prep' | 'custom'.
  final String activityRefType;

  /// Heartbeat timestamp flushed periodically while running.
  final DateTime? lastHeartbeatAt;
  final DateTime createdAt;
  const TimeSession({
    required this.id,
    required this.label,
    required this.activityType,
    required this.categoryId,
    this.linkedTaskId,
    required this.startedAt,
    this.endedAt,
    required this.pausedIntervals,
    required this.status,
    required this.durationSeconds,
    required this.activityRefType,
    this.lastHeartbeatAt,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['label'] = Variable<String>(label);
    map['activity_type'] = Variable<String>(activityType);
    map['category_id'] = Variable<int>(categoryId);
    if (!nullToAbsent || linkedTaskId != null) {
      map['linked_task_id'] = Variable<int>(linkedTaskId);
    }
    map['started_at'] = Variable<DateTime>(startedAt);
    if (!nullToAbsent || endedAt != null) {
      map['ended_at'] = Variable<DateTime>(endedAt);
    }
    map['paused_intervals'] = Variable<String>(pausedIntervals);
    map['status'] = Variable<String>(status);
    map['duration_seconds'] = Variable<int>(durationSeconds);
    map['activity_ref_type'] = Variable<String>(activityRefType);
    if (!nullToAbsent || lastHeartbeatAt != null) {
      map['last_heartbeat_at'] = Variable<DateTime>(lastHeartbeatAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  TimeSessionTableCompanion toCompanion(bool nullToAbsent) {
    return TimeSessionTableCompanion(
      id: Value(id),
      label: Value(label),
      activityType: Value(activityType),
      categoryId: Value(categoryId),
      linkedTaskId: linkedTaskId == null && nullToAbsent
          ? const Value.absent()
          : Value(linkedTaskId),
      startedAt: Value(startedAt),
      endedAt: endedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(endedAt),
      pausedIntervals: Value(pausedIntervals),
      status: Value(status),
      durationSeconds: Value(durationSeconds),
      activityRefType: Value(activityRefType),
      lastHeartbeatAt: lastHeartbeatAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastHeartbeatAt),
      createdAt: Value(createdAt),
    );
  }

  factory TimeSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TimeSession(
      id: serializer.fromJson<int>(json['id']),
      label: serializer.fromJson<String>(json['label']),
      activityType: serializer.fromJson<String>(json['activityType']),
      categoryId: serializer.fromJson<int>(json['categoryId']),
      linkedTaskId: serializer.fromJson<int?>(json['linkedTaskId']),
      startedAt: serializer.fromJson<DateTime>(json['startedAt']),
      endedAt: serializer.fromJson<DateTime?>(json['endedAt']),
      pausedIntervals: serializer.fromJson<String>(json['pausedIntervals']),
      status: serializer.fromJson<String>(json['status']),
      durationSeconds: serializer.fromJson<int>(json['durationSeconds']),
      activityRefType: serializer.fromJson<String>(json['activityRefType']),
      lastHeartbeatAt: serializer.fromJson<DateTime?>(json['lastHeartbeatAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'label': serializer.toJson<String>(label),
      'activityType': serializer.toJson<String>(activityType),
      'categoryId': serializer.toJson<int>(categoryId),
      'linkedTaskId': serializer.toJson<int?>(linkedTaskId),
      'startedAt': serializer.toJson<DateTime>(startedAt),
      'endedAt': serializer.toJson<DateTime?>(endedAt),
      'pausedIntervals': serializer.toJson<String>(pausedIntervals),
      'status': serializer.toJson<String>(status),
      'durationSeconds': serializer.toJson<int>(durationSeconds),
      'activityRefType': serializer.toJson<String>(activityRefType),
      'lastHeartbeatAt': serializer.toJson<DateTime?>(lastHeartbeatAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  TimeSession copyWith({
    int? id,
    String? label,
    String? activityType,
    int? categoryId,
    Value<int?> linkedTaskId = const Value.absent(),
    DateTime? startedAt,
    Value<DateTime?> endedAt = const Value.absent(),
    String? pausedIntervals,
    String? status,
    int? durationSeconds,
    String? activityRefType,
    Value<DateTime?> lastHeartbeatAt = const Value.absent(),
    DateTime? createdAt,
  }) => TimeSession(
    id: id ?? this.id,
    label: label ?? this.label,
    activityType: activityType ?? this.activityType,
    categoryId: categoryId ?? this.categoryId,
    linkedTaskId: linkedTaskId.present ? linkedTaskId.value : this.linkedTaskId,
    startedAt: startedAt ?? this.startedAt,
    endedAt: endedAt.present ? endedAt.value : this.endedAt,
    pausedIntervals: pausedIntervals ?? this.pausedIntervals,
    status: status ?? this.status,
    durationSeconds: durationSeconds ?? this.durationSeconds,
    activityRefType: activityRefType ?? this.activityRefType,
    lastHeartbeatAt: lastHeartbeatAt.present
        ? lastHeartbeatAt.value
        : this.lastHeartbeatAt,
    createdAt: createdAt ?? this.createdAt,
  );
  TimeSession copyWithCompanion(TimeSessionTableCompanion data) {
    return TimeSession(
      id: data.id.present ? data.id.value : this.id,
      label: data.label.present ? data.label.value : this.label,
      activityType: data.activityType.present
          ? data.activityType.value
          : this.activityType,
      categoryId: data.categoryId.present
          ? data.categoryId.value
          : this.categoryId,
      linkedTaskId: data.linkedTaskId.present
          ? data.linkedTaskId.value
          : this.linkedTaskId,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      endedAt: data.endedAt.present ? data.endedAt.value : this.endedAt,
      pausedIntervals: data.pausedIntervals.present
          ? data.pausedIntervals.value
          : this.pausedIntervals,
      status: data.status.present ? data.status.value : this.status,
      durationSeconds: data.durationSeconds.present
          ? data.durationSeconds.value
          : this.durationSeconds,
      activityRefType: data.activityRefType.present
          ? data.activityRefType.value
          : this.activityRefType,
      lastHeartbeatAt: data.lastHeartbeatAt.present
          ? data.lastHeartbeatAt.value
          : this.lastHeartbeatAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TimeSession(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('activityType: $activityType, ')
          ..write('categoryId: $categoryId, ')
          ..write('linkedTaskId: $linkedTaskId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('pausedIntervals: $pausedIntervals, ')
          ..write('status: $status, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('activityRefType: $activityRefType, ')
          ..write('lastHeartbeatAt: $lastHeartbeatAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    label,
    activityType,
    categoryId,
    linkedTaskId,
    startedAt,
    endedAt,
    pausedIntervals,
    status,
    durationSeconds,
    activityRefType,
    lastHeartbeatAt,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TimeSession &&
          other.id == this.id &&
          other.label == this.label &&
          other.activityType == this.activityType &&
          other.categoryId == this.categoryId &&
          other.linkedTaskId == this.linkedTaskId &&
          other.startedAt == this.startedAt &&
          other.endedAt == this.endedAt &&
          other.pausedIntervals == this.pausedIntervals &&
          other.status == this.status &&
          other.durationSeconds == this.durationSeconds &&
          other.activityRefType == this.activityRefType &&
          other.lastHeartbeatAt == this.lastHeartbeatAt &&
          other.createdAt == this.createdAt);
}

class TimeSessionTableCompanion extends UpdateCompanion<TimeSession> {
  final Value<int> id;
  final Value<String> label;
  final Value<String> activityType;
  final Value<int> categoryId;
  final Value<int?> linkedTaskId;
  final Value<DateTime> startedAt;
  final Value<DateTime?> endedAt;
  final Value<String> pausedIntervals;
  final Value<String> status;
  final Value<int> durationSeconds;
  final Value<String> activityRefType;
  final Value<DateTime?> lastHeartbeatAt;
  final Value<DateTime> createdAt;
  const TimeSessionTableCompanion({
    this.id = const Value.absent(),
    this.label = const Value.absent(),
    this.activityType = const Value.absent(),
    this.categoryId = const Value.absent(),
    this.linkedTaskId = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.endedAt = const Value.absent(),
    this.pausedIntervals = const Value.absent(),
    this.status = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.activityRefType = const Value.absent(),
    this.lastHeartbeatAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  TimeSessionTableCompanion.insert({
    this.id = const Value.absent(),
    required String label,
    this.activityType = const Value.absent(),
    required int categoryId,
    this.linkedTaskId = const Value.absent(),
    required DateTime startedAt,
    this.endedAt = const Value.absent(),
    this.pausedIntervals = const Value.absent(),
    this.status = const Value.absent(),
    this.durationSeconds = const Value.absent(),
    this.activityRefType = const Value.absent(),
    this.lastHeartbeatAt = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : label = Value(label),
       categoryId = Value(categoryId),
       startedAt = Value(startedAt);
  static Insertable<TimeSession> custom({
    Expression<int>? id,
    Expression<String>? label,
    Expression<String>? activityType,
    Expression<int>? categoryId,
    Expression<int>? linkedTaskId,
    Expression<DateTime>? startedAt,
    Expression<DateTime>? endedAt,
    Expression<String>? pausedIntervals,
    Expression<String>? status,
    Expression<int>? durationSeconds,
    Expression<String>? activityRefType,
    Expression<DateTime>? lastHeartbeatAt,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (label != null) 'label': label,
      if (activityType != null) 'activity_type': activityType,
      if (categoryId != null) 'category_id': categoryId,
      if (linkedTaskId != null) 'linked_task_id': linkedTaskId,
      if (startedAt != null) 'started_at': startedAt,
      if (endedAt != null) 'ended_at': endedAt,
      if (pausedIntervals != null) 'paused_intervals': pausedIntervals,
      if (status != null) 'status': status,
      if (durationSeconds != null) 'duration_seconds': durationSeconds,
      if (activityRefType != null) 'activity_ref_type': activityRefType,
      if (lastHeartbeatAt != null) 'last_heartbeat_at': lastHeartbeatAt,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  TimeSessionTableCompanion copyWith({
    Value<int>? id,
    Value<String>? label,
    Value<String>? activityType,
    Value<int>? categoryId,
    Value<int?>? linkedTaskId,
    Value<DateTime>? startedAt,
    Value<DateTime?>? endedAt,
    Value<String>? pausedIntervals,
    Value<String>? status,
    Value<int>? durationSeconds,
    Value<String>? activityRefType,
    Value<DateTime?>? lastHeartbeatAt,
    Value<DateTime>? createdAt,
  }) {
    return TimeSessionTableCompanion(
      id: id ?? this.id,
      label: label ?? this.label,
      activityType: activityType ?? this.activityType,
      categoryId: categoryId ?? this.categoryId,
      linkedTaskId: linkedTaskId ?? this.linkedTaskId,
      startedAt: startedAt ?? this.startedAt,
      endedAt: endedAt ?? this.endedAt,
      pausedIntervals: pausedIntervals ?? this.pausedIntervals,
      status: status ?? this.status,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      activityRefType: activityRefType ?? this.activityRefType,
      lastHeartbeatAt: lastHeartbeatAt ?? this.lastHeartbeatAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (label.present) {
      map['label'] = Variable<String>(label.value);
    }
    if (activityType.present) {
      map['activity_type'] = Variable<String>(activityType.value);
    }
    if (categoryId.present) {
      map['category_id'] = Variable<int>(categoryId.value);
    }
    if (linkedTaskId.present) {
      map['linked_task_id'] = Variable<int>(linkedTaskId.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<DateTime>(startedAt.value);
    }
    if (endedAt.present) {
      map['ended_at'] = Variable<DateTime>(endedAt.value);
    }
    if (pausedIntervals.present) {
      map['paused_intervals'] = Variable<String>(pausedIntervals.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (durationSeconds.present) {
      map['duration_seconds'] = Variable<int>(durationSeconds.value);
    }
    if (activityRefType.present) {
      map['activity_ref_type'] = Variable<String>(activityRefType.value);
    }
    if (lastHeartbeatAt.present) {
      map['last_heartbeat_at'] = Variable<DateTime>(lastHeartbeatAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TimeSessionTableCompanion(')
          ..write('id: $id, ')
          ..write('label: $label, ')
          ..write('activityType: $activityType, ')
          ..write('categoryId: $categoryId, ')
          ..write('linkedTaskId: $linkedTaskId, ')
          ..write('startedAt: $startedAt, ')
          ..write('endedAt: $endedAt, ')
          ..write('pausedIntervals: $pausedIntervals, ')
          ..write('status: $status, ')
          ..write('durationSeconds: $durationSeconds, ')
          ..write('activityRefType: $activityRefType, ')
          ..write('lastHeartbeatAt: $lastHeartbeatAt, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $UpcomingInterviewTableTable extends UpcomingInterviewTable
    with TableInfo<$UpcomingInterviewTableTable, UpcomingInterview> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UpcomingInterviewTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _companyNameMeta = const VerificationMeta(
    'companyName',
  );
  @override
  late final GeneratedColumn<String> companyName = GeneratedColumn<String>(
    'company_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _interviewDateMeta = const VerificationMeta(
    'interviewDate',
  );
  @override
  late final GeneratedColumn<DateTime> interviewDate =
      GeneratedColumn<DateTime>(
        'interview_date',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    companyName,
    interviewDate,
    notes,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'upcoming_interviews';
  @override
  VerificationContext validateIntegrity(
    Insertable<UpcomingInterview> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('company_name')) {
      context.handle(
        _companyNameMeta,
        companyName.isAcceptableOrUnknown(
          data['company_name']!,
          _companyNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_companyNameMeta);
    }
    if (data.containsKey('interview_date')) {
      context.handle(
        _interviewDateMeta,
        interviewDate.isAcceptableOrUnknown(
          data['interview_date']!,
          _interviewDateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_interviewDateMeta);
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UpcomingInterview map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UpcomingInterview(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      companyName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}company_name'],
      )!,
      interviewDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}interview_date'],
      )!,
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $UpcomingInterviewTableTable createAlias(String alias) {
    return $UpcomingInterviewTableTable(attachedDatabase, alias);
  }
}

class UpcomingInterview extends DataClass
    implements Insertable<UpcomingInterview> {
  final int id;

  /// Target company name, e.g. "Google", "Stripe".
  final String companyName;

  /// Date (and optional time) of the interview.
  final DateTime interviewDate;

  /// Optional free-text notes for the interview.
  final String? notes;
  final DateTime createdAt;
  const UpcomingInterview({
    required this.id,
    required this.companyName,
    required this.interviewDate,
    this.notes,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['company_name'] = Variable<String>(companyName);
    map['interview_date'] = Variable<DateTime>(interviewDate);
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  UpcomingInterviewTableCompanion toCompanion(bool nullToAbsent) {
    return UpcomingInterviewTableCompanion(
      id: Value(id),
      companyName: Value(companyName),
      interviewDate: Value(interviewDate),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      createdAt: Value(createdAt),
    );
  }

  factory UpcomingInterview.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UpcomingInterview(
      id: serializer.fromJson<int>(json['id']),
      companyName: serializer.fromJson<String>(json['companyName']),
      interviewDate: serializer.fromJson<DateTime>(json['interviewDate']),
      notes: serializer.fromJson<String?>(json['notes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'companyName': serializer.toJson<String>(companyName),
      'interviewDate': serializer.toJson<DateTime>(interviewDate),
      'notes': serializer.toJson<String?>(notes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  UpcomingInterview copyWith({
    int? id,
    String? companyName,
    DateTime? interviewDate,
    Value<String?> notes = const Value.absent(),
    DateTime? createdAt,
  }) => UpcomingInterview(
    id: id ?? this.id,
    companyName: companyName ?? this.companyName,
    interviewDate: interviewDate ?? this.interviewDate,
    notes: notes.present ? notes.value : this.notes,
    createdAt: createdAt ?? this.createdAt,
  );
  UpcomingInterview copyWithCompanion(UpcomingInterviewTableCompanion data) {
    return UpcomingInterview(
      id: data.id.present ? data.id.value : this.id,
      companyName: data.companyName.present
          ? data.companyName.value
          : this.companyName,
      interviewDate: data.interviewDate.present
          ? data.interviewDate.value
          : this.interviewDate,
      notes: data.notes.present ? data.notes.value : this.notes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UpcomingInterview(')
          ..write('id: $id, ')
          ..write('companyName: $companyName, ')
          ..write('interviewDate: $interviewDate, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, companyName, interviewDate, notes, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UpcomingInterview &&
          other.id == this.id &&
          other.companyName == this.companyName &&
          other.interviewDate == this.interviewDate &&
          other.notes == this.notes &&
          other.createdAt == this.createdAt);
}

class UpcomingInterviewTableCompanion
    extends UpdateCompanion<UpcomingInterview> {
  final Value<int> id;
  final Value<String> companyName;
  final Value<DateTime> interviewDate;
  final Value<String?> notes;
  final Value<DateTime> createdAt;
  const UpcomingInterviewTableCompanion({
    this.id = const Value.absent(),
    this.companyName = const Value.absent(),
    this.interviewDate = const Value.absent(),
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  UpcomingInterviewTableCompanion.insert({
    this.id = const Value.absent(),
    required String companyName,
    required DateTime interviewDate,
    this.notes = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : companyName = Value(companyName),
       interviewDate = Value(interviewDate);
  static Insertable<UpcomingInterview> custom({
    Expression<int>? id,
    Expression<String>? companyName,
    Expression<DateTime>? interviewDate,
    Expression<String>? notes,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (companyName != null) 'company_name': companyName,
      if (interviewDate != null) 'interview_date': interviewDate,
      if (notes != null) 'notes': notes,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  UpcomingInterviewTableCompanion copyWith({
    Value<int>? id,
    Value<String>? companyName,
    Value<DateTime>? interviewDate,
    Value<String?>? notes,
    Value<DateTime>? createdAt,
  }) {
    return UpcomingInterviewTableCompanion(
      id: id ?? this.id,
      companyName: companyName ?? this.companyName,
      interviewDate: interviewDate ?? this.interviewDate,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (companyName.present) {
      map['company_name'] = Variable<String>(companyName.value);
    }
    if (interviewDate.present) {
      map['interview_date'] = Variable<DateTime>(interviewDate.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UpcomingInterviewTableCompanion(')
          ..write('id: $id, ')
          ..write('companyName: $companyName, ')
          ..write('interviewDate: $interviewDate, ')
          ..write('notes: $notes, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $ReminderTableTable extends ReminderTable
    with TableInfo<$ReminderTableTable, Reminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ReminderTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    additionalChecks: GeneratedColumn.checkTextLength(
      minTextLength: 1,
      maxTextLength: 300,
    ),
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _scheduledAtMeta = const VerificationMeta(
    'scheduledAt',
  );
  @override
  late final GeneratedColumn<DateTime> scheduledAt = GeneratedColumn<DateTime>(
    'scheduled_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _isActiveMeta = const VerificationMeta(
    'isActive',
  );
  @override
  late final GeneratedColumn<bool> isActive = GeneratedColumn<bool>(
    'is_active',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_active" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    title,
    scheduledAt,
    isActive,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'reminders';
  @override
  VerificationContext validateIntegrity(
    Insertable<Reminder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('scheduled_at')) {
      context.handle(
        _scheduledAtMeta,
        scheduledAt.isAcceptableOrUnknown(
          data['scheduled_at']!,
          _scheduledAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_scheduledAtMeta);
    }
    if (data.containsKey('is_active')) {
      context.handle(
        _isActiveMeta,
        isActive.isAcceptableOrUnknown(data['is_active']!, _isActiveMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Reminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Reminder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      scheduledAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}scheduled_at'],
      )!,
      isActive: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_active'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $ReminderTableTable createAlias(String alias) {
    return $ReminderTableTable(attachedDatabase, alias);
  }
}

class Reminder extends DataClass implements Insertable<Reminder> {
  final int id;

  /// The text content/label of the reminder.
  final String title;

  /// Scheduled date & time for the reminder notification.
  final DateTime scheduledAt;

  /// Whether notification is active.
  final bool isActive;
  final DateTime createdAt;
  const Reminder({
    required this.id,
    required this.title,
    required this.scheduledAt,
    required this.isActive,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['title'] = Variable<String>(title);
    map['scheduled_at'] = Variable<DateTime>(scheduledAt);
    map['is_active'] = Variable<bool>(isActive);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  ReminderTableCompanion toCompanion(bool nullToAbsent) {
    return ReminderTableCompanion(
      id: Value(id),
      title: Value(title),
      scheduledAt: Value(scheduledAt),
      isActive: Value(isActive),
      createdAt: Value(createdAt),
    );
  }

  factory Reminder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Reminder(
      id: serializer.fromJson<int>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      scheduledAt: serializer.fromJson<DateTime>(json['scheduledAt']),
      isActive: serializer.fromJson<bool>(json['isActive']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'title': serializer.toJson<String>(title),
      'scheduledAt': serializer.toJson<DateTime>(scheduledAt),
      'isActive': serializer.toJson<bool>(isActive),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Reminder copyWith({
    int? id,
    String? title,
    DateTime? scheduledAt,
    bool? isActive,
    DateTime? createdAt,
  }) => Reminder(
    id: id ?? this.id,
    title: title ?? this.title,
    scheduledAt: scheduledAt ?? this.scheduledAt,
    isActive: isActive ?? this.isActive,
    createdAt: createdAt ?? this.createdAt,
  );
  Reminder copyWithCompanion(ReminderTableCompanion data) {
    return Reminder(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      scheduledAt: data.scheduledAt.present
          ? data.scheduledAt.value
          : this.scheduledAt,
      isActive: data.isActive.present ? data.isActive.value : this.isActive,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Reminder(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('scheduledAt: $scheduledAt, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, scheduledAt, isActive, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Reminder &&
          other.id == this.id &&
          other.title == this.title &&
          other.scheduledAt == this.scheduledAt &&
          other.isActive == this.isActive &&
          other.createdAt == this.createdAt);
}

class ReminderTableCompanion extends UpdateCompanion<Reminder> {
  final Value<int> id;
  final Value<String> title;
  final Value<DateTime> scheduledAt;
  final Value<bool> isActive;
  final Value<DateTime> createdAt;
  const ReminderTableCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.scheduledAt = const Value.absent(),
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  ReminderTableCompanion.insert({
    this.id = const Value.absent(),
    required String title,
    required DateTime scheduledAt,
    this.isActive = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : title = Value(title),
       scheduledAt = Value(scheduledAt);
  static Insertable<Reminder> custom({
    Expression<int>? id,
    Expression<String>? title,
    Expression<DateTime>? scheduledAt,
    Expression<bool>? isActive,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (scheduledAt != null) 'scheduled_at': scheduledAt,
      if (isActive != null) 'is_active': isActive,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  ReminderTableCompanion copyWith({
    Value<int>? id,
    Value<String>? title,
    Value<DateTime>? scheduledAt,
    Value<bool>? isActive,
    Value<DateTime>? createdAt,
  }) {
    return ReminderTableCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      scheduledAt: scheduledAt ?? this.scheduledAt,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (scheduledAt.present) {
      map['scheduled_at'] = Variable<DateTime>(scheduledAt.value);
    }
    if (isActive.present) {
      map['is_active'] = Variable<bool>(isActive.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ReminderTableCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('scheduledAt: $scheduledAt, ')
          ..write('isActive: $isActive, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $UserProfileTableTable userProfileTable = $UserProfileTableTable(
    this,
  );
  late final $StudyPhaseTableTable studyPhaseTable = $StudyPhaseTableTable(
    this,
  );
  late final $SeriesTableTable seriesTable = $SeriesTableTable(this);
  late final $ApplicationTableTable applicationTable = $ApplicationTableTable(
    this,
  );
  late final $TaskTableTable taskTable = $TaskTableTable(this);
  late final $DsaLogTableTable dsaLogTable = $DsaLogTableTable(this);
  late final $ApplicationStatusHistoryTableTable applicationStatusHistoryTable =
      $ApplicationStatusHistoryTableTable(this);
  late final $ConsistencyLogTableTable consistencyLogTable =
      $ConsistencyLogTableTable(this);
  late final $ResumeTableTable resumeTable = $ResumeTableTable(this);
  late final $InterviewPrepTableTable interviewPrepTable =
      $InterviewPrepTableTable(this);
  late final $NoteTableTable noteTable = $NoteTableTable(this);
  late final $NoteTagTableTable noteTagTable = $NoteTagTableTable(this);
  late final $InsightDismissalTableTable insightDismissalTable =
      $InsightDismissalTableTable(this);
  late final $SessionCategoryTableTable sessionCategoryTable =
      $SessionCategoryTableTable(this);
  late final $TimeSessionTableTable timeSessionTable = $TimeSessionTableTable(
    this,
  );
  late final $UpcomingInterviewTableTable upcomingInterviewTable =
      $UpcomingInterviewTableTable(this);
  late final $ReminderTableTable reminderTable = $ReminderTableTable(this);
  late final UserProfileDao userProfileDao = UserProfileDao(
    this as AppDatabase,
  );
  late final TaskDao taskDao = TaskDao(this as AppDatabase);
  late final ApplicationDao applicationDao = ApplicationDao(
    this as AppDatabase,
  );
  late final ConsistencyDao consistencyDao = ConsistencyDao(
    this as AppDatabase,
  );
  late final DsaDao dsaDao = DsaDao(this as AppDatabase);
  late final NotesDao notesDao = NotesDao(this as AppDatabase);
  late final SeriesDao seriesDao = SeriesDao(this as AppDatabase);
  late final StudyPhaseDao studyPhaseDao = StudyPhaseDao(this as AppDatabase);
  late final ResumeDao resumeDao = ResumeDao(this as AppDatabase);
  late final InterviewPrepDao interviewPrepDao = InterviewPrepDao(
    this as AppDatabase,
  );
  late final InsightDismissalDao insightDismissalDao = InsightDismissalDao(
    this as AppDatabase,
  );
  late final TimeSessionDao timeSessionDao = TimeSessionDao(
    this as AppDatabase,
  );
  late final UpcomingInterviewDao upcomingInterviewDao = UpcomingInterviewDao(
    this as AppDatabase,
  );
  late final ReminderDao reminderDao = ReminderDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    userProfileTable,
    studyPhaseTable,
    seriesTable,
    applicationTable,
    taskTable,
    dsaLogTable,
    applicationStatusHistoryTable,
    consistencyLogTable,
    resumeTable,
    interviewPrepTable,
    noteTable,
    noteTagTable,
    insightDismissalTable,
    sessionCategoryTable,
    timeSessionTable,
    upcomingInterviewTable,
    reminderTable,
  ];
}

typedef $$UserProfileTableTableCreateCompanionBuilder =
    UserProfileTableCompanion Function({
      Value<int> id,
      required String name,
      Value<String> targetRole,
      Value<String> targetCompanies,
      Value<DateTime?> interviewDate,
      Value<int> weeklyHoursAvailable,
      Value<String> preferredStudyWindow,
      Value<String> skillSelfRatings,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> lastOpenedAt,
      Value<bool> onboardingComplete,
    });
typedef $$UserProfileTableTableUpdateCompanionBuilder =
    UserProfileTableCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> targetRole,
      Value<String> targetCompanies,
      Value<DateTime?> interviewDate,
      Value<int> weeklyHoursAvailable,
      Value<String> preferredStudyWindow,
      Value<String> skillSelfRatings,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> lastOpenedAt,
      Value<bool> onboardingComplete,
    });

class $$UserProfileTableTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfileTableTable> {
  $$UserProfileTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetRole => $composableBuilder(
    column: $table.targetRole,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get targetCompanies => $composableBuilder(
    column: $table.targetCompanies,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get interviewDate => $composableBuilder(
    column: $table.interviewDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get weeklyHoursAvailable => $composableBuilder(
    column: $table.weeklyHoursAvailable,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get preferredStudyWindow => $composableBuilder(
    column: $table.preferredStudyWindow,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get skillSelfRatings => $composableBuilder(
    column: $table.skillSelfRatings,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get onboardingComplete => $composableBuilder(
    column: $table.onboardingComplete,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UserProfileTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfileTableTable> {
  $$UserProfileTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetRole => $composableBuilder(
    column: $table.targetRole,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get targetCompanies => $composableBuilder(
    column: $table.targetCompanies,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get interviewDate => $composableBuilder(
    column: $table.interviewDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get weeklyHoursAvailable => $composableBuilder(
    column: $table.weeklyHoursAvailable,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get preferredStudyWindow => $composableBuilder(
    column: $table.preferredStudyWindow,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get skillSelfRatings => $composableBuilder(
    column: $table.skillSelfRatings,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get onboardingComplete => $composableBuilder(
    column: $table.onboardingComplete,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfileTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfileTableTable> {
  $$UserProfileTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get targetRole => $composableBuilder(
    column: $table.targetRole,
    builder: (column) => column,
  );

  GeneratedColumn<String> get targetCompanies => $composableBuilder(
    column: $table.targetCompanies,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get interviewDate => $composableBuilder(
    column: $table.interviewDate,
    builder: (column) => column,
  );

  GeneratedColumn<int> get weeklyHoursAvailable => $composableBuilder(
    column: $table.weeklyHoursAvailable,
    builder: (column) => column,
  );

  GeneratedColumn<String> get preferredStudyWindow => $composableBuilder(
    column: $table.preferredStudyWindow,
    builder: (column) => column,
  );

  GeneratedColumn<String> get skillSelfRatings => $composableBuilder(
    column: $table.skillSelfRatings,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastOpenedAt => $composableBuilder(
    column: $table.lastOpenedAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get onboardingComplete => $composableBuilder(
    column: $table.onboardingComplete,
    builder: (column) => column,
  );
}

class $$UserProfileTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProfileTableTable,
          UserProfile,
          $$UserProfileTableTableFilterComposer,
          $$UserProfileTableTableOrderingComposer,
          $$UserProfileTableTableAnnotationComposer,
          $$UserProfileTableTableCreateCompanionBuilder,
          $$UserProfileTableTableUpdateCompanionBuilder,
          (
            UserProfile,
            BaseReferences<_$AppDatabase, $UserProfileTableTable, UserProfile>,
          ),
          UserProfile,
          PrefetchHooks Function()
        > {
  $$UserProfileTableTableTableManager(
    _$AppDatabase db,
    $UserProfileTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfileTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfileTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfileTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> targetRole = const Value.absent(),
                Value<String> targetCompanies = const Value.absent(),
                Value<DateTime?> interviewDate = const Value.absent(),
                Value<int> weeklyHoursAvailable = const Value.absent(),
                Value<String> preferredStudyWindow = const Value.absent(),
                Value<String> skillSelfRatings = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<bool> onboardingComplete = const Value.absent(),
              }) => UserProfileTableCompanion(
                id: id,
                name: name,
                targetRole: targetRole,
                targetCompanies: targetCompanies,
                interviewDate: interviewDate,
                weeklyHoursAvailable: weeklyHoursAvailable,
                preferredStudyWindow: preferredStudyWindow,
                skillSelfRatings: skillSelfRatings,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastOpenedAt: lastOpenedAt,
                onboardingComplete: onboardingComplete,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String> targetRole = const Value.absent(),
                Value<String> targetCompanies = const Value.absent(),
                Value<DateTime?> interviewDate = const Value.absent(),
                Value<int> weeklyHoursAvailable = const Value.absent(),
                Value<String> preferredStudyWindow = const Value.absent(),
                Value<String> skillSelfRatings = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> lastOpenedAt = const Value.absent(),
                Value<bool> onboardingComplete = const Value.absent(),
              }) => UserProfileTableCompanion.insert(
                id: id,
                name: name,
                targetRole: targetRole,
                targetCompanies: targetCompanies,
                interviewDate: interviewDate,
                weeklyHoursAvailable: weeklyHoursAvailable,
                preferredStudyWindow: preferredStudyWindow,
                skillSelfRatings: skillSelfRatings,
                createdAt: createdAt,
                updatedAt: updatedAt,
                lastOpenedAt: lastOpenedAt,
                onboardingComplete: onboardingComplete,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UserProfileTableTable, UserProfile>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $UserProfileTableTable,
                    UserProfile
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UserProfileTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProfileTableTable,
      UserProfile,
      $$UserProfileTableTableFilterComposer,
      $$UserProfileTableTableOrderingComposer,
      $$UserProfileTableTableAnnotationComposer,
      $$UserProfileTableTableCreateCompanionBuilder,
      $$UserProfileTableTableUpdateCompanionBuilder,
      (
        UserProfile,
        BaseReferences<_$AppDatabase, $UserProfileTableTable, UserProfile>,
      ),
      UserProfile,
      PrefetchHooks Function()
    >;
typedef $$StudyPhaseTableTableCreateCompanionBuilder =
    StudyPhaseTableCompanion Function({
      Value<int> id,
      required String title,
      Value<String?> description,
      Value<int> orderIndex,
      Value<DateTime?> startDate,
      Value<DateTime?> endDate,
      Value<String> colorHex,
      Value<DateTime> createdAt,
    });
typedef $$StudyPhaseTableTableUpdateCompanionBuilder =
    StudyPhaseTableCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String?> description,
      Value<int> orderIndex,
      Value<DateTime?> startDate,
      Value<DateTime?> endDate,
      Value<String> colorHex,
      Value<DateTime> createdAt,
    });

final class $$StudyPhaseTableTableReferences
    extends BaseReferences<_$AppDatabase, $StudyPhaseTableTable, StudyPhase> {
  $$StudyPhaseTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$SeriesTableTable, List<Series>>
  _seriesTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.seriesTable,
    aliasName: 'study_phases__id__series__linked_phase_id',
  );

  $$SeriesTableTableProcessedTableManager get seriesTableRefs {
    final manager = $$SeriesTableTableTableManager(
      $_db,
      $_db.seriesTable,
    ).filter((f) => f.linkedPhaseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_seriesTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$TaskTableTable, List<Task>> _taskTableRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.taskTable,
    aliasName: 'study_phases__id__tasks__linked_phase_id',
  );

  $$TaskTableTableProcessedTableManager get taskTableRefs {
    final manager = $$TaskTableTableTableManager(
      $_db,
      $_db.taskTable,
    ).filter((f) => f.linkedPhaseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$NoteTableTable, List<Note>> _noteTableRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.noteTable,
    aliasName: 'study_phases__id__notes__linked_phase_id',
  );

  $$NoteTableTableProcessedTableManager get noteTableRefs {
    final manager = $$NoteTableTableTableManager(
      $_db,
      $_db.noteTable,
    ).filter((f) => f.linkedPhaseId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_noteTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$StudyPhaseTableTableFilterComposer
    extends Composer<_$AppDatabase, $StudyPhaseTableTable> {
  $$StudyPhaseTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> seriesTableRefs(
    Expression<bool> Function($$SeriesTableTableFilterComposer f) f,
  ) {
    final $$SeriesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.seriesTable,
      getReferencedColumn: (t) => t.linkedPhaseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableTableFilterComposer(
            $db: $db,
            $table: $db.seriesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> taskTableRefs(
    Expression<bool> Function($$TaskTableTableFilterComposer f) f,
  ) {
    final $$TaskTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskTable,
      getReferencedColumn: (t) => t.linkedPhaseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTableTableFilterComposer(
            $db: $db,
            $table: $db.taskTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> noteTableRefs(
    Expression<bool> Function($$NoteTableTableFilterComposer f) f,
  ) {
    final $$NoteTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTable,
      getReferencedColumn: (t) => t.linkedPhaseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTableTableFilterComposer(
            $db: $db,
            $table: $db.noteTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StudyPhaseTableTableOrderingComposer
    extends Composer<_$AppDatabase, $StudyPhaseTableTable> {
  $$StudyPhaseTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startDate => $composableBuilder(
    column: $table.startDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StudyPhaseTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $StudyPhaseTableTable> {
  $$StudyPhaseTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get description => $composableBuilder(
    column: $table.description,
    builder: (column) => column,
  );

  GeneratedColumn<int> get orderIndex => $composableBuilder(
    column: $table.orderIndex,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startDate =>
      $composableBuilder(column: $table.startDate, builder: (column) => column);

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  Expression<T> seriesTableRefs<T extends Object>(
    Expression<T> Function($$SeriesTableTableAnnotationComposer a) f,
  ) {
    final $$SeriesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.seriesTable,
      getReferencedColumn: (t) => t.linkedPhaseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.seriesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> taskTableRefs<T extends Object>(
    Expression<T> Function($$TaskTableTableAnnotationComposer a) f,
  ) {
    final $$TaskTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskTable,
      getReferencedColumn: (t) => t.linkedPhaseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTableTableAnnotationComposer(
            $db: $db,
            $table: $db.taskTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> noteTableRefs<T extends Object>(
    Expression<T> Function($$NoteTableTableAnnotationComposer a) f,
  ) {
    final $$NoteTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTable,
      getReferencedColumn: (t) => t.linkedPhaseId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTableTableAnnotationComposer(
            $db: $db,
            $table: $db.noteTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$StudyPhaseTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StudyPhaseTableTable,
          StudyPhase,
          $$StudyPhaseTableTableFilterComposer,
          $$StudyPhaseTableTableOrderingComposer,
          $$StudyPhaseTableTableAnnotationComposer,
          $$StudyPhaseTableTableCreateCompanionBuilder,
          $$StudyPhaseTableTableUpdateCompanionBuilder,
          (StudyPhase, $$StudyPhaseTableTableReferences),
          StudyPhase,
          PrefetchHooks Function({
            bool seriesTableRefs,
            bool taskTableRefs,
            bool noteTableRefs,
          })
        > {
  $$StudyPhaseTableTableTableManager(
    _$AppDatabase db,
    $StudyPhaseTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StudyPhaseTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StudyPhaseTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StudyPhaseTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> description = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<String> colorHex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => StudyPhaseTableCompanion(
                id: id,
                title: title,
                description: description,
                orderIndex: orderIndex,
                startDate: startDate,
                endDate: endDate,
                colorHex: colorHex,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                Value<String?> description = const Value.absent(),
                Value<int> orderIndex = const Value.absent(),
                Value<DateTime?> startDate = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<String> colorHex = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => StudyPhaseTableCompanion.insert(
                id: id,
                title: title,
                description: description,
                orderIndex: orderIndex,
                startDate: startDate,
                endDate: endDate,
                colorHex: colorHex,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$StudyPhaseTableTable, StudyPhase>(table),
                  $$StudyPhaseTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                seriesTableRefs = false,
                taskTableRefs = false,
                noteTableRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (seriesTableRefs) db.seriesTable,
                    if (taskTableRefs) db.taskTable,
                    if (noteTableRefs) db.noteTable,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (seriesTableRefs)
                        await $_getPrefetchedData<
                          StudyPhase,
                          $StudyPhaseTableTable,
                          Series
                        >(
                          currentTable: table,
                          referencedTable: $$StudyPhaseTableTableReferences
                              ._seriesTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StudyPhaseTableTableReferences(
                                db,
                                table,
                                p0,
                              ).seriesTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.linkedPhaseId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (taskTableRefs)
                        await $_getPrefetchedData<
                          StudyPhase,
                          $StudyPhaseTableTable,
                          Task
                        >(
                          currentTable: table,
                          referencedTable: $$StudyPhaseTableTableReferences
                              ._taskTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StudyPhaseTableTableReferences(
                                db,
                                table,
                                p0,
                              ).taskTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.linkedPhaseId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (noteTableRefs)
                        await $_getPrefetchedData<
                          StudyPhase,
                          $StudyPhaseTableTable,
                          Note
                        >(
                          currentTable: table,
                          referencedTable: $$StudyPhaseTableTableReferences
                              ._noteTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$StudyPhaseTableTableReferences(
                                db,
                                table,
                                p0,
                              ).noteTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.linkedPhaseId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$StudyPhaseTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StudyPhaseTableTable,
      StudyPhase,
      $$StudyPhaseTableTableFilterComposer,
      $$StudyPhaseTableTableOrderingComposer,
      $$StudyPhaseTableTableAnnotationComposer,
      $$StudyPhaseTableTableCreateCompanionBuilder,
      $$StudyPhaseTableTableUpdateCompanionBuilder,
      (StudyPhase, $$StudyPhaseTableTableReferences),
      StudyPhase,
      PrefetchHooks Function({
        bool seriesTableRefs,
        bool taskTableRefs,
        bool noteTableRefs,
      })
    >;
typedef $$SeriesTableTableCreateCompanionBuilder =
    SeriesTableCompanion Function({
      Value<int> id,
      required String title,
      Value<int?> totalItems,
      Value<String> pacingRule,
      Value<int?> fixedIntervalDays,
      Value<DateTime?> endDate,
      Value<int?> linkedPhaseId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$SeriesTableTableUpdateCompanionBuilder =
    SeriesTableCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<int?> totalItems,
      Value<String> pacingRule,
      Value<int?> fixedIntervalDays,
      Value<DateTime?> endDate,
      Value<int?> linkedPhaseId,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$SeriesTableTableReferences
    extends BaseReferences<_$AppDatabase, $SeriesTableTable, Series> {
  $$SeriesTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StudyPhaseTableTable _linkedPhaseIdTable(_$AppDatabase db) => db
      .studyPhaseTable
      .createAlias('series__linked_phase_id__study_phases__id');

  $$StudyPhaseTableTableProcessedTableManager? get linkedPhaseId {
    final $_column = $_itemColumn<int>('linked_phase_id');
    if ($_column == null) return null;
    final manager = $$StudyPhaseTableTableTableManager(
      $_db,
      $_db.studyPhaseTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_linkedPhaseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TaskTableTable, List<Task>> _taskTableRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.taskTable,
    aliasName: 'series__id__tasks__series_id',
  );

  $$TaskTableTableProcessedTableManager get taskTableRefs {
    final manager = $$TaskTableTableTableManager(
      $_db,
      $_db.taskTable,
    ).filter((f) => f.seriesId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_taskTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SeriesTableTableFilterComposer
    extends Composer<_$AppDatabase, $SeriesTableTable> {
  $$SeriesTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get totalItems => $composableBuilder(
    column: $table.totalItems,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pacingRule => $composableBuilder(
    column: $table.pacingRule,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fixedIntervalDays => $composableBuilder(
    column: $table.fixedIntervalDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$StudyPhaseTableTableFilterComposer get linkedPhaseId {
    final $$StudyPhaseTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedPhaseId,
      referencedTable: $db.studyPhaseTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudyPhaseTableTableFilterComposer(
            $db: $db,
            $table: $db.studyPhaseTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> taskTableRefs(
    Expression<bool> Function($$TaskTableTableFilterComposer f) f,
  ) {
    final $$TaskTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskTable,
      getReferencedColumn: (t) => t.seriesId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTableTableFilterComposer(
            $db: $db,
            $table: $db.taskTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SeriesTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SeriesTableTable> {
  $$SeriesTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get totalItems => $composableBuilder(
    column: $table.totalItems,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pacingRule => $composableBuilder(
    column: $table.pacingRule,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fixedIntervalDays => $composableBuilder(
    column: $table.fixedIntervalDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endDate => $composableBuilder(
    column: $table.endDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$StudyPhaseTableTableOrderingComposer get linkedPhaseId {
    final $$StudyPhaseTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedPhaseId,
      referencedTable: $db.studyPhaseTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudyPhaseTableTableOrderingComposer(
            $db: $db,
            $table: $db.studyPhaseTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$SeriesTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SeriesTableTable> {
  $$SeriesTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<int> get totalItems => $composableBuilder(
    column: $table.totalItems,
    builder: (column) => column,
  );

  GeneratedColumn<String> get pacingRule => $composableBuilder(
    column: $table.pacingRule,
    builder: (column) => column,
  );

  GeneratedColumn<int> get fixedIntervalDays => $composableBuilder(
    column: $table.fixedIntervalDays,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get endDate =>
      $composableBuilder(column: $table.endDate, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$StudyPhaseTableTableAnnotationComposer get linkedPhaseId {
    final $$StudyPhaseTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedPhaseId,
      referencedTable: $db.studyPhaseTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudyPhaseTableTableAnnotationComposer(
            $db: $db,
            $table: $db.studyPhaseTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> taskTableRefs<T extends Object>(
    Expression<T> Function($$TaskTableTableAnnotationComposer a) f,
  ) {
    final $$TaskTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskTable,
      getReferencedColumn: (t) => t.seriesId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTableTableAnnotationComposer(
            $db: $db,
            $table: $db.taskTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SeriesTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SeriesTableTable,
          Series,
          $$SeriesTableTableFilterComposer,
          $$SeriesTableTableOrderingComposer,
          $$SeriesTableTableAnnotationComposer,
          $$SeriesTableTableCreateCompanionBuilder,
          $$SeriesTableTableUpdateCompanionBuilder,
          (Series, $$SeriesTableTableReferences),
          Series,
          PrefetchHooks Function({bool linkedPhaseId, bool taskTableRefs})
        > {
  $$SeriesTableTableTableManager(_$AppDatabase db, $SeriesTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SeriesTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SeriesTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SeriesTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<int?> totalItems = const Value.absent(),
                Value<String> pacingRule = const Value.absent(),
                Value<int?> fixedIntervalDays = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<int?> linkedPhaseId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => SeriesTableCompanion(
                id: id,
                title: title,
                totalItems: totalItems,
                pacingRule: pacingRule,
                fixedIntervalDays: fixedIntervalDays,
                endDate: endDate,
                linkedPhaseId: linkedPhaseId,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                Value<int?> totalItems = const Value.absent(),
                Value<String> pacingRule = const Value.absent(),
                Value<int?> fixedIntervalDays = const Value.absent(),
                Value<DateTime?> endDate = const Value.absent(),
                Value<int?> linkedPhaseId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => SeriesTableCompanion.insert(
                id: id,
                title: title,
                totalItems: totalItems,
                pacingRule: pacingRule,
                fixedIntervalDays: fixedIntervalDays,
                endDate: endDate,
                linkedPhaseId: linkedPhaseId,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SeriesTableTable, Series>(table),
                  $$SeriesTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({linkedPhaseId = false, taskTableRefs = false}) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [if (taskTableRefs) db.taskTable],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (linkedPhaseId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.linkedPhaseId,
                                    referencedTable:
                                        $$SeriesTableTableReferences
                                            ._linkedPhaseIdTable(db),
                                    referencedColumn:
                                        $$SeriesTableTableReferences
                                            ._linkedPhaseIdTable(db)
                                            .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (taskTableRefs)
                        await $_getPrefetchedData<
                          Series,
                          $SeriesTableTable,
                          Task
                        >(
                          currentTable: table,
                          referencedTable: $$SeriesTableTableReferences
                              ._taskTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$SeriesTableTableReferences(
                                db,
                                table,
                                p0,
                              ).taskTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.seriesId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$SeriesTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SeriesTableTable,
      Series,
      $$SeriesTableTableFilterComposer,
      $$SeriesTableTableOrderingComposer,
      $$SeriesTableTableAnnotationComposer,
      $$SeriesTableTableCreateCompanionBuilder,
      $$SeriesTableTableUpdateCompanionBuilder,
      (Series, $$SeriesTableTableReferences),
      Series,
      PrefetchHooks Function({bool linkedPhaseId, bool taskTableRefs})
    >;
typedef $$ApplicationTableTableCreateCompanionBuilder =
    ApplicationTableCompanion Function({
      Value<int> id,
      required String company,
      required String role,
      Value<String> currentStage,
      Value<String?> notes,
      Value<DateTime?> nextActionDate,
      Value<String?> jobUrl,
      Value<String?> salary,
      Value<DateTime?> lastInteractedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$ApplicationTableTableUpdateCompanionBuilder =
    ApplicationTableCompanion Function({
      Value<int> id,
      Value<String> company,
      Value<String> role,
      Value<String> currentStage,
      Value<String?> notes,
      Value<DateTime?> nextActionDate,
      Value<String?> jobUrl,
      Value<String?> salary,
      Value<DateTime?> lastInteractedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$ApplicationTableTableReferences
    extends
        BaseReferences<_$AppDatabase, $ApplicationTableTable, ApplicationRow> {
  $$ApplicationTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$TaskTableTable, List<Task>> _taskTableRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.taskTable,
    aliasName: 'applications__id__tasks__linked_application_id',
  );

  $$TaskTableTableProcessedTableManager get taskTableRefs {
    final manager = $$TaskTableTableTableManager($_db, $_db.taskTable).filter(
      (f) => f.linkedApplicationId.id.sqlEquals($_itemColumn<int>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_taskTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<
    $ApplicationStatusHistoryTableTable,
    List<ApplicationStatusHistory>
  >
  _applicationStatusHistoryTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.applicationStatusHistoryTable,
        aliasName:
            'applications__id__application_status_history__application_id',
      );

  $$ApplicationStatusHistoryTableTableProcessedTableManager
  get applicationStatusHistoryTableRefs {
    final manager = $$ApplicationStatusHistoryTableTableTableManager(
      $_db,
      $_db.applicationStatusHistoryTable,
    ).filter((f) => f.applicationId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _applicationStatusHistoryTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$ResumeTableTable, List<Resume>>
  _resumeTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.resumeTable,
    aliasName: 'applications__id__resumes__linked_application_id',
  );

  $$ResumeTableTableProcessedTableManager get resumeTableRefs {
    final manager = $$ResumeTableTableTableManager($_db, $_db.resumeTable)
        .filter(
          (f) => f.linkedApplicationId.id.sqlEquals($_itemColumn<int>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(_resumeTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$InterviewPrepTableTable, List<InterviewPrep>>
  _interviewPrepTableRefsTable(_$AppDatabase db) =>
      MultiTypedResultKey.fromTable(
        db.interviewPrepTable,
        aliasName: 'applications__id__interview_prep__linked_application_id',
      );

  $$InterviewPrepTableTableProcessedTableManager get interviewPrepTableRefs {
    final manager =
        $$InterviewPrepTableTableTableManager(
          $_db,
          $_db.interviewPrepTable,
        ).filter(
          (f) => f.linkedApplicationId.id.sqlEquals($_itemColumn<int>('id')!),
        );

    final cache = $_typedResult.readTableOrNull(
      _interviewPrepTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$NoteTableTable, List<Note>> _noteTableRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.noteTable,
    aliasName: 'applications__id__notes__linked_application_id',
  );

  $$NoteTableTableProcessedTableManager get noteTableRefs {
    final manager = $$NoteTableTableTableManager($_db, $_db.noteTable).filter(
      (f) => f.linkedApplicationId.id.sqlEquals($_itemColumn<int>('id')!),
    );

    final cache = $_typedResult.readTableOrNull(_noteTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$ApplicationTableTableFilterComposer
    extends Composer<_$AppDatabase, $ApplicationTableTable> {
  $$ApplicationTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get company => $composableBuilder(
    column: $table.company,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentStage => $composableBuilder(
    column: $table.currentStage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get nextActionDate => $composableBuilder(
    column: $table.nextActionDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get jobUrl => $composableBuilder(
    column: $table.jobUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get salary => $composableBuilder(
    column: $table.salary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastInteractedAt => $composableBuilder(
    column: $table.lastInteractedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> taskTableRefs(
    Expression<bool> Function($$TaskTableTableFilterComposer f) f,
  ) {
    final $$TaskTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskTable,
      getReferencedColumn: (t) => t.linkedApplicationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTableTableFilterComposer(
            $db: $db,
            $table: $db.taskTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> applicationStatusHistoryTableRefs(
    Expression<bool> Function(
      $$ApplicationStatusHistoryTableTableFilterComposer f,
    )
    f,
  ) {
    final $$ApplicationStatusHistoryTableTableFilterComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.applicationStatusHistoryTable,
          getReferencedColumn: (t) => t.applicationId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ApplicationStatusHistoryTableTableFilterComposer(
                $db: $db,
                $table: $db.applicationStatusHistoryTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<bool> resumeTableRefs(
    Expression<bool> Function($$ResumeTableTableFilterComposer f) f,
  ) {
    final $$ResumeTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.resumeTable,
      getReferencedColumn: (t) => t.linkedApplicationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ResumeTableTableFilterComposer(
            $db: $db,
            $table: $db.resumeTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> interviewPrepTableRefs(
    Expression<bool> Function($$InterviewPrepTableTableFilterComposer f) f,
  ) {
    final $$InterviewPrepTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.interviewPrepTable,
      getReferencedColumn: (t) => t.linkedApplicationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$InterviewPrepTableTableFilterComposer(
            $db: $db,
            $table: $db.interviewPrepTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> noteTableRefs(
    Expression<bool> Function($$NoteTableTableFilterComposer f) f,
  ) {
    final $$NoteTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTable,
      getReferencedColumn: (t) => t.linkedApplicationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTableTableFilterComposer(
            $db: $db,
            $table: $db.noteTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ApplicationTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ApplicationTableTable> {
  $$ApplicationTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get company => $composableBuilder(
    column: $table.company,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentStage => $composableBuilder(
    column: $table.currentStage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get nextActionDate => $composableBuilder(
    column: $table.nextActionDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get jobUrl => $composableBuilder(
    column: $table.jobUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get salary => $composableBuilder(
    column: $table.salary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastInteractedAt => $composableBuilder(
    column: $table.lastInteractedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ApplicationTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ApplicationTableTable> {
  $$ApplicationTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get company =>
      $composableBuilder(column: $table.company, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get currentStage => $composableBuilder(
    column: $table.currentStage,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get nextActionDate => $composableBuilder(
    column: $table.nextActionDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get jobUrl =>
      $composableBuilder(column: $table.jobUrl, builder: (column) => column);

  GeneratedColumn<String> get salary =>
      $composableBuilder(column: $table.salary, builder: (column) => column);

  GeneratedColumn<DateTime> get lastInteractedAt => $composableBuilder(
    column: $table.lastInteractedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> taskTableRefs<T extends Object>(
    Expression<T> Function($$TaskTableTableAnnotationComposer a) f,
  ) {
    final $$TaskTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.taskTable,
      getReferencedColumn: (t) => t.linkedApplicationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTableTableAnnotationComposer(
            $db: $db,
            $table: $db.taskTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> applicationStatusHistoryTableRefs<T extends Object>(
    Expression<T> Function(
      $$ApplicationStatusHistoryTableTableAnnotationComposer a,
    )
    f,
  ) {
    final $$ApplicationStatusHistoryTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.applicationStatusHistoryTable,
          getReferencedColumn: (t) => t.applicationId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$ApplicationStatusHistoryTableTableAnnotationComposer(
                $db: $db,
                $table: $db.applicationStatusHistoryTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> resumeTableRefs<T extends Object>(
    Expression<T> Function($$ResumeTableTableAnnotationComposer a) f,
  ) {
    final $$ResumeTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.resumeTable,
      getReferencedColumn: (t) => t.linkedApplicationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ResumeTableTableAnnotationComposer(
            $db: $db,
            $table: $db.resumeTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> interviewPrepTableRefs<T extends Object>(
    Expression<T> Function($$InterviewPrepTableTableAnnotationComposer a) f,
  ) {
    final $$InterviewPrepTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.id,
          referencedTable: $db.interviewPrepTable,
          getReferencedColumn: (t) => t.linkedApplicationId,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$InterviewPrepTableTableAnnotationComposer(
                $db: $db,
                $table: $db.interviewPrepTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return f(composer);
  }

  Expression<T> noteTableRefs<T extends Object>(
    Expression<T> Function($$NoteTableTableAnnotationComposer a) f,
  ) {
    final $$NoteTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTable,
      getReferencedColumn: (t) => t.linkedApplicationId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTableTableAnnotationComposer(
            $db: $db,
            $table: $db.noteTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$ApplicationTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ApplicationTableTable,
          ApplicationRow,
          $$ApplicationTableTableFilterComposer,
          $$ApplicationTableTableOrderingComposer,
          $$ApplicationTableTableAnnotationComposer,
          $$ApplicationTableTableCreateCompanionBuilder,
          $$ApplicationTableTableUpdateCompanionBuilder,
          (ApplicationRow, $$ApplicationTableTableReferences),
          ApplicationRow,
          PrefetchHooks Function({
            bool taskTableRefs,
            bool applicationStatusHistoryTableRefs,
            bool resumeTableRefs,
            bool interviewPrepTableRefs,
            bool noteTableRefs,
          })
        > {
  $$ApplicationTableTableTableManager(
    _$AppDatabase db,
    $ApplicationTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ApplicationTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ApplicationTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ApplicationTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> company = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<String> currentStage = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> nextActionDate = const Value.absent(),
                Value<String?> jobUrl = const Value.absent(),
                Value<String?> salary = const Value.absent(),
                Value<DateTime?> lastInteractedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ApplicationTableCompanion(
                id: id,
                company: company,
                role: role,
                currentStage: currentStage,
                notes: notes,
                nextActionDate: nextActionDate,
                jobUrl: jobUrl,
                salary: salary,
                lastInteractedAt: lastInteractedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String company,
                required String role,
                Value<String> currentStage = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> nextActionDate = const Value.absent(),
                Value<String?> jobUrl = const Value.absent(),
                Value<String?> salary = const Value.absent(),
                Value<DateTime?> lastInteractedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => ApplicationTableCompanion.insert(
                id: id,
                company: company,
                role: role,
                currentStage: currentStage,
                notes: notes,
                nextActionDate: nextActionDate,
                jobUrl: jobUrl,
                salary: salary,
                lastInteractedAt: lastInteractedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ApplicationTableTable, ApplicationRow>(table),
                  $$ApplicationTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                taskTableRefs = false,
                applicationStatusHistoryTableRefs = false,
                resumeTableRefs = false,
                interviewPrepTableRefs = false,
                noteTableRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (taskTableRefs) db.taskTable,
                    if (applicationStatusHistoryTableRefs)
                      db.applicationStatusHistoryTable,
                    if (resumeTableRefs) db.resumeTable,
                    if (interviewPrepTableRefs) db.interviewPrepTable,
                    if (noteTableRefs) db.noteTable,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (taskTableRefs)
                        await $_getPrefetchedData<
                          ApplicationRow,
                          $ApplicationTableTable,
                          Task
                        >(
                          currentTable: table,
                          referencedTable: $$ApplicationTableTableReferences
                              ._taskTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ApplicationTableTableReferences(
                                db,
                                table,
                                p0,
                              ).taskTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.linkedApplicationId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (applicationStatusHistoryTableRefs)
                        await $_getPrefetchedData<
                          ApplicationRow,
                          $ApplicationTableTable,
                          ApplicationStatusHistory
                        >(
                          currentTable: table,
                          referencedTable: $$ApplicationTableTableReferences
                              ._applicationStatusHistoryTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ApplicationTableTableReferences(
                                db,
                                table,
                                p0,
                              ).applicationStatusHistoryTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.applicationId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (resumeTableRefs)
                        await $_getPrefetchedData<
                          ApplicationRow,
                          $ApplicationTableTable,
                          Resume
                        >(
                          currentTable: table,
                          referencedTable: $$ApplicationTableTableReferences
                              ._resumeTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ApplicationTableTableReferences(
                                db,
                                table,
                                p0,
                              ).resumeTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.linkedApplicationId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (interviewPrepTableRefs)
                        await $_getPrefetchedData<
                          ApplicationRow,
                          $ApplicationTableTable,
                          InterviewPrep
                        >(
                          currentTable: table,
                          referencedTable: $$ApplicationTableTableReferences
                              ._interviewPrepTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ApplicationTableTableReferences(
                                db,
                                table,
                                p0,
                              ).interviewPrepTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.linkedApplicationId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (noteTableRefs)
                        await $_getPrefetchedData<
                          ApplicationRow,
                          $ApplicationTableTable,
                          Note
                        >(
                          currentTable: table,
                          referencedTable: $$ApplicationTableTableReferences
                              ._noteTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$ApplicationTableTableReferences(
                                db,
                                table,
                                p0,
                              ).noteTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.linkedApplicationId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$ApplicationTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ApplicationTableTable,
      ApplicationRow,
      $$ApplicationTableTableFilterComposer,
      $$ApplicationTableTableOrderingComposer,
      $$ApplicationTableTableAnnotationComposer,
      $$ApplicationTableTableCreateCompanionBuilder,
      $$ApplicationTableTableUpdateCompanionBuilder,
      (ApplicationRow, $$ApplicationTableTableReferences),
      ApplicationRow,
      PrefetchHooks Function({
        bool taskTableRefs,
        bool applicationStatusHistoryTableRefs,
        bool resumeTableRefs,
        bool interviewPrepTableRefs,
        bool noteTableRefs,
      })
    >;
typedef $$TaskTableTableCreateCompanionBuilder =
    TaskTableCompanion Function({
      Value<int> id,
      required String title,
      Value<String?> notes,
      Value<DateTime?> plannedDate,
      Value<DateTime?> actualCompletedDate,
      Value<String> priority,
      Value<int?> linkedPhaseId,
      Value<int?> seriesId,
      Value<int?> seriesItemIndex,
      Value<int?> parentTaskId,
      Value<int?> linkedApplicationId,
      Value<int?> estimatedMinutes,
      Value<int?> actualMinutes,
      Value<bool> revisitFlag,
      Value<DateTime?> lastInteractedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$TaskTableTableUpdateCompanionBuilder =
    TaskTableCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<String?> notes,
      Value<DateTime?> plannedDate,
      Value<DateTime?> actualCompletedDate,
      Value<String> priority,
      Value<int?> linkedPhaseId,
      Value<int?> seriesId,
      Value<int?> seriesItemIndex,
      Value<int?> parentTaskId,
      Value<int?> linkedApplicationId,
      Value<int?> estimatedMinutes,
      Value<int?> actualMinutes,
      Value<bool> revisitFlag,
      Value<DateTime?> lastInteractedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$TaskTableTableReferences
    extends BaseReferences<_$AppDatabase, $TaskTableTable, Task> {
  $$TaskTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $StudyPhaseTableTable _linkedPhaseIdTable(_$AppDatabase db) => db
      .studyPhaseTable
      .createAlias('tasks__linked_phase_id__study_phases__id');

  $$StudyPhaseTableTableProcessedTableManager? get linkedPhaseId {
    final $_column = $_itemColumn<int>('linked_phase_id');
    if ($_column == null) return null;
    final manager = $$StudyPhaseTableTableTableManager(
      $_db,
      $_db.studyPhaseTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_linkedPhaseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $SeriesTableTable _seriesIdTable(_$AppDatabase db) =>
      db.seriesTable.createAlias('tasks__series_id__series__id');

  $$SeriesTableTableProcessedTableManager? get seriesId {
    final $_column = $_itemColumn<int>('series_id');
    if ($_column == null) return null;
    final manager = $$SeriesTableTableTableManager(
      $_db,
      $_db.seriesTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_seriesIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TaskTableTable _parentTaskIdTable(_$AppDatabase db) =>
      db.taskTable.createAlias('tasks__parent_task_id__tasks__id');

  $$TaskTableTableProcessedTableManager? get parentTaskId {
    final $_column = $_itemColumn<int>('parent_task_id');
    if ($_column == null) return null;
    final manager = $$TaskTableTableTableManager(
      $_db,
      $_db.taskTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentTaskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $ApplicationTableTable _linkedApplicationIdTable(_$AppDatabase db) =>
      db.applicationTable.createAlias(
        'tasks__linked_application_id__applications__id',
      );

  $$ApplicationTableTableProcessedTableManager? get linkedApplicationId {
    final $_column = $_itemColumn<int>('linked_application_id');
    if ($_column == null) return null;
    final manager = $$ApplicationTableTableTableManager(
      $_db,
      $_db.applicationTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_linkedApplicationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TimeSessionTableTable, List<TimeSession>>
  _timeSessionTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.timeSessionTable,
    aliasName: 'tasks__id__time_sessions__linked_task_id',
  );

  $$TimeSessionTableTableProcessedTableManager get timeSessionTableRefs {
    final manager = $$TimeSessionTableTableTableManager(
      $_db,
      $_db.timeSessionTable,
    ).filter((f) => f.linkedTaskId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _timeSessionTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TaskTableTableFilterComposer
    extends Composer<_$AppDatabase, $TaskTableTable> {
  $$TaskTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get plannedDate => $composableBuilder(
    column: $table.plannedDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get actualCompletedDate => $composableBuilder(
    column: $table.actualCompletedDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get seriesItemIndex => $composableBuilder(
    column: $table.seriesItemIndex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get estimatedMinutes => $composableBuilder(
    column: $table.estimatedMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get actualMinutes => $composableBuilder(
    column: $table.actualMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get revisitFlag => $composableBuilder(
    column: $table.revisitFlag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastInteractedAt => $composableBuilder(
    column: $table.lastInteractedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$StudyPhaseTableTableFilterComposer get linkedPhaseId {
    final $$StudyPhaseTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedPhaseId,
      referencedTable: $db.studyPhaseTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudyPhaseTableTableFilterComposer(
            $db: $db,
            $table: $db.studyPhaseTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SeriesTableTableFilterComposer get seriesId {
    final $$SeriesTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.seriesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableTableFilterComposer(
            $db: $db,
            $table: $db.seriesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TaskTableTableFilterComposer get parentTaskId {
    final $$TaskTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentTaskId,
      referencedTable: $db.taskTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTableTableFilterComposer(
            $db: $db,
            $table: $db.taskTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ApplicationTableTableFilterComposer get linkedApplicationId {
    final $$ApplicationTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedApplicationId,
      referencedTable: $db.applicationTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApplicationTableTableFilterComposer(
            $db: $db,
            $table: $db.applicationTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> timeSessionTableRefs(
    Expression<bool> Function($$TimeSessionTableTableFilterComposer f) f,
  ) {
    final $$TimeSessionTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timeSessionTable,
      getReferencedColumn: (t) => t.linkedTaskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimeSessionTableTableFilterComposer(
            $db: $db,
            $table: $db.timeSessionTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TaskTableTableOrderingComposer
    extends Composer<_$AppDatabase, $TaskTableTable> {
  $$TaskTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get plannedDate => $composableBuilder(
    column: $table.plannedDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get actualCompletedDate => $composableBuilder(
    column: $table.actualCompletedDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get seriesItemIndex => $composableBuilder(
    column: $table.seriesItemIndex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get estimatedMinutes => $composableBuilder(
    column: $table.estimatedMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get actualMinutes => $composableBuilder(
    column: $table.actualMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get revisitFlag => $composableBuilder(
    column: $table.revisitFlag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastInteractedAt => $composableBuilder(
    column: $table.lastInteractedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$StudyPhaseTableTableOrderingComposer get linkedPhaseId {
    final $$StudyPhaseTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedPhaseId,
      referencedTable: $db.studyPhaseTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudyPhaseTableTableOrderingComposer(
            $db: $db,
            $table: $db.studyPhaseTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SeriesTableTableOrderingComposer get seriesId {
    final $$SeriesTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.seriesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableTableOrderingComposer(
            $db: $db,
            $table: $db.seriesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TaskTableTableOrderingComposer get parentTaskId {
    final $$TaskTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentTaskId,
      referencedTable: $db.taskTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTableTableOrderingComposer(
            $db: $db,
            $table: $db.taskTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ApplicationTableTableOrderingComposer get linkedApplicationId {
    final $$ApplicationTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedApplicationId,
      referencedTable: $db.applicationTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApplicationTableTableOrderingComposer(
            $db: $db,
            $table: $db.applicationTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TaskTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $TaskTableTable> {
  $$TaskTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get plannedDate => $composableBuilder(
    column: $table.plannedDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get actualCompletedDate => $composableBuilder(
    column: $table.actualCompletedDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get seriesItemIndex => $composableBuilder(
    column: $table.seriesItemIndex,
    builder: (column) => column,
  );

  GeneratedColumn<int> get estimatedMinutes => $composableBuilder(
    column: $table.estimatedMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get actualMinutes => $composableBuilder(
    column: $table.actualMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get revisitFlag => $composableBuilder(
    column: $table.revisitFlag,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastInteractedAt => $composableBuilder(
    column: $table.lastInteractedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$StudyPhaseTableTableAnnotationComposer get linkedPhaseId {
    final $$StudyPhaseTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedPhaseId,
      referencedTable: $db.studyPhaseTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudyPhaseTableTableAnnotationComposer(
            $db: $db,
            $table: $db.studyPhaseTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$SeriesTableTableAnnotationComposer get seriesId {
    final $$SeriesTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.seriesId,
      referencedTable: $db.seriesTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SeriesTableTableAnnotationComposer(
            $db: $db,
            $table: $db.seriesTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TaskTableTableAnnotationComposer get parentTaskId {
    final $$TaskTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.parentTaskId,
      referencedTable: $db.taskTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTableTableAnnotationComposer(
            $db: $db,
            $table: $db.taskTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$ApplicationTableTableAnnotationComposer get linkedApplicationId {
    final $$ApplicationTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedApplicationId,
      referencedTable: $db.applicationTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApplicationTableTableAnnotationComposer(
            $db: $db,
            $table: $db.applicationTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> timeSessionTableRefs<T extends Object>(
    Expression<T> Function($$TimeSessionTableTableAnnotationComposer a) f,
  ) {
    final $$TimeSessionTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timeSessionTable,
      getReferencedColumn: (t) => t.linkedTaskId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimeSessionTableTableAnnotationComposer(
            $db: $db,
            $table: $db.timeSessionTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TaskTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TaskTableTable,
          Task,
          $$TaskTableTableFilterComposer,
          $$TaskTableTableOrderingComposer,
          $$TaskTableTableAnnotationComposer,
          $$TaskTableTableCreateCompanionBuilder,
          $$TaskTableTableUpdateCompanionBuilder,
          (Task, $$TaskTableTableReferences),
          Task,
          PrefetchHooks Function({
            bool linkedPhaseId,
            bool seriesId,
            bool parentTaskId,
            bool linkedApplicationId,
            bool timeSessionTableRefs,
          })
        > {
  $$TaskTableTableTableManager(_$AppDatabase db, $TaskTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TaskTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TaskTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TaskTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> plannedDate = const Value.absent(),
                Value<DateTime?> actualCompletedDate = const Value.absent(),
                Value<String> priority = const Value.absent(),
                Value<int?> linkedPhaseId = const Value.absent(),
                Value<int?> seriesId = const Value.absent(),
                Value<int?> seriesItemIndex = const Value.absent(),
                Value<int?> parentTaskId = const Value.absent(),
                Value<int?> linkedApplicationId = const Value.absent(),
                Value<int?> estimatedMinutes = const Value.absent(),
                Value<int?> actualMinutes = const Value.absent(),
                Value<bool> revisitFlag = const Value.absent(),
                Value<DateTime?> lastInteractedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TaskTableCompanion(
                id: id,
                title: title,
                notes: notes,
                plannedDate: plannedDate,
                actualCompletedDate: actualCompletedDate,
                priority: priority,
                linkedPhaseId: linkedPhaseId,
                seriesId: seriesId,
                seriesItemIndex: seriesItemIndex,
                parentTaskId: parentTaskId,
                linkedApplicationId: linkedApplicationId,
                estimatedMinutes: estimatedMinutes,
                actualMinutes: actualMinutes,
                revisitFlag: revisitFlag,
                lastInteractedAt: lastInteractedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                Value<String?> notes = const Value.absent(),
                Value<DateTime?> plannedDate = const Value.absent(),
                Value<DateTime?> actualCompletedDate = const Value.absent(),
                Value<String> priority = const Value.absent(),
                Value<int?> linkedPhaseId = const Value.absent(),
                Value<int?> seriesId = const Value.absent(),
                Value<int?> seriesItemIndex = const Value.absent(),
                Value<int?> parentTaskId = const Value.absent(),
                Value<int?> linkedApplicationId = const Value.absent(),
                Value<int?> estimatedMinutes = const Value.absent(),
                Value<int?> actualMinutes = const Value.absent(),
                Value<bool> revisitFlag = const Value.absent(),
                Value<DateTime?> lastInteractedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TaskTableCompanion.insert(
                id: id,
                title: title,
                notes: notes,
                plannedDate: plannedDate,
                actualCompletedDate: actualCompletedDate,
                priority: priority,
                linkedPhaseId: linkedPhaseId,
                seriesId: seriesId,
                seriesItemIndex: seriesItemIndex,
                parentTaskId: parentTaskId,
                linkedApplicationId: linkedApplicationId,
                estimatedMinutes: estimatedMinutes,
                actualMinutes: actualMinutes,
                revisitFlag: revisitFlag,
                lastInteractedAt: lastInteractedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TaskTableTable, Task>(table),
                  $$TaskTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                linkedPhaseId = false,
                seriesId = false,
                parentTaskId = false,
                linkedApplicationId = false,
                timeSessionTableRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (timeSessionTableRefs) db.timeSessionTable,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (linkedPhaseId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.linkedPhaseId,
                                    referencedTable: $$TaskTableTableReferences
                                        ._linkedPhaseIdTable(db),
                                    referencedColumn: $$TaskTableTableReferences
                                        ._linkedPhaseIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (seriesId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.seriesId,
                                    referencedTable: $$TaskTableTableReferences
                                        ._seriesIdTable(db),
                                    referencedColumn: $$TaskTableTableReferences
                                        ._seriesIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (parentTaskId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.parentTaskId,
                                    referencedTable: $$TaskTableTableReferences
                                        ._parentTaskIdTable(db),
                                    referencedColumn: $$TaskTableTableReferences
                                        ._parentTaskIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (linkedApplicationId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.linkedApplicationId,
                                    referencedTable: $$TaskTableTableReferences
                                        ._linkedApplicationIdTable(db),
                                    referencedColumn: $$TaskTableTableReferences
                                        ._linkedApplicationIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (timeSessionTableRefs)
                        await $_getPrefetchedData<
                          Task,
                          $TaskTableTable,
                          TimeSession
                        >(
                          currentTable: table,
                          referencedTable: $$TaskTableTableReferences
                              ._timeSessionTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$TaskTableTableReferences(
                                db,
                                table,
                                p0,
                              ).timeSessionTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.linkedTaskId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$TaskTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TaskTableTable,
      Task,
      $$TaskTableTableFilterComposer,
      $$TaskTableTableOrderingComposer,
      $$TaskTableTableAnnotationComposer,
      $$TaskTableTableCreateCompanionBuilder,
      $$TaskTableTableUpdateCompanionBuilder,
      (Task, $$TaskTableTableReferences),
      Task,
      PrefetchHooks Function({
        bool linkedPhaseId,
        bool seriesId,
        bool parentTaskId,
        bool linkedApplicationId,
        bool timeSessionTableRefs,
      })
    >;
typedef $$DsaLogTableTableCreateCompanionBuilder =
    DsaLogTableCompanion Function({
      Value<int> id,
      required String problemName,
      required String topic,
      required String difficulty,
      required DateTime dateSolved,
      Value<bool> revisitFlag,
      Value<int?> timeTakenMinutes,
      Value<String?> notes,
      Value<String?> problemUrl,
      Value<DateTime> createdAt,
    });
typedef $$DsaLogTableTableUpdateCompanionBuilder =
    DsaLogTableCompanion Function({
      Value<int> id,
      Value<String> problemName,
      Value<String> topic,
      Value<String> difficulty,
      Value<DateTime> dateSolved,
      Value<bool> revisitFlag,
      Value<int?> timeTakenMinutes,
      Value<String?> notes,
      Value<String?> problemUrl,
      Value<DateTime> createdAt,
    });

class $$DsaLogTableTableFilterComposer
    extends Composer<_$AppDatabase, $DsaLogTableTable> {
  $$DsaLogTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get problemName => $composableBuilder(
    column: $table.problemName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get topic => $composableBuilder(
    column: $table.topic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dateSolved => $composableBuilder(
    column: $table.dateSolved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get revisitFlag => $composableBuilder(
    column: $table.revisitFlag,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get timeTakenMinutes => $composableBuilder(
    column: $table.timeTakenMinutes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get problemUrl => $composableBuilder(
    column: $table.problemUrl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DsaLogTableTableOrderingComposer
    extends Composer<_$AppDatabase, $DsaLogTableTable> {
  $$DsaLogTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get problemName => $composableBuilder(
    column: $table.problemName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get topic => $composableBuilder(
    column: $table.topic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dateSolved => $composableBuilder(
    column: $table.dateSolved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get revisitFlag => $composableBuilder(
    column: $table.revisitFlag,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get timeTakenMinutes => $composableBuilder(
    column: $table.timeTakenMinutes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get problemUrl => $composableBuilder(
    column: $table.problemUrl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DsaLogTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $DsaLogTableTable> {
  $$DsaLogTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get problemName => $composableBuilder(
    column: $table.problemName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get topic =>
      $composableBuilder(column: $table.topic, builder: (column) => column);

  GeneratedColumn<String> get difficulty => $composableBuilder(
    column: $table.difficulty,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dateSolved => $composableBuilder(
    column: $table.dateSolved,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get revisitFlag => $composableBuilder(
    column: $table.revisitFlag,
    builder: (column) => column,
  );

  GeneratedColumn<int> get timeTakenMinutes => $composableBuilder(
    column: $table.timeTakenMinutes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<String> get problemUrl => $composableBuilder(
    column: $table.problemUrl,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$DsaLogTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DsaLogTableTable,
          DsaLog,
          $$DsaLogTableTableFilterComposer,
          $$DsaLogTableTableOrderingComposer,
          $$DsaLogTableTableAnnotationComposer,
          $$DsaLogTableTableCreateCompanionBuilder,
          $$DsaLogTableTableUpdateCompanionBuilder,
          (DsaLog, BaseReferences<_$AppDatabase, $DsaLogTableTable, DsaLog>),
          DsaLog,
          PrefetchHooks Function()
        > {
  $$DsaLogTableTableTableManager(_$AppDatabase db, $DsaLogTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DsaLogTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DsaLogTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DsaLogTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> problemName = const Value.absent(),
                Value<String> topic = const Value.absent(),
                Value<String> difficulty = const Value.absent(),
                Value<DateTime> dateSolved = const Value.absent(),
                Value<bool> revisitFlag = const Value.absent(),
                Value<int?> timeTakenMinutes = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> problemUrl = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DsaLogTableCompanion(
                id: id,
                problemName: problemName,
                topic: topic,
                difficulty: difficulty,
                dateSolved: dateSolved,
                revisitFlag: revisitFlag,
                timeTakenMinutes: timeTakenMinutes,
                notes: notes,
                problemUrl: problemUrl,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String problemName,
                required String topic,
                required String difficulty,
                required DateTime dateSolved,
                Value<bool> revisitFlag = const Value.absent(),
                Value<int?> timeTakenMinutes = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<String?> problemUrl = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => DsaLogTableCompanion.insert(
                id: id,
                problemName: problemName,
                topic: topic,
                difficulty: difficulty,
                dateSolved: dateSolved,
                revisitFlag: revisitFlag,
                timeTakenMinutes: timeTakenMinutes,
                notes: notes,
                problemUrl: problemUrl,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$DsaLogTableTable, DsaLog>(table),
                  BaseReferences<_$AppDatabase, $DsaLogTableTable, DsaLog>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DsaLogTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DsaLogTableTable,
      DsaLog,
      $$DsaLogTableTableFilterComposer,
      $$DsaLogTableTableOrderingComposer,
      $$DsaLogTableTableAnnotationComposer,
      $$DsaLogTableTableCreateCompanionBuilder,
      $$DsaLogTableTableUpdateCompanionBuilder,
      (DsaLog, BaseReferences<_$AppDatabase, $DsaLogTableTable, DsaLog>),
      DsaLog,
      PrefetchHooks Function()
    >;
typedef $$ApplicationStatusHistoryTableTableCreateCompanionBuilder =
    ApplicationStatusHistoryTableCompanion Function({
      Value<int> id,
      required int applicationId,
      required String stage,
      Value<String?> notes,
      Value<DateTime> occurredAt,
    });
typedef $$ApplicationStatusHistoryTableTableUpdateCompanionBuilder =
    ApplicationStatusHistoryTableCompanion Function({
      Value<int> id,
      Value<int> applicationId,
      Value<String> stage,
      Value<String?> notes,
      Value<DateTime> occurredAt,
    });

final class $$ApplicationStatusHistoryTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $ApplicationStatusHistoryTableTable,
          ApplicationStatusHistory
        > {
  $$ApplicationStatusHistoryTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ApplicationTableTable _applicationIdTable(_$AppDatabase db) =>
      db.applicationTable.createAlias(
        'application_status_history__application_id__applications__id',
      );

  $$ApplicationTableTableProcessedTableManager get applicationId {
    final $_column = $_itemColumn<int>('application_id')!;

    final manager = $$ApplicationTableTableTableManager(
      $_db,
      $_db.applicationTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_applicationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ApplicationStatusHistoryTableTableFilterComposer
    extends Composer<_$AppDatabase, $ApplicationStatusHistoryTableTable> {
  $$ApplicationStatusHistoryTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ApplicationTableTableFilterComposer get applicationId {
    final $$ApplicationTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.applicationId,
      referencedTable: $db.applicationTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApplicationTableTableFilterComposer(
            $db: $db,
            $table: $db.applicationTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ApplicationStatusHistoryTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ApplicationStatusHistoryTableTable> {
  $$ApplicationStatusHistoryTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get stage => $composableBuilder(
    column: $table.stage,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ApplicationTableTableOrderingComposer get applicationId {
    final $$ApplicationTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.applicationId,
      referencedTable: $db.applicationTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApplicationTableTableOrderingComposer(
            $db: $db,
            $table: $db.applicationTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ApplicationStatusHistoryTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ApplicationStatusHistoryTableTable> {
  $$ApplicationStatusHistoryTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get stage =>
      $composableBuilder(column: $table.stage, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  $$ApplicationTableTableAnnotationComposer get applicationId {
    final $$ApplicationTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.applicationId,
      referencedTable: $db.applicationTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApplicationTableTableAnnotationComposer(
            $db: $db,
            $table: $db.applicationTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ApplicationStatusHistoryTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ApplicationStatusHistoryTableTable,
          ApplicationStatusHistory,
          $$ApplicationStatusHistoryTableTableFilterComposer,
          $$ApplicationStatusHistoryTableTableOrderingComposer,
          $$ApplicationStatusHistoryTableTableAnnotationComposer,
          $$ApplicationStatusHistoryTableTableCreateCompanionBuilder,
          $$ApplicationStatusHistoryTableTableUpdateCompanionBuilder,
          (
            ApplicationStatusHistory,
            $$ApplicationStatusHistoryTableTableReferences,
          ),
          ApplicationStatusHistory,
          PrefetchHooks Function({bool applicationId})
        > {
  $$ApplicationStatusHistoryTableTableTableManager(
    _$AppDatabase db,
    $ApplicationStatusHistoryTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ApplicationStatusHistoryTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$ApplicationStatusHistoryTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ApplicationStatusHistoryTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> applicationId = const Value.absent(),
                Value<String> stage = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
              }) => ApplicationStatusHistoryTableCompanion(
                id: id,
                applicationId: applicationId,
                stage: stage,
                notes: notes,
                occurredAt: occurredAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int applicationId,
                required String stage,
                Value<String?> notes = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
              }) => ApplicationStatusHistoryTableCompanion.insert(
                id: id,
                applicationId: applicationId,
                stage: stage,
                notes: notes,
                occurredAt: occurredAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $ApplicationStatusHistoryTableTable,
                    ApplicationStatusHistory
                  >(table),
                  $$ApplicationStatusHistoryTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({applicationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (applicationId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.applicationId,
                                referencedTable:
                                    $$ApplicationStatusHistoryTableTableReferences
                                        ._applicationIdTable(db),
                                referencedColumn:
                                    $$ApplicationStatusHistoryTableTableReferences
                                        ._applicationIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ApplicationStatusHistoryTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ApplicationStatusHistoryTableTable,
      ApplicationStatusHistory,
      $$ApplicationStatusHistoryTableTableFilterComposer,
      $$ApplicationStatusHistoryTableTableOrderingComposer,
      $$ApplicationStatusHistoryTableTableAnnotationComposer,
      $$ApplicationStatusHistoryTableTableCreateCompanionBuilder,
      $$ApplicationStatusHistoryTableTableUpdateCompanionBuilder,
      (
        ApplicationStatusHistory,
        $$ApplicationStatusHistoryTableTableReferences,
      ),
      ApplicationStatusHistory,
      PrefetchHooks Function({bool applicationId})
    >;
typedef $$ConsistencyLogTableTableCreateCompanionBuilder =
    ConsistencyLogTableCompanion Function({
      Value<int> id,
      required DateTime date,
      required bool present,
      Value<String?> note,
      Value<double?> hoursStudied,
    });
typedef $$ConsistencyLogTableTableUpdateCompanionBuilder =
    ConsistencyLogTableCompanion Function({
      Value<int> id,
      Value<DateTime> date,
      Value<bool> present,
      Value<String?> note,
      Value<double?> hoursStudied,
    });

class $$ConsistencyLogTableTableFilterComposer
    extends Composer<_$AppDatabase, $ConsistencyLogTableTable> {
  $$ConsistencyLogTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get present => $composableBuilder(
    column: $table.present,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get hoursStudied => $composableBuilder(
    column: $table.hoursStudied,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ConsistencyLogTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ConsistencyLogTableTable> {
  $$ConsistencyLogTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get present => $composableBuilder(
    column: $table.present,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get hoursStudied => $composableBuilder(
    column: $table.hoursStudied,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ConsistencyLogTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ConsistencyLogTableTable> {
  $$ConsistencyLogTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<bool> get present =>
      $composableBuilder(column: $table.present, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<double> get hoursStudied => $composableBuilder(
    column: $table.hoursStudied,
    builder: (column) => column,
  );
}

class $$ConsistencyLogTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ConsistencyLogTableTable,
          ConsistencyLog,
          $$ConsistencyLogTableTableFilterComposer,
          $$ConsistencyLogTableTableOrderingComposer,
          $$ConsistencyLogTableTableAnnotationComposer,
          $$ConsistencyLogTableTableCreateCompanionBuilder,
          $$ConsistencyLogTableTableUpdateCompanionBuilder,
          (
            ConsistencyLog,
            BaseReferences<
              _$AppDatabase,
              $ConsistencyLogTableTable,
              ConsistencyLog
            >,
          ),
          ConsistencyLog,
          PrefetchHooks Function()
        > {
  $$ConsistencyLogTableTableTableManager(
    _$AppDatabase db,
    $ConsistencyLogTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ConsistencyLogTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ConsistencyLogTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$ConsistencyLogTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<bool> present = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<double?> hoursStudied = const Value.absent(),
              }) => ConsistencyLogTableCompanion(
                id: id,
                date: date,
                present: present,
                note: note,
                hoursStudied: hoursStudied,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required DateTime date,
                required bool present,
                Value<String?> note = const Value.absent(),
                Value<double?> hoursStudied = const Value.absent(),
              }) => ConsistencyLogTableCompanion.insert(
                id: id,
                date: date,
                present: present,
                note: note,
                hoursStudied: hoursStudied,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ConsistencyLogTableTable, ConsistencyLog>(table),
                  BaseReferences<
                    _$AppDatabase,
                    $ConsistencyLogTableTable,
                    ConsistencyLog
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ConsistencyLogTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ConsistencyLogTableTable,
      ConsistencyLog,
      $$ConsistencyLogTableTableFilterComposer,
      $$ConsistencyLogTableTableOrderingComposer,
      $$ConsistencyLogTableTableAnnotationComposer,
      $$ConsistencyLogTableTableCreateCompanionBuilder,
      $$ConsistencyLogTableTableUpdateCompanionBuilder,
      (
        ConsistencyLog,
        BaseReferences<
          _$AppDatabase,
          $ConsistencyLogTableTable,
          ConsistencyLog
        >,
      ),
      ConsistencyLog,
      PrefetchHooks Function()
    >;
typedef $$ResumeTableTableCreateCompanionBuilder =
    ResumeTableCompanion Function({
      Value<int> id,
      required String versionLabel,
      required String filePath,
      Value<int?> fileSize,
      Value<String?> tailoredForCompany,
      Value<int?> linkedApplicationId,
      Value<DateTime> uploadedAt,
      Value<String?> notes,
    });
typedef $$ResumeTableTableUpdateCompanionBuilder =
    ResumeTableCompanion Function({
      Value<int> id,
      Value<String> versionLabel,
      Value<String> filePath,
      Value<int?> fileSize,
      Value<String?> tailoredForCompany,
      Value<int?> linkedApplicationId,
      Value<DateTime> uploadedAt,
      Value<String?> notes,
    });

final class $$ResumeTableTableReferences
    extends BaseReferences<_$AppDatabase, $ResumeTableTable, Resume> {
  $$ResumeTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ApplicationTableTable _linkedApplicationIdTable(_$AppDatabase db) =>
      db.applicationTable.createAlias(
        'resumes__linked_application_id__applications__id',
      );

  $$ApplicationTableTableProcessedTableManager? get linkedApplicationId {
    final $_column = $_itemColumn<int>('linked_application_id');
    if ($_column == null) return null;
    final manager = $$ApplicationTableTableTableManager(
      $_db,
      $_db.applicationTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_linkedApplicationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$ResumeTableTableFilterComposer
    extends Composer<_$AppDatabase, $ResumeTableTable> {
  $$ResumeTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get versionLabel => $composableBuilder(
    column: $table.versionLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tailoredForCompany => $composableBuilder(
    column: $table.tailoredForCompany,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get uploadedAt => $composableBuilder(
    column: $table.uploadedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  $$ApplicationTableTableFilterComposer get linkedApplicationId {
    final $$ApplicationTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedApplicationId,
      referencedTable: $db.applicationTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApplicationTableTableFilterComposer(
            $db: $db,
            $table: $db.applicationTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ResumeTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ResumeTableTable> {
  $$ResumeTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get versionLabel => $composableBuilder(
    column: $table.versionLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get filePath => $composableBuilder(
    column: $table.filePath,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fileSize => $composableBuilder(
    column: $table.fileSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tailoredForCompany => $composableBuilder(
    column: $table.tailoredForCompany,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get uploadedAt => $composableBuilder(
    column: $table.uploadedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  $$ApplicationTableTableOrderingComposer get linkedApplicationId {
    final $$ApplicationTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedApplicationId,
      referencedTable: $db.applicationTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApplicationTableTableOrderingComposer(
            $db: $db,
            $table: $db.applicationTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ResumeTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ResumeTableTable> {
  $$ResumeTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get versionLabel => $composableBuilder(
    column: $table.versionLabel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get filePath =>
      $composableBuilder(column: $table.filePath, builder: (column) => column);

  GeneratedColumn<int> get fileSize =>
      $composableBuilder(column: $table.fileSize, builder: (column) => column);

  GeneratedColumn<String> get tailoredForCompany => $composableBuilder(
    column: $table.tailoredForCompany,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get uploadedAt => $composableBuilder(
    column: $table.uploadedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  $$ApplicationTableTableAnnotationComposer get linkedApplicationId {
    final $$ApplicationTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedApplicationId,
      referencedTable: $db.applicationTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApplicationTableTableAnnotationComposer(
            $db: $db,
            $table: $db.applicationTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$ResumeTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ResumeTableTable,
          Resume,
          $$ResumeTableTableFilterComposer,
          $$ResumeTableTableOrderingComposer,
          $$ResumeTableTableAnnotationComposer,
          $$ResumeTableTableCreateCompanionBuilder,
          $$ResumeTableTableUpdateCompanionBuilder,
          (Resume, $$ResumeTableTableReferences),
          Resume,
          PrefetchHooks Function({bool linkedApplicationId})
        > {
  $$ResumeTableTableTableManager(_$AppDatabase db, $ResumeTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ResumeTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ResumeTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ResumeTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> versionLabel = const Value.absent(),
                Value<String> filePath = const Value.absent(),
                Value<int?> fileSize = const Value.absent(),
                Value<String?> tailoredForCompany = const Value.absent(),
                Value<int?> linkedApplicationId = const Value.absent(),
                Value<DateTime> uploadedAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => ResumeTableCompanion(
                id: id,
                versionLabel: versionLabel,
                filePath: filePath,
                fileSize: fileSize,
                tailoredForCompany: tailoredForCompany,
                linkedApplicationId: linkedApplicationId,
                uploadedAt: uploadedAt,
                notes: notes,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String versionLabel,
                required String filePath,
                Value<int?> fileSize = const Value.absent(),
                Value<String?> tailoredForCompany = const Value.absent(),
                Value<int?> linkedApplicationId = const Value.absent(),
                Value<DateTime> uploadedAt = const Value.absent(),
                Value<String?> notes = const Value.absent(),
              }) => ResumeTableCompanion.insert(
                id: id,
                versionLabel: versionLabel,
                filePath: filePath,
                fileSize: fileSize,
                tailoredForCompany: tailoredForCompany,
                linkedApplicationId: linkedApplicationId,
                uploadedAt: uploadedAt,
                notes: notes,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ResumeTableTable, Resume>(table),
                  $$ResumeTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({linkedApplicationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (linkedApplicationId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.linkedApplicationId,
                                referencedTable: $$ResumeTableTableReferences
                                    ._linkedApplicationIdTable(db),
                                referencedColumn: $$ResumeTableTableReferences
                                    ._linkedApplicationIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$ResumeTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ResumeTableTable,
      Resume,
      $$ResumeTableTableFilterComposer,
      $$ResumeTableTableOrderingComposer,
      $$ResumeTableTableAnnotationComposer,
      $$ResumeTableTableCreateCompanionBuilder,
      $$ResumeTableTableUpdateCompanionBuilder,
      (Resume, $$ResumeTableTableReferences),
      Resume,
      PrefetchHooks Function({bool linkedApplicationId})
    >;
typedef $$InterviewPrepTableTableCreateCompanionBuilder =
    InterviewPrepTableCompanion Function({
      Value<int> id,
      Value<String?> company,
      Value<String?> role,
      Value<int?> linkedApplicationId,
      required String questionAsked,
      Value<String?> answerNotes,
      Value<String?> outcome,
      Value<String?> category,
      Value<DateTime> preparedAt,
      Value<DateTime?> lastInteractedAt,
    });
typedef $$InterviewPrepTableTableUpdateCompanionBuilder =
    InterviewPrepTableCompanion Function({
      Value<int> id,
      Value<String?> company,
      Value<String?> role,
      Value<int?> linkedApplicationId,
      Value<String> questionAsked,
      Value<String?> answerNotes,
      Value<String?> outcome,
      Value<String?> category,
      Value<DateTime> preparedAt,
      Value<DateTime?> lastInteractedAt,
    });

final class $$InterviewPrepTableTableReferences
    extends
        BaseReferences<_$AppDatabase, $InterviewPrepTableTable, InterviewPrep> {
  $$InterviewPrepTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $ApplicationTableTable _linkedApplicationIdTable(_$AppDatabase db) =>
      db.applicationTable.createAlias(
        'interview_prep__linked_application_id__applications__id',
      );

  $$ApplicationTableTableProcessedTableManager? get linkedApplicationId {
    final $_column = $_itemColumn<int>('linked_application_id');
    if ($_column == null) return null;
    final manager = $$ApplicationTableTableTableManager(
      $_db,
      $_db.applicationTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_linkedApplicationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$InterviewPrepTableTableFilterComposer
    extends Composer<_$AppDatabase, $InterviewPrepTableTable> {
  $$InterviewPrepTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get company => $composableBuilder(
    column: $table.company,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get questionAsked => $composableBuilder(
    column: $table.questionAsked,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get answerNotes => $composableBuilder(
    column: $table.answerNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get preparedAt => $composableBuilder(
    column: $table.preparedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastInteractedAt => $composableBuilder(
    column: $table.lastInteractedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ApplicationTableTableFilterComposer get linkedApplicationId {
    final $$ApplicationTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedApplicationId,
      referencedTable: $db.applicationTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApplicationTableTableFilterComposer(
            $db: $db,
            $table: $db.applicationTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InterviewPrepTableTableOrderingComposer
    extends Composer<_$AppDatabase, $InterviewPrepTableTable> {
  $$InterviewPrepTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get company => $composableBuilder(
    column: $table.company,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get questionAsked => $composableBuilder(
    column: $table.questionAsked,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get answerNotes => $composableBuilder(
    column: $table.answerNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get preparedAt => $composableBuilder(
    column: $table.preparedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastInteractedAt => $composableBuilder(
    column: $table.lastInteractedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ApplicationTableTableOrderingComposer get linkedApplicationId {
    final $$ApplicationTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedApplicationId,
      referencedTable: $db.applicationTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApplicationTableTableOrderingComposer(
            $db: $db,
            $table: $db.applicationTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InterviewPrepTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $InterviewPrepTableTable> {
  $$InterviewPrepTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get company =>
      $composableBuilder(column: $table.company, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<String> get questionAsked => $composableBuilder(
    column: $table.questionAsked,
    builder: (column) => column,
  );

  GeneratedColumn<String> get answerNotes => $composableBuilder(
    column: $table.answerNotes,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<DateTime> get preparedAt => $composableBuilder(
    column: $table.preparedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastInteractedAt => $composableBuilder(
    column: $table.lastInteractedAt,
    builder: (column) => column,
  );

  $$ApplicationTableTableAnnotationComposer get linkedApplicationId {
    final $$ApplicationTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedApplicationId,
      referencedTable: $db.applicationTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApplicationTableTableAnnotationComposer(
            $db: $db,
            $table: $db.applicationTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$InterviewPrepTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InterviewPrepTableTable,
          InterviewPrep,
          $$InterviewPrepTableTableFilterComposer,
          $$InterviewPrepTableTableOrderingComposer,
          $$InterviewPrepTableTableAnnotationComposer,
          $$InterviewPrepTableTableCreateCompanionBuilder,
          $$InterviewPrepTableTableUpdateCompanionBuilder,
          (InterviewPrep, $$InterviewPrepTableTableReferences),
          InterviewPrep,
          PrefetchHooks Function({bool linkedApplicationId})
        > {
  $$InterviewPrepTableTableTableManager(
    _$AppDatabase db,
    $InterviewPrepTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InterviewPrepTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$InterviewPrepTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$InterviewPrepTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> company = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<int?> linkedApplicationId = const Value.absent(),
                Value<String> questionAsked = const Value.absent(),
                Value<String?> answerNotes = const Value.absent(),
                Value<String?> outcome = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<DateTime> preparedAt = const Value.absent(),
                Value<DateTime?> lastInteractedAt = const Value.absent(),
              }) => InterviewPrepTableCompanion(
                id: id,
                company: company,
                role: role,
                linkedApplicationId: linkedApplicationId,
                questionAsked: questionAsked,
                answerNotes: answerNotes,
                outcome: outcome,
                category: category,
                preparedAt: preparedAt,
                lastInteractedAt: lastInteractedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> company = const Value.absent(),
                Value<String?> role = const Value.absent(),
                Value<int?> linkedApplicationId = const Value.absent(),
                required String questionAsked,
                Value<String?> answerNotes = const Value.absent(),
                Value<String?> outcome = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<DateTime> preparedAt = const Value.absent(),
                Value<DateTime?> lastInteractedAt = const Value.absent(),
              }) => InterviewPrepTableCompanion.insert(
                id: id,
                company: company,
                role: role,
                linkedApplicationId: linkedApplicationId,
                questionAsked: questionAsked,
                answerNotes: answerNotes,
                outcome: outcome,
                category: category,
                preparedAt: preparedAt,
                lastInteractedAt: lastInteractedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InterviewPrepTableTable, InterviewPrep>(table),
                  $$InterviewPrepTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({linkedApplicationId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (linkedApplicationId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.linkedApplicationId,
                                referencedTable:
                                    $$InterviewPrepTableTableReferences
                                        ._linkedApplicationIdTable(db),
                                referencedColumn:
                                    $$InterviewPrepTableTableReferences
                                        ._linkedApplicationIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$InterviewPrepTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InterviewPrepTableTable,
      InterviewPrep,
      $$InterviewPrepTableTableFilterComposer,
      $$InterviewPrepTableTableOrderingComposer,
      $$InterviewPrepTableTableAnnotationComposer,
      $$InterviewPrepTableTableCreateCompanionBuilder,
      $$InterviewPrepTableTableUpdateCompanionBuilder,
      (InterviewPrep, $$InterviewPrepTableTableReferences),
      InterviewPrep,
      PrefetchHooks Function({bool linkedApplicationId})
    >;
typedef $$NoteTableTableCreateCompanionBuilder =
    NoteTableCompanion Function({
      Value<int> id,
      Value<String?> title,
      required String content,
      Value<String?> linkedCompany,
      Value<String?> linkedTopic,
      Value<int?> linkedApplicationId,
      Value<int?> linkedPhaseId,
      Value<DateTime?> lastInteractedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$NoteTableTableUpdateCompanionBuilder =
    NoteTableCompanion Function({
      Value<int> id,
      Value<String?> title,
      Value<String> content,
      Value<String?> linkedCompany,
      Value<String?> linkedTopic,
      Value<int?> linkedApplicationId,
      Value<int?> linkedPhaseId,
      Value<DateTime?> lastInteractedAt,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$NoteTableTableReferences
    extends BaseReferences<_$AppDatabase, $NoteTableTable, Note> {
  $$NoteTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ApplicationTableTable _linkedApplicationIdTable(_$AppDatabase db) =>
      db.applicationTable.createAlias(
        'notes__linked_application_id__applications__id',
      );

  $$ApplicationTableTableProcessedTableManager? get linkedApplicationId {
    final $_column = $_itemColumn<int>('linked_application_id');
    if ($_column == null) return null;
    final manager = $$ApplicationTableTableTableManager(
      $_db,
      $_db.applicationTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_linkedApplicationIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $StudyPhaseTableTable _linkedPhaseIdTable(_$AppDatabase db) => db
      .studyPhaseTable
      .createAlias('notes__linked_phase_id__study_phases__id');

  $$StudyPhaseTableTableProcessedTableManager? get linkedPhaseId {
    final $_column = $_itemColumn<int>('linked_phase_id');
    if ($_column == null) return null;
    final manager = $$StudyPhaseTableTableTableManager(
      $_db,
      $_db.studyPhaseTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_linkedPhaseIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$NoteTagTableTable, List<NoteTag>>
  _noteTagTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.noteTagTable,
    aliasName: 'notes__id__note_tags__note_id',
  );

  $$NoteTagTableTableProcessedTableManager get noteTagTableRefs {
    final manager = $$NoteTagTableTableTableManager(
      $_db,
      $_db.noteTagTable,
    ).filter((f) => f.noteId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_noteTagTableRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$NoteTableTableFilterComposer
    extends Composer<_$AppDatabase, $NoteTableTable> {
  $$NoteTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedCompany => $composableBuilder(
    column: $table.linkedCompany,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get linkedTopic => $composableBuilder(
    column: $table.linkedTopic,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastInteractedAt => $composableBuilder(
    column: $table.lastInteractedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$ApplicationTableTableFilterComposer get linkedApplicationId {
    final $$ApplicationTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedApplicationId,
      referencedTable: $db.applicationTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApplicationTableTableFilterComposer(
            $db: $db,
            $table: $db.applicationTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StudyPhaseTableTableFilterComposer get linkedPhaseId {
    final $$StudyPhaseTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedPhaseId,
      referencedTable: $db.studyPhaseTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudyPhaseTableTableFilterComposer(
            $db: $db,
            $table: $db.studyPhaseTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> noteTagTableRefs(
    Expression<bool> Function($$NoteTagTableTableFilterComposer f) f,
  ) {
    final $$NoteTagTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTagTable,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTagTableTableFilterComposer(
            $db: $db,
            $table: $db.noteTagTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NoteTableTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteTableTable> {
  $$NoteTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get content => $composableBuilder(
    column: $table.content,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedCompany => $composableBuilder(
    column: $table.linkedCompany,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get linkedTopic => $composableBuilder(
    column: $table.linkedTopic,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastInteractedAt => $composableBuilder(
    column: $table.lastInteractedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$ApplicationTableTableOrderingComposer get linkedApplicationId {
    final $$ApplicationTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedApplicationId,
      referencedTable: $db.applicationTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApplicationTableTableOrderingComposer(
            $db: $db,
            $table: $db.applicationTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StudyPhaseTableTableOrderingComposer get linkedPhaseId {
    final $$StudyPhaseTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedPhaseId,
      referencedTable: $db.studyPhaseTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudyPhaseTableTableOrderingComposer(
            $db: $db,
            $table: $db.studyPhaseTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteTableTable> {
  $$NoteTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get content =>
      $composableBuilder(column: $table.content, builder: (column) => column);

  GeneratedColumn<String> get linkedCompany => $composableBuilder(
    column: $table.linkedCompany,
    builder: (column) => column,
  );

  GeneratedColumn<String> get linkedTopic => $composableBuilder(
    column: $table.linkedTopic,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastInteractedAt => $composableBuilder(
    column: $table.lastInteractedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ApplicationTableTableAnnotationComposer get linkedApplicationId {
    final $$ApplicationTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedApplicationId,
      referencedTable: $db.applicationTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$ApplicationTableTableAnnotationComposer(
            $db: $db,
            $table: $db.applicationTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$StudyPhaseTableTableAnnotationComposer get linkedPhaseId {
    final $$StudyPhaseTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedPhaseId,
      referencedTable: $db.studyPhaseTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$StudyPhaseTableTableAnnotationComposer(
            $db: $db,
            $table: $db.studyPhaseTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> noteTagTableRefs<T extends Object>(
    Expression<T> Function($$NoteTagTableTableAnnotationComposer a) f,
  ) {
    final $$NoteTagTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.noteTagTable,
      getReferencedColumn: (t) => t.noteId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTagTableTableAnnotationComposer(
            $db: $db,
            $table: $db.noteTagTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$NoteTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NoteTableTable,
          Note,
          $$NoteTableTableFilterComposer,
          $$NoteTableTableOrderingComposer,
          $$NoteTableTableAnnotationComposer,
          $$NoteTableTableCreateCompanionBuilder,
          $$NoteTableTableUpdateCompanionBuilder,
          (Note, $$NoteTableTableReferences),
          Note,
          PrefetchHooks Function({
            bool linkedApplicationId,
            bool linkedPhaseId,
            bool noteTagTableRefs,
          })
        > {
  $$NoteTableTableTableManager(_$AppDatabase db, $NoteTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> title = const Value.absent(),
                Value<String> content = const Value.absent(),
                Value<String?> linkedCompany = const Value.absent(),
                Value<String?> linkedTopic = const Value.absent(),
                Value<int?> linkedApplicationId = const Value.absent(),
                Value<int?> linkedPhaseId = const Value.absent(),
                Value<DateTime?> lastInteractedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => NoteTableCompanion(
                id: id,
                title: title,
                content: content,
                linkedCompany: linkedCompany,
                linkedTopic: linkedTopic,
                linkedApplicationId: linkedApplicationId,
                linkedPhaseId: linkedPhaseId,
                lastInteractedAt: lastInteractedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String?> title = const Value.absent(),
                required String content,
                Value<String?> linkedCompany = const Value.absent(),
                Value<String?> linkedTopic = const Value.absent(),
                Value<int?> linkedApplicationId = const Value.absent(),
                Value<int?> linkedPhaseId = const Value.absent(),
                Value<DateTime?> lastInteractedAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => NoteTableCompanion.insert(
                id: id,
                title: title,
                content: content,
                linkedCompany: linkedCompany,
                linkedTopic: linkedTopic,
                linkedApplicationId: linkedApplicationId,
                linkedPhaseId: linkedPhaseId,
                lastInteractedAt: lastInteractedAt,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NoteTableTable, Note>(table),
                  $$NoteTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                linkedApplicationId = false,
                linkedPhaseId = false,
                noteTagTableRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (noteTagTableRefs) db.noteTagTable,
                  ],
                  addJoins:
                      <
                        T extends TableManagerState<
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic,
                          dynamic
                        >
                      >(state) {
                        if (linkedApplicationId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.linkedApplicationId,
                                    referencedTable: $$NoteTableTableReferences
                                        ._linkedApplicationIdTable(db),
                                    referencedColumn: $$NoteTableTableReferences
                                        ._linkedApplicationIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }
                        if (linkedPhaseId) {
                          state =
                              state.withJoin(
                                    currentTable: table,
                                    currentColumn: table.linkedPhaseId,
                                    referencedTable: $$NoteTableTableReferences
                                        ._linkedPhaseIdTable(db),
                                    referencedColumn: $$NoteTableTableReferences
                                        ._linkedPhaseIdTable(db)
                                        .id,
                                  )
                                  as T;
                        }

                        return state;
                      },
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (noteTagTableRefs)
                        await $_getPrefetchedData<
                          Note,
                          $NoteTableTable,
                          NoteTag
                        >(
                          currentTable: table,
                          referencedTable: $$NoteTableTableReferences
                              ._noteTagTableRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$NoteTableTableReferences(
                                db,
                                table,
                                p0,
                              ).noteTagTableRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.noteId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$NoteTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NoteTableTable,
      Note,
      $$NoteTableTableFilterComposer,
      $$NoteTableTableOrderingComposer,
      $$NoteTableTableAnnotationComposer,
      $$NoteTableTableCreateCompanionBuilder,
      $$NoteTableTableUpdateCompanionBuilder,
      (Note, $$NoteTableTableReferences),
      Note,
      PrefetchHooks Function({
        bool linkedApplicationId,
        bool linkedPhaseId,
        bool noteTagTableRefs,
      })
    >;
typedef $$NoteTagTableTableCreateCompanionBuilder =
    NoteTagTableCompanion Function({
      Value<int> id,
      required int noteId,
      required String tag,
    });
typedef $$NoteTagTableTableUpdateCompanionBuilder =
    NoteTagTableCompanion Function({
      Value<int> id,
      Value<int> noteId,
      Value<String> tag,
    });

final class $$NoteTagTableTableReferences
    extends BaseReferences<_$AppDatabase, $NoteTagTableTable, NoteTag> {
  $$NoteTagTableTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $NoteTableTable _noteIdTable(_$AppDatabase db) =>
      db.noteTable.createAlias('note_tags__note_id__notes__id');

  $$NoteTableTableProcessedTableManager get noteId {
    final $_column = $_itemColumn<int>('note_id')!;

    final manager = $$NoteTableTableTableManager(
      $_db,
      $_db.noteTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_noteIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$NoteTagTableTableFilterComposer
    extends Composer<_$AppDatabase, $NoteTagTableTable> {
  $$NoteTagTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnFilters(column),
  );

  $$NoteTableTableFilterComposer get noteId {
    final $$NoteTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.noteTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTableTableFilterComposer(
            $db: $db,
            $table: $db.noteTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteTagTableTableOrderingComposer
    extends Composer<_$AppDatabase, $NoteTagTableTable> {
  $$NoteTagTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get tag => $composableBuilder(
    column: $table.tag,
    builder: (column) => ColumnOrderings(column),
  );

  $$NoteTableTableOrderingComposer get noteId {
    final $$NoteTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.noteTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTableTableOrderingComposer(
            $db: $db,
            $table: $db.noteTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteTagTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $NoteTagTableTable> {
  $$NoteTagTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get tag =>
      $composableBuilder(column: $table.tag, builder: (column) => column);

  $$NoteTableTableAnnotationComposer get noteId {
    final $$NoteTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.noteId,
      referencedTable: $db.noteTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$NoteTableTableAnnotationComposer(
            $db: $db,
            $table: $db.noteTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$NoteTagTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NoteTagTableTable,
          NoteTag,
          $$NoteTagTableTableFilterComposer,
          $$NoteTagTableTableOrderingComposer,
          $$NoteTagTableTableAnnotationComposer,
          $$NoteTagTableTableCreateCompanionBuilder,
          $$NoteTagTableTableUpdateCompanionBuilder,
          (NoteTag, $$NoteTagTableTableReferences),
          NoteTag,
          PrefetchHooks Function({bool noteId})
        > {
  $$NoteTagTableTableTableManager(_$AppDatabase db, $NoteTagTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NoteTagTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$NoteTagTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$NoteTagTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> noteId = const Value.absent(),
                Value<String> tag = const Value.absent(),
              }) => NoteTagTableCompanion(id: id, noteId: noteId, tag: tag),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int noteId,
                required String tag,
              }) => NoteTagTableCompanion.insert(
                id: id,
                noteId: noteId,
                tag: tag,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$NoteTagTableTable, NoteTag>(table),
                  $$NoteTagTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({noteId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (noteId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.noteId,
                                referencedTable: $$NoteTagTableTableReferences
                                    ._noteIdTable(db),
                                referencedColumn: $$NoteTagTableTableReferences
                                    ._noteIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$NoteTagTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NoteTagTableTable,
      NoteTag,
      $$NoteTagTableTableFilterComposer,
      $$NoteTagTableTableOrderingComposer,
      $$NoteTagTableTableAnnotationComposer,
      $$NoteTagTableTableCreateCompanionBuilder,
      $$NoteTagTableTableUpdateCompanionBuilder,
      (NoteTag, $$NoteTagTableTableReferences),
      NoteTag,
      PrefetchHooks Function({bool noteId})
    >;
typedef $$InsightDismissalTableTableCreateCompanionBuilder =
    InsightDismissalTableCompanion Function({
      Value<int> id,
      required String insightType,
      Value<DateTime> dismissedAt,
      Value<DateTime?> snoozedUntil,
      Value<int> dismissalCount,
    });
typedef $$InsightDismissalTableTableUpdateCompanionBuilder =
    InsightDismissalTableCompanion Function({
      Value<int> id,
      Value<String> insightType,
      Value<DateTime> dismissedAt,
      Value<DateTime?> snoozedUntil,
      Value<int> dismissalCount,
    });

class $$InsightDismissalTableTableFilterComposer
    extends Composer<_$AppDatabase, $InsightDismissalTableTable> {
  $$InsightDismissalTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get insightType => $composableBuilder(
    column: $table.insightType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get dismissalCount => $composableBuilder(
    column: $table.dismissalCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$InsightDismissalTableTableOrderingComposer
    extends Composer<_$AppDatabase, $InsightDismissalTableTable> {
  $$InsightDismissalTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get insightType => $composableBuilder(
    column: $table.insightType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get dismissalCount => $composableBuilder(
    column: $table.dismissalCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$InsightDismissalTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $InsightDismissalTableTable> {
  $$InsightDismissalTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get insightType => $composableBuilder(
    column: $table.insightType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get dismissedAt => $composableBuilder(
    column: $table.dismissedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get snoozedUntil => $composableBuilder(
    column: $table.snoozedUntil,
    builder: (column) => column,
  );

  GeneratedColumn<int> get dismissalCount => $composableBuilder(
    column: $table.dismissalCount,
    builder: (column) => column,
  );
}

class $$InsightDismissalTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $InsightDismissalTableTable,
          InsightDismissal,
          $$InsightDismissalTableTableFilterComposer,
          $$InsightDismissalTableTableOrderingComposer,
          $$InsightDismissalTableTableAnnotationComposer,
          $$InsightDismissalTableTableCreateCompanionBuilder,
          $$InsightDismissalTableTableUpdateCompanionBuilder,
          (
            InsightDismissal,
            BaseReferences<
              _$AppDatabase,
              $InsightDismissalTableTable,
              InsightDismissal
            >,
          ),
          InsightDismissal,
          PrefetchHooks Function()
        > {
  $$InsightDismissalTableTableTableManager(
    _$AppDatabase db,
    $InsightDismissalTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$InsightDismissalTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$InsightDismissalTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$InsightDismissalTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> insightType = const Value.absent(),
                Value<DateTime> dismissedAt = const Value.absent(),
                Value<DateTime?> snoozedUntil = const Value.absent(),
                Value<int> dismissalCount = const Value.absent(),
              }) => InsightDismissalTableCompanion(
                id: id,
                insightType: insightType,
                dismissedAt: dismissedAt,
                snoozedUntil: snoozedUntil,
                dismissalCount: dismissalCount,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String insightType,
                Value<DateTime> dismissedAt = const Value.absent(),
                Value<DateTime?> snoozedUntil = const Value.absent(),
                Value<int> dismissalCount = const Value.absent(),
              }) => InsightDismissalTableCompanion.insert(
                id: id,
                insightType: insightType,
                dismissedAt: dismissedAt,
                snoozedUntil: snoozedUntil,
                dismissalCount: dismissalCount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$InsightDismissalTableTable, InsightDismissal>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $InsightDismissalTableTable,
                    InsightDismissal
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$InsightDismissalTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $InsightDismissalTableTable,
      InsightDismissal,
      $$InsightDismissalTableTableFilterComposer,
      $$InsightDismissalTableTableOrderingComposer,
      $$InsightDismissalTableTableAnnotationComposer,
      $$InsightDismissalTableTableCreateCompanionBuilder,
      $$InsightDismissalTableTableUpdateCompanionBuilder,
      (
        InsightDismissal,
        BaseReferences<
          _$AppDatabase,
          $InsightDismissalTableTable,
          InsightDismissal
        >,
      ),
      InsightDismissal,
      PrefetchHooks Function()
    >;
typedef $$SessionCategoryTableTableCreateCompanionBuilder =
    SessionCategoryTableCompanion Function({
      Value<int> id,
      required String name,
      required String colorHex,
      Value<bool> isBuiltIn,
    });
typedef $$SessionCategoryTableTableUpdateCompanionBuilder =
    SessionCategoryTableCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String> colorHex,
      Value<bool> isBuiltIn,
    });

final class $$SessionCategoryTableTableReferences
    extends
        BaseReferences<
          _$AppDatabase,
          $SessionCategoryTableTable,
          SessionCategory
        > {
  $$SessionCategoryTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static MultiTypedResultKey<$TimeSessionTableTable, List<TimeSession>>
  _timeSessionTableRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.timeSessionTable,
    aliasName: 'session_categories__id__time_sessions__category_id',
  );

  $$TimeSessionTableTableProcessedTableManager get timeSessionTableRefs {
    final manager = $$TimeSessionTableTableTableManager(
      $_db,
      $_db.timeSessionTable,
    ).filter((f) => f.categoryId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(
      _timeSessionTableRefsTable($_db),
    );
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$SessionCategoryTableTableFilterComposer
    extends Composer<_$AppDatabase, $SessionCategoryTableTable> {
  $$SessionCategoryTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> timeSessionTableRefs(
    Expression<bool> Function($$TimeSessionTableTableFilterComposer f) f,
  ) {
    final $$TimeSessionTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timeSessionTable,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimeSessionTableTableFilterComposer(
            $db: $db,
            $table: $db.timeSessionTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionCategoryTableTableOrderingComposer
    extends Composer<_$AppDatabase, $SessionCategoryTableTable> {
  $$SessionCategoryTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get colorHex => $composableBuilder(
    column: $table.colorHex,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isBuiltIn => $composableBuilder(
    column: $table.isBuiltIn,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SessionCategoryTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $SessionCategoryTableTable> {
  $$SessionCategoryTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get colorHex =>
      $composableBuilder(column: $table.colorHex, builder: (column) => column);

  GeneratedColumn<bool> get isBuiltIn =>
      $composableBuilder(column: $table.isBuiltIn, builder: (column) => column);

  Expression<T> timeSessionTableRefs<T extends Object>(
    Expression<T> Function($$TimeSessionTableTableAnnotationComposer a) f,
  ) {
    final $$TimeSessionTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.timeSessionTable,
      getReferencedColumn: (t) => t.categoryId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TimeSessionTableTableAnnotationComposer(
            $db: $db,
            $table: $db.timeSessionTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$SessionCategoryTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SessionCategoryTableTable,
          SessionCategory,
          $$SessionCategoryTableTableFilterComposer,
          $$SessionCategoryTableTableOrderingComposer,
          $$SessionCategoryTableTableAnnotationComposer,
          $$SessionCategoryTableTableCreateCompanionBuilder,
          $$SessionCategoryTableTableUpdateCompanionBuilder,
          (SessionCategory, $$SessionCategoryTableTableReferences),
          SessionCategory,
          PrefetchHooks Function({bool timeSessionTableRefs})
        > {
  $$SessionCategoryTableTableTableManager(
    _$AppDatabase db,
    $SessionCategoryTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SessionCategoryTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SessionCategoryTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SessionCategoryTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> colorHex = const Value.absent(),
                Value<bool> isBuiltIn = const Value.absent(),
              }) => SessionCategoryTableCompanion(
                id: id,
                name: name,
                colorHex: colorHex,
                isBuiltIn: isBuiltIn,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                required String colorHex,
                Value<bool> isBuiltIn = const Value.absent(),
              }) => SessionCategoryTableCompanion.insert(
                id: id,
                name: name,
                colorHex: colorHex,
                isBuiltIn: isBuiltIn,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$SessionCategoryTableTable, SessionCategory>(
                    table,
                  ),
                  $$SessionCategoryTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({timeSessionTableRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (timeSessionTableRefs) db.timeSessionTable,
              ],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (timeSessionTableRefs)
                    await $_getPrefetchedData<
                      SessionCategory,
                      $SessionCategoryTableTable,
                      TimeSession
                    >(
                      currentTable: table,
                      referencedTable: $$SessionCategoryTableTableReferences
                          ._timeSessionTableRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$SessionCategoryTableTableReferences(
                            db,
                            table,
                            p0,
                          ).timeSessionTableRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.categoryId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$SessionCategoryTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SessionCategoryTableTable,
      SessionCategory,
      $$SessionCategoryTableTableFilterComposer,
      $$SessionCategoryTableTableOrderingComposer,
      $$SessionCategoryTableTableAnnotationComposer,
      $$SessionCategoryTableTableCreateCompanionBuilder,
      $$SessionCategoryTableTableUpdateCompanionBuilder,
      (SessionCategory, $$SessionCategoryTableTableReferences),
      SessionCategory,
      PrefetchHooks Function({bool timeSessionTableRefs})
    >;
typedef $$TimeSessionTableTableCreateCompanionBuilder =
    TimeSessionTableCompanion Function({
      Value<int> id,
      required String label,
      Value<String> activityType,
      required int categoryId,
      Value<int?> linkedTaskId,
      required DateTime startedAt,
      Value<DateTime?> endedAt,
      Value<String> pausedIntervals,
      Value<String> status,
      Value<int> durationSeconds,
      Value<String> activityRefType,
      Value<DateTime?> lastHeartbeatAt,
      Value<DateTime> createdAt,
    });
typedef $$TimeSessionTableTableUpdateCompanionBuilder =
    TimeSessionTableCompanion Function({
      Value<int> id,
      Value<String> label,
      Value<String> activityType,
      Value<int> categoryId,
      Value<int?> linkedTaskId,
      Value<DateTime> startedAt,
      Value<DateTime?> endedAt,
      Value<String> pausedIntervals,
      Value<String> status,
      Value<int> durationSeconds,
      Value<String> activityRefType,
      Value<DateTime?> lastHeartbeatAt,
      Value<DateTime> createdAt,
    });

final class $$TimeSessionTableTableReferences
    extends BaseReferences<_$AppDatabase, $TimeSessionTableTable, TimeSession> {
  $$TimeSessionTableTableReferences(
    super.$_db,
    super.$_table,
    super.$_typedResult,
  );

  static $SessionCategoryTableTable _categoryIdTable(_$AppDatabase db) => db
      .sessionCategoryTable
      .createAlias('time_sessions__category_id__session_categories__id');

  $$SessionCategoryTableTableProcessedTableManager get categoryId {
    final $_column = $_itemColumn<int>('category_id')!;

    final manager = $$SessionCategoryTableTableTableManager(
      $_db,
      $_db.sessionCategoryTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_categoryIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $TaskTableTable _linkedTaskIdTable(_$AppDatabase db) =>
      db.taskTable.createAlias('time_sessions__linked_task_id__tasks__id');

  $$TaskTableTableProcessedTableManager? get linkedTaskId {
    final $_column = $_itemColumn<int>('linked_task_id');
    if ($_column == null) return null;
    final manager = $$TaskTableTableTableManager(
      $_db,
      $_db.taskTable,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_linkedTaskIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TimeSessionTableTableFilterComposer
    extends Composer<_$AppDatabase, $TimeSessionTableTable> {
  $$TimeSessionTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get pausedIntervals => $composableBuilder(
    column: $table.pausedIntervals,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityRefType => $composableBuilder(
    column: $table.activityRefType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get lastHeartbeatAt => $composableBuilder(
    column: $table.lastHeartbeatAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$SessionCategoryTableTableFilterComposer get categoryId {
    final $$SessionCategoryTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.categoryId,
      referencedTable: $db.sessionCategoryTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$SessionCategoryTableTableFilterComposer(
            $db: $db,
            $table: $db.sessionCategoryTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$TaskTableTableFilterComposer get linkedTaskId {
    final $$TaskTableTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedTaskId,
      referencedTable: $db.taskTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTableTableFilterComposer(
            $db: $db,
            $table: $db.taskTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimeSessionTableTableOrderingComposer
    extends Composer<_$AppDatabase, $TimeSessionTableTable> {
  $$TimeSessionTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get label => $composableBuilder(
    column: $table.label,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get endedAt => $composableBuilder(
    column: $table.endedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get pausedIntervals => $composableBuilder(
    column: $table.pausedIntervals,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityRefType => $composableBuilder(
    column: $table.activityRefType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get lastHeartbeatAt => $composableBuilder(
    column: $table.lastHeartbeatAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$SessionCategoryTableTableOrderingComposer get categoryId {
    final $$SessionCategoryTableTableOrderingComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.categoryId,
          referencedTable: $db.sessionCategoryTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SessionCategoryTableTableOrderingComposer(
                $db: $db,
                $table: $db.sessionCategoryTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$TaskTableTableOrderingComposer get linkedTaskId {
    final $$TaskTableTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedTaskId,
      referencedTable: $db.taskTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTableTableOrderingComposer(
            $db: $db,
            $table: $db.taskTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimeSessionTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $TimeSessionTableTable> {
  $$TimeSessionTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get label =>
      $composableBuilder(column: $table.label, builder: (column) => column);

  GeneratedColumn<String> get activityType => $composableBuilder(
    column: $table.activityType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get endedAt =>
      $composableBuilder(column: $table.endedAt, builder: (column) => column);

  GeneratedColumn<String> get pausedIntervals => $composableBuilder(
    column: $table.pausedIntervals,
    builder: (column) => column,
  );

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get durationSeconds => $composableBuilder(
    column: $table.durationSeconds,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activityRefType => $composableBuilder(
    column: $table.activityRefType,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get lastHeartbeatAt => $composableBuilder(
    column: $table.lastHeartbeatAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$SessionCategoryTableTableAnnotationComposer get categoryId {
    final $$SessionCategoryTableTableAnnotationComposer composer =
        $composerBuilder(
          composer: this,
          getCurrentColumn: (t) => t.categoryId,
          referencedTable: $db.sessionCategoryTable,
          getReferencedColumn: (t) => t.id,
          builder:
              (
                joinBuilder, {
                $addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer,
              }) => $$SessionCategoryTableTableAnnotationComposer(
                $db: $db,
                $table: $db.sessionCategoryTable,
                $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
                joinBuilder: joinBuilder,
                $removeJoinBuilderFromRootComposer:
                    $removeJoinBuilderFromRootComposer,
              ),
        );
    return composer;
  }

  $$TaskTableTableAnnotationComposer get linkedTaskId {
    final $$TaskTableTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.linkedTaskId,
      referencedTable: $db.taskTable,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TaskTableTableAnnotationComposer(
            $db: $db,
            $table: $db.taskTable,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TimeSessionTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TimeSessionTableTable,
          TimeSession,
          $$TimeSessionTableTableFilterComposer,
          $$TimeSessionTableTableOrderingComposer,
          $$TimeSessionTableTableAnnotationComposer,
          $$TimeSessionTableTableCreateCompanionBuilder,
          $$TimeSessionTableTableUpdateCompanionBuilder,
          (TimeSession, $$TimeSessionTableTableReferences),
          TimeSession,
          PrefetchHooks Function({bool categoryId, bool linkedTaskId})
        > {
  $$TimeSessionTableTableTableManager(
    _$AppDatabase db,
    $TimeSessionTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TimeSessionTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TimeSessionTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TimeSessionTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> label = const Value.absent(),
                Value<String> activityType = const Value.absent(),
                Value<int> categoryId = const Value.absent(),
                Value<int?> linkedTaskId = const Value.absent(),
                Value<DateTime> startedAt = const Value.absent(),
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String> pausedIntervals = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<String> activityRefType = const Value.absent(),
                Value<DateTime?> lastHeartbeatAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TimeSessionTableCompanion(
                id: id,
                label: label,
                activityType: activityType,
                categoryId: categoryId,
                linkedTaskId: linkedTaskId,
                startedAt: startedAt,
                endedAt: endedAt,
                pausedIntervals: pausedIntervals,
                status: status,
                durationSeconds: durationSeconds,
                activityRefType: activityRefType,
                lastHeartbeatAt: lastHeartbeatAt,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String label,
                Value<String> activityType = const Value.absent(),
                required int categoryId,
                Value<int?> linkedTaskId = const Value.absent(),
                required DateTime startedAt,
                Value<DateTime?> endedAt = const Value.absent(),
                Value<String> pausedIntervals = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<int> durationSeconds = const Value.absent(),
                Value<String> activityRefType = const Value.absent(),
                Value<DateTime?> lastHeartbeatAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => TimeSessionTableCompanion.insert(
                id: id,
                label: label,
                activityType: activityType,
                categoryId: categoryId,
                linkedTaskId: linkedTaskId,
                startedAt: startedAt,
                endedAt: endedAt,
                pausedIntervals: pausedIntervals,
                status: status,
                durationSeconds: durationSeconds,
                activityRefType: activityRefType,
                lastHeartbeatAt: lastHeartbeatAt,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$TimeSessionTableTable, TimeSession>(table),
                  $$TimeSessionTableTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({categoryId = false, linkedTaskId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (categoryId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.categoryId,
                                referencedTable:
                                    $$TimeSessionTableTableReferences
                                        ._categoryIdTable(db),
                                referencedColumn:
                                    $$TimeSessionTableTableReferences
                                        ._categoryIdTable(db)
                                        .id,
                              )
                              as T;
                    }
                    if (linkedTaskId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.linkedTaskId,
                                referencedTable:
                                    $$TimeSessionTableTableReferences
                                        ._linkedTaskIdTable(db),
                                referencedColumn:
                                    $$TimeSessionTableTableReferences
                                        ._linkedTaskIdTable(db)
                                        .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TimeSessionTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TimeSessionTableTable,
      TimeSession,
      $$TimeSessionTableTableFilterComposer,
      $$TimeSessionTableTableOrderingComposer,
      $$TimeSessionTableTableAnnotationComposer,
      $$TimeSessionTableTableCreateCompanionBuilder,
      $$TimeSessionTableTableUpdateCompanionBuilder,
      (TimeSession, $$TimeSessionTableTableReferences),
      TimeSession,
      PrefetchHooks Function({bool categoryId, bool linkedTaskId})
    >;
typedef $$UpcomingInterviewTableTableCreateCompanionBuilder =
    UpcomingInterviewTableCompanion Function({
      Value<int> id,
      required String companyName,
      required DateTime interviewDate,
      Value<String?> notes,
      Value<DateTime> createdAt,
    });
typedef $$UpcomingInterviewTableTableUpdateCompanionBuilder =
    UpcomingInterviewTableCompanion Function({
      Value<int> id,
      Value<String> companyName,
      Value<DateTime> interviewDate,
      Value<String?> notes,
      Value<DateTime> createdAt,
    });

class $$UpcomingInterviewTableTableFilterComposer
    extends Composer<_$AppDatabase, $UpcomingInterviewTableTable> {
  $$UpcomingInterviewTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get interviewDate => $composableBuilder(
    column: $table.interviewDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$UpcomingInterviewTableTableOrderingComposer
    extends Composer<_$AppDatabase, $UpcomingInterviewTableTable> {
  $$UpcomingInterviewTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get interviewDate => $composableBuilder(
    column: $table.interviewDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UpcomingInterviewTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $UpcomingInterviewTableTable> {
  $$UpcomingInterviewTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get companyName => $composableBuilder(
    column: $table.companyName,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get interviewDate => $composableBuilder(
    column: $table.interviewDate,
    builder: (column) => column,
  );

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$UpcomingInterviewTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UpcomingInterviewTableTable,
          UpcomingInterview,
          $$UpcomingInterviewTableTableFilterComposer,
          $$UpcomingInterviewTableTableOrderingComposer,
          $$UpcomingInterviewTableTableAnnotationComposer,
          $$UpcomingInterviewTableTableCreateCompanionBuilder,
          $$UpcomingInterviewTableTableUpdateCompanionBuilder,
          (
            UpcomingInterview,
            BaseReferences<
              _$AppDatabase,
              $UpcomingInterviewTableTable,
              UpcomingInterview
            >,
          ),
          UpcomingInterview,
          PrefetchHooks Function()
        > {
  $$UpcomingInterviewTableTableTableManager(
    _$AppDatabase db,
    $UpcomingInterviewTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UpcomingInterviewTableTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$UpcomingInterviewTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$UpcomingInterviewTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> companyName = const Value.absent(),
                Value<DateTime> interviewDate = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => UpcomingInterviewTableCompanion(
                id: id,
                companyName: companyName,
                interviewDate: interviewDate,
                notes: notes,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String companyName,
                required DateTime interviewDate,
                Value<String?> notes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => UpcomingInterviewTableCompanion.insert(
                id: id,
                companyName: companyName,
                interviewDate: interviewDate,
                notes: notes,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$UpcomingInterviewTableTable, UpcomingInterview>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $UpcomingInterviewTableTable,
                    UpcomingInterview
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$UpcomingInterviewTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UpcomingInterviewTableTable,
      UpcomingInterview,
      $$UpcomingInterviewTableTableFilterComposer,
      $$UpcomingInterviewTableTableOrderingComposer,
      $$UpcomingInterviewTableTableAnnotationComposer,
      $$UpcomingInterviewTableTableCreateCompanionBuilder,
      $$UpcomingInterviewTableTableUpdateCompanionBuilder,
      (
        UpcomingInterview,
        BaseReferences<
          _$AppDatabase,
          $UpcomingInterviewTableTable,
          UpcomingInterview
        >,
      ),
      UpcomingInterview,
      PrefetchHooks Function()
    >;
typedef $$ReminderTableTableCreateCompanionBuilder =
    ReminderTableCompanion Function({
      Value<int> id,
      required String title,
      required DateTime scheduledAt,
      Value<bool> isActive,
      Value<DateTime> createdAt,
    });
typedef $$ReminderTableTableUpdateCompanionBuilder =
    ReminderTableCompanion Function({
      Value<int> id,
      Value<String> title,
      Value<DateTime> scheduledAt,
      Value<bool> isActive,
      Value<DateTime> createdAt,
    });

class $$ReminderTableTableFilterComposer
    extends Composer<_$AppDatabase, $ReminderTableTable> {
  $$ReminderTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get scheduledAt => $composableBuilder(
    column: $table.scheduledAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ReminderTableTableOrderingComposer
    extends Composer<_$AppDatabase, $ReminderTableTable> {
  $$ReminderTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get scheduledAt => $composableBuilder(
    column: $table.scheduledAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isActive => $composableBuilder(
    column: $table.isActive,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ReminderTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $ReminderTableTable> {
  $$ReminderTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledAt => $composableBuilder(
    column: $table.scheduledAt,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isActive =>
      $composableBuilder(column: $table.isActive, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$ReminderTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ReminderTableTable,
          Reminder,
          $$ReminderTableTableFilterComposer,
          $$ReminderTableTableOrderingComposer,
          $$ReminderTableTableAnnotationComposer,
          $$ReminderTableTableCreateCompanionBuilder,
          $$ReminderTableTableUpdateCompanionBuilder,
          (
            Reminder,
            BaseReferences<_$AppDatabase, $ReminderTableTable, Reminder>,
          ),
          Reminder,
          PrefetchHooks Function()
        > {
  $$ReminderTableTableTableManager(_$AppDatabase db, $ReminderTableTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ReminderTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ReminderTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ReminderTableTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<DateTime> scheduledAt = const Value.absent(),
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ReminderTableCompanion(
                id: id,
                title: title,
                scheduledAt: scheduledAt,
                isActive: isActive,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String title,
                required DateTime scheduledAt,
                Value<bool> isActive = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => ReminderTableCompanion.insert(
                id: id,
                title: title,
                scheduledAt: scheduledAt,
                isActive: isActive,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$ReminderTableTable, Reminder>(table),
                  BaseReferences<_$AppDatabase, $ReminderTableTable, Reminder>(
                    db,
                    table,
                    e,
                  ),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ReminderTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ReminderTableTable,
      Reminder,
      $$ReminderTableTableFilterComposer,
      $$ReminderTableTableOrderingComposer,
      $$ReminderTableTableAnnotationComposer,
      $$ReminderTableTableCreateCompanionBuilder,
      $$ReminderTableTableUpdateCompanionBuilder,
      (Reminder, BaseReferences<_$AppDatabase, $ReminderTableTable, Reminder>),
      Reminder,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$UserProfileTableTableTableManager get userProfileTable =>
      $$UserProfileTableTableTableManager(_db, _db.userProfileTable);
  $$StudyPhaseTableTableTableManager get studyPhaseTable =>
      $$StudyPhaseTableTableTableManager(_db, _db.studyPhaseTable);
  $$SeriesTableTableTableManager get seriesTable =>
      $$SeriesTableTableTableManager(_db, _db.seriesTable);
  $$ApplicationTableTableTableManager get applicationTable =>
      $$ApplicationTableTableTableManager(_db, _db.applicationTable);
  $$TaskTableTableTableManager get taskTable =>
      $$TaskTableTableTableManager(_db, _db.taskTable);
  $$DsaLogTableTableTableManager get dsaLogTable =>
      $$DsaLogTableTableTableManager(_db, _db.dsaLogTable);
  $$ApplicationStatusHistoryTableTableTableManager
  get applicationStatusHistoryTable =>
      $$ApplicationStatusHistoryTableTableTableManager(
        _db,
        _db.applicationStatusHistoryTable,
      );
  $$ConsistencyLogTableTableTableManager get consistencyLogTable =>
      $$ConsistencyLogTableTableTableManager(_db, _db.consistencyLogTable);
  $$ResumeTableTableTableManager get resumeTable =>
      $$ResumeTableTableTableManager(_db, _db.resumeTable);
  $$InterviewPrepTableTableTableManager get interviewPrepTable =>
      $$InterviewPrepTableTableTableManager(_db, _db.interviewPrepTable);
  $$NoteTableTableTableManager get noteTable =>
      $$NoteTableTableTableManager(_db, _db.noteTable);
  $$NoteTagTableTableTableManager get noteTagTable =>
      $$NoteTagTableTableTableManager(_db, _db.noteTagTable);
  $$InsightDismissalTableTableTableManager get insightDismissalTable =>
      $$InsightDismissalTableTableTableManager(_db, _db.insightDismissalTable);
  $$SessionCategoryTableTableTableManager get sessionCategoryTable =>
      $$SessionCategoryTableTableTableManager(_db, _db.sessionCategoryTable);
  $$TimeSessionTableTableTableManager get timeSessionTable =>
      $$TimeSessionTableTableTableManager(_db, _db.timeSessionTable);
  $$UpcomingInterviewTableTableTableManager get upcomingInterviewTable =>
      $$UpcomingInterviewTableTableTableManager(
        _db,
        _db.upcomingInterviewTable,
      );
  $$ReminderTableTableTableManager get reminderTable =>
      $$ReminderTableTableTableManager(_db, _db.reminderTable);
}

mixin _$UserProfileDaoMixin on DatabaseAccessor<AppDatabase> {
  $UserProfileTableTable get userProfileTable =>
      attachedDatabase.userProfileTable;
  UserProfileDaoManager get managers => UserProfileDaoManager(this);
}

class UserProfileDaoManager {
  final _$UserProfileDaoMixin _db;
  UserProfileDaoManager(this._db);
  $$UserProfileTableTableTableManager get userProfileTable =>
      $$UserProfileTableTableTableManager(
        _db.attachedDatabase,
        _db.userProfileTable,
      );
}

mixin _$TaskDaoMixin on DatabaseAccessor<AppDatabase> {
  $StudyPhaseTableTable get studyPhaseTable => attachedDatabase.studyPhaseTable;
  $SeriesTableTable get seriesTable => attachedDatabase.seriesTable;
  $ApplicationTableTable get applicationTable =>
      attachedDatabase.applicationTable;
  $TaskTableTable get taskTable => attachedDatabase.taskTable;
  TaskDaoManager get managers => TaskDaoManager(this);
}

class TaskDaoManager {
  final _$TaskDaoMixin _db;
  TaskDaoManager(this._db);
  $$StudyPhaseTableTableTableManager get studyPhaseTable =>
      $$StudyPhaseTableTableTableManager(
        _db.attachedDatabase,
        _db.studyPhaseTable,
      );
  $$SeriesTableTableTableManager get seriesTable =>
      $$SeriesTableTableTableManager(_db.attachedDatabase, _db.seriesTable);
  $$ApplicationTableTableTableManager get applicationTable =>
      $$ApplicationTableTableTableManager(
        _db.attachedDatabase,
        _db.applicationTable,
      );
  $$TaskTableTableTableManager get taskTable =>
      $$TaskTableTableTableManager(_db.attachedDatabase, _db.taskTable);
}

mixin _$ApplicationDaoMixin on DatabaseAccessor<AppDatabase> {
  $ApplicationTableTable get applicationTable =>
      attachedDatabase.applicationTable;
  $ApplicationStatusHistoryTableTable get applicationStatusHistoryTable =>
      attachedDatabase.applicationStatusHistoryTable;
  ApplicationDaoManager get managers => ApplicationDaoManager(this);
}

class ApplicationDaoManager {
  final _$ApplicationDaoMixin _db;
  ApplicationDaoManager(this._db);
  $$ApplicationTableTableTableManager get applicationTable =>
      $$ApplicationTableTableTableManager(
        _db.attachedDatabase,
        _db.applicationTable,
      );
  $$ApplicationStatusHistoryTableTableTableManager
  get applicationStatusHistoryTable =>
      $$ApplicationStatusHistoryTableTableTableManager(
        _db.attachedDatabase,
        _db.applicationStatusHistoryTable,
      );
}

mixin _$ConsistencyDaoMixin on DatabaseAccessor<AppDatabase> {
  $ConsistencyLogTableTable get consistencyLogTable =>
      attachedDatabase.consistencyLogTable;
  ConsistencyDaoManager get managers => ConsistencyDaoManager(this);
}

class ConsistencyDaoManager {
  final _$ConsistencyDaoMixin _db;
  ConsistencyDaoManager(this._db);
  $$ConsistencyLogTableTableTableManager get consistencyLogTable =>
      $$ConsistencyLogTableTableTableManager(
        _db.attachedDatabase,
        _db.consistencyLogTable,
      );
}

mixin _$DsaDaoMixin on DatabaseAccessor<AppDatabase> {
  $DsaLogTableTable get dsaLogTable => attachedDatabase.dsaLogTable;
  DsaDaoManager get managers => DsaDaoManager(this);
}

class DsaDaoManager {
  final _$DsaDaoMixin _db;
  DsaDaoManager(this._db);
  $$DsaLogTableTableTableManager get dsaLogTable =>
      $$DsaLogTableTableTableManager(_db.attachedDatabase, _db.dsaLogTable);
}

mixin _$NotesDaoMixin on DatabaseAccessor<AppDatabase> {
  $ApplicationTableTable get applicationTable =>
      attachedDatabase.applicationTable;
  $StudyPhaseTableTable get studyPhaseTable => attachedDatabase.studyPhaseTable;
  $NoteTableTable get noteTable => attachedDatabase.noteTable;
  $NoteTagTableTable get noteTagTable => attachedDatabase.noteTagTable;
  NotesDaoManager get managers => NotesDaoManager(this);
}

class NotesDaoManager {
  final _$NotesDaoMixin _db;
  NotesDaoManager(this._db);
  $$ApplicationTableTableTableManager get applicationTable =>
      $$ApplicationTableTableTableManager(
        _db.attachedDatabase,
        _db.applicationTable,
      );
  $$StudyPhaseTableTableTableManager get studyPhaseTable =>
      $$StudyPhaseTableTableTableManager(
        _db.attachedDatabase,
        _db.studyPhaseTable,
      );
  $$NoteTableTableTableManager get noteTable =>
      $$NoteTableTableTableManager(_db.attachedDatabase, _db.noteTable);
  $$NoteTagTableTableTableManager get noteTagTable =>
      $$NoteTagTableTableTableManager(_db.attachedDatabase, _db.noteTagTable);
}

mixin _$SeriesDaoMixin on DatabaseAccessor<AppDatabase> {
  $StudyPhaseTableTable get studyPhaseTable => attachedDatabase.studyPhaseTable;
  $SeriesTableTable get seriesTable => attachedDatabase.seriesTable;
  $ApplicationTableTable get applicationTable =>
      attachedDatabase.applicationTable;
  $TaskTableTable get taskTable => attachedDatabase.taskTable;
  SeriesDaoManager get managers => SeriesDaoManager(this);
}

class SeriesDaoManager {
  final _$SeriesDaoMixin _db;
  SeriesDaoManager(this._db);
  $$StudyPhaseTableTableTableManager get studyPhaseTable =>
      $$StudyPhaseTableTableTableManager(
        _db.attachedDatabase,
        _db.studyPhaseTable,
      );
  $$SeriesTableTableTableManager get seriesTable =>
      $$SeriesTableTableTableManager(_db.attachedDatabase, _db.seriesTable);
  $$ApplicationTableTableTableManager get applicationTable =>
      $$ApplicationTableTableTableManager(
        _db.attachedDatabase,
        _db.applicationTable,
      );
  $$TaskTableTableTableManager get taskTable =>
      $$TaskTableTableTableManager(_db.attachedDatabase, _db.taskTable);
}

mixin _$StudyPhaseDaoMixin on DatabaseAccessor<AppDatabase> {
  $StudyPhaseTableTable get studyPhaseTable => attachedDatabase.studyPhaseTable;
  $SeriesTableTable get seriesTable => attachedDatabase.seriesTable;
  $ApplicationTableTable get applicationTable =>
      attachedDatabase.applicationTable;
  $TaskTableTable get taskTable => attachedDatabase.taskTable;
  StudyPhaseDaoManager get managers => StudyPhaseDaoManager(this);
}

class StudyPhaseDaoManager {
  final _$StudyPhaseDaoMixin _db;
  StudyPhaseDaoManager(this._db);
  $$StudyPhaseTableTableTableManager get studyPhaseTable =>
      $$StudyPhaseTableTableTableManager(
        _db.attachedDatabase,
        _db.studyPhaseTable,
      );
  $$SeriesTableTableTableManager get seriesTable =>
      $$SeriesTableTableTableManager(_db.attachedDatabase, _db.seriesTable);
  $$ApplicationTableTableTableManager get applicationTable =>
      $$ApplicationTableTableTableManager(
        _db.attachedDatabase,
        _db.applicationTable,
      );
  $$TaskTableTableTableManager get taskTable =>
      $$TaskTableTableTableManager(_db.attachedDatabase, _db.taskTable);
}

mixin _$ResumeDaoMixin on DatabaseAccessor<AppDatabase> {
  $ApplicationTableTable get applicationTable =>
      attachedDatabase.applicationTable;
  $ResumeTableTable get resumeTable => attachedDatabase.resumeTable;
  ResumeDaoManager get managers => ResumeDaoManager(this);
}

class ResumeDaoManager {
  final _$ResumeDaoMixin _db;
  ResumeDaoManager(this._db);
  $$ApplicationTableTableTableManager get applicationTable =>
      $$ApplicationTableTableTableManager(
        _db.attachedDatabase,
        _db.applicationTable,
      );
  $$ResumeTableTableTableManager get resumeTable =>
      $$ResumeTableTableTableManager(_db.attachedDatabase, _db.resumeTable);
}

mixin _$InterviewPrepDaoMixin on DatabaseAccessor<AppDatabase> {
  $ApplicationTableTable get applicationTable =>
      attachedDatabase.applicationTable;
  $InterviewPrepTableTable get interviewPrepTable =>
      attachedDatabase.interviewPrepTable;
  InterviewPrepDaoManager get managers => InterviewPrepDaoManager(this);
}

class InterviewPrepDaoManager {
  final _$InterviewPrepDaoMixin _db;
  InterviewPrepDaoManager(this._db);
  $$ApplicationTableTableTableManager get applicationTable =>
      $$ApplicationTableTableTableManager(
        _db.attachedDatabase,
        _db.applicationTable,
      );
  $$InterviewPrepTableTableTableManager get interviewPrepTable =>
      $$InterviewPrepTableTableTableManager(
        _db.attachedDatabase,
        _db.interviewPrepTable,
      );
}

mixin _$InsightDismissalDaoMixin on DatabaseAccessor<AppDatabase> {
  $InsightDismissalTableTable get insightDismissalTable =>
      attachedDatabase.insightDismissalTable;
  InsightDismissalDaoManager get managers => InsightDismissalDaoManager(this);
}

class InsightDismissalDaoManager {
  final _$InsightDismissalDaoMixin _db;
  InsightDismissalDaoManager(this._db);
  $$InsightDismissalTableTableTableManager get insightDismissalTable =>
      $$InsightDismissalTableTableTableManager(
        _db.attachedDatabase,
        _db.insightDismissalTable,
      );
}

mixin _$TimeSessionDaoMixin on DatabaseAccessor<AppDatabase> {
  $SessionCategoryTableTable get sessionCategoryTable =>
      attachedDatabase.sessionCategoryTable;
  $StudyPhaseTableTable get studyPhaseTable => attachedDatabase.studyPhaseTable;
  $SeriesTableTable get seriesTable => attachedDatabase.seriesTable;
  $ApplicationTableTable get applicationTable =>
      attachedDatabase.applicationTable;
  $TaskTableTable get taskTable => attachedDatabase.taskTable;
  $TimeSessionTableTable get timeSessionTable =>
      attachedDatabase.timeSessionTable;
  $ConsistencyLogTableTable get consistencyLogTable =>
      attachedDatabase.consistencyLogTable;
  TimeSessionDaoManager get managers => TimeSessionDaoManager(this);
}

class TimeSessionDaoManager {
  final _$TimeSessionDaoMixin _db;
  TimeSessionDaoManager(this._db);
  $$SessionCategoryTableTableTableManager get sessionCategoryTable =>
      $$SessionCategoryTableTableTableManager(
        _db.attachedDatabase,
        _db.sessionCategoryTable,
      );
  $$StudyPhaseTableTableTableManager get studyPhaseTable =>
      $$StudyPhaseTableTableTableManager(
        _db.attachedDatabase,
        _db.studyPhaseTable,
      );
  $$SeriesTableTableTableManager get seriesTable =>
      $$SeriesTableTableTableManager(_db.attachedDatabase, _db.seriesTable);
  $$ApplicationTableTableTableManager get applicationTable =>
      $$ApplicationTableTableTableManager(
        _db.attachedDatabase,
        _db.applicationTable,
      );
  $$TaskTableTableTableManager get taskTable =>
      $$TaskTableTableTableManager(_db.attachedDatabase, _db.taskTable);
  $$TimeSessionTableTableTableManager get timeSessionTable =>
      $$TimeSessionTableTableTableManager(
        _db.attachedDatabase,
        _db.timeSessionTable,
      );
  $$ConsistencyLogTableTableTableManager get consistencyLogTable =>
      $$ConsistencyLogTableTableTableManager(
        _db.attachedDatabase,
        _db.consistencyLogTable,
      );
}

mixin _$UpcomingInterviewDaoMixin on DatabaseAccessor<AppDatabase> {
  $UpcomingInterviewTableTable get upcomingInterviewTable =>
      attachedDatabase.upcomingInterviewTable;
  UpcomingInterviewDaoManager get managers => UpcomingInterviewDaoManager(this);
}

class UpcomingInterviewDaoManager {
  final _$UpcomingInterviewDaoMixin _db;
  UpcomingInterviewDaoManager(this._db);
  $$UpcomingInterviewTableTableTableManager get upcomingInterviewTable =>
      $$UpcomingInterviewTableTableTableManager(
        _db.attachedDatabase,
        _db.upcomingInterviewTable,
      );
}

mixin _$ReminderDaoMixin on DatabaseAccessor<AppDatabase> {
  $ReminderTableTable get reminderTable => attachedDatabase.reminderTable;
  ReminderDaoManager get managers => ReminderDaoManager(this);
}

class ReminderDaoManager {
  final _$ReminderDaoMixin _db;
  ReminderDaoManager(this._db);
  $$ReminderTableTableTableManager get reminderTable =>
      $$ReminderTableTableTableManager(_db.attachedDatabase, _db.reminderTable);
}

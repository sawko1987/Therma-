// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ProjectEntriesTable extends ProjectEntries
    with TableInfo<$ProjectEntriesTable, ProjectEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ProjectEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _climatePointIdMeta = const VerificationMeta(
    'climatePointId',
  );
  @override
  late final GeneratedColumn<String> climatePointId = GeneratedColumn<String>(
    'climate_point_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _roomPresetMeta = const VerificationMeta(
    'roomPreset',
  );
  @override
  late final GeneratedColumn<String> roomPreset = GeneratedColumn<String>(
    'room_preset',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _projectFormatVersionMeta =
      const VerificationMeta('projectFormatVersion');
  @override
  late final GeneratedColumn<int> projectFormatVersion = GeneratedColumn<int>(
    'project_format_version',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _datasetVersionMeta = const VerificationMeta(
    'datasetVersion',
  );
  @override
  late final GeneratedColumn<String> datasetVersion = GeneratedColumn<String>(
    'dataset_version',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(legacyUnversionedDatasetVersion),
  );
  static const VerificationMeta _migratedFromDatasetVersionMeta =
      const VerificationMeta('migratedFromDatasetVersion');
  @override
  late final GeneratedColumn<String> migratedFromDatasetVersion =
      GeneratedColumn<String>(
        'migrated_from_dataset_version',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _updatedAtEpochMsMeta = const VerificationMeta(
    'updatedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtEpochMs = GeneratedColumn<int>(
    'updated_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    climatePointId,
    roomPreset,
    payloadJson,
    projectFormatVersion,
    datasetVersion,
    migratedFromDatasetVersion,
    updatedAtEpochMs,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'project_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<ProjectEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('climate_point_id')) {
      context.handle(
        _climatePointIdMeta,
        climatePointId.isAcceptableOrUnknown(
          data['climate_point_id']!,
          _climatePointIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_climatePointIdMeta);
    }
    if (data.containsKey('room_preset')) {
      context.handle(
        _roomPresetMeta,
        roomPreset.isAcceptableOrUnknown(data['room_preset']!, _roomPresetMeta),
      );
    } else if (isInserting) {
      context.missing(_roomPresetMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('project_format_version')) {
      context.handle(
        _projectFormatVersionMeta,
        projectFormatVersion.isAcceptableOrUnknown(
          data['project_format_version']!,
          _projectFormatVersionMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_projectFormatVersionMeta);
    }
    if (data.containsKey('dataset_version')) {
      context.handle(
        _datasetVersionMeta,
        datasetVersion.isAcceptableOrUnknown(
          data['dataset_version']!,
          _datasetVersionMeta,
        ),
      );
    }
    if (data.containsKey('migrated_from_dataset_version')) {
      context.handle(
        _migratedFromDatasetVersionMeta,
        migratedFromDatasetVersion.isAcceptableOrUnknown(
          data['migrated_from_dataset_version']!,
          _migratedFromDatasetVersionMeta,
        ),
      );
    }
    if (data.containsKey('updated_at_epoch_ms')) {
      context.handle(
        _updatedAtEpochMsMeta,
        updatedAtEpochMs.isAcceptableOrUnknown(
          data['updated_at_epoch_ms']!,
          _updatedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtEpochMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ProjectEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ProjectEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      climatePointId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}climate_point_id'],
      )!,
      roomPreset: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}room_preset'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      projectFormatVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}project_format_version'],
      )!,
      datasetVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}dataset_version'],
      )!,
      migratedFromDatasetVersion: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}migrated_from_dataset_version'],
      ),
      updatedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_epoch_ms'],
      )!,
    );
  }

  @override
  $ProjectEntriesTable createAlias(String alias) {
    return $ProjectEntriesTable(attachedDatabase, alias);
  }
}

class ProjectEntry extends DataClass implements Insertable<ProjectEntry> {
  final String id;
  final String name;
  final String climatePointId;
  final String roomPreset;
  final String payloadJson;
  final int projectFormatVersion;
  final String datasetVersion;
  final String? migratedFromDatasetVersion;
  final int updatedAtEpochMs;
  const ProjectEntry({
    required this.id,
    required this.name,
    required this.climatePointId,
    required this.roomPreset,
    required this.payloadJson,
    required this.projectFormatVersion,
    required this.datasetVersion,
    this.migratedFromDatasetVersion,
    required this.updatedAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['climate_point_id'] = Variable<String>(climatePointId);
    map['room_preset'] = Variable<String>(roomPreset);
    map['payload_json'] = Variable<String>(payloadJson);
    map['project_format_version'] = Variable<int>(projectFormatVersion);
    map['dataset_version'] = Variable<String>(datasetVersion);
    if (!nullToAbsent || migratedFromDatasetVersion != null) {
      map['migrated_from_dataset_version'] = Variable<String>(
        migratedFromDatasetVersion,
      );
    }
    map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs);
    return map;
  }

  ProjectEntriesCompanion toCompanion(bool nullToAbsent) {
    return ProjectEntriesCompanion(
      id: Value(id),
      name: Value(name),
      climatePointId: Value(climatePointId),
      roomPreset: Value(roomPreset),
      payloadJson: Value(payloadJson),
      projectFormatVersion: Value(projectFormatVersion),
      datasetVersion: Value(datasetVersion),
      migratedFromDatasetVersion:
          migratedFromDatasetVersion == null && nullToAbsent
          ? const Value.absent()
          : Value(migratedFromDatasetVersion),
      updatedAtEpochMs: Value(updatedAtEpochMs),
    );
  }

  factory ProjectEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ProjectEntry(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      climatePointId: serializer.fromJson<String>(json['climatePointId']),
      roomPreset: serializer.fromJson<String>(json['roomPreset']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      projectFormatVersion: serializer.fromJson<int>(
        json['projectFormatVersion'],
      ),
      datasetVersion: serializer.fromJson<String>(json['datasetVersion']),
      migratedFromDatasetVersion: serializer.fromJson<String?>(
        json['migratedFromDatasetVersion'],
      ),
      updatedAtEpochMs: serializer.fromJson<int>(json['updatedAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'climatePointId': serializer.toJson<String>(climatePointId),
      'roomPreset': serializer.toJson<String>(roomPreset),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'projectFormatVersion': serializer.toJson<int>(projectFormatVersion),
      'datasetVersion': serializer.toJson<String>(datasetVersion),
      'migratedFromDatasetVersion': serializer.toJson<String?>(
        migratedFromDatasetVersion,
      ),
      'updatedAtEpochMs': serializer.toJson<int>(updatedAtEpochMs),
    };
  }

  ProjectEntry copyWith({
    String? id,
    String? name,
    String? climatePointId,
    String? roomPreset,
    String? payloadJson,
    int? projectFormatVersion,
    String? datasetVersion,
    Value<String?> migratedFromDatasetVersion = const Value.absent(),
    int? updatedAtEpochMs,
  }) => ProjectEntry(
    id: id ?? this.id,
    name: name ?? this.name,
    climatePointId: climatePointId ?? this.climatePointId,
    roomPreset: roomPreset ?? this.roomPreset,
    payloadJson: payloadJson ?? this.payloadJson,
    projectFormatVersion: projectFormatVersion ?? this.projectFormatVersion,
    datasetVersion: datasetVersion ?? this.datasetVersion,
    migratedFromDatasetVersion: migratedFromDatasetVersion.present
        ? migratedFromDatasetVersion.value
        : this.migratedFromDatasetVersion,
    updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
  );
  ProjectEntry copyWithCompanion(ProjectEntriesCompanion data) {
    return ProjectEntry(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      climatePointId: data.climatePointId.present
          ? data.climatePointId.value
          : this.climatePointId,
      roomPreset: data.roomPreset.present
          ? data.roomPreset.value
          : this.roomPreset,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      projectFormatVersion: data.projectFormatVersion.present
          ? data.projectFormatVersion.value
          : this.projectFormatVersion,
      datasetVersion: data.datasetVersion.present
          ? data.datasetVersion.value
          : this.datasetVersion,
      migratedFromDatasetVersion: data.migratedFromDatasetVersion.present
          ? data.migratedFromDatasetVersion.value
          : this.migratedFromDatasetVersion,
      updatedAtEpochMs: data.updatedAtEpochMs.present
          ? data.updatedAtEpochMs.value
          : this.updatedAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ProjectEntry(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('climatePointId: $climatePointId, ')
          ..write('roomPreset: $roomPreset, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('projectFormatVersion: $projectFormatVersion, ')
          ..write('datasetVersion: $datasetVersion, ')
          ..write('migratedFromDatasetVersion: $migratedFromDatasetVersion, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    climatePointId,
    roomPreset,
    payloadJson,
    projectFormatVersion,
    datasetVersion,
    migratedFromDatasetVersion,
    updatedAtEpochMs,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ProjectEntry &&
          other.id == this.id &&
          other.name == this.name &&
          other.climatePointId == this.climatePointId &&
          other.roomPreset == this.roomPreset &&
          other.payloadJson == this.payloadJson &&
          other.projectFormatVersion == this.projectFormatVersion &&
          other.datasetVersion == this.datasetVersion &&
          other.migratedFromDatasetVersion == this.migratedFromDatasetVersion &&
          other.updatedAtEpochMs == this.updatedAtEpochMs);
}

class ProjectEntriesCompanion extends UpdateCompanion<ProjectEntry> {
  final Value<String> id;
  final Value<String> name;
  final Value<String> climatePointId;
  final Value<String> roomPreset;
  final Value<String> payloadJson;
  final Value<int> projectFormatVersion;
  final Value<String> datasetVersion;
  final Value<String?> migratedFromDatasetVersion;
  final Value<int> updatedAtEpochMs;
  final Value<int> rowid;
  const ProjectEntriesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.climatePointId = const Value.absent(),
    this.roomPreset = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.projectFormatVersion = const Value.absent(),
    this.datasetVersion = const Value.absent(),
    this.migratedFromDatasetVersion = const Value.absent(),
    this.updatedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ProjectEntriesCompanion.insert({
    required String id,
    required String name,
    required String climatePointId,
    required String roomPreset,
    required String payloadJson,
    required int projectFormatVersion,
    this.datasetVersion = const Value.absent(),
    this.migratedFromDatasetVersion = const Value.absent(),
    required int updatedAtEpochMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       climatePointId = Value(climatePointId),
       roomPreset = Value(roomPreset),
       payloadJson = Value(payloadJson),
       projectFormatVersion = Value(projectFormatVersion),
       updatedAtEpochMs = Value(updatedAtEpochMs);
  static Insertable<ProjectEntry> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? climatePointId,
    Expression<String>? roomPreset,
    Expression<String>? payloadJson,
    Expression<int>? projectFormatVersion,
    Expression<String>? datasetVersion,
    Expression<String>? migratedFromDatasetVersion,
    Expression<int>? updatedAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (climatePointId != null) 'climate_point_id': climatePointId,
      if (roomPreset != null) 'room_preset': roomPreset,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (projectFormatVersion != null)
        'project_format_version': projectFormatVersion,
      if (datasetVersion != null) 'dataset_version': datasetVersion,
      if (migratedFromDatasetVersion != null)
        'migrated_from_dataset_version': migratedFromDatasetVersion,
      if (updatedAtEpochMs != null) 'updated_at_epoch_ms': updatedAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ProjectEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<String>? climatePointId,
    Value<String>? roomPreset,
    Value<String>? payloadJson,
    Value<int>? projectFormatVersion,
    Value<String>? datasetVersion,
    Value<String?>? migratedFromDatasetVersion,
    Value<int>? updatedAtEpochMs,
    Value<int>? rowid,
  }) {
    return ProjectEntriesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      climatePointId: climatePointId ?? this.climatePointId,
      roomPreset: roomPreset ?? this.roomPreset,
      payloadJson: payloadJson ?? this.payloadJson,
      projectFormatVersion: projectFormatVersion ?? this.projectFormatVersion,
      datasetVersion: datasetVersion ?? this.datasetVersion,
      migratedFromDatasetVersion:
          migratedFromDatasetVersion ?? this.migratedFromDatasetVersion,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (climatePointId.present) {
      map['climate_point_id'] = Variable<String>(climatePointId.value);
    }
    if (roomPreset.present) {
      map['room_preset'] = Variable<String>(roomPreset.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (projectFormatVersion.present) {
      map['project_format_version'] = Variable<int>(projectFormatVersion.value);
    }
    if (datasetVersion.present) {
      map['dataset_version'] = Variable<String>(datasetVersion.value);
    }
    if (migratedFromDatasetVersion.present) {
      map['migrated_from_dataset_version'] = Variable<String>(
        migratedFromDatasetVersion.value,
      );
    }
    if (updatedAtEpochMs.present) {
      map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ProjectEntriesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('climatePointId: $climatePointId, ')
          ..write('roomPreset: $roomPreset, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('projectFormatVersion: $projectFormatVersion, ')
          ..write('datasetVersion: $datasetVersion, ')
          ..write('migratedFromDatasetVersion: $migratedFromDatasetVersion, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredOpeningCatalogEntriesTable extends StoredOpeningCatalogEntries
    with
        TableInfo<
          $StoredOpeningCatalogEntriesTable,
          StoredOpeningCatalogEntry
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredOpeningCatalogEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtEpochMsMeta = const VerificationMeta(
    'updatedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtEpochMs = GeneratedColumn<int>(
    'updated_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, payloadJson, updatedAtEpochMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stored_opening_catalog_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredOpeningCatalogEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('updated_at_epoch_ms')) {
      context.handle(
        _updatedAtEpochMsMeta,
        updatedAtEpochMs.isAcceptableOrUnknown(
          data['updated_at_epoch_ms']!,
          _updatedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtEpochMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredOpeningCatalogEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredOpeningCatalogEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      updatedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_epoch_ms'],
      )!,
    );
  }

  @override
  $StoredOpeningCatalogEntriesTable createAlias(String alias) {
    return $StoredOpeningCatalogEntriesTable(attachedDatabase, alias);
  }
}

class StoredOpeningCatalogEntry extends DataClass
    implements Insertable<StoredOpeningCatalogEntry> {
  final String id;
  final String payloadJson;
  final int updatedAtEpochMs;
  const StoredOpeningCatalogEntry({
    required this.id,
    required this.payloadJson,
    required this.updatedAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['payload_json'] = Variable<String>(payloadJson);
    map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs);
    return map;
  }

  StoredOpeningCatalogEntriesCompanion toCompanion(bool nullToAbsent) {
    return StoredOpeningCatalogEntriesCompanion(
      id: Value(id),
      payloadJson: Value(payloadJson),
      updatedAtEpochMs: Value(updatedAtEpochMs),
    );
  }

  factory StoredOpeningCatalogEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredOpeningCatalogEntry(
      id: serializer.fromJson<String>(json['id']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      updatedAtEpochMs: serializer.fromJson<int>(json['updatedAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'updatedAtEpochMs': serializer.toJson<int>(updatedAtEpochMs),
    };
  }

  StoredOpeningCatalogEntry copyWith({
    String? id,
    String? payloadJson,
    int? updatedAtEpochMs,
  }) => StoredOpeningCatalogEntry(
    id: id ?? this.id,
    payloadJson: payloadJson ?? this.payloadJson,
    updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
  );
  StoredOpeningCatalogEntry copyWithCompanion(
    StoredOpeningCatalogEntriesCompanion data,
  ) {
    return StoredOpeningCatalogEntry(
      id: data.id.present ? data.id.value : this.id,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      updatedAtEpochMs: data.updatedAtEpochMs.present
          ? data.updatedAtEpochMs.value
          : this.updatedAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredOpeningCatalogEntry(')
          ..write('id: $id, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, payloadJson, updatedAtEpochMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredOpeningCatalogEntry &&
          other.id == this.id &&
          other.payloadJson == this.payloadJson &&
          other.updatedAtEpochMs == this.updatedAtEpochMs);
}

class StoredOpeningCatalogEntriesCompanion
    extends UpdateCompanion<StoredOpeningCatalogEntry> {
  final Value<String> id;
  final Value<String> payloadJson;
  final Value<int> updatedAtEpochMs;
  final Value<int> rowid;
  const StoredOpeningCatalogEntriesCompanion({
    this.id = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredOpeningCatalogEntriesCompanion.insert({
    required String id,
    required String payloadJson,
    required int updatedAtEpochMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       payloadJson = Value(payloadJson),
       updatedAtEpochMs = Value(updatedAtEpochMs);
  static Insertable<StoredOpeningCatalogEntry> custom({
    Expression<String>? id,
    Expression<String>? payloadJson,
    Expression<int>? updatedAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAtEpochMs != null) 'updated_at_epoch_ms': updatedAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredOpeningCatalogEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? payloadJson,
    Value<int>? updatedAtEpochMs,
    Value<int>? rowid,
  }) {
    return StoredOpeningCatalogEntriesCompanion(
      id: id ?? this.id,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (updatedAtEpochMs.present) {
      map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredOpeningCatalogEntriesCompanion(')
          ..write('id: $id, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoredHeatingDeviceCatalogEntriesTable
    extends StoredHeatingDeviceCatalogEntries
    with
        TableInfo<
          $StoredHeatingDeviceCatalogEntriesTable,
          StoredHeatingDeviceCatalogEntry
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoredHeatingDeviceCatalogEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadJsonMeta = const VerificationMeta(
    'payloadJson',
  );
  @override
  late final GeneratedColumn<String> payloadJson = GeneratedColumn<String>(
    'payload_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtEpochMsMeta = const VerificationMeta(
    'updatedAtEpochMs',
  );
  @override
  late final GeneratedColumn<int> updatedAtEpochMs = GeneratedColumn<int>(
    'updated_at_epoch_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, payloadJson, updatedAtEpochMs];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'stored_heating_device_catalog_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoredHeatingDeviceCatalogEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('payload_json')) {
      context.handle(
        _payloadJsonMeta,
        payloadJson.isAcceptableOrUnknown(
          data['payload_json']!,
          _payloadJsonMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_payloadJsonMeta);
    }
    if (data.containsKey('updated_at_epoch_ms')) {
      context.handle(
        _updatedAtEpochMsMeta,
        updatedAtEpochMs.isAcceptableOrUnknown(
          data['updated_at_epoch_ms']!,
          _updatedAtEpochMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updatedAtEpochMsMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoredHeatingDeviceCatalogEntry map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoredHeatingDeviceCatalogEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      payloadJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload_json'],
      )!,
      updatedAtEpochMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at_epoch_ms'],
      )!,
    );
  }

  @override
  $StoredHeatingDeviceCatalogEntriesTable createAlias(String alias) {
    return $StoredHeatingDeviceCatalogEntriesTable(attachedDatabase, alias);
  }
}

class StoredHeatingDeviceCatalogEntry extends DataClass
    implements Insertable<StoredHeatingDeviceCatalogEntry> {
  final String id;
  final String payloadJson;
  final int updatedAtEpochMs;
  const StoredHeatingDeviceCatalogEntry({
    required this.id,
    required this.payloadJson,
    required this.updatedAtEpochMs,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['payload_json'] = Variable<String>(payloadJson);
    map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs);
    return map;
  }

  StoredHeatingDeviceCatalogEntriesCompanion toCompanion(bool nullToAbsent) {
    return StoredHeatingDeviceCatalogEntriesCompanion(
      id: Value(id),
      payloadJson: Value(payloadJson),
      updatedAtEpochMs: Value(updatedAtEpochMs),
    );
  }

  factory StoredHeatingDeviceCatalogEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoredHeatingDeviceCatalogEntry(
      id: serializer.fromJson<String>(json['id']),
      payloadJson: serializer.fromJson<String>(json['payloadJson']),
      updatedAtEpochMs: serializer.fromJson<int>(json['updatedAtEpochMs']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'payloadJson': serializer.toJson<String>(payloadJson),
      'updatedAtEpochMs': serializer.toJson<int>(updatedAtEpochMs),
    };
  }

  StoredHeatingDeviceCatalogEntry copyWith({
    String? id,
    String? payloadJson,
    int? updatedAtEpochMs,
  }) => StoredHeatingDeviceCatalogEntry(
    id: id ?? this.id,
    payloadJson: payloadJson ?? this.payloadJson,
    updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
  );
  StoredHeatingDeviceCatalogEntry copyWithCompanion(
    StoredHeatingDeviceCatalogEntriesCompanion data,
  ) {
    return StoredHeatingDeviceCatalogEntry(
      id: data.id.present ? data.id.value : this.id,
      payloadJson: data.payloadJson.present
          ? data.payloadJson.value
          : this.payloadJson,
      updatedAtEpochMs: data.updatedAtEpochMs.present
          ? data.updatedAtEpochMs.value
          : this.updatedAtEpochMs,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoredHeatingDeviceCatalogEntry(')
          ..write('id: $id, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, payloadJson, updatedAtEpochMs);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoredHeatingDeviceCatalogEntry &&
          other.id == this.id &&
          other.payloadJson == this.payloadJson &&
          other.updatedAtEpochMs == this.updatedAtEpochMs);
}

class StoredHeatingDeviceCatalogEntriesCompanion
    extends UpdateCompanion<StoredHeatingDeviceCatalogEntry> {
  final Value<String> id;
  final Value<String> payloadJson;
  final Value<int> updatedAtEpochMs;
  final Value<int> rowid;
  const StoredHeatingDeviceCatalogEntriesCompanion({
    this.id = const Value.absent(),
    this.payloadJson = const Value.absent(),
    this.updatedAtEpochMs = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StoredHeatingDeviceCatalogEntriesCompanion.insert({
    required String id,
    required String payloadJson,
    required int updatedAtEpochMs,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       payloadJson = Value(payloadJson),
       updatedAtEpochMs = Value(updatedAtEpochMs);
  static Insertable<StoredHeatingDeviceCatalogEntry> custom({
    Expression<String>? id,
    Expression<String>? payloadJson,
    Expression<int>? updatedAtEpochMs,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (payloadJson != null) 'payload_json': payloadJson,
      if (updatedAtEpochMs != null) 'updated_at_epoch_ms': updatedAtEpochMs,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StoredHeatingDeviceCatalogEntriesCompanion copyWith({
    Value<String>? id,
    Value<String>? payloadJson,
    Value<int>? updatedAtEpochMs,
    Value<int>? rowid,
  }) {
    return StoredHeatingDeviceCatalogEntriesCompanion(
      id: id ?? this.id,
      payloadJson: payloadJson ?? this.payloadJson,
      updatedAtEpochMs: updatedAtEpochMs ?? this.updatedAtEpochMs,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (payloadJson.present) {
      map['payload_json'] = Variable<String>(payloadJson.value);
    }
    if (updatedAtEpochMs.present) {
      map['updated_at_epoch_ms'] = Variable<int>(updatedAtEpochMs.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoredHeatingDeviceCatalogEntriesCompanion(')
          ..write('id: $id, ')
          ..write('payloadJson: $payloadJson, ')
          ..write('updatedAtEpochMs: $updatedAtEpochMs, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ProjectEntriesTable projectEntries = $ProjectEntriesTable(this);
  late final $StoredOpeningCatalogEntriesTable storedOpeningCatalogEntries =
      $StoredOpeningCatalogEntriesTable(this);
  late final $StoredHeatingDeviceCatalogEntriesTable
  storedHeatingDeviceCatalogEntries = $StoredHeatingDeviceCatalogEntriesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    projectEntries,
    storedOpeningCatalogEntries,
    storedHeatingDeviceCatalogEntries,
  ];
}

typedef $$ProjectEntriesTableCreateCompanionBuilder =
    ProjectEntriesCompanion Function({
      required String id,
      required String name,
      required String climatePointId,
      required String roomPreset,
      required String payloadJson,
      required int projectFormatVersion,
      Value<String> datasetVersion,
      Value<String?> migratedFromDatasetVersion,
      required int updatedAtEpochMs,
      Value<int> rowid,
    });
typedef $$ProjectEntriesTableUpdateCompanionBuilder =
    ProjectEntriesCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<String> climatePointId,
      Value<String> roomPreset,
      Value<String> payloadJson,
      Value<int> projectFormatVersion,
      Value<String> datasetVersion,
      Value<String?> migratedFromDatasetVersion,
      Value<int> updatedAtEpochMs,
      Value<int> rowid,
    });

class $$ProjectEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ProjectEntriesTable> {
  $$ProjectEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get climatePointId => $composableBuilder(
    column: $table.climatePointId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get roomPreset => $composableBuilder(
    column: $table.roomPreset,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get projectFormatVersion => $composableBuilder(
    column: $table.projectFormatVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get datasetVersion => $composableBuilder(
    column: $table.datasetVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get migratedFromDatasetVersion => $composableBuilder(
    column: $table.migratedFromDatasetVersion,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$ProjectEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ProjectEntriesTable> {
  $$ProjectEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get climatePointId => $composableBuilder(
    column: $table.climatePointId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get roomPreset => $composableBuilder(
    column: $table.roomPreset,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get projectFormatVersion => $composableBuilder(
    column: $table.projectFormatVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get datasetVersion => $composableBuilder(
    column: $table.datasetVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get migratedFromDatasetVersion => $composableBuilder(
    column: $table.migratedFromDatasetVersion,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$ProjectEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ProjectEntriesTable> {
  $$ProjectEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get climatePointId => $composableBuilder(
    column: $table.climatePointId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get roomPreset => $composableBuilder(
    column: $table.roomPreset,
    builder: (column) => column,
  );

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get projectFormatVersion => $composableBuilder(
    column: $table.projectFormatVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get datasetVersion => $composableBuilder(
    column: $table.datasetVersion,
    builder: (column) => column,
  );

  GeneratedColumn<String> get migratedFromDatasetVersion => $composableBuilder(
    column: $table.migratedFromDatasetVersion,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => column,
  );
}

class $$ProjectEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $ProjectEntriesTable,
          ProjectEntry,
          $$ProjectEntriesTableFilterComposer,
          $$ProjectEntriesTableOrderingComposer,
          $$ProjectEntriesTableAnnotationComposer,
          $$ProjectEntriesTableCreateCompanionBuilder,
          $$ProjectEntriesTableUpdateCompanionBuilder,
          (
            ProjectEntry,
            BaseReferences<_$AppDatabase, $ProjectEntriesTable, ProjectEntry>,
          ),
          ProjectEntry,
          PrefetchHooks Function()
        > {
  $$ProjectEntriesTableTableManager(
    _$AppDatabase db,
    $ProjectEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ProjectEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ProjectEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ProjectEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> climatePointId = const Value.absent(),
                Value<String> roomPreset = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> projectFormatVersion = const Value.absent(),
                Value<String> datasetVersion = const Value.absent(),
                Value<String?> migratedFromDatasetVersion =
                    const Value.absent(),
                Value<int> updatedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => ProjectEntriesCompanion(
                id: id,
                name: name,
                climatePointId: climatePointId,
                roomPreset: roomPreset,
                payloadJson: payloadJson,
                projectFormatVersion: projectFormatVersion,
                datasetVersion: datasetVersion,
                migratedFromDatasetVersion: migratedFromDatasetVersion,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required String climatePointId,
                required String roomPreset,
                required String payloadJson,
                required int projectFormatVersion,
                Value<String> datasetVersion = const Value.absent(),
                Value<String?> migratedFromDatasetVersion =
                    const Value.absent(),
                required int updatedAtEpochMs,
                Value<int> rowid = const Value.absent(),
              }) => ProjectEntriesCompanion.insert(
                id: id,
                name: name,
                climatePointId: climatePointId,
                roomPreset: roomPreset,
                payloadJson: payloadJson,
                projectFormatVersion: projectFormatVersion,
                datasetVersion: datasetVersion,
                migratedFromDatasetVersion: migratedFromDatasetVersion,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$ProjectEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $ProjectEntriesTable,
      ProjectEntry,
      $$ProjectEntriesTableFilterComposer,
      $$ProjectEntriesTableOrderingComposer,
      $$ProjectEntriesTableAnnotationComposer,
      $$ProjectEntriesTableCreateCompanionBuilder,
      $$ProjectEntriesTableUpdateCompanionBuilder,
      (
        ProjectEntry,
        BaseReferences<_$AppDatabase, $ProjectEntriesTable, ProjectEntry>,
      ),
      ProjectEntry,
      PrefetchHooks Function()
    >;
typedef $$StoredOpeningCatalogEntriesTableCreateCompanionBuilder =
    StoredOpeningCatalogEntriesCompanion Function({
      required String id,
      required String payloadJson,
      required int updatedAtEpochMs,
      Value<int> rowid,
    });
typedef $$StoredOpeningCatalogEntriesTableUpdateCompanionBuilder =
    StoredOpeningCatalogEntriesCompanion Function({
      Value<String> id,
      Value<String> payloadJson,
      Value<int> updatedAtEpochMs,
      Value<int> rowid,
    });

class $$StoredOpeningCatalogEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $StoredOpeningCatalogEntriesTable> {
  $$StoredOpeningCatalogEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredOpeningCatalogEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredOpeningCatalogEntriesTable> {
  $$StoredOpeningCatalogEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredOpeningCatalogEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredOpeningCatalogEntriesTable> {
  $$StoredOpeningCatalogEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => column,
  );
}

class $$StoredOpeningCatalogEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredOpeningCatalogEntriesTable,
          StoredOpeningCatalogEntry,
          $$StoredOpeningCatalogEntriesTableFilterComposer,
          $$StoredOpeningCatalogEntriesTableOrderingComposer,
          $$StoredOpeningCatalogEntriesTableAnnotationComposer,
          $$StoredOpeningCatalogEntriesTableCreateCompanionBuilder,
          $$StoredOpeningCatalogEntriesTableUpdateCompanionBuilder,
          (
            StoredOpeningCatalogEntry,
            BaseReferences<
              _$AppDatabase,
              $StoredOpeningCatalogEntriesTable,
              StoredOpeningCatalogEntry
            >,
          ),
          StoredOpeningCatalogEntry,
          PrefetchHooks Function()
        > {
  $$StoredOpeningCatalogEntriesTableTableManager(
    _$AppDatabase db,
    $StoredOpeningCatalogEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoredOpeningCatalogEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$StoredOpeningCatalogEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$StoredOpeningCatalogEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> updatedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredOpeningCatalogEntriesCompanion(
                id: id,
                payloadJson: payloadJson,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String payloadJson,
                required int updatedAtEpochMs,
                Value<int> rowid = const Value.absent(),
              }) => StoredOpeningCatalogEntriesCompanion.insert(
                id: id,
                payloadJson: payloadJson,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StoredOpeningCatalogEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredOpeningCatalogEntriesTable,
      StoredOpeningCatalogEntry,
      $$StoredOpeningCatalogEntriesTableFilterComposer,
      $$StoredOpeningCatalogEntriesTableOrderingComposer,
      $$StoredOpeningCatalogEntriesTableAnnotationComposer,
      $$StoredOpeningCatalogEntriesTableCreateCompanionBuilder,
      $$StoredOpeningCatalogEntriesTableUpdateCompanionBuilder,
      (
        StoredOpeningCatalogEntry,
        BaseReferences<
          _$AppDatabase,
          $StoredOpeningCatalogEntriesTable,
          StoredOpeningCatalogEntry
        >,
      ),
      StoredOpeningCatalogEntry,
      PrefetchHooks Function()
    >;
typedef $$StoredHeatingDeviceCatalogEntriesTableCreateCompanionBuilder =
    StoredHeatingDeviceCatalogEntriesCompanion Function({
      required String id,
      required String payloadJson,
      required int updatedAtEpochMs,
      Value<int> rowid,
    });
typedef $$StoredHeatingDeviceCatalogEntriesTableUpdateCompanionBuilder =
    StoredHeatingDeviceCatalogEntriesCompanion Function({
      Value<String> id,
      Value<String> payloadJson,
      Value<int> updatedAtEpochMs,
      Value<int> rowid,
    });

class $$StoredHeatingDeviceCatalogEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $StoredHeatingDeviceCatalogEntriesTable> {
  $$StoredHeatingDeviceCatalogEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoredHeatingDeviceCatalogEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $StoredHeatingDeviceCatalogEntriesTable> {
  $$StoredHeatingDeviceCatalogEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoredHeatingDeviceCatalogEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoredHeatingDeviceCatalogEntriesTable> {
  $$StoredHeatingDeviceCatalogEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get payloadJson => $composableBuilder(
    column: $table.payloadJson,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAtEpochMs => $composableBuilder(
    column: $table.updatedAtEpochMs,
    builder: (column) => column,
  );
}

class $$StoredHeatingDeviceCatalogEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoredHeatingDeviceCatalogEntriesTable,
          StoredHeatingDeviceCatalogEntry,
          $$StoredHeatingDeviceCatalogEntriesTableFilterComposer,
          $$StoredHeatingDeviceCatalogEntriesTableOrderingComposer,
          $$StoredHeatingDeviceCatalogEntriesTableAnnotationComposer,
          $$StoredHeatingDeviceCatalogEntriesTableCreateCompanionBuilder,
          $$StoredHeatingDeviceCatalogEntriesTableUpdateCompanionBuilder,
          (
            StoredHeatingDeviceCatalogEntry,
            BaseReferences<
              _$AppDatabase,
              $StoredHeatingDeviceCatalogEntriesTable,
              StoredHeatingDeviceCatalogEntry
            >,
          ),
          StoredHeatingDeviceCatalogEntry,
          PrefetchHooks Function()
        > {
  $$StoredHeatingDeviceCatalogEntriesTableTableManager(
    _$AppDatabase db,
    $StoredHeatingDeviceCatalogEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoredHeatingDeviceCatalogEntriesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$StoredHeatingDeviceCatalogEntriesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$StoredHeatingDeviceCatalogEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> payloadJson = const Value.absent(),
                Value<int> updatedAtEpochMs = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StoredHeatingDeviceCatalogEntriesCompanion(
                id: id,
                payloadJson: payloadJson,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String payloadJson,
                required int updatedAtEpochMs,
                Value<int> rowid = const Value.absent(),
              }) => StoredHeatingDeviceCatalogEntriesCompanion.insert(
                id: id,
                payloadJson: payloadJson,
                updatedAtEpochMs: updatedAtEpochMs,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StoredHeatingDeviceCatalogEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoredHeatingDeviceCatalogEntriesTable,
      StoredHeatingDeviceCatalogEntry,
      $$StoredHeatingDeviceCatalogEntriesTableFilterComposer,
      $$StoredHeatingDeviceCatalogEntriesTableOrderingComposer,
      $$StoredHeatingDeviceCatalogEntriesTableAnnotationComposer,
      $$StoredHeatingDeviceCatalogEntriesTableCreateCompanionBuilder,
      $$StoredHeatingDeviceCatalogEntriesTableUpdateCompanionBuilder,
      (
        StoredHeatingDeviceCatalogEntry,
        BaseReferences<
          _$AppDatabase,
          $StoredHeatingDeviceCatalogEntriesTable,
          StoredHeatingDeviceCatalogEntry
        >,
      ),
      StoredHeatingDeviceCatalogEntry,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ProjectEntriesTableTableManager get projectEntries =>
      $$ProjectEntriesTableTableManager(_db, _db.projectEntries);
  $$StoredOpeningCatalogEntriesTableTableManager
  get storedOpeningCatalogEntries =>
      $$StoredOpeningCatalogEntriesTableTableManager(
        _db,
        _db.storedOpeningCatalogEntries,
      );
  $$StoredHeatingDeviceCatalogEntriesTableTableManager
  get storedHeatingDeviceCatalogEntries =>
      $$StoredHeatingDeviceCatalogEntriesTableTableManager(
        _db,
        _db.storedHeatingDeviceCatalogEntries,
      );
}

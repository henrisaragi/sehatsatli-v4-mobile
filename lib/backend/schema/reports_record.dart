import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class ReportsRecord extends FirestoreRecord {
  ReportsRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "clientId" field.
  String? _clientId;
  String get clientId => _clientId ?? '';
  bool hasClientId() => _clientId != null;

  // "speciesName" field.
  String? _speciesName;
  String get speciesName => _speciesName ?? '';
  bool hasSpeciesName() => _speciesName != null;

  // "healthStatus" field.
  String? _healthStatus;
  String get healthStatus => _healthStatus ?? '';
  bool hasHealthStatus() => _healthStatus != null;

  // "observationNotes" field.
  String? _observationNotes;
  String get observationNotes => _observationNotes ?? '';
  bool hasObservationNotes() => _observationNotes != null;

  // "latitude" field.
  double? _latitude;
  double get latitude => _latitude ?? 0.0;
  bool hasLatitude() => _latitude != null;

  // "longitude" field.
  double? _longitude;
  double get longitude => _longitude ?? 0.0;
  bool hasLongitude() => _longitude != null;

  // "timestamp" field.
  int? _timestamp;
  int get timestamp => _timestamp ?? 0;
  bool hasTimestamp() => _timestamp != null;

  // "status" field.
  String? _status;
  String get status => _status ?? '';
  bool hasStatus() => _status != null;

  // "reporterId" field.
  String? _reporterId;
  String get reporterId => _reporterId ?? '';
  bool hasReporterId() => _reporterId != null;

  // "lastSyncAt" field.
  DateTime? _lastSyncAt;
  DateTime? get lastSyncAt => _lastSyncAt;
  bool hasLastSyncAt() => _lastSyncAt != null;

  void _initializeFields() {
    _clientId = snapshotData['clientId'] as String?;
    _speciesName = snapshotData['speciesName'] as String?;
    _healthStatus = snapshotData['healthStatus'] as String?;
    _observationNotes = snapshotData['observationNotes'] as String?;
    _latitude = castToType<double>(snapshotData['latitude']);
    _longitude = castToType<double>(snapshotData['longitude']);
    _timestamp = castToType<int>(snapshotData['timestamp']);
    _status = snapshotData['status'] as String?;
    _reporterId = snapshotData['reporterId'] as String?;
    _lastSyncAt = snapshotData['lastSyncAt'] as DateTime?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('reports');

  static Stream<ReportsRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => ReportsRecord.fromSnapshot(s));

  static Future<ReportsRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => ReportsRecord.fromSnapshot(s));

  static ReportsRecord fromSnapshot(DocumentSnapshot snapshot) =>
      ReportsRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static ReportsRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      ReportsRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'ReportsRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is ReportsRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createReportsRecordData({
  String? clientId,
  String? speciesName,
  String? healthStatus,
  String? observationNotes,
  double? latitude,
  double? longitude,
  int? timestamp,
  String? status,
  String? reporterId,
  DateTime? lastSyncAt,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'clientId': clientId,
      'speciesName': speciesName,
      'healthStatus': healthStatus,
      'observationNotes': observationNotes,
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': timestamp,
      'status': status,
      'reporterId': reporterId,
      'lastSyncAt': lastSyncAt,
    }.withoutNulls,
  );

  return firestoreData;
}

class ReportsRecordDocumentEquality implements Equality<ReportsRecord> {
  const ReportsRecordDocumentEquality();

  @override
  bool equals(ReportsRecord? e1, ReportsRecord? e2) {
    return e1?.clientId == e2?.clientId &&
        e1?.speciesName == e2?.speciesName &&
        e1?.healthStatus == e2?.healthStatus &&
        e1?.observationNotes == e2?.observationNotes &&
        e1?.latitude == e2?.latitude &&
        e1?.longitude == e2?.longitude &&
        e1?.timestamp == e2?.timestamp &&
        e1?.status == e2?.status &&
        e1?.reporterId == e2?.reporterId &&
        e1?.lastSyncAt == e2?.lastSyncAt;
  }

  @override
  int hash(ReportsRecord? e) => const ListEquality().hash([
        e?.clientId,
        e?.speciesName,
        e?.healthStatus,
        e?.observationNotes,
        e?.latitude,
        e?.longitude,
        e?.timestamp,
        e?.status,
        e?.reporterId,
        e?.lastSyncAt
      ]);

  @override
  bool isValidKey(Object? o) => o is ReportsRecord;
}

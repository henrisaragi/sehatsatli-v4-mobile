import 'dart:async';

import 'package:collection/collection.dart';

import '/backend/schema/util/firestore_util.dart';
import '/backend/schema/util/schema_util.dart';

import 'index.dart';
import '/flutter_flow/flutter_flow_util.dart';

class MediaRecord extends FirestoreRecord {
  MediaRecord._(
    DocumentReference reference,
    Map<String, dynamic> data,
  ) : super(reference, data) {
    _initializeFields();
  }

  // "localPath" field.
  String? _localPath;
  String get localPath => _localPath ?? '';
  bool hasLocalPath() => _localPath != null;

  // "category" field.
  String? _category;
  String get category => _category ?? '';
  bool hasCategory() => _category != null;

  // "reportClientId" field.
  String? _reportClientId;
  String get reportClientId => _reportClientId ?? '';
  bool hasReportClientId() => _reportClientId != null;

  void _initializeFields() {
    _localPath = snapshotData['localPath'] as String?;
    _category = snapshotData['category'] as String?;
    _reportClientId = snapshotData['reportClientId'] as String?;
  }

  static CollectionReference get collection =>
      FirebaseFirestore.instance.collection('media');

  static Stream<MediaRecord> getDocument(DocumentReference ref) =>
      ref.snapshots().map((s) => MediaRecord.fromSnapshot(s));

  static Future<MediaRecord> getDocumentOnce(DocumentReference ref) =>
      ref.get().then((s) => MediaRecord.fromSnapshot(s));

  static MediaRecord fromSnapshot(DocumentSnapshot snapshot) => MediaRecord._(
        snapshot.reference,
        mapFromFirestore(snapshot.data() as Map<String, dynamic>),
      );

  static MediaRecord getDocumentFromData(
    Map<String, dynamic> data,
    DocumentReference reference,
  ) =>
      MediaRecord._(reference, mapFromFirestore(data));

  @override
  String toString() =>
      'MediaRecord(reference: ${reference.path}, data: $snapshotData)';

  @override
  int get hashCode => reference.path.hashCode;

  @override
  bool operator ==(other) =>
      other is MediaRecord &&
      reference.path.hashCode == other.reference.path.hashCode;
}

Map<String, dynamic> createMediaRecordData({
  String? localPath,
  String? category,
  String? reportClientId,
}) {
  final firestoreData = mapToFirestore(
    <String, dynamic>{
      'localPath': localPath,
      'category': category,
      'reportClientId': reportClientId,
    }.withoutNulls,
  );

  return firestoreData;
}

class MediaRecordDocumentEquality implements Equality<MediaRecord> {
  const MediaRecordDocumentEquality();

  @override
  bool equals(MediaRecord? e1, MediaRecord? e2) {
    return e1?.localPath == e2?.localPath &&
        e1?.category == e2?.category &&
        e1?.reportClientId == e2?.reportClientId;
  }

  @override
  int hash(MediaRecord? e) =>
      const ListEquality().hash([e?.localPath, e?.category, e?.reportClientId]);

  @override
  bool isValidKey(Object? o) => o is MediaRecord;
}

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:timeago/timeago.dart' as timeago;
import '/flutter_flow/custom_functions.dart';
import '/flutter_flow/lat_lng.dart';
import '/flutter_flow/place.dart';
import '/flutter_flow/uploaded_file.dart';
import '/backend/backend.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '/backend/sqlite/sqlite_manager.dart';

dynamic currentReport(
  List<ReportsRecord> reports,
  String reportId,
) {
  final r = reports
      .where((r) => r.reference.id == reportId)
      .firstOrNull
      ?.snapshotData;
  if (r == null) return {};
  return {
    "id": r['clientId'],
    "species": r['speciesName'],
    "status": r['status'],
    "notes": r['observationNotes'],
    "lat": r['latitude'],
    "lng": r['longitude'],
    "timestamp": r['timestamp'],
    "health": r['healthStatus'],
    "reporter": r['reporterId'],
    "sync_at": r['lastSyncAt']
  };
}

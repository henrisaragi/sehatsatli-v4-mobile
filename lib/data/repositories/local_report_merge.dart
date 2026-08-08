import 'dart:convert';

import '../../backend/sqlite/sqlite_manager.dart';

/// Applies a server request/response pair to `local_reports` for [clientId].
///
/// [performUpsertLocalReport] does a full-row replace — every call
/// overwrites `payload_json` wholesale and overwrites `server_id`/
/// `report_code` with whatever is passed (including null if omitted). That's
/// correct for a full-report save (Quick Report create, Full Report Tab 1
/// update), where [outgoingPayload] already *is* the complete report
/// snapshot. It is wrong for a Tab 2-4 section save, which only carries that
/// tab's fields — passed here with a `_sectionKey` marker so this function
/// merges it into the existing cached snapshot instead of clobbering the
/// other tabs' data, and never nulls out an already-known `server_id`/
/// `report_code` just because a particular response happens not to echo
/// them back.
///
/// Shared by [ReportRepository]'s immediate-send paths (`submit`,
/// `submitSection`) and [SyncRepository.runSyncQueue]'s deferred-send path,
/// so both behave identically regardless of whether a report was sent
/// immediately or drained from the offline queue later.
Future<void> applyServerResultToLocalReport({
  required String clientId,
  required Map<String, dynamic> outgoingPayload,
  required Map<String, dynamic> responseData,
  required String syncStatus,
}) async {
  final existing = await SQLiteManager.instance.getLocalReport(clientId);
  final existingPayload = existing?.payloadJson != null
      ? jsonDecode(existing!.payloadJson!) as Map<String, dynamic>
      : <String, dynamic>{};

  final sectionKey = outgoingPayload['_sectionKey'] as String?;
  final mergedPayload = sectionKey != null
      ? {
          ...existingPayload,
          sectionKey: {...outgoingPayload}
            ..remove('_sectionKey')
            ..remove('_resolveIdFromClientId'),
        }
      : outgoingPayload;

  await SQLiteManager.instance.upsertLocalReport(
    clientId: clientId,
    payloadJson: jsonEncode(mergedPayload),
    syncStatus: syncStatus,
    serverId: (responseData['id'] as int?) ?? existing?.serverId,
    reportCode: (responseData['report_code'] as String?) ?? existing?.reportCode,
  );
}

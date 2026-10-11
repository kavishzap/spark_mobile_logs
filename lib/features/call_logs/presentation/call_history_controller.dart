import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:spark_sales/app/dependencies.dart';
import 'package:spark_sales/features/call_logs/data/call_queue_repository.dart';
import 'package:spark_sales/features/call_logs/domain/call_record.dart';
import 'package:spark_sales/features/sync/presentation/sync_controller.dart';

class CallHistoryState {
  const CallHistoryState({
    required this.calls,
    this.type,
    this.preset = DateRangePreset.all,
    this.customStart,
    this.customEnd,
    this.search = '',
  });

  final List<CallRecord> calls;
  final CallType? type;
  final DateRangePreset preset;
  final DateTime? customStart;
  final DateTime? customEnd;
  final String search;
}

final callHistoryProvider =
    AsyncNotifierProvider<CallHistoryController, CallHistoryState>(
      CallHistoryController.new,
    );

class CallHistoryController extends AsyncNotifier<CallHistoryState> {
  CallType? _type;
  DateRangePreset _preset = DateRangePreset.all;
  DateTime? _customStart;
  DateTime? _customEnd;
  String _search = '';

  @override
  Future<CallHistoryState> build() async {
    ref.watch(syncGenerationProvider);
    return _load();
  }

  Future<void> setType(CallType? type) {
    _type = type;
    return _reload();
  }

  Future<void> setPreset(DateRangePreset preset) {
    _preset = preset;
    return _reload();
  }

  Future<void> setCustomRange(DateTime start, DateTime end) {
    _preset = DateRangePreset.custom;
    _customStart = start;
    _customEnd = end;
    return _reload();
  }

  Future<void> setSearch(String search) {
    _search = search;
    return _reload();
  }

  Future<void> _reload() async {
    state = AsyncData(await _load());
  }

  Future<CallHistoryState> _load() {
    final query = CallQuery.build(
      type: _type,
      preset: _preset,
      customStart: _customStart,
      customEnd: _customEnd,
      search: _search,
    );
    return ref.read(callQueueRepositoryProvider).search(query).then((calls) {
      return CallHistoryState(
        calls: calls,
        type: _type,
        preset: _preset,
        customStart: _customStart,
        customEnd: _customEnd,
        search: _search,
      );
    });
  }
}

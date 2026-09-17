/// Outcome of one drain pass.
class DrainResult {
  final int synced;
  final int rejected;
  final int conflicts;
  final int retries;

  const DrainResult({
    this.synced = 0,
    this.rejected = 0,
    this.conflicts = 0,
    this.retries = 0,
  });

  int get completed => synced + rejected + conflicts;
  bool get hadRetry => retries > 0;
  bool get hadConflict => conflicts > 0;
  bool get allClean => !hadRetry && !hadConflict;

  @override
  String toString() =>
      'DrainResult(synced: $synced, rejected: $rejected, '
      'conflicts: $conflicts, retries: $retries)';
}

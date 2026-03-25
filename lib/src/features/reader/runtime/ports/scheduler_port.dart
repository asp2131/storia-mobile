abstract interface class CancelableTask {
  void cancel();
}

abstract interface class SchedulerPort {
  CancelableTask schedule(Duration delay, void Function() action);
}

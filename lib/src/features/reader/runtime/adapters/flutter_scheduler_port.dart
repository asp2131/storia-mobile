import 'dart:async';

import '../ports/scheduler_port.dart';

class TimerCancelableTask implements CancelableTask {
  TimerCancelableTask(this._timer);

  final Timer _timer;

  @override
  void cancel() {
    _timer.cancel();
  }
}

class FlutterSchedulerPort implements SchedulerPort {
  @override
  CancelableTask schedule(Duration delay, void Function() action) {
    final timer = Timer(delay, action);
    return TimerCancelableTask(timer);
  }
}

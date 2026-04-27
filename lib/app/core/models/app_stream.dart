import 'package:rxdart/rxdart.dart';

class AppStream<T> {
  late final T t;
  AppStream() {
    controller = BehaviorSubject<T>();
  }

  AppStream.seed(this.t) {
    controller = BehaviorSubject<T>.seeded(t);
  }

  late final BehaviorSubject<T> controller;
  void add(T e) => controller.sink.add(e);
  Stream<T> get listen => controller.stream;
  T get value => controller.stream.value;
  T? get valueOrNull => controller.valueOrNull;
  bool get hasValue => controller.hasValue;
  void update() => controller.sink.add(controller.value);
}

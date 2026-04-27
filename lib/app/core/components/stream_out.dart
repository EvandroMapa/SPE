import 'package:acoplan/app/core/components/loading.dart';
import 'package:flutter/material.dart';

class StreamOut<T> extends StatelessWidget {
  final Stream<T> stream;
  final Widget Function(BuildContext context, T data) builder;
  final Widget loading;

  const StreamOut({
    super.key,
    required this.stream,
    required this.builder,
    this.loading = const LoadingStreamOut(),
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T>(
      stream: stream,
      builder: (value, snapshot) {
        if (snapshot.connectionState == ConnectionState.active ||
            snapshot.hasData) {
          if (snapshot.data != null) {
            return builder(value, snapshot.requireData);
          } else {
            return loading;
          }
        } else {
          return loading;
        }
      },
    );
  }
}

class StreamOutNull<T> extends StatelessWidget {
  final Stream<T?> stream;
  final Widget Function(BuildContext context, T? data) child;
  final Widget loading;

  const StreamOutNull({
    super.key,
    required this.stream,
    required this.child,
    this.loading = const SizedBox(),
  });

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<T?>(
      stream: stream,
      builder: (BuildContext value, AsyncSnapshot<T?> snapshot) {
        if (snapshot.connectionState == ConnectionState.active ||
            snapshot.hasData) {
          return child(value, snapshot.data);
        } else {
          return loading;
        }
      },
    );
  }
}

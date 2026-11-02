import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class HistoryAction extends StatelessWidget {
  const HistoryAction({super.key, required this.module, this.entity});
  final String module;
  final String? entity;
  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: 'History',
    icon: const Icon(Icons.history_rounded),
    onPressed: () => context.push(
      Uri(
        path: '/history',
        queryParameters: {'module': module, 'entity': ?entity},
      ).toString(),
    ),
  );
}

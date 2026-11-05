import 'package:flutter/material.dart';

import 'services/stream_resolver.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'ui/home_screen.dart';

class ExpeditusApp extends StatelessWidget {
  const ExpeditusApp({super.key, required this.state, this.playerResolver});

  final AppState state;
  final Future<ResolvedStream> Function(String videoId)? playerResolver;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expeditus',
      debugShowCheckedModeBanner: false,
      theme: expeditusTheme(),
      home: HomeScreen(state: state, playerResolver: playerResolver),
    );
  }
}

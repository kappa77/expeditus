import 'package:flutter/material.dart';

import 'services/stream_resolver.dart';
import 'state/app_state.dart';
import 'theme.dart';
import 'ui/home_screen.dart';
import 'ui/welcome_screen.dart';

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
      home: _RootGate(state: state, playerResolver: playerResolver),
    );
  }
}


class _RootGate extends StatelessWidget {
  const _RootGate({required this.state, this.playerResolver});

  final AppState state;
  final Future<ResolvedStream> Function(String videoId)? playerResolver;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        if (state.loading) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (state.channels.isEmpty && !state.onboardingSeen) {
          return WelcomeScreen(state: state);
        }
        return HomeScreen(state: state, playerResolver: playerResolver);
      },
    );
  }
}

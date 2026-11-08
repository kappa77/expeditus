import 'dart:io' show Platform;

import 'package:flutter/widgets.dart';

/// Runtime platform detection.
///
/// `defaultTargetPlatform` is forced to Android in Flutter's test runner, so
/// `dart:io` is the reliable source for both the app and the host tests.
bool get isAndroid => Platform.isAndroid;

/// True for Android and iOS. Used for wording and for hiding desktop-only
/// integrations (DLNA casting, Windows installer updates).
bool get isMobilePlatform => Platform.isAndroid || Platform.isIOS;

/// True on the platforms where the current release assets are Windows
/// installers.
bool get usesWindowsInstaller => Platform.isWindows;

/// The update check only knows how to offer a Windows installer. On Android
/// the store (or a future APK channel) owns updates, so the desktop flow is
/// hidden instead of leading to an .exe download.
bool get supportsDesktopUpdates => !isMobilePlatform;

/// DLNA casting is available on desktop and on Android (which holds a
/// multicast lock during discovery). The Windows Firewall helper is a no-op
/// on other platforms.
bool get supportsDlnaCast => true;

/// Default shell breakpoint. The desktop layout needs roughly 860dp to keep
/// the sidebar and the single-row header from overflowing.
const double compactBreakpoint = 860;

bool isCompactWidth(BuildContext context) {
  final size = MediaQuery.sizeOf(context);
  return size.width < compactBreakpoint || size.height < 480;
}

/// Wording helpers for the local-video copy.
String get deviceNoun => isMobilePlatform ? 'dispositivo' : 'computer';
String get onDeviceLabel =>
    isMobilePlatform ? 'sul dispositivo' : 'sul computer';
String get fromDeviceLabel =>
    isMobilePlatform ? 'dal dispositivo' : 'dal computer';

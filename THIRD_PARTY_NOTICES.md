# Third-party notices

Expeditus itself is released under the MIT License (see [LICENSE](LICENSE)).

This file lists the third-party components shipped with the Windows build and the license families of the Dart/Flutter dependencies. It is provided for transparency; it is not legal advice.

## Native components

| Component | Version | License | Notes |
|---|---|---|---|
| libmpv (`libmpv-2.dll`) | 0.36.0-403-g652a1dd907 | **GPL-2.0-or-later** | [mpv source](https://github.com/mpv-player/mpv/tree/652a1dd907) · [build](https://github.com/media-kit/libmpv-win32-video-build) · [GPL text](LICENSES/GPL-2.0.txt) |
| FFmpeg and codec libraries (bundled in libmpv) | see libmpv build | **GPL-2.0-or-later** | Exact revisions are pinned by the [libmpv build scripts](https://github.com/media-kit/libmpv-win32-video-build) |
| ANGLE (`libEGL.dll`, `libGLESv2.dll`) | 2022 build | BSD-3-Clause | [ANGLE](https://github.com/google/angle) · [license](LICENSES/ANGLE-BSD-3-Clause.txt) |
| SwiftShader (`vk_swiftshader.dll`) | 2022 build | Apache-2.0 | [SwiftShader](https://github.com/google/swiftshader) · [license](LICENSES/Apache-2.0.txt) |
| Vulkan loader (`vulkan-1.dll`) | 2022 build | Apache-2.0 | [Vulkan-Loader](https://github.com/KhronosGroup/Vulkan-Loader) · [license](LICENSES/Apache-2.0.txt) |
| zlib (`zlib.dll`) | 2022 build | Zlib | [zlib](https://zlib.net) · [license](LICENSES/Zlib.txt) |
| `d3dcompiler_47.dll` | Microsoft | Microsoft DirectX redistributable | Redistributed as part of the ANGLE package under Microsoft’s terms |
| Microsoft Visual C++ Runtime (`msvcp140.dll`, `vcruntime140.dll`, `vcruntime140_1.dll`) | bundled | Microsoft Visual Studio redistributable | App-local deployment under Microsoft’s redistribution terms |
| SQLite (`sqlite3.dll`) | bundled | Public domain | [SQLite copyright](https://sqlite.org/copyright.html) |
| Flutter engine (`flutter_windows.dll`, `dartjni.dll`, ICU data) | Flutter 3.47.7 | BSD-3-Clause | [Flutter license](LICENSES/Flutter-BSD-3-Clause.txt) |

### GPL source offer

Expeditus includes **libmpv** and the FFmpeg/codec libraries linked into that libmpv build under **GPL-2.0-or-later**. The corresponding source code is available at:

- mpv, exact revision: <https://github.com/mpv-player/mpv/tree/652a1dd907>
- libmpv Windows build scripts: <https://github.com/media-kit/libmpv-win32-video-build>
- FFmpeg and codec sources: the revisions pinned by those build scripts

For a period of three years from the date of distribution, the distributor offers to provide the complete corresponding source code for the GPL-covered components on physical media for no more than the cost of distribution. Contact: <https://github.com/kappa77/expeditus/issues>.

The MIT license of Expeditus itself is compatible with the GPL for this distribution, but the combined installer includes GPL-covered components. If you need a permissive-only build, replace the libmpv backend with an LGPL build or a different playback backend.

## Dart and Flutter packages

Flutter bundles the full license texts of the Dart/Flutter packages in `data/flutter_assets/NOTICES.Z`; the app exposes them under **Settings → Open source licenses**. The table below lists the package license families.

| Package | Version | Dependency | License |
|---|---|---|---|
| `archive` | 4.6.0 | transitive | MIT + third-party (MIT/BSD/Zlib/Apache-2.0) |
| `args` | 2.7.0 | transitive | BSD-3-Clause |
| `async` | 2.13.1 | transitive | BSD-3-Clause |
| `boolean_selector` | 2.1.2 | transitive | BSD-3-Clause |
| `characters` | 1.4.1 | transitive | BSD-3-Clause |
| `clock` | 1.1.3 | transitive | Apache-2.0 |
| `cnativeapi` | 0.5.10 | transitive | MIT |
| `code_assets` | 2.1.0 | transitive | BSD-3-Clause |
| `collection` | 1.19.1 | transitive | BSD-3-Clause |
| `cross_file` | 0.3.5+5 | transitive | BSD-3-Clause |
| `crypto` | 3.0.8 | transitive | BSD-3-Clause |
| `csslib` | 1.0.2 | transitive | BSD-3-Clause |
| `csv` | 8.0.0 | direct main | MIT |
| `cupertino_icons` | 1.0.9 | direct main | MIT |
| `dbus` | 0.8.0 | transitive | MPL-2.0 |
| `fake_async` | 1.3.3 | transitive | Apache-2.0 |
| `ffi` | 2.2.0 | transitive | BSD-3-Clause |
| `ffi_leak_tracker` | 0.1.2 | transitive | BSD-3-Clause |
| `file` | 7.0.1 | transitive | BSD-3-Clause |
| `file_selector` | 1.1.0 | direct main | BSD-3-Clause |
| `file_selector_android` | 0.5.2+11 | transitive | Apache-2.0 |
| `file_selector_ios` | 0.5.3+7 | transitive | BSD-3-Clause |
| `file_selector_linux` | 0.9.4+1 | transitive | BSD-3-Clause |
| `file_selector_macos` | 0.9.5+2 | transitive | BSD-3-Clause |
| `file_selector_platform_interface` | 2.7.0 | transitive | BSD-3-Clause |
| `file_selector_web` | 0.9.5 | transitive | BSD-3-Clause |
| `file_selector_windows` | 0.9.3+6 | transitive | BSD-3-Clause |
| `fixnum` | 1.1.1 | transitive | BSD-3-Clause |
| `flutter` | SDK | direct main | BSD-3-Clause |
| `flutter_driver` | SDK | transitive dev | BSD-3-Clause |
| `flutter_lints` | 6.0.0 | direct dev | BSD-3-Clause |
| `flutter_test` | SDK | direct dev | BSD-3-Clause |
| `flutter_web_plugins` | SDK | transitive | BSD-3-Clause |
| `freezed_annotation` | 3.1.0 | transitive | MIT |
| `fuchsia_remote_debug_protocol` | SDK | transitive dev | BSD-3-Clause |
| `glob` | 2.2.0 | transitive | BSD-3-Clause |
| `hooks` | 2.2.0 | transitive | BSD-3-Clause |
| `html` | 0.15.7 | transitive | MIT |
| `http` | 1.6.0 | direct main | BSD-3-Clause |
| `http_parser` | 4.1.2 | transitive | BSD-3-Clause |
| `image` | 4.12.0 | transitive | MIT + third-party (MIT/BSD/Zlib/Apache-2.0) |
| `integration_test` | SDK | direct dev | BSD-3-Clause |
| `intl` | 0.20.3 | direct main | BSD-3-Clause |
| `jni` | 1.1.2 | transitive | BSD-3-Clause |
| `jni_flutter` | 1.0.4+1 | transitive | BSD-3-Clause |
| `jni_util` | 1.0.0 | transitive | BSD-3-Clause |
| `json_annotation` | 4.12.0 | transitive | BSD-3-Clause |
| `leak_tracker` | 11.0.2 | transitive | BSD-3-Clause |
| `leak_tracker_flutter_testing` | 3.0.10 | transitive | BSD-3-Clause |
| `leak_tracker_testing` | 3.0.2 | transitive | BSD-3-Clause |
| `lints` | 6.1.0 | transitive | BSD-3-Clause |
| `logging` | 1.3.0 | transitive | BSD-3-Clause |
| `matcher` | 0.12.20 | transitive | BSD-3-Clause |
| `material_color_utilities` | 0.13.0 | transitive | Apache-2.0 |
| `media_kit` | 1.2.6 | direct main | MIT |
| `media_kit_libs_android_video` | 1.3.8 | transitive | MIT (package; native binaries have separate licenses) |
| `media_kit_libs_ios_video` | 1.1.4 | transitive | MIT (package; native binaries have separate licenses) |
| `media_kit_libs_linux` | 1.2.1 | transitive | MIT (package; native binaries have separate licenses) |
| `media_kit_libs_macos_video` | 1.1.4 | transitive | MIT (package; native binaries have separate licenses) |
| `media_kit_libs_video` | 1.0.7 | direct main | MIT (package; native binaries have separate licenses) |
| `media_kit_libs_windows_video` | 1.0.11 | transitive | MIT (package; native binaries have separate licenses) |
| `media_kit_video` | 2.0.1 | direct main | MIT |
| `meta` | 1.19.0 | transitive | BSD-3-Clause |
| `native_toolchain_c` | 0.19.5 | transitive | BSD-3-Clause |
| `nativeapi` | 0.5.10 | transitive | MIT |
| `nativeapi_flutter` | 0.5.10 | transitive | MIT |
| `objective_c` | 9.6.2 | transitive | BSD-3-Clause |
| `package_config` | 3.0.0 | transitive | BSD-3-Clause |
| `package_info_plus` | 10.2.2 | transitive | BSD-3-Clause |
| `package_info_plus_platform_interface` | 4.1.0 | transitive | BSD-3-Clause |
| `path` | 1.9.1 | direct main | BSD-3-Clause |
| `path_provider` | 2.1.6 | direct main | BSD-3-Clause |
| `path_provider_android` | 2.3.1 | transitive | BSD-3-Clause |
| `path_provider_foundation` | 2.6.0 | transitive | BSD-3-Clause |
| `path_provider_linux` | 2.2.2 | transitive | BSD-3-Clause |
| `path_provider_platform_interface` | 2.1.3 | transitive | BSD-3-Clause |
| `path_provider_windows` | 2.3.0 | transitive | BSD-3-Clause |
| `petitparser` | 7.1.0 | transitive | MIT |
| `platform` | 3.2.0 | transitive | BSD-3-Clause |
| `plugin_platform_interface` | 2.1.8 | transitive | BSD-3-Clause |
| `posix` | 6.5.4 | transitive | MIT |
| `process` | 5.0.6 | transitive | BSD-3-Clause |
| `pub_semver` | 2.2.1 | transitive | BSD-3-Clause |
| `record_use` | 1.1.1 | transitive | BSD-3-Clause |
| `safe_local_storage` | 2.0.7 | transitive | MIT |
| `simple_sparse_list` | 0.1.4 | transitive | BSD-3-Clause |
| `sky_engine` | SDK | transitive | BSD-3-Clause |
| `source_span` | 1.10.2 | transitive | BSD-3-Clause |
| `sqflite_common` | 2.5.15 | transitive | BSD-2-Clause |
| `sqflite_common_ffi` | 2.4.5 | direct main | BSD-2-Clause |
| `sqlite3` | 3.9.0 | transitive | MIT (SQLite itself is public domain) |
| `sqlite3_flutter_libs` | 0.6.0+eol | direct main | MIT (SQLite itself is public domain) |
| `stack_trace` | 1.12.2 | transitive | BSD-3-Clause |
| `stream_channel` | 2.1.4 | transitive | BSD-3-Clause |
| `string_scanner` | 1.4.1 | transitive | BSD-3-Clause |
| `sync_http` | 0.3.1 | transitive | BSD-3-Clause |
| `synchronized` | 3.6.1 | transitive | MIT |
| `term_glyph` | 1.2.2 | transitive | BSD-3-Clause |
| `test_api` | 0.7.12 | transitive | BSD-3-Clause |
| `typed_data` | 1.4.0 | transitive | BSD-3-Clause |
| `unicode` | 1.1.9 | transitive | BSD-3-Clause |
| `universal_platform` | 1.1.0 | transitive | MIT |
| `uri_parser` | 3.0.2 | transitive | MIT |
| `url_launcher` | 6.3.3 | direct main | BSD-3-Clause |
| `url_launcher_android` | 6.3.33 | transitive | BSD-3-Clause |
| `url_launcher_ios` | 6.4.2 | transitive | BSD-3-Clause |
| `url_launcher_linux` | 3.2.3 | transitive | BSD-3-Clause |
| `url_launcher_macos` | 3.2.6 | transitive | BSD-3-Clause |
| `url_launcher_platform_interface` | 2.3.2 | transitive | BSD-3-Clause |
| `url_launcher_web` | 2.4.3 | transitive | BSD-3-Clause |
| `url_launcher_windows` | 3.1.6 | transitive | BSD-3-Clause |
| `uuid` | 4.6.0 | transitive | MIT |
| `vector_math` | 2.4.0 | transitive | BSD-3-Clause |
| `vm_service` | 15.4.0 | transitive | BSD-3-Clause |
| `wakelock_plus` | 1.8.2 | transitive | BSD-3-Clause |
| `wakelock_plus_platform_interface` | 1.7.0 | transitive | BSD-3-Clause |
| `web` | 1.1.2 | transitive | BSD-3-Clause |
| `webdriver` | 3.2.0 | transitive | Apache-2.0 |
| `win32` | 6.4.0 | transitive | BSD-3-Clause |
| `window_manager` | 0.6.0 | direct main | MIT |
| `xdg_directories` | 1.1.0 | transitive | BSD-3-Clause |
| `xml` | 6.6.1 | direct main | MIT |
| `yaml` | 3.1.4 | transitive | MIT |
| `youtube_explode_dart` | 3.1.0 | direct main | BSD-3-Clause |

Platform-specific packages that are not present in the Windows bundle (for example Android/iOS/Linux implementations) are listed here because they are part of the dependency graph, but their binaries are not shipped in the Windows installer.

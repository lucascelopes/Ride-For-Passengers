// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'loc_stream_holder.dart';

Future<void> stopLocationStreamSimple(BuildContext context) async {
  try {
    if (LocStreamHolderSimple.callback != null) {
      bg.BackgroundGeolocation.removeListener(
          LocStreamHolderSimple.callback!);
      LocStreamHolderSimple.callback = null;
    }
    await bg.BackgroundGeolocation.stop();
  } catch (_) {}
}

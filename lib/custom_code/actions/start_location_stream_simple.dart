// Automatic FlutterFlow imports
import '/backend/backend.dart';
import '/flutter_flow/flutter_flow_theme.dart';
import '/flutter_flow/flutter_flow_util.dart';
import 'index.dart'; // Imports other custom actions
import '/flutter_flow/custom_functions.dart'; // Imports custom functions
import 'package:flutter/material.dart';
// Begin custom action code
// DO NOT REMOVE OR MODIFY THE CODE ABOVE!

import '/custom_code/actions/index.dart';

import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;
import 'loc_stream_holder.dart';

/// Requisitos no FFAppState:
/// double currentLat = 0;
/// double currentLng = 0;
/// DateTime? locationTimestamp;
/// String locationStatus = 'idle';
Future<void> startLocationStreamSimple(BuildContext context) async {
  // Configuração inicial do plugin
  await bg.BackgroundGeolocation.ready(bg.Config(
    desiredAccuracy: bg.Config.DESIRED_ACCURACY_HIGH,
    distanceFilter: 5.0,
    stopOnTerminate: false,
    startOnBoot: true,
  ));

  // Remove callback anterior, se existir
  if (LocStreamHolderSimple.callback != null) {
    bg.BackgroundGeolocation.removeListener(
        LocStreamHolderSimple.callback!);
  }

  // Escuta atualizações de localização
  LocStreamHolderSimple.callback = (bg.Location location) {
    FFAppState().currentLat = location.coords.latitude;
    FFAppState().currentLng = location.coords.longitude;
    FFAppState().locationTimestamp = DateTime.now();
  };

  bg.BackgroundGeolocation.onLocation(
      LocStreamHolderSimple.callback!, (bg.LocationError error) {
    FFAppState().locationStatus = 'denied';
  });

  FFAppState().locationStatus = 'ok';

  // Inicia o monitoramento
  await bg.BackgroundGeolocation.start();

  // Posição inicial rápida
  try {
    final loc = await bg.BackgroundGeolocation.getCurrentPosition(
        persist: false);
    FFAppState().currentLat = loc.coords.latitude;
    FFAppState().currentLng = loc.coords.longitude;
    FFAppState().locationTimestamp = DateTime.now();
  } catch (_) {}
}

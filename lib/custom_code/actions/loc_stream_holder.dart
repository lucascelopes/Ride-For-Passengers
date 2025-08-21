import 'package:flutter_background_geolocation/flutter_background_geolocation.dart'
    as bg;

/// Holds a reference to the location callback so it can be removed later.
class LocStreamHolderSimple {
  static Function(bg.Location)? callback;
}


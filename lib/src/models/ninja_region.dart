/// Region enum for multi-region support
///
/// Defines supported regions for the InAppNinja SDK
enum NinjaRegion {
  /// United States
  US,

  /// European Union
  EU,

  /// India
  IN,

  /// Australia
  AU,

  /// Singapore
  SG,

  /// United Kingdom
  UK,
}

/// Extension to convert region enum to string
extension NinjaRegionExtension on NinjaRegion {
  String get value {
    switch (this) {
      case NinjaRegion.US:
        return 'US';
      case NinjaRegion.EU:
        return 'EU';
      case NinjaRegion.IN:
        return 'IN';
      case NinjaRegion.AU:
        return 'AU';
      case NinjaRegion.SG:
        return 'SG';
      case NinjaRegion.UK:
        return 'UK';
    }
  }

  String get name {
    switch (this) {
      case NinjaRegion.US:
        return 'United States';
      case NinjaRegion.EU:
        return 'European Union';
      case NinjaRegion.IN:
        return 'India';
      case NinjaRegion.AU:
        return 'Australia';
      case NinjaRegion.SG:
        return 'Singapore';
      case NinjaRegion.UK:
        return 'United Kingdom';
    }
  }
}

/// Parse string to NinjaRegion
NinjaRegion? parseNinjaRegion(String value) {
  switch (value.toUpperCase()) {
    case 'US':
      return NinjaRegion.US;
    case 'EU':
      return NinjaRegion.EU;
    case 'IN':
      return NinjaRegion.IN;
    case 'AU':
      return NinjaRegion.AU;
    case 'SG':
      return NinjaRegion.SG;
    case 'UK':
      return NinjaRegion.UK;
    default:
      return null;
  }
}

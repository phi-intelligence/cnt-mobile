/// Model for storing location selection results from the map picker
class LocationResult {
  final String address;
  final double latitude;
  final double longitude;

  const LocationResult({
    required this.address,
    required this.latitude,
    required this.longitude,
  });

  /// Create from a map (for JSON deserialization)
  factory LocationResult.fromJson(Map<String, dynamic> json) {
    return LocationResult(
      address: json['address'] as String? ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
    );
  }

  /// Convert to a map (for JSON serialization)
  Map<String, dynamic> toJson() {
    return {
      'address': address,
      'latitude': latitude,
      'longitude': longitude,
    };
  }

  /// Check if location has valid coordinates
  bool get hasValidCoordinates => 
      latitude != 0.0 && longitude != 0.0;

  /// Get a short display string
  String get shortDisplay {
    if (address.isNotEmpty) {
      // Return first part of address (before first comma)
      final parts = address.split(',');
      return parts.first.trim();
    }
    return 'Lat: ${latitude.toStringAsFixed(4)}, Lng: ${longitude.toStringAsFixed(4)}';
  }

  @override
  String toString() => 'LocationResult(address: $address, lat: $latitude, lng: $longitude)';

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is LocationResult &&
        other.address == address &&
        other.latitude == latitude &&
        other.longitude == longitude;
  }

  @override
  int get hashCode => Object.hash(address, latitude, longitude);
}


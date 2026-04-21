// ─────────────────────────────────────────────────────────────────────────────
//  ev_pricing.dart  —  EV Charging Pricing & Estimation Engine
//
//  FORMULA EXPLAINED:
//  ─────────────────
//  Step 1 — Base rate per kWh (₹):
//    India average grid cost = ₹8/kWh
//    Station operator markup = 50%  → ₹12/kWh base
//
//  Step 2 — Vehicle type multiplier:
//    Scooty / 2-wheeler  → ×0.8   (smaller battery, lower draw, cheaper)
//    Auto / 3-wheeler    → ×1.0   (medium, baseline)
//    Car / 4-wheeler     → ×1.3   (larger battery, faster charger, premium)
//
//  Step 3 — Connector type surcharge:
//    Type 1 / Type 2 (AC slow)  → ×1.0   (standard)
//    CCS2 / CHAdeMO (DC fast)   → ×1.4   (fast charging premium)
//    GB/T                        → ×1.1
//    Other                       → ×1.0
//
//  Step 4 — Power (kW) tier bonus:
//    ≤ 7.2 kW   → ×1.0   (home/slow AC)
//    ≤ 22 kW    → ×1.1   (semi-fast AC)
//    ≤ 50 kW    → ×1.25  (fast DC)
//    > 50 kW    → ×1.5   (ultra-fast DC)
//
//  FINAL price per hour = base_rate × vehicle_mult × connector_mult × kW_mult
//                       × powerKW  (energy delivered per hour)
//  Capped at ₹20 min, ₹500 max per hour.
//
//  Estimated charging time:
//    Battery capacity per vehicle type (kWh):
//      Scooty → 2.5 kWh typical
//      Auto   → 8   kWh typical
//      Car    → 40  kWh typical
//    Energy needed = capacity × (1 - batteryPercent/100)
//    Charging time (hrs) = energyNeeded / effectiveKW
//    effectiveKW = min(chargerKW, vehicle_max_kW) × 0.85 efficiency factor
// ─────────────────────────────────────────────────────────────────────────────

enum VehicleType { scooty, auto, car }

class EVPricingResult {
  final double pricePerHour;   // ₹/hr
  final double totalPrice;     // ₹ for selected duration
  final double estimatedHours; // how long to reach 100% from current battery
  final double energyNeeded;   // kWh needed
  final String breakdown;      // human-readable explanation

  const EVPricingResult({
    required this.pricePerHour,
    required this.totalPrice,
    required this.estimatedHours,
    required this.energyNeeded,
    required this.breakdown,
  });
}

class EVPricing {
  static const double _baseRatePerKwh = 12.0; // ₹12/kWh

  // ── Vehicle multipliers ───────────────────────────────────────────────────
  static double vehicleMultiplier(VehicleType type) {
    switch (type) {
      case VehicleType.scooty: return 0.8;
      case VehicleType.auto:   return 1.0;
      case VehicleType.car:    return 1.3;
    }
  }

  // ── Vehicle battery capacity (kWh) ───────────────────────────────────────
  static double batteryCapacityKwh(VehicleType type) {
    switch (type) {
      case VehicleType.scooty: return 2.5;
      case VehicleType.auto:   return 8.0;
      case VehicleType.car:    return 40.0;
    }
  }

  // ── Max AC/DC input rate per vehicle (kW) ────────────────────────────────
  static double maxChargeRateKw(VehicleType type) {
    switch (type) {
      case VehicleType.scooty: return 3.3;
      case VehicleType.auto:   return 7.2;
      case VehicleType.car:    return 150.0;
    }
  }

  // ── Connector multiplier ──────────────────────────────────────────────────
  static double connectorMultiplier(String connectorType) {
    final c = connectorType.toLowerCase();
    if (c.contains('ccs') || c.contains('chademo')) return 1.4;
    if (c.contains('gb/t')) return 1.1;
    return 1.0; // Type 1, Type 2, other
  }

  // ── Power tier multiplier ─────────────────────────────────────────────────
  static double powerTierMultiplier(double powerKw) {
    if (powerKw <= 7.2)  return 1.0;
    if (powerKw <= 22)   return 1.1;
    if (powerKw <= 50)   return 1.25;
    return 1.5;
  }

  // ── Vehicle label ─────────────────────────────────────────────────────────
  static String vehicleLabel(VehicleType type) {
    switch (type) {
      case VehicleType.scooty: return '2-Wheeler / Scooty';
      case VehicleType.auto:   return '3-Wheeler / Auto';
      case VehicleType.car:    return '4-Wheeler / Car';
    }
  }

  // ── MAIN CALCULATION ──────────────────────────────────────────────────────
  static EVPricingResult calculate({
    required VehicleType vehicleType,
    required String connectorType,
    required double powerKw,
    required int batteryPercent,     // 0–100, current battery level
    required int durationHours,
  }) {
    // Clamp inputs
    final kw = powerKw.clamp(1.0, 500.0);
    final bat = batteryPercent.clamp(0, 100);

    final vMult  = vehicleMultiplier(vehicleType);
    final cMult  = connectorMultiplier(connectorType);
    final pMult  = powerTierMultiplier(kw);

    // Price per hour = base × multipliers × kW (energy delivered per hour)
    double rawPricePerHour = _baseRatePerKwh * vMult * cMult * pMult * kw;

    // Cap between ₹20 and ₹500 per hour
    final pricePerHour = rawPricePerHour.clamp(20.0, 500.0);
    final totalPrice   = pricePerHour * durationHours;

    // Charging time estimate
    final capacity     = batteryCapacityKwh(vehicleType);
    final energyNeeded = capacity * (1 - bat / 100.0);
    final maxVehicleKw = maxChargeRateKw(vehicleType);
    final effectiveKw  = (kw < maxVehicleKw ? kw : maxVehicleKw) * 0.85;
    final estHours     = effectiveKw > 0 ? energyNeeded / effectiveKw : 0.0;

    final breakdown = '''
Vehicle: ${vehicleLabel(vehicleType)}
Charger: ${kw.toStringAsFixed(1)} kW  |  Connector: $connectorType
Current battery: $bat%  →  Need ${energyNeeded.toStringAsFixed(2)} kWh
Effective charge rate: ${effectiveKw.toStringAsFixed(2)} kW (85% efficiency)
Est. full charge time: ${estHours.toStringAsFixed(1)} hrs
─────────────────────────
Rate: ₹$_baseRatePerKwh/kWh × ${vMult}x (vehicle) × ${cMult}x (connector) × ${pMult}x (power tier) × ${kw.toStringAsFixed(1)} kW
= ₹${pricePerHour.toStringAsFixed(0)}/hour
Total for $durationHours hr: ₹${totalPrice.toStringAsFixed(0)}''';

    return EVPricingResult(
      pricePerHour: pricePerHour,
      totalPrice: totalPrice,
      estimatedHours: estHours,
      energyNeeded: energyNeeded,
      breakdown: breakdown,
    );
  }
}
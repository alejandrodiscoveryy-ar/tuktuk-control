/// Regla unica para mostrar, validar y guardar capacidades del vehiculo.
/// Los servicios elegidos, no las capacidades residuales, determinan el uso.
bool marketplaceNeedsPassengerCapacity(Set<String> services) =>
    services.contains('passenger') || services.contains('tourism');

bool marketplaceNeedsCargoCapacity(Set<String> services) =>
    services.contains('cargo');

const int marketplaceMaxPassengerCapacity = 99;

int marketplacePassengerLimit(String? category) =>
    category == 'motorcycle' ? 2 : marketplaceMaxPassengerCapacity;

bool marketplaceValidPassengerCapacity(int? value, String? category) =>
    value != null && value >= 1 && value <= marketplacePassengerLimit(category);

/// Una motocicleta admite por defecto un pasajero aparte del conductor.
/// Si no ofrece pasajeros o turismo, no anuncia plazas.
int? marketplaceResolvedPassengerCapacity({
  required String? vehicleCategory,
  required Set<String> services,
  required int? enteredCapacity,
}) {
  if (!marketplaceNeedsPassengerCapacity(services)) return null;
  if (vehicleCategory == 'motorcycle') return enteredCapacity ?? 1;
  return enteredCapacity;
}

/// Mensajeria no obliga a declarar capacidad de carga pesada.
double? marketplaceResolvedCargoCapacity({
  required Set<String> services,
  required double? enteredCapacity,
}) {
  if (!marketplaceNeedsCargoCapacity(services)) return null;
  return enteredCapacity;
}

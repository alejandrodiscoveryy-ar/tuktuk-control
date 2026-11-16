import 'package:control_tuk_tuk/domain/marketplace_vehicle_capacity_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chapa obligatoria para nuevas altas matriculables', () {
    for (final category in ['car', 'light_car', 'motorcycle', 'tricycle', 'van', 'truck']) {
      expect(marketplaceRequiresVehicleRegistration(
        category: category, propulsion: 'electric',
        previouslyOperational: false, savedRegistration: null,
      ), isTrue);
    }
  });

  test('bicicletas, bicitaxis y propulsión humana quedan exentos', () {
    for (final category in ['bicycle', 'bicitaxi', 'tricycle']) {
      expect(marketplaceRequiresVehicleRegistration(
        category: category, propulsion: 'human',
        previouslyOperational: false, savedRegistration: null,
      ), isFalse);
    }
    expect(marketplaceRequiresVehicleRegistration(
      category: 'bicitaxi', propulsion: null,
      previouslyOperational: false, savedRegistration: null,
    ), isFalse);
  });

  test('vehículo operativo sin chapa conserva excepción; con chapa no puede borrarla', () {
    expect(marketplaceRequiresVehicleRegistration(
      category: 'car', propulsion: 'combustion',
      previouslyOperational: true, savedRegistration: null,
    ), isFalse);
    expect(marketplaceRequiresVehicleRegistration(
      category: 'car', propulsion: 'combustion',
      previouslyOperational: true, savedRegistration: 'P123456',
    ), isTrue);
  });

  test('motocicleta de pasajeros recibe una plaza sin escribirla', () {
    expect(
      marketplaceResolvedPassengerCapacity(
        vehicleCategory: 'motorcycle',
        services: {'passenger'},
        enteredCapacity: null,
      ),
      1,
    );
    expect(
      marketplaceResolvedPassengerCapacity(
        vehicleCategory: 'motorcycle',
        services: {'tourism'},
        enteredCapacity: null,
      ),
      1,
    );
  });

  test('limites y excepcion de motocicleta', () {
    expect(marketplacePassengerLimit('motorcycle'), 2);
    expect(marketplacePassengerLimit('tricycle'), 99);
    expect(marketplaceValidPassengerCapacity(1, 'motorcycle'), isTrue);
    expect(marketplaceValidPassengerCapacity(2, 'motorcycle'), isTrue);
    expect(marketplaceValidPassengerCapacity(3, 'motorcycle'), isFalse);
    expect(marketplaceValidPassengerCapacity(100, 'tricycle'), isFalse);
    expect(marketplaceValidPassengerCapacity(0, 'tricycle'), isFalse);
    expect(
      marketplaceResolvedPassengerCapacity(
        vehicleCategory: 'motorcycle',
        services: {'passenger'},
        enteredCapacity: 2,
      ),
      2,
    );
  });

  test('motocicleta de mensajeria no ofrece pasajeros ni exige kg', () {
    const services = {'courier'};
    expect(marketplaceNeedsPassengerCapacity(services), isFalse);
    expect(marketplaceNeedsCargoCapacity(services), isFalse);
    expect(
      marketplaceResolvedPassengerCapacity(
        vehicleCategory: 'motorcycle',
        services: services,
        enteredCapacity: 1,
      ),
      isNull,
    );
    expect(
      marketplaceResolvedCargoCapacity(
        services: services,
        enteredCapacity: 55,
      ),
      isNull,
    );
  });

  test('vehiculo de pasajeros no anuncia capacidad de carga sobrante', () {
    const services = {'passenger'};
    expect(
      marketplaceResolvedPassengerCapacity(
        vehicleCategory: 'tricycle',
        services: services,
        enteredCapacity: 8,
      ),
      8,
    );
    expect(
      marketplaceResolvedCargoCapacity(
        services: services,
        enteredCapacity: 250,
      ),
      isNull,
    );
  });

  test('vehiculo de carga no anuncia plazas residuales', () {
    const services = {'cargo'};
    expect(
      marketplaceResolvedPassengerCapacity(
        vehicleCategory: 'tricycle',
        services: services,
        enteredCapacity: 8,
      ),
      isNull,
    );
    expect(
      marketplaceResolvedCargoCapacity(
        services: services,
        enteredCapacity: 250,
      ),
      250,
    );
  });

  test('vehiculo mixto conserva capacidades reales', () {
    const services = {'cargo', 'passenger'};
    expect(
      marketplaceResolvedPassengerCapacity(
        vehicleCategory: 'tricycle',
        services: services,
        enteredCapacity: 4,
      ),
      4,
    );
    expect(
      marketplaceResolvedCargoCapacity(
        services: services,
        enteredCapacity: 120,
      ),
      120,
    );
  });

  test('al desactivar un servicio deja de enviarse su capacidad', () {
    expect(
      marketplaceResolvedPassengerCapacity(
        vehicleCategory: 'car',
        services: {'cargo'},
        enteredCapacity: 5,
      ),
      isNull,
    );
    expect(
      marketplaceResolvedCargoCapacity(
        services: {'tourism'},
        enteredCapacity: 200,
      ),
      isNull,
    );
  });

  test('la cantidad de pasajeros de otros vehiculos nunca se inventa', () {
    expect(
      marketplaceResolvedPassengerCapacity(
        vehicleCategory: 'tricycle',
        services: {'passenger'},
        enteredCapacity: null,
      ),
      isNull,
    );
  });
}

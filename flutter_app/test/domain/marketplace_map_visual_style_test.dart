import 'package:control_tuk_tuk/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const custom = 'alejandrodiscoveryy/cmuxhqa9v00ez01rwegq7703v';
  test('Mapbox custom style from Admin is normalized for raster tiles', () {
    final settings = MarketplaceMapVisualConfiguration.fromCapabilities({
      'capabilities': [
        {
          'capability': 'map_visual',
          'enabled': true,
          'provider_code': 'mapbox',
          'public_token': 'pk.test',
          'config': {
            'style': 'mapbox://styles/$custom',
            'tile_size': 256,
          },
        },
      ],
    });
    expect(settings, isNotNull);
    expect(settings!.stylePath, custom);
    expect(settings.tileUrlTemplate,
        contains('/styles/v1/$custom/tiles/256/{z}/{x}/{y}'));
  });

  test('legacy style, unsupported style, and private config are safe', () {
    expect(marketplaceMapboxStylePath('mapbox/dark-v11'), 'mapbox/dark-v11');
    expect(marketplaceMapboxStylePath('mapbox://styles/owner/style'),
        'owner/style');
    expect(marketplaceMapboxStylePath('https://example.test/style'), isNull);
    expect(marketplaceMapboxStylePath('../../secret'), isNull);
    expect(
        MarketplaceMapVisualConfiguration.fromCapabilities({
          'capabilities': [
            {
              'capability': 'map_visual',
              'enabled': false,
              'provider_code': 'mapbox',
              'public_token': 'pk.test',
            }
          ],
        }),
        isNull);
  });
}
import 'package:birdnet_live/features/explore/widgets/pick_wikipedia_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pickWikipediaUrl', () {
    test('returns localized URL when available', () {
      final url = pickWikipediaUrl(
        scientificName: 'Parus major',
        bundledUrls: const {
          'en': 'https://en.wikipedia.org/wiki/Great_tit',
          'de': 'https://de.wikipedia.org/wiki/Kohlmeise',
        },
        locale: 'de',
      );
      expect(url, 'https://de.wikipedia.org/wiki/Kohlmeise');
    });

    test('falls back to English when locale missing', () {
      final url = pickWikipediaUrl(
        scientificName: 'Parus major',
        bundledUrls: const {
          'en': 'https://en.wikipedia.org/wiki/Great_tit',
        },
        locale: 'fr',
      );
      expect(url, 'https://en.wikipedia.org/wiki/Great_tit');
    });

    test('falls back to English when localized entry is empty string', () {
      final url = pickWikipediaUrl(
        scientificName: 'Parus major',
        bundledUrls: const {
          'en': 'https://en.wikipedia.org/wiki/Great_tit',
          'de': '',
        },
        locale: 'de',
      );
      expect(url, 'https://en.wikipedia.org/wiki/Great_tit');
    });

    test('constructs scientific-name URL when bundledUrls is null', () {
      final url = pickWikipediaUrl(
        scientificName: 'Parus major',
        bundledUrls: null,
        locale: 'en',
      );
      expect(url, 'https://en.wikipedia.org/wiki/Parus_major');
    });

    test('constructs scientific-name URL when bundledUrls is empty', () {
      final url = pickWikipediaUrl(
        scientificName: 'Loxia curvirostra',
        bundledUrls: const {},
        locale: 'de',
      );
      expect(url, 'https://en.wikipedia.org/wiki/Loxia_curvirostra');
    });

    test('constructs scientific-name URL when no usable bundled entries', () {
      final url = pickWikipediaUrl(
        scientificName: 'Loxia curvirostra',
        bundledUrls: const {'de': ''},
        locale: 'de',
      );
      expect(url, 'https://en.wikipedia.org/wiki/Loxia_curvirostra');
    });

    test('URL-encodes scientific names with special characters', () {
      final url = pickWikipediaUrl(
        scientificName: "Pica pica",
        bundledUrls: null,
        locale: 'en',
      );
      expect(url, 'https://en.wikipedia.org/wiki/Pica_pica');
    });

    test('trims surrounding whitespace from scientific name', () {
      final url = pickWikipediaUrl(
        scientificName: '  Parus major  ',
        bundledUrls: null,
        locale: 'en',
      );
      expect(url, 'https://en.wikipedia.org/wiki/Parus_major');
    });
  });
}

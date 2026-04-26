<!-- TRANSLATION TODO (it) -->

# API Integration

External API usage and integration.

## Taxonomy API

Species images and descriptions come from the BirdNET taxonomy API:

```
https://birdnet.cornell.edu/taxonomy/api/
```

### Endpoints

| Endpoint | Description |
|----------|-------------|
| `GET /api/image/{sci_name}?size=thumb` | 150x100 WebP thumbnail (3:2) |
| `GET /api/image/{sci_name}?size=medium` | 480x320 WebP image (3:2) |
| `GET /api/species/{sci_name}` | Full species record (descriptions, Wikipedia, links) |
| `GET /api/download/json` | Full taxonomy export used by the local bundle tooling |

### Usage

The app's default experience is offline-first: bundled species images,
descriptions, and taxonomy metadata are generated ahead of time from the public
taxonomy export. The live API remains useful for refreshing metadata exports and
for any future opt-in online enrichments.

### Error Handling

The API is optional — the app works fully offline. Network failures show placeholder images and a "No description available" message.

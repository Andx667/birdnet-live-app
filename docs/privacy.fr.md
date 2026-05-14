# Politique de Confidentialité

**Dernière mise à jour :** Mai 2026

BirdNET Live respecte votre vie privée. Ce document explique le traitement de vos données.

## Traitement sur l'Appareil
L'analyse audio et l'identification des espèces aviaires s'effectuent **intégralement sur votre appareil** (Modèles BirdNET+ et Geomodel). Aucune donnée n'est transmise aux serveurs.

## Collecte de Données
L'application **ne** collecte **aucune** donnée personnelle, analyse ou télémétrie.
- Fichiers audios, bases de données SQLite, GPS et préférences sont stockées en local.
- Données des espèces sont intégrées hors-ligne.
- Quand **Autoriser la requête météo** est actif, chaque session enregistre localement un instantané de température, précipitations, vent, nuages et code météo aux coordonnées de la session.

## Ressources Externes

L'application peut accéder aux services externes ci-dessous. Chacun est contrôlé par un interrupteur indépendant sous **Réglages → Confidentialité**, et **les trois sont désactivés par défaut** sur une nouvelle installation. Rien ne quitte votre appareil avant que vous l'autorisiez.

| Ressource | Objectif | Interrupteur | Envoyé à chaque requête |
|-----------|----------|--------------|--------------------------|
| Tuiles de carte (OpenStreetMap) | Carte de base pour sélecteur de position, carte live de Survey, carte de la session et pré-téléchargement | **Réglages → Confidentialité → Autoriser les tuiles de carte** | Uniquement coordonnées de tuile `(z, x, y)` — pas de PII |
| Géocodage inverse (OpenStreetMap Nominatim) | Résoudre les coordonnées GPS en un nom de lieu (p. ex. «Paris, France») | **Réglages → Confidentialité → Autoriser la recherche de nom de lieu** | Lat/lon de la session et un user-agent générique `BirdNET-Live/<version>` |
| Instantané météo (Open-Meteo) | Capture ponctuelle des conditions (température, précipitations, vent, nuages, code WMO) aux coordonnées et à l'heure de fin | **Réglages → Confidentialité → Autoriser la requête météo** | Lat/lon de la session et horodatage de fin, plus un user-agent générique `BirdNET-Live/<version>` |

Les requêtes de tuiles sont des HTTPS GET standard vers `tile.openstreetmap.org` ; le géocodage inverse cible `nominatim.openstreetmap.org` selon la [Politique d'usage Nominatim](https://operations.osmfoundation.org/policies/nominatim/) ; les requêtes météo ciblent `api.open-meteo.com`. [Open-Meteo](https://open-meteo.com/) est un service gratuit et n'exige ni compte ni clé API.

**Rétention :** aucun de ces services externes ne stocke vos données. Les valeurs renvoyées (nom de lieu, instantané météo) ne vivent que dans l'enregistrement local de la session et ne voyagent que dans les fichiers d'export que vous produisez explicitement.

**Révocation :** vous pouvez désactiver l'un des trois services à tout moment sous **Réglages → Confidentialité**. Pour effacer aussi les noms de lieu et instantanés météo historiques, utilisez **Réglages → Zone dangereuse → Effacer toutes les données**.

## Suppression et Exportation
L'utilisateur peut effacer l'ensemble de ses données via **Paramètres > Zone de Danger**. Sous **Réglages → Exporter → Formats**, vous pouvez cocher n'importe quelle combinaison de formats (Raven Selection Table, CSV, JSON, GPX) ; ils sont regroupés dans un ZIP unique avec les clips audio et le rapport HTML optionnel.

## Contact
[ccb-birdnet@cornell.edu](mailto:ccb-birdnet@cornell.edu)

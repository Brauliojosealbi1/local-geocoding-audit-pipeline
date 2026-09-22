# Local Geocoding & Geospatial Quality Audit Engine

End-to-end reproducible pipeline for high-throughput reverse geocoding, address token-matching, and administrative parish validation using an on-premise Nominatim/PostGIS cluster.

## Architecture
- **Infrastructure:** Docker Compose (Nominatim 4.4 + PostgreSQL/PostGIS) with memory tuning for dense GiST indexing.
- **Client Pipeline (R):** Asynchronous multi-thread HTTP worker pool (`curl::multi_run`) with lexical scoping isolation.
- **Data Quality Logic:** Canonical string normalization, token-overlap scoring, and Jaro-Winkler distance against official administrative boundaries.

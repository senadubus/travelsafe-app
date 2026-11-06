# TravelSafe

TravelSafe is a crime-aware route planning system for Chicago. It combines a
weekly XGBoost crime forecast on a spatial grid with a pgRouting-based road
network so that users can request three kinds of routes between two points:
**Shortest**, **Balanced** and **Safest**. A Flutter mobile application provides
the map interface, and a FastAPI backend serves crime tiles, points of interest
and route geometry.

This repository also contains the sensitivity analyses prepared in response to
the reviewer report of the associated paper.

---

## Repository layout

```
travelsafe-app/
├── README.md                          ← this file
├── travel-safe-app/                   ← Flutter mobile application (SafeJourney)
│   ├── lib/                           ← Dart source (screens, services, widgets)
│   ├── android/  ios/  web/  windows/ linux/ macos/
│   ├── assets/                        ← icons, images
│   └── pubspec.yaml                   ← Flutter dependencies
│
├── travelsafe-api/                    ← FastAPI backend (git submodule)
│   ├── app/
│   │   ├── main.py                    ← FastAPI application entry point
│   │   ├── database.py                ← SQLAlchemy engine / session
│   │   ├── models.py                  ← ORM models
│   │   ├── schemas.py                 ← Pydantic response schemas
│   │   ├── routing_service.py         ← pgRouting / Dijkstra helpers
│   │   ├── routers/
│   │   │   ├── crime.py               ← crime grid / heatmap endpoints
│   │   │   ├── tiles.py               ← map tile endpoints
│   │   │   ├── points.py              ← points of interest endpoints
│   │   │   ├── route.py               ← route generation API
│   │   │   └── ui_route.py             ← route API used by the Flutter app
│   │   └── env.example                ← template for DATABASE_URL (copy to .env)
│   └── requirements / environment     ← see "Backend" below
│
├── revision-sensitivity-analysis/     ← reviewer response materials
│   ├── README.md                      ← detailed documentation of both analyses
│   ├── grid_resolution_summary.md     ← grid resolution results
│   ├── weight_sensitivity_summary.md  ← weight sensitivity results
│   ├── weight_sensitivity_analysis_EN.md
│   ├── sql/                           ← schema dumps + analysis queries
│   ├── scripts/                       ← analysis scripts
│   ├── data/                          ← CSV outputs
│   └── logs/                          ← run logs
│
└── xgboost-weekly-with-feature-engineering.py
                                       ← weekly XGBoost training script
                                         (feature engineering, model export)
```

> **Note:** `travelsafe-api/` is tracked as a git submodule. Its own repository is
> `https://github.com/senadubus/travelsafe-api`. Clone with
> `git clone --recurse-submodules`, or run `git submodule update --init` after a
> plain clone.

---

## Components

| Component | Location | Technology |
|---|---|---|
| Mobile app | `travel-safe-app/` | Flutter / Dart, Google Maps SDK, Provider |
| Backend API | `travelsafe-api/app/` | FastAPI, SQLAlchemy, psycopg2 |
| Routing | `travelsafe-api/app/routing_service.py` | PostgreSQL + PostGIS + pgRouting (Dijkstra) |
| Crime prediction | `xgboost-weekly-with-feature-engineering.py` | XGBoost, scikit-learn |
| Analyses | `revision-sensitivity-analysis/` | Python (pandas, XGBoost), SQL |

---

## Data

| Item | Value |
|---|---|
| Crime source | City of Chicago "Crimes — 2001 to Present" |
| Modelling period | 2021-01-04 – 2025-08-04 (weekly, Monday start) |
| Spatial grid | 500 × 500 m (primary), split into cells with PostGIS |
| Road network | OpenStreetMap, imported via osm2pgsql into `road_nodes` / `road_segments` |
| Crime categories | Violent, Property, Drug/Vice, Public-order |
| Base category weights | 1.0 / 0.6 / 0.4 / 0.3 |

Main database tables:

| Table | Role |
|---|---|
| `crime` | Raw incident records (date, coordinates, category) |
| `grid_cells` | 500 m grid polygons |
| `crime_grid_daily` | Daily per-grid, per-category crime counts |
| `crime_grid_weekly` | Weekly per-grid counts and engineered features (model input) |
| `weekly_predicted_crime` | Model predictions written back to the database |
| `cell_risk_scores` | Aggregated risk score per grid cell |
| `road_nodes` / `road_segments` | OSM road graph used for routing |
| `road_segment_grid_map` | Segment ↔ grid-cell mapping |
| `grid_neighbors` | 8-neighbour topology between grid cells |

The full schema is available in
`revision-sensitivity-analysis/sql/schema_full.sql` (generated with
`pg_dump --schema-only`).

---

## Crime prediction model

- **Target:** stationary formulation `z = log1p(y) − log1p(y^(4))`, where `y^(4)` is
  the mean of the previous 4 weeks (paper Eq. 2). Predictions are converted back
  with `y = expm1(z + log1p(y^(4)))`.
- **Features:** calendar (year, month, ISO week, sin/cos encodings), spatial
  (lat/lon, distance to city centre), lags (1, 2, 3, 4, 8, 12, 26, 52 weeks),
  rolling means/std/max (4, 8, 12 weeks), momentum, neighbour features (8-cell
  ring), zero-ratio over 12 weeks, weeks since last crime, historical density rank.
- **Hyperparameters:** `n_estimators=400`, `learning_rate=0.03`, `max_depth=5`,
  `min_child_weight=15`, `subsample=0.7`, `colsample_bytree=0.5`, `reg_alpha=1.0`,
  `reg_lambda=5.0`.
- **Validation:** 5-fold chronological `TimeSeriesSplit`.
- **Cleaning rule:** grids with fewer than 10 total crimes over the period are
  excluded from training.

---

## Routing

Routes are generated with `pgr_dijkstra` over a temporary edge table whose cost is

```
cost = length_m + λ · length_m · (risk_norm / 100)
```

where `risk_norm` is the min–max normalized (0–100) per-segment risk density and
`λ` is the profile weight:

| Profile | λ | Behaviour |
|---|---|---|
| Shortest | 0 | Pure distance |
| Balanced | 5 | Distance with moderate risk penalty |
| Safest | 50 | Risk-dominated |

Segment risk is computed from the category crime counts of the grid cells the
segment intersects, weighted by the category weights, and divided by segment
length in km.

---

## Running the system

### Prerequisites

- PostgreSQL 14+ with PostGIS and pgRouting
- Python 3.10+ with `fastapi`, `uvicorn`, `sqlalchemy`, `psycopg2`, `pandas`,
  `numpy`, `scikit-learn`, `xgboost`
- Flutter 3.x with the Android SDK (for the mobile app)
- A Google Maps API key (for the map view)

### Database

Create the `travelsafe` database and enable the extensions:

```sql
CREATE EXTENSION IF NOT EXISTS postgis;
CREATE EXTENSION IF NOT EXISTS pgrouting;
```

Load the schema from `revision-sensitivity-analysis/sql/schema_core.sql` (core
tables) or `schema_full.sql` (everything), then import the OSM road network with
`revision-sensitivity-analysis/scripts/reference_osm_road_import.py` and the crime
data from the Chicago Open Data portal.

### Backend

```bash
cd travelsafe-api

# Database credentials for the analysis scripts are read from environment
# variables. Set them in your shell, or create travelsafe-api/.env:
#   DB_HOST=localhost
#   DB_PORT=5432
#   DB_NAME=travelsafe
#   DB_USER=postgres
#   DB_PASSWORD=<your-password>
#   DATABASE_URL=postgresql+psycopg2://<user>:<password>@localhost:5432/travelsafe
# A template is provided in travelsafe-api/app/env.example.

uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

Interactive API documentation is then available at `http://localhost:8000/docs`.

### Model training

```bash
python xgboost-weekly-with-feature-engineering.py
```

The script reads `crime_grid_weekly`, trains the weekly model and writes results
to `weekly_predicted_crime` / `cell_risk_scores`.

### Mobile app

```bash
cd travel-safe-app
flutter pub get
flutter run
```

Add the Google Maps API key to the Android manifest and point the app's base URL
at the backend. When running on an Android emulator, the host machine is reached
at `10.0.2.2` rather than `localhost`.

---

## Sensitivity analyses

The `revision-sensitivity-analysis/` folder contains two analyses prepared for the
reviewer:

1. **Grid resolution** — 250 / 500 / 1000 m compared under identical data,
   cleaning rules, target definition, hyperparameters and validation; plus a
   sparsity analysis for 10 × 10 m.
2. **Crime category weights** — Base / Equal / Compressed / Violent-focused weight
   sets compared on the same six route requests and three route profiles, reporting
   distance, normalized risk, generation time, whether the route changed, and edge-set
   Jaccard / overlap similarity against the Base route.

See `revision-sensitivity-analysis/README.md` for method details, run instructions
and outputs, and the four CSV files under `revision-sensitivity-analysis/data/`
for the numeric results.

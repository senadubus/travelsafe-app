-- =====================================================================
-- TravelSafe — Revision Sensitivity Analysis: Kullanılan SQL Sorguları
-- =====================================================================
-- Bu dosya, grid çözünürlüğü ve ağırlık duyarlılığı analizlerinde
-- kullanılan SQL sorgularını belgeler. Şema için schema_core.sql /
-- schema_full.sql dosyalarına bakınız.
--
-- Veri dönemi: 2021-01-04 .. 2025-08-04
-- Kaynak: City of Chicago "Crimes - 2001 to Present"
-- =====================================================================


-- ---------------------------------------------------------------------
-- 1) GRID ÇÖZÜNÜRLÜĞÜ ANALİZİ
-- ---------------------------------------------------------------------

-- 1.1 Ham suç verisi (analiz script'i bu sorguyu kullanır)
--     Not: Grid çözünürlüğü analizinde hücreler Python tarafında
--     bbox tabanlı metre grid ile yeniden atanır; DB'deki 500 m grid
--     burada kullanılmaz (çözünürlükler arası adil karşılaştırma için).
SELECT "Date" AS ts, "Latitude" AS lat, "Longitude" AS lng
FROM crime
WHERE "Date" >= DATE '2021-01-04'
  AND "Latitude"  BETWEEN 41.63732681153954 AND 42.02280114700859
  AND "Longitude" BETWEEN -87.94558663867282 AND -87.51375507892669
  AND "Latitude" IS NOT NULL
  AND "Longitude" IS NOT NULL;


-- 1.2 Mevcut sistemdeki (500 m) haftalık grid tablosundan model verisi
--     Makaledeki temizleme kuralı: grid başına toplam suç >= 10
SELECT *
FROM crime_grid_weekly
WHERE week_start <= DATE '2025-07-28'
  AND grid_id IN (
      SELECT grid_id
      FROM crime_grid_weekly
      WHERE week_start <= DATE '2025-07-28'
      GROUP BY grid_id
      HAVING SUM(total_count) >= 10
  )
ORDER BY week_start, grid_id;


-- 1.3 Eğitim verisinin kapsamını doğrulama (veri dönemi kontrolü)
SELECT MIN(week_start) AS first_week,
       MAX(week_start) AS last_week,
       COUNT(DISTINCT week_start) AS n_weeks,
       COUNT(DISTINCT grid_id) AS n_grids
FROM crime_grid_weekly
WHERE week_start <= DATE '2025-07-28';


-- 1.4 Grid tablosundaki haftalık gözlem sayısı ve sıfır oranı
SELECT g.grid_id,
       COUNT(*)                                   AS n_weeks,
       SUM(CASE WHEN w.total_count = 0 THEN 1 ELSE 0 END) AS zero_weeks,
       ROUND(AVG(w.total_count)::numeric, 4)      AS mean_count
FROM grid_cells g
LEFT JOIN crime_grid_weekly w ON w.grid_id = g.id
GROUP BY g.grid_id;


-- ---------------------------------------------------------------------
-- 2) AĞIRLIK DUYARLILIĞI ANALİZİ
-- ---------------------------------------------------------------------

-- 2.1 Segment -> grid hücreleri -> kategori bazlı suç sayıları
--     (test_weight_sensitivity.py::load_segment_risk_inputs ile aynı)
WITH grid_agg AS (
    SELECT grid_id,
           SUM(siddet_count)            AS siddet,
           SUM(mala_karsi_count)        AS property,
           SUM(uyusturucu_ahlaki_count) AS drug,
           SUM(kamu_duzeni_count)       AS pub
    FROM crime_grid_daily
    GROUP BY grid_id
),
seg_cells AS (
    SELECT rs.id AS seg_id, gc.id AS grid_id
    FROM road_segments rs
    JOIN grid_cells gc ON ST_Intersects(gc.geom, rs.geometry)
    WHERE rs.source_node IS NOT NULL
      AND rs.target_node IS NOT NULL
      AND rs.length_m IS NOT NULL
)
SELECT rs.id,
       rs.length_m,
       rs.allowed_walk,
       rs.allowed_car,
       COALESCE(SUM(ga.siddet), 0)   AS siddet,
       COALESCE(SUM(ga.property), 0) AS property,
       COALESCE(SUM(ga.drug), 0)     AS drug,
       COALESCE(SUM(ga.pub), 0)      AS pub
FROM road_segments rs
LEFT JOIN seg_cells sc ON sc.seg_id = rs.id
LEFT JOIN grid_agg ga  ON ga.grid_id = sc.grid_id
WHERE rs.source_node IS NOT NULL
  AND rs.target_node IS NOT NULL
  AND rs.length_m IS NOT NULL
GROUP BY rs.id, rs.length_m, rs.allowed_walk, rs.allowed_car;


-- 2.2 En yakın node bulma (mod bazlı) — koordinat snapping
--     (:lng, :lat parametreleri ile)
WITH nearest_segment AS (
    SELECT source_node, target_node, geometry
    FROM road_segments
    WHERE source_node IS NOT NULL
      AND target_node IS NOT NULL
      AND geometry IS NOT NULL
      AND allowed_walk = TRUE          -- mod: allowed_walk | allowed_car
    ORDER BY geometry <-> ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)
    LIMIT 1
),
candidate_nodes AS (
    SELECT n.osmid AS node_id, n.geometry
    FROM road_nodes n JOIN nearest_segment ns ON n.osmid = ns.source_node
    UNION ALL
    SELECT n.osmid AS node_id, n.geometry
    FROM road_nodes n JOIN nearest_segment ns ON n.osmid = ns.target_node
)
SELECT node_id
FROM candidate_nodes
ORDER BY geometry <-> ST_SetSRID(ST_MakePoint(:lng, :lat), 4326)
LIMIT 1;


-- 2.3 Risk-ağırlıklı Dijkstra (pgRouting)
--     cost = length_m + lambda * length_m * (risk_norm / 100)
--     risk_norm: segment riskinin min-max ile 0-100 aralığına normalize hâli
--     (Python tarafında hesaplanıp tmp_seg_cost'a yazılır)
CREATE TEMP TABLE IF NOT EXISTS tmp_seg_cost (
    seg_id bigint PRIMARY KEY,
    cost   float8
) ON COMMIT DROP;

CREATE TEMP TABLE IF NOT EXISTS tmp_cost_edges (
    id bigint, source bigint, target bigint,
    cost float8, reverse_cost float8
) ON COMMIT DROP;

INSERT INTO tmp_cost_edges (id, source, target, cost, reverse_cost)
SELECT rs.id, rs.source_node, rs.target_node, sc.cost, sc.cost
FROM road_segments rs
JOIN tmp_seg_cost sc ON sc.seg_id = rs.id
WHERE rs.source_node IS NOT NULL
  AND rs.target_node IS NOT NULL;

SELECT seq, node, edge, cost
FROM pgr_dijkstra(
    'SELECT id, source, target, cost, reverse_cost FROM tmp_cost_edges',
    :start_node, :end_node, directed := false
)
ORDER BY seq;


-- ---------------------------------------------------------------------
-- 3) KONTROL / DOĞRULAMA SORGULARI
-- ---------------------------------------------------------------------

-- 3.1 Tablo satır sayıları (veri ölçeği raporlaması için)
SELECT 'crime'                 AS table_name, COUNT(*) AS rows FROM crime
UNION ALL SELECT 'grid_cells',           COUNT(*) FROM grid_cells
UNION ALL SELECT 'crime_grid_daily',     COUNT(*) FROM crime_grid_daily
UNION ALL SELECT 'crime_grid_weekly',    COUNT(*) FROM crime_grid_weekly
UNION ALL SELECT 'road_nodes',           COUNT(*) FROM road_nodes
UNION ALL SELECT 'road_segments',        COUNT(*) FROM road_segments
UNION ALL SELECT 'road_segment_grid_map',COUNT(*) FROM road_segment_grid_map;

-- 3.2 Suç kategorilerinin dağılımı (kategori ağırlıklarının kaynağı)
SELECT primary_type, COUNT(*) AS n
FROM crime
WHERE "Date" BETWEEN DATE '2021-01-04' AND DATE '2025-08-04'
GROUP BY primary_type
ORDER BY n DESC;

-- 3.3 Mekânsal indekslerin varlığı
SELECT tablename, indexname
FROM pg_indexes
WHERE schemaname = 'public'
  AND (indexdef ILIKE '%gist%')
ORDER BY tablename;

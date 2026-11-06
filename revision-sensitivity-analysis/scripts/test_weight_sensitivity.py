"""
TravelSafe - Risk Ağırlık Duyarlılık Testi
==========================================

Amaç:
    Farklı KATEGORİ AĞIRLIK SETLERİ (violent / property / drug-vice / public-order)
    altında rota üretimini çalıştırıp, her (ağırlık seti, senaryo, ulaşım modu,
    rota profili) için şu çıktıları toplamak:

        - Rota mesafesi (m)
        - Normalize risk değeri
        - Rota üretim süresi (ms)
        - Temel ağırlıklandırmaya (Base) göre rota değişti mi? (bool)
        - Base rotayla edge-set Jaccard benzerliği
        - Base rotayla ortak segment oranı (overlap ratio)

    Sonuçlar bir CSV dosyasına yazılır.

Nasıl çalışır:
    1. DB'den (bir kez) segment -> grid_cells -> kategori sayıları agregasyonu çekilir.
    2. Her ağırlık seti için segment risk skoru Python tarafında yeniden hesaplanır
       (böylece ağırlıklar gerçekten değişebilir; önceden pişmiş skor kullanılmaz).
    3. Ağırlıklandırılmış cost ile geçici bir edge tablosu kurulur ve pgr_dijkstra
       ile rota üretilir (uygulama arayüzüne gerek yok).
    4. Metrikler hesaplanıp CSV'ye eklenir.

Çalıştırma:
    cd travelsafe-api
    python test_weight_sensitivity.py

Not:
    DATABASE_URL ortam değişkeni (.env) okunur. Varsayılan yerel bağlantı kullanılır.
"""

import os
import time
import csv
import math
from typing import Dict, List, Tuple

import psycopg2
from dotenv import load_dotenv

load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "app", ".env"))

DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql://USER:PASSWORD@localhost:5432/travelsafe",
)
# SQLAlchemy formatındaki URL'i psycopg2 formatına çevir
DATABASE_URL = DATABASE_URL.replace("postgresql+psycopg2://", "postgresql://")

OUTPUT_CSV = os.path.join(os.path.dirname(os.path.abspath(__file__)), "weight_sensitivity_routes.csv")
OUTPUT_SUMMARY_CSV = os.path.join(os.path.dirname(os.path.abspath(__file__)), "weight_sensitivity_summary.csv")


# ---------------------------------------------------------------------------
# 1. AĞIRLIK SETLERİ  (Violent, Property, Drug/Vice, Public-order)
# ---------------------------------------------------------------------------
WEIGHT_SETS: Dict[str, Tuple[float, float, float, float]] = {
    "Base":           (1.0, 0.6, 0.4, 0.3),
    "Equal":          (1.0, 1.0, 1.0, 1.0),
    "Compressed":     (1.0, 0.8, 0.6, 0.4),
    "Violent-focused": (1.0, 0.5, 0.25, 0.15),
}
BASE_WEIGHT_NAME = "Base"


# ---------------------------------------------------------------------------
# 2. ROTA PROFİLLERİ  (profil adı -> risk_weight, mesafeye göre riskin AĞIRLIĞI)
#    Uygulamadaki ui_route.py ile uyumlu.
# ---------------------------------------------------------------------------
ROUTE_PROFILES: Dict[str, float] = {
    "Shortest": 0.0,
    "Balanced": 5.0,
    "Safest": 50.0,
}


# ---------------------------------------------------------------------------
# 3. SENARYOLAR  (her senaryo: başlangıç ve bitiş koordinatı, lat/lng)
# ---------------------------------------------------------------------------
SCENARIOS: List[dict] = [
    {"name": "S1", "start": (41.85598, -87.67280), "end": (41.84169, -87.68438)},
    {"name": "S2", "start": (41.88438, -87.62063), "end": (41.86917, -87.64857)},
    {"name": "S3", "start": (41.85418, -87.64163), "end": (41.83179, -87.65692)},
]

# Ulaşım modları -> road_segments üzerindeki izin kolonu
MODES: Dict[str, str] = {
    "walk": "allowed_walk",
    "car": "allowed_car",
}


# ---------------------------------------------------------------------------
# DB YARDIMCILARI
# ---------------------------------------------------------------------------
def get_conn():
    return psycopg2.connect(DATABASE_URL)


def nearest_node(cur, lat: float, lng: float, mode_column: str) -> int:
    """Verilen koordinata, ilgili modda izinli en yakın segmentin uç node'unu bul."""
    sql = f"""
        WITH nearest_segment AS (
            SELECT source_node, target_node, geometry
            FROM road_segments
            WHERE source_node IS NOT NULL
              AND target_node IS NOT NULL
              AND geometry IS NOT NULL
              AND {mode_column} = TRUE
            ORDER BY geometry <-> ST_SetSRID(ST_MakePoint(%s, %s), 4326)
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
        ORDER BY geometry <-> ST_SetSRID(ST_MakePoint(%s, %s), 4326)
        LIMIT 1;
    """
    cur.execute(sql, (lng, lat, lng, lat))
    row = cur.fetchone()
    return int(row[0]) if row else None


def load_segment_risk_inputs(cur) -> Dict[int, dict]:
    """
    Her road_segment için, üzerinden geçtiği 500m grid_cells hücrelerinin
    kategori bazlı toplam suç sayılarını toplar. Bir kez çalışır (cache).

    Dönen yapı:
        { seg_id: {
              'length_m': float, 'walk': bool, 'car': bool,
              'siddet': int, 'property': int, 'drug': int, 'pub': int } }
    """
    sql = """
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
        SELECT
            rs.id,
            rs.length_m,
            rs.allowed_walk,
            rs.allowed_car,
            COALESCE(SUM(ga.siddet), 0),
            COALESCE(SUM(ga.property), 0),
            COALESCE(SUM(ga.drug), 0),
            COALESCE(SUM(ga.pub), 0)
        FROM road_segments rs
        LEFT JOIN seg_cells sc ON sc.seg_id = rs.id
        LEFT JOIN grid_agg ga ON ga.grid_id = sc.grid_id
        WHERE rs.source_node IS NOT NULL
          AND rs.target_node IS NOT NULL
          AND rs.length_m IS NOT NULL
        GROUP BY rs.id, rs.length_m, rs.allowed_walk, rs.allowed_car;
    """
    cur.execute(sql)
    out: Dict[int, dict] = {}
    for seg_id, length_m, walk, car, s, p, d, k in cur.fetchall():
        out[int(seg_id)] = {
            "length_m": float(length_m or 0.0),
            "walk": bool(walk),
            "car": bool(car),
            "siddet": float(s or 0),
            "property": float(p or 0),
            "drug": float(d or 0),
            "pub": float(k or 0),
        }
    return out


# ---------------------------------------------------------------------------
# RİSK HESABI  (ağırlıklara bağlı)
# ---------------------------------------------------------------------------
def compute_segment_risk(seg_inputs: Dict[int, dict],
                         weights: Tuple[float, float, float, float]) -> Dict[int, float]:
    """
    Segment risk skoru:
        harm = w_v*siddet + w_p*property + w_d*drug + w_o*pub
        risk = harm / length_km   (birim uzunluk başına risk)
    Normalize için segment risklerini 0-100 aralığına çekeriz (aşağıda).
    """
    w_v, w_p, w_d, w_o = weights
    raw: Dict[int, float] = {}
    for seg_id, d in seg_inputs.items():
        harm = (w_v * d["siddet"] + w_p * d["property"]
                + w_d * d["drug"] + w_o * d["pub"])
        length_km = max(d["length_m"] / 1000.0, 1e-6)
        raw[seg_id] = harm / length_km  # uzunluk-normalize risk yoğunluğu
    return raw


def normalize_risk(raw: Dict[int, float]) -> Dict[int, float]:
    """Risk değerlerini min-max ile 0-100 aralığına normalize et."""
    if not raw:
        return {}
    vals = list(raw.values())
    mn, mx = min(vals), max(vals)
    if mx - mn < 1e-12:
        return {k: 0.0 for k in raw}
    return {k: (v - mn) / (mx - mn) * 100.0 for k, v in raw.items()}


# ---------------------------------------------------------------------------
# ROTA ÜRETİMİ  (pgr_dijkstra + geçici edge tablosu)
# ---------------------------------------------------------------------------
def build_cost_edges(seg_inputs, risk_norm, mode_column, risk_weight, mmax):
    """
    Geçici edge listesi üret:
        cost = length_m + risk_weight * length_m * (risk_norm/100)
    (ui_route.py ile aynı formül.)
    """
    edges = []
    for seg_id, d in seg_inputs.items():
        if not d[mode_column if False else ("walk" if mode_column == "allowed_walk" else "car")]:
            continue
        length = d["length_m"]
        r = risk_norm.get(seg_id, 0.0)
        cost = length + risk_weight * length * (r / 100.0)
        edges.append((seg_id, length, cost, r))
    return edges


def run_dijkstra(cur, start_node, end_node, mode_column, seg_inputs, risk_norm, risk_weight):
    """
    pgr_dijkstra ile rota üret. Döner:
        (segment_ids, total_length_m, path_nodes)
    Geçici tablo kullanmadan, VALUES-CTE ile edge kaynağını besleriz.
    """
    mode_key = "walk" if mode_column == "allowed_walk" else "car"

    # Edge satırlarını üret (yalnızca bu modda izinli segmentler)
    rows = []
    for seg_id, d in seg_inputs.items():
        if not d[mode_key]:
            continue
        length = d["length_m"]
        r = risk_norm.get(seg_id, 0.0)
        cost = length + risk_weight * length * (r / 100.0)
        rows.append((seg_id, length, cost))
        rows.append((seg_id, length, cost))

    # Not: source/target'ı DB'den almak için road_segments'e geri join edeceğiz.
    # Bu yüzden geçici bir tablo oluşturup dijkstra'ya onu veriyoruz.
    cur.execute("""
        CREATE TEMP TABLE IF NOT EXISTS tmp_cost_edges (
            id bigint, source bigint, target bigint,
            cost float8, reverse_cost float8
        ) ON COMMIT DROP;
    """)
    cur.execute("TRUNCATE tmp_cost_edges;")

    # Segment cost'larını geçici bir cost tablosuna yaz, sonra join ile edge üret
    cur.execute("""
        CREATE TEMP TABLE IF NOT EXISTS tmp_seg_cost (
            seg_id bigint PRIMARY KEY, cost float8
        ) ON COMMIT DROP;
    """)
    cur.execute("TRUNCATE tmp_seg_cost;")

    import psycopg2.extras
    cost_data = []
    for seg_id, d in seg_inputs.items():
        if not d[mode_key]:
            continue
        length = d["length_m"]
        r = risk_norm.get(seg_id, 0.0)
        cost_data.append((seg_id, length + risk_weight * length * (r / 100.0)))

    if not cost_data:
        return [], 0.0, []

    psycopg2.extras.execute_values(
        cur,
        "INSERT INTO tmp_seg_cost (seg_id, cost) VALUES %s",
        cost_data,
    )

    cur.execute("""
        INSERT INTO tmp_cost_edges (id, source, target, cost, reverse_cost)
        SELECT rs.id, rs.source_node, rs.target_node, sc.cost, sc.cost
        FROM road_segments rs
        JOIN tmp_seg_cost sc ON sc.seg_id = rs.id
        WHERE rs.source_node IS NOT NULL AND rs.target_node IS NOT NULL;
    """)

    cur.execute("""
        SELECT seq, node, edge, cost
        FROM pgr_dijkstra(
            'SELECT id, source, target, cost, reverse_cost FROM tmp_cost_edges',
            %s, %s, directed := false
        )
        ORDER BY seq;
    """, (start_node, end_node))

    dijkstra_rows = cur.fetchall()

    segment_ids = []
    path_nodes = []
    total_length = 0.0

    for seq, node, edge, cost in dijkstra_rows:
        if edge is not None and int(edge) != -1:
            segment_ids.append(int(edge))
        if node is not None:
            path_nodes.append(int(node))

    # Toplam uzunluğu segmentlerden hesapla
    if segment_ids:
        seg_len = {sid: seg_inputs[sid]["length_m"] for sid in set(segment_ids) if sid in seg_inputs}
        total_length = sum(seg_len.get(sid, 0.0) for sid in segment_ids)

    return segment_ids, total_length, path_nodes


# ---------------------------------------------------------------------------
# METRİKLER
# ---------------------------------------------------------------------------
def jaccard(a: List[int], b: List[int]) -> float:
    sa, sb = set(a), set(b)
    if not sa and not sb:
        return 1.0
    if not sa or not sb:
        return 0.0
    return len(sa & sb) / len(sa | sb)


def overlap_ratio(a: List[int], b: List[int]) -> float:
    """Ortak segment / min(len) — route_overlap_ratio ile uyumlu."""
    sa, sb = set(a), set(b)
    if not sa or not sb:
        return 0.0
    return len(sa & sb) / min(len(sa), len(sb))


def route_risk_value(segment_ids, risk_norm) -> float:
    """Rota boyunca ortalama normalize risk (segment risklerinin ortalaması)."""
    if not segment_ids:
        return 0.0
    vals = [risk_norm.get(sid, 0.0) for sid in segment_ids]
    return sum(vals) / len(vals)


# ---------------------------------------------------------------------------
# ANA AKIŞ
# ---------------------------------------------------------------------------
def main():
    print("=" * 78)
    print("TravelSafe - Risk Ağırlık Duyarlılık Testi")
    print("=" * 78)

    conn = get_conn()
    conn.autocommit = False
    cur = conn.cursor()

    print("\n[1/4] Segment risk girdileri DB'den yükleniyor (bir kez)...")
    t0 = time.time()
    seg_inputs = load_segment_risk_inputs(cur)
    print(f"      {len(seg_inputs)} segment yüklendi ({time.time()-t0:.1f}s)")

    print("\n[2/4] Her ağırlık seti için normalize risk hesaplanıyor...")
    norm_risk_by_set: Dict[str, Dict[int, float]] = {}
    for wname, w in WEIGHT_SETS.items():
        raw = compute_segment_risk(seg_inputs, w)
        norm_risk_by_set[wname] = normalize_risk(raw)
        print(f"      {wname:16s} {w} -> normalize edildi")

    rows_out: List[dict] = []

    # Base rotaları, karşılaştırma için saklayacağız: (senaryo, mod, profil) -> segment_ids
    base_routes: Dict[Tuple[str, str, str], List[int]] = {}

    # İlk geçiş: Base ağırlıkları ile tüm rotaları üret (karşılaştırma referansı)
    print("\n[3/4] Rotasyonlar üretiliyor...")

    for scen in SCENARIOS:
        for mode_name, mode_col in MODES.items():
            # Node'ları mod bazında bul
            start_node = nearest_node(cur, scen["start"][0], scen["start"][1], mode_col)
            end_node = nearest_node(cur, scen["end"][0], scen["end"][1], mode_col)

            if start_node is None or end_node is None:
                print(f"      !! {scen['name']}/{mode_name}: node bulunamadı, atlanıyor.")
                continue

            for profile_name, risk_w in ROUTE_PROFILES.items():
                for wname in WEIGHT_SETS:
                    risk_norm = norm_risk_by_set[wname]

                    t_start = time.perf_counter()
                    seg_ids, total_len, path_nodes = run_dijkstra(
                        cur, start_node, end_node, mode_col,
                        seg_inputs, risk_norm, risk_w,
                    )
                    elapsed_ms = (time.perf_counter() - t_start) * 1000.0

                    risk_val = route_risk_value(seg_ids, risk_norm)

                    key = (scen["name"], mode_name, profile_name)
                    if wname == BASE_WEIGHT_NAME:
                        base_routes[key] = seg_ids
                        changed = False
                        jac = 1.0
                        ovl = 1.0
                    else:
                        base_segs = base_routes.get(key, [])
                        changed = (set(seg_ids) != set(base_segs))
                        jac = jaccard(seg_ids, base_segs)
                        ovl = overlap_ratio(seg_ids, base_segs)

                    rows_out.append({
                        "weight_set": wname,
                        "scenario": scen["name"],
                        "mode": mode_name,
                        "profile": profile_name,
                        "risk_weight": risk_w,
                        "start_node": start_node,
                        "end_node": end_node,
                        "route_distance_m": round(total_len, 2),
                        "route_risk_normalized": round(risk_val, 4),
                        "route_time_ms": round(elapsed_ms, 2),
                        "n_segments": len(seg_ids),
                        "changed_vs_base": changed,
                        "jaccard_vs_base": round(jac, 4),
                        "overlap_ratio_vs_base": round(ovl, 4),
                    })

                    conn.commit()  # geçici tabloları temizle

            print(f"      {scen['name']}/{mode_name}: tamamlandı "
                  f"(start={start_node}, end={end_node})")

    # CSV yaz
    print(f"\n[4/4] Sonuçlar yazılıyor -> {OUTPUT_CSV}")
    if rows_out:
        with open(OUTPUT_CSV, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=list(rows_out[0].keys()))
            writer.writeheader()
            writer.writerows(rows_out)
        print(f"      {len(rows_out)} satır yazıldı.")

    # ---------------------------------------------------------------------
    # ÖZET CSV: ağırlık seti düzeyinde + rota profili sıralaması korunuyor mu
    # ---------------------------------------------------------------------
    def _ranking_preserved(records, key_metric):
        """
        Aynı (senaryo, mod, ağırlık seti) içinde profillerin mesafeye göre
        sıralaması Base ile aynı mı? (Shortest <= Balanced <= Safest beklenir.)
        """
        order = {p: r for p, r in records.items()}
        base_order = sorted(order, key=lambda p: order[p])
        return base_order

    summary_rows = []

    # Base rotaların (senaryo, mod) bazında profil bazlı değerleri
    base_lookup = {}
    for r in rows_out:
        if r["weight_set"] == BASE_WEIGHT_NAME:
            base_lookup[(r["scenario"], r["mode"], r["profile"])] = r

    for wname, w in WEIGHT_SETS.items():
        sub = [r for r in rows_out if r["weight_set"] == wname]
        n_total = len(sub)

        if wname == BASE_WEIGHT_NAME:
            n_changed = 0
            avg_jac = 1.0
            avg_ovl = 1.0
            max_risk_dev = 0.0
            avg_dist_dev = 0.0
        else:
            n_changed = sum(1 for r in sub if r["changed_vs_base"])
            avg_jac = sum(r["jaccard_vs_base"] for r in sub) / n_total
            avg_ovl = sum(r["overlap_ratio_vs_base"] for r in sub) / n_total

            risk_devs, dist_devs = [], []
            for r in sub:
                b = base_lookup.get((r["scenario"], r["mode"], r["profile"]))
                if b is None:
                    continue
                risk_devs.append(abs(r["route_risk_normalized"] - b["route_risk_normalized"]))
                dist_devs.append(abs(r["route_distance_m"] - b["route_distance_m"]))
            max_risk_dev = max(risk_devs) if risk_devs else 0.0
            avg_dist_dev = (sum(dist_devs) / len(dist_devs)) if dist_devs else 0.0

        # Profil sıralaması korunuyor mu? (mesafeye göre Shortest <= Balanced <= Safest)
        profile_order_ok = 0
        profile_order_total = 0
        dist_order_ok = 0
        dist_order_total = 0
        for scen in SCENARIOS:
            for mode_name in MODES:
                cells = {r["profile"]: r for r in sub
                         if r["scenario"] == scen["name"] and r["mode"] == mode_name}
                if len(cells) < 3:
                    continue
                profile_order_total += 1

                # Mesafeye göre sıralama
                sorted_by_dist = sorted(cells, key=lambda p: cells[p]["route_distance_m"])
                expected = ["Shortest", "Balanced", "Safest"]
                if sorted_by_dist == expected:
                    dist_order_ok += 1

                # Sağlık kontrolü: Safest riski Shortest riskinden büyük olmamalı
                if cells["Safest"]["route_risk_normalized"] <= cells["Shortest"]["route_risk_normalized"]:
                    profile_order_ok += 1

        summary_rows.append({
            "weight_set": wname,
            "weights_violent_property_drug_public": "|".join(str(x) for x in w),
            "n_route_records": n_total,
            "n_routes_changed_vs_base": n_changed,
            "changed_ratio": round(n_changed / n_total, 4) if n_total else 0.0,
            "avg_jaccard_vs_base": round(avg_jac, 4),
            "min_jaccard_vs_base": round(min([r["jaccard_vs_base"] for r in sub]), 4) if sub else 1.0,
            "avg_overlap_ratio_vs_base": round(avg_ovl, 4),
            "max_abs_risk_deviation": round(max_risk_dev, 4),
            "avg_abs_distance_deviation_m": round(avg_dist_dev, 2),
            "avg_route_time_ms": round(sum(r["route_time_ms"] for r in sub) / n_total, 2),
            "mean_route_distance_m": round(sum(r["route_distance_m"] for r in sub) / n_total, 2),
            "mean_route_risk_normalized": round(sum(r["route_risk_normalized"] for r in sub) / n_total, 4),
            "dist_order_preserved_cases": f"{dist_order_ok}/{dist_order_total}",
            "safest_better_than_shortest_cases": f"{profile_order_ok}/{profile_order_total}",
        })

    with open(OUTPUT_SUMMARY_CSV, "w", newline="", encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=list(summary_rows[0].keys()))
        writer.writeheader()
        writer.writerows(summary_rows)
    print(f"      Özet yazıldı -> {OUTPUT_SUMMARY_CSV}")

    cur.close()
    conn.close()

    # Özet istatistik
    print("\n" + "=" * 78)
    print("ÖZET")
    print("=" * 78)
    print(f"Toplam kayıt: {len(rows_out)}")
    for wname in WEIGHT_SETS:
        sub = [r for r in rows_out if r["weight_set"] == wname and wname != BASE_WEIGHT_NAME]
        if not sub:
            continue
        n_changed = sum(1 for r in sub if r["changed_vs_base"])
        avg_jac = sum(r["jaccard_vs_base"] for r in sub) / len(sub)
        avg_ovl = sum(r["overlap_ratio_vs_base"] for r in sub) / len(sub)
        print(f"  {wname:16s}: rota değişen {n_changed}/{len(sub)} | "
              f"ort. Jaccard={avg_jac:.3f} | ort. overlap={avg_ovl:.3f}")

    print(f"\nCSV: {OUTPUT_CSV}")


if __name__ == "__main__":
    main()

"""
TravelSafe - Grid Çözünürlük Karşılaştırması (250m / 500m / 1000m ve 10m seyreklik)
==================================================================================

Amaç:
    Mevcut sistem 500 x 500 m grid kullanıyor. Aynı veri dönemi, temizleme kuralları
    ve suç kategorileri korunarak 250 x 250 m, 500 x 500 m ve 1000 x 1000 m
    çözünürlükleri karşılaştırmak. Her çözünürlük için:

        - Toplam grid sayısı
        - Suç kaydı bulunan aktif grid sayısı
        - Toplam grid-hafta gözlem sayısı
        - Sıfır suç içeren grid-hafta oranı
        - Grid-hafta başına ortalama ve medyan suç sayısı
        - Modelde kullanılan grid sayısı
        - XGBoost 5-fold ortalama MAE, RMSE, R2
        - Normalize MAE = MAE / mean(observed crime count)
        - Veri hazırlama ve model çalışma süresi

    Ek olarak hakemin önerdiği 10 x 10 m için (tam model eğitmeden) seyreklik
    analizi: toplam hücre sayısı, aktif hücre oranı, sıfır grid-hafta oranı.

Önemli:
    - Bu script SADECE VERİTABANINI OKUR. Uygulama kodunu değiştirmez.
    - Feature engineering, mevcut crime_grid_weekly tablosunun mantığıyla
      (lag/rolling/zero/momentum/neighbor/density) birebir aynı şekilde, üç
      çözünürlük için de TUTARLI biçimde yeniden uygulanır.
    - XGBoost ayarları ve 5-katli kronolojik doğrulama mevcut modelle aynıdır.

Çalıştırma:
    cd travelsafe-api
    python grid_resolution_comparison.py
"""

import os
import time
import warnings

import numpy as np
import pandas as pd
import psycopg2
from dotenv import load_dotenv

from sklearn.model_selection import TimeSeriesSplit
from sklearn.metrics import mean_absolute_error, mean_squared_error, r2_score
from xgboost import XGBRegressor

warnings.filterwarnings("ignore")

# ---------------------------------------------------------------------------
# DB BAĞLANTISI
# ---------------------------------------------------------------------------
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "app", ".env"))
DATABASE_URL = os.getenv(
    "DATABASE_URL",
    "postgresql+psycopg2://postgres:yeni_sifre@localhost:5432/travelsafe",
)

DB_PARAMS = dict(
    host="localhost",
    port="5432",
    database="travelsafe",
    user="postgres",
    password="yeni_sifre",
)  # .env farklıysa düzeltilebilir

_HERE = os.path.dirname(os.path.abspath(__file__))
OUTPUT_CSV = os.path.join(_HERE, "grid_resolution_comparison.csv")
OUTPUT_SUMMARY_CSV = os.path.join(_HERE, "grid_resolution_summary.csv")
OUTPUT_CV_CSV = os.path.join(_HERE, "grid_resolution_cv_metrics.csv")

# Chicago referans enlemi (metre dönüşümü için) ve modelleme merkezi
REF_LAT = 41.85
M_PER_DEG_LAT = 111320.0
M_PER_DEG_LNG = 111320.0 * np.cos(np.radians(REF_LAT))  # ~82.900 m/deg

# Mevcut sistemle uyumlu veri dönemi (crime_grid_weekly başlangıcı) ve bbox
DATA_START = "2021-01-04"
BBOX = dict(
    lat_min=41.63732681153954, lat_max=42.02280114700859,
    lng_min=-87.94558663867282, lng_max=-87.51375507892669,
)

# Modelleme merkezi (dist_to_center_km için)
CENTER_LAT, CENTER_LNG = 41.878, -87.630

# Çözünürlükler (metre)
RESOLUTIONS = [250, 500, 1000]
SPARSITY_RES = 10  # hakem önerisi, sadece seyreklik analizi

# XGBoost - makale (Section 3.3) ile birebir aynı ayarlar
XGB_PARAMS = dict(
    objective="reg:squarederror",
    n_estimators=400,
    learning_rate=0.03,
    max_depth=5,
    min_child_weight=15,
    subsample=0.7,
    colsample_bytree=0.5,
    reg_alpha=1.0,
    reg_lambda=5.0,
    random_state=42,
    n_jobs=-1,
)

# Makaledeki temizleme kuralı: modelde yalnızca toplam suç sayısı
# >= MIN_CELL_TOTAL olan grid'ler kullanılır (crime_grid_weekly filtresiyle aynı).
MIN_CELL_TOTAL = 10

FEATURE_COLS = [
    "year", "month", "weekofyear",
    "month_sin", "month_cos", "week_sin", "week_cos",
    "grid_lat", "grid_lon", "dist_to_center_km",
    "lag_1w", "lag_2w", "lag_3w", "lag_4w", "lag_8w", "lag_12w", "lag_26w", "lag_52w",
    "rolling_4w_mean", "rolling_8w_mean", "rolling_12w_mean",
    "rolling_4w_std", "rolling_8w_std", "rolling_12w_std",
    "rolling_4w_max", "rolling_12w_max",
    "momentum_4_12",
    "neighbor_prev_1w", "neighbor_prev_4w_mean", "neighbor_momentum",
    "zero_ratio_12w", "weeks_since_last_crime",
    "historical_density_rank",
]


# ---------------------------------------------------------------------------
# 1. HAM SUÇ VERİSİ
# ---------------------------------------------------------------------------
def load_raw_crimes() -> pd.DataFrame:
    conn = psycopg2.connect(**DB_PARAMS)
    q = """
        SELECT "Date" AS ts, "Latitude" AS lat, "Longitude" AS lng
        FROM crime
        WHERE "Date" >= %s
          AND "Latitude"  BETWEEN %s AND %s
          AND "Longitude" BETWEEN %s AND %s
          AND "Latitude" IS NOT NULL AND "Longitude" IS NOT NULL
    """
    df = pd.read_sql(q, conn, params=(
        DATA_START,
        BBOX["lat_min"], BBOX["lat_max"], BBOX["lng_min"], BBOX["lng_max"],
    ))
    conn.close()
    df["ts"] = pd.to_datetime(df["ts"])
    # Haftalık başlangıç: Pazartesi (ISO)
    df["week_start"] = (df["ts"] - pd.to_timedelta(df["ts"].dt.weekday, unit="D")).dt.normalize()
    return df


# ---------------------------------------------------------------------------
# 2. HÜCRE ATAMA (metre tabanlı grid)
# ---------------------------------------------------------------------------
def assign_cells(df: pd.DataFrame, cell_m: int) -> pd.DataFrame:
    """
    Her suçu, cell_m x cell_m metre hücresine ata.
    Global grid: bbox tabanlı, metre koordinatlarında biner.
    """
    # metre koordinatları (global, sabit orijin = bbox sol-alt)
    x_m = (df["lng"].values - BBOX["lng_min"]) * M_PER_DEG_LNG
    y_m = (df["lat"].values - BBOX["lat_min"]) * M_PER_DEG_LAT

    gx = np.floor(x_m / cell_m).astype(np.int64)
    gy = np.floor(y_m / cell_m).astype(np.int64)

    n_cols = int(np.ceil((BBOX["lng_max"] - BBOX["lng_min"]) * M_PER_DEG_LNG / cell_m))
    # hücre kimliği
    df = df.copy()
    df["cell_id"] = gy * n_cols + gx
    # hücre merkez lat/lon (feature için)
    cx_m = (gx + 0.5) * cell_m
    cy_m = (gy + 0.5) * cell_m
    df["cell_lat"] = BBOX["lat_min"] + cy_m / M_PER_DEG_LAT
    df["cell_lon"] = BBOX["lng_min"] + cx_m / M_PER_DEG_LNG
    return df, n_cols


# ---------------------------------------------------------------------------
# 3. HAFTALIK PANEL + FEATURE ENGINEERING
# ---------------------------------------------------------------------------
def build_weekly_panel(df, n_cols, cell_m, total_cells_all):
    """
    grid x hafta paneli kur, eksik haftaları 0 ile doldur, feature üret.
    total_cells_all: bu çözünürlükteki TÜM olası hücre sayısı (bbox içinde).
    """
    # aktivite: hücre bazında ilk/son suç haftası
    counts = (df.groupby(["cell_id", "week_start"])
                .size().reset_index(name="total_count"))

    weeks = pd.date_range(df["week_start"].min(), df["week_start"].max(), freq="7D")
    cells = counts["cell_id"].unique()
    # hücre lat/lon
    cell_pos = (df.groupby("cell_id")[["cell_lat", "cell_lon"]].first().reset_index())

    # full panel
    full_idx = pd.MultiIndex.from_product([cells, weeks], names=["cell_id", "week_start"])
    panel = (counts.set_index(["cell_id", "week_start"])
                  .reindex(full_idx, fill_value=0)
                  .reset_index()
                  .sort_values(["cell_id", "week_start"]))

    panel = panel.merge(cell_pos, on="cell_id", how="left")

    g = panel.groupby("cell_id", group_keys=False)

    # Lag'ler (shift)
    for lag_w in [1, 2, 3, 4, 8, 12, 26, 52]:
        panel[f"lag_{lag_w}w"] = g["total_count"].shift(lag_w)

    # Rolling istatistikler (mevcut hafta hariç: shift(1) sonrası rolling)
    for w in [4, 8, 12]:
        shifted = g["total_count"].shift(1)
        panel[f"rolling_{w}w_mean"] = shifted.rolling(w, min_periods=1).mean().values
        panel[f"rolling_{w}w_std"] = shifted.rolling(w, min_periods=1).std().values

    shifted = g["total_count"].shift(1)
    panel["rolling_4w_max"] = shifted.rolling(4, min_periods=1).max().values
    panel["rolling_12w_max"] = shifted.rolling(12, min_periods=1).max().values

    # momentum = rolling4 - rolling12
    panel["momentum_4_12"] = panel["rolling_4w_mean"] - panel["rolling_12w_mean"]

    # zero_ratio_12w: son 12 haftada (geçmiş) sıfır olan hafta oranı
    is_zero = (panel["total_count"] == 0).astype(float)
    panel["_is_zero"] = is_zero
    zg = panel.groupby("cell_id", group_keys=False)["_is_zero"].shift(1)
    panel["zero_ratio_12w"] = zg.rolling(12, min_periods=1).mean().values

    # weeks_since_last_crime
    def weeks_since(s):
        out = []
        last = None
        idx = 0
        for v in s.values:
            if v > 0:
                out.append(0)
                last = idx
            else:
                out.append(idx - last if last is not None else idx)
            idx += 1
        return pd.Series(out, index=s.index[:len(out)]) if False else out
    panel["weeks_since_last_crime"] = (
        panel.groupby("cell_id", group_keys=False)["total_count"].transform(
            lambda s: pd.Series(weeks_since(s), index=s.index[:len(s)]) if False else
            _weeks_since_arr(s.values)
        )
    )

    # Temporal
    panel["year"] = panel["week_start"].dt.year
    panel["month"] = panel["week_start"].dt.month
    panel["weekofyear"] = panel["week_start"].dt.isocalendar().week.astype(int)
    panel["month_sin"] = np.sin(2 * np.pi * panel["month"] / 12)
    panel["month_cos"] = np.cos(2 * np.pi * panel["month"] / 12)
    panel["week_sin"] = np.sin(2 * np.pi * panel["weekofyear"] / 52)
    panel["week_cos"] = np.cos(2 * np.pi * panel["weekofyear"] / 52)

    # Spatial
    panel["grid_lat"] = panel["cell_lat"]
    panel["grid_lon"] = panel["cell_lon"]
    panel["dist_to_center_km"] = haversine(
        panel["cell_lat"].values, panel["cell_lon"].values, CENTER_LAT, CENTER_LNG
    )

    # Neighbor (8 komşu) - komşu hücrelerin önceki hafta toplamı
    panel = add_neighbor_features(panel, cell_m, n_cols)

    # historical_density_rank: hücrenin toplam suç yoğunluğunun yüzdelik sırası
    cell_total = panel.groupby("cell_id")["total_count"].sum()
    rank = cell_total.rank(pct=True) * 100
    panel["historical_density_rank"] = panel["cell_id"].map(rank)

    return panel


def _weeks_since_arr(vals):
    out = []
    idx = 0
    last = -1
    for v in vals:
        if v > 0:
            out.append(0)
            last = idx
        else:
            out.append(idx - last if last >= 0 else idx)
        idx += 1
    return out


def haversine(lat1, lon1, lat2, lon2):
    r = 6371.0
    dlat = np.radians(lat2 - lat1)
    dlon = np.radians(lon2 - lon1)
    a = np.sin(dlat/2)**2 + np.cos(np.radians(lat1))*np.cos(np.radians(lat2))*np.sin(dlon/2)**2
    return r * 2 * np.arcsin(np.sqrt(a))


def add_neighbor_features(panel, cell_m, n_cols):
    """
    8-komşuluk: aynı çözünürlükte komşu hücre kimlikleri.
    neighbor_prev_1w = komşuların önceki hafta total_count ortalaması
    """
    # hücre -> gx, gy
    cells = panel[["cell_id"]].drop_duplicates().copy()
    cells["gx"] = cells["cell_id"] % n_cols
    cells["gy"] = cells["cell_id"] // n_cols
    cell_gx = cells.set_index("cell_id")["gx"].to_dict()
    cell_gy = cells.set_index("cell_id")["gy"].to_dict()

    # (gy, gx) -> cell_id
    coord_to_cell = {(gx, gy): cid for cid, gx, gy in cells[["cell_id","gx","gy"]].itertuples(index=False)}

    # pivot: hafta x hücre -> count
    pv = panel.pivot(index="week_start", columns="cell_id", values="total_count").sort_index()
    pv_prev = pv.shift(1)  # önceki hafta

    neighbor_1w = {}
    all_cells = list(pv.columns)
    for cid in all_cells:
        gx, gy = cell_gx[cid], cell_gy[cid]
        neigh = []
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                if dx == 0 and dy == 0:
                    continue
                ncid = coord_to_cell.get((gx+dx, gy+dy))
                if ncid is not None:
                    neigh.append(ncid)
        neighbor_1w[cid] = neigh

    # önceki hafta toplamından komşu ortalaması
    prev_arr = pv_prev.reindex(columns=all_cells).fillna(0)
    n_prev1 = {}
    for cid in all_cells:
        neigh = neighbor_1w[cid]
        if neigh:
            n_prev1[cid] = prev_arr[neigh].sum(axis=1) / len(neigh)
        else:
            n_prev1[cid] = pd.Series(0.0, index=prev_arr.index)
    neighbor_prev_1w = pd.DataFrame(n_prev1)

    def map_series(dfc):
        return dfc.stack().rename("val")

    n1 = map_series(neighbor_prev_1w)
    panel = panel.merge(
        n1.reset_index().rename(columns={"level_0": "week_start", "level_1": "cell_id"}),
        on=["week_start", "cell_id"], how="left"
    ).rename(columns={"val": "neighbor_prev_1w"})

    # neighbor_prev_4w_mean: önceki 4 haftanın komşu ortalaması
    pv_prev2 = pv.shift(1).rolling(4, min_periods=1).mean()
    n_prev4 = {}
    for cid in all_cells:
        neigh = neighbor_1w[cid]
        n_prev4[cid] = (pv_prev2.reindex(columns=neigh).sum(axis=1) / len(neigh)) if neigh else pd.Series(0.0, index=pv_prev2.index)
    n4 = pd.DataFrame(n_prev4).stack().rename("val")
    panel = panel.merge(
        n4.reset_index().rename(columns={"level_0": "week_start", "level_1": "cell_id"}),
        on=["week_start", "cell_id"], how="left"
    ).rename(columns={"val": "neighbor_prev_4w_mean"})

    panel["neighbor_momentum"] = panel["neighbor_prev_1w"] - panel["neighbor_prev_4w_mean"]
    return panel


# ---------------------------------------------------------------------------
# 4. MODEL EĞİTİMİ (5-katli kronolojik)
# ---------------------------------------------------------------------------
def train_eval(panel, features):
    df = panel.sort_values("week_start").copy()

    # Makale Eq. (2): salınımlı (stationary) hedef
    #   z = log1p(y) - log1p(y^(4)),  y^(4) = önceki 4 haftalık ortalama
    df["target_log"] = np.log1p(df["total_count"])
    df["baseline_log"] = np.log1p(df["rolling_4w_mean"].fillna(0))
    df["target_diff"] = df["target_log"] - df["baseline_log"]

    X = df[features].copy()
    for c in X.columns:
        X[c] = pd.to_numeric(X[c], errors="coerce")
    X = X.fillna(0)
    y = df["target_diff"].fillna(0)
    base_log_all = df["baseline_log"].to_numpy()

    tscv = TimeSeriesSplit(n_splits=5)
    maes, rmses, r2s = [], [], []
    observed_means = []
    fold_records = []

    for fold_no, (tr, te) in enumerate(tscv.split(X), start=1):
        model = XGBRegressor(**XGB_PARAMS)
        model.fit(X.iloc[tr], y.iloc[tr])

        pred_diff = model.predict(X.iloc[te])
        base_log_te = base_log_all[te]

        # Tahmini geri dönüştür (Eq. 2 tersi)
        pred = np.clip(np.expm1(pred_diff + base_log_te), 0, None)
        real = np.clip(np.expm1(y.iloc[te].to_numpy() + base_log_te), 0, None)

        fold_mae = mean_absolute_error(real, pred)
        fold_rmse = np.sqrt(mean_squared_error(real, pred))
        fold_r2 = r2_score(real, pred)
        fold_obs = float(real.mean())

        observed_means.append(fold_obs)
        maes.append(fold_mae)
        rmses.append(fold_rmse)
        r2s.append(fold_r2)

        fold_records.append(dict(
            fold=fold_no,
            train_size=int(len(tr)),
            test_size=int(len(te)),
            mae=round(float(fold_mae), 4),
            rmse=round(float(fold_rmse), 4),
            r2=round(float(fold_r2), 4),
            mean_observed=round(fold_obs, 4),
            norm_mae=round(float(fold_mae) / fold_obs, 4) if fold_obs > 0 else np.nan,
        ))

    mean_obs = float(np.mean(observed_means)) if observed_means else 0.0
    mean_mae = float(np.mean(maes))
    return dict(
        mae=mean_mae,
        rmse=float(np.mean(rmses)),
        r2=float(np.mean(r2s)),
        norm_mae=mean_mae / mean_obs if mean_obs > 0 else np.nan,
        mean_observed=mean_obs,
        fold_metrics=fold_records,
    )


# ---------------------------------------------------------------------------
# 5. TEK ÇÖZÜNÜRLÜK İŞLEME
# ---------------------------------------------------------------------------
def process_resolution(raw_df, cell_m, full_model=True):
    t0 = time.time()
    df, n_cols = assign_cells(raw_df, cell_m)

    # bu çözünürlükteki TÜM olası hücreler (bbox içinde)
    n_cols_total = int(np.ceil((BBOX["lng_max"] - BBOX["lng_min"]) * M_PER_DEG_LNG / cell_m))
    n_rows_total = int(np.ceil((BBOX["lat_max"] - BBOX["lat_min"]) * M_PER_DEG_LAT / cell_m))
    total_cells = n_cols_total * n_rows_total

    active_cells = df["cell_id"].nunique()

    if not full_model:
        # sadece seyreklik analizi
        n_weeks = df["week_start"].nunique()
        grid_weeks = active_cells * n_weeks  # aktif hücreler üzerinden
        act_counts = df.groupby(["cell_id", "week_start"]).size()
        # sıfır grid-hafta oranı: (toplam aktif hücre-hafta - dolu) / toplam
        filled = len(act_counts)
        zero_ratio = 1 - filled / grid_weeks if grid_weeks > 0 else np.nan
        prep_time = time.time() - t0
        return dict(
            resolution_m=cell_m,
            total_cells=total_cells,
            active_cells=active_cells,
            active_cell_ratio=active_cells / total_cells,
            total_grid_weeks=int(grid_weeks),
            zero_grid_week_ratio=zero_ratio,
            mean_crimes_per_grid_week=float(act_counts.mean()),
            median_crimes_per_grid_week=float(act_counts.median()),
            model_cells=None,
            mae=np.nan, rmse=np.nan, r2=np.nan, norm_mae=np.nan,
            prep_time_s=round(prep_time, 2),
            model_time_s=np.nan,
            note="sadece seyreklik analizi (tam model egitilmedi)",
        )

    panel = build_weekly_panel(df, n_cols, cell_m, total_cells)

    # Makaledeki temizleme kuralı: toplam suç sayısı < MIN_CELL_TOTAL olan
    # grid'ler modelden çıkarılır (crime_grid_weekly sorgusuyla birebir aynı).
    cell_totals = panel.groupby("cell_id")["total_count"].sum()
    eligible = cell_totals[cell_totals >= MIN_CELL_TOTAL].index
    panel = panel[panel["cell_id"].isin(eligible)].copy()

    prep_time = time.time() - t0

    # panel istatistikleri
    total_grid_weeks = len(panel)
    zero_ratio = float((panel["total_count"] == 0).mean())
    mean_cpw = float(panel["total_count"].mean())
    median_cpw = float(panel["total_count"].median())
    model_cells = panel["cell_id"].nunique()

    # model
    t1 = time.time()
    metrics = train_eval(panel, FEATURE_COLS)
    model_time = time.time() - t1

    return dict(
        resolution_m=cell_m,
        total_cells=total_cells,
        active_cells=active_cells,
        active_cell_ratio=round(active_cells / total_cells, 4),
        total_grid_weeks=int(total_grid_weeks),
        zero_grid_week_ratio=round(zero_ratio, 4),
        mean_crimes_per_grid_week=round(mean_cpw, 4),
        median_crimes_per_grid_week=round(median_cpw, 4),
        model_cells=model_cells,
        mae=round(metrics["mae"], 4),
        rmse=round(metrics["rmse"], 4),
        r2=round(metrics["r2"], 4),
        norm_mae=round(metrics["norm_mae"], 4),
        prep_time_s=round(prep_time, 2),
        model_time_s=round(model_time, 2),
        note="",
        fold_metrics=metrics["fold_metrics"],
    )


# ---------------------------------------------------------------------------
# ANA AKIŞ
# ---------------------------------------------------------------------------
def main():
    print("=" * 78)
    print("Grid Çözünürlük Karşılaştırması (250 / 500 / 1000 m) + 10m seyreklik")
    print("=" * 78)

    print("\n[1/3] Ham suç verisi yükleniyor...")
    t = time.time()
    raw = load_raw_crimes()
    print(f"      {len(raw):,} suç kaydı ({time.time()-t:.1f}s), "
          f"{raw['week_start'].min().date()} .. {raw['week_start'].max().date()}")

    results = []

    print("\n[2/3] 250 / 500 / 1000 m çözünürlükleri işleniyor...")
    for res in RESOLUTIONS:
        print(f"      -> {res} m ...", flush=True)
        r = process_resolution(raw, res, full_model=True)
        results.append(r)
        print(f"         hücre={r['total_cells']:,} aktif={r['active_cells']:,} "
              f"MAE={r['mae']} R2={r['r2']} ({r['prep_time_s']}+{r['model_time_s']}s)")

    print(f"\n[3/3] {SPARSITY_RES} m seyreklik analizi (tam model yok)...")
    r10 = process_resolution(raw, SPARSITY_RES, full_model=False)
    results.append(r10)
    print(f"      -> toplam hücre={r10['total_cells']:,} aktif={r10['active_cells']:,} "
          f"({r10['active_cell_ratio']*100:.4f}%) sıfır-oran={r10['zero_grid_week_ratio']*100:.2f}%")

    # CSV - ana karşılaştırma tablosu
    df_out = pd.DataFrame(results)
    cols = [
        "resolution_m", "total_cells", "active_cells", "active_cell_ratio",
        "total_grid_weeks", "zero_grid_week_ratio",
        "mean_crimes_per_grid_week", "median_crimes_per_grid_week",
        "model_cells", "mae", "rmse", "r2", "norm_mae",
        "prep_time_s", "model_time_s", "note",
    ]
    df_out = df_out[cols]
    df_out.to_csv(OUTPUT_CSV, index=False, encoding="utf-8")

    # CSV - özet tablo (summary): ana tablo + 5-fold ortalama std'leri
    summary_df = df_out.copy()
    summary_df["cv_folds"] = 5
    std_rows = {
        r["resolution_m"]: r for r in results if r.get("fold_metrics")
    }
    def _std(res, key):
        recs = std_rows.get(res, {}).get("fold_metrics", [])
        return round(float(np.std([x[key] for x in recs])), 4) if recs else np.nan
    summary_df["mae_std"] = summary_df["resolution_m"].map(lambda r: _std(r, "mae"))
    summary_df["rmse_std"] = summary_df["resolution_m"].map(lambda r: _std(r, "rmse"))
    summary_df["r2_std"] = summary_df["resolution_m"].map(lambda r: _std(r, "r2"))
    summary_df.to_csv(OUTPUT_SUMMARY_CSV, index=False, encoding="utf-8")

    # CSV - 5-fold fold bazlı metrikler
    cv_rows = []
    for r in results:
        for rec in r.get("fold_metrics", []):
            cv_rows.append({
                "resolution_m": r["resolution_m"],
                "model_cells": r["model_cells"],
                "total_grid_weeks": r["total_grid_weeks"],
                **rec,
            })
    cv_df = pd.DataFrame(cv_rows)
    cv_df.to_csv(OUTPUT_CV_CSV, index=False, encoding="utf-8")

    print("\n" + "=" * 78)
    print("SONUÇ TABLOSU")
    print("=" * 78)
    with pd.option_context("display.max_columns", None, "display.width", 200):
        print(df_out.to_string(index=False))

    print("\n" + "=" * 78)
    print("5-FOLD CV METRİKLERİ (grid_resolution_cv_metrics.csv)")
    print("=" * 78)
    with pd.option_context("display.max_columns", None, "display.width", 200):
        print(cv_df.to_string(index=False))

    print(f"\nCSV yazıldı -> {OUTPUT_CSV}")
    print(f"CSV yazıldı -> {OUTPUT_SUMMARY_CSV}")
    print(f"CSV yazıldı -> {OUTPUT_CV_CSV}")
    print("\nBitti.")


if __name__ == "__main__":
    main()

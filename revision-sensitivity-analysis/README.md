# Revision Sensitivity Analysis — TravelSafe

Bu klasör, **TravelSafe** makalesinin hakem raporuna yanıt olarak yapılan iki
duyarlılık analizini ve tekrar üretilebilirlik dosyalarını içerir:

1. **Grid çözünürlüğü duyarlılık analizi** (250 / 500 / 1000 m + 10 m seyreklik)
2. **Suç kategorisi ağırlık duyarlılık analizi** (Base / Equal / Compressed / Violent-focused)

> Bu çalışma, makaledeki Tablo 3 sonuçlarını değiştirmek için değil, hakemin
> grid boyutu ve ağırlıklandırma tercihlerine ilişkin sorularını sayısal olarak
> yanıtlamak için yapılmıştır.

---

## 1. Veri ve dönem

| Öğe | Değer |
|---|---|
| Suç kaynağı | City of Chicago "Crimes — 2001 to Present" (Open Data Portal) |
| Analiz dönemi | **2021-01-04 – 2025-08-04** (haftalık, Pazartesi başlangıçlı) |
| Bounding box | lat 41.63732681153954 – 42.02280114700859, lng −87.94558663867282 – −87.51375507892669 |
| Ham kayıt sayısı | 1.094.336 |
| Yol ağı | OpenStreetMap → PostgreSQL/PostGIS (`road_nodes`, `road_segments`) |
| Veritabanı | PostgreSQL + PostGIS + pgRouting (`travelsafe`) |
| Referans enlem (m↔derece) | 41.85° (111.320 m/der; lng için cos düzeltmesi) |

**Suç kategorisi ağırlıkları (Base):** Violent 1.0 · Property 0.6 · Drug/Vice 0.4 · Public-order 0.3

**Model:** XGBoost — `n_estimators=400, learning_rate=0.03, max_depth=5,
min_child_weight=15, subsample=0.7, colsample_bytree=0.5, reg_alpha=1.0, reg_lambda=5.0`,
hedef `z = log1p(y) − log1p(y^(4))` (makale Eq. 2), 5-katlı kronolojik `TimeSeriesSplit`.

---

## 2. Klasör yapısı

```
revision_sensitivity_analysis/
├── README.md                          ← bu dosya
├── grid_resolution_summary.md         ← grid analizi kısa özeti (bulgular + yorum)
├── weight_sensitivity_summary.md      ← ağırlık analizi kısa özeti
├── sql/
│   ├── schema_full.sql                ← pg_dump --schema-only (tüm şema)
│   ├── schema_core.sql                ← analizle ilgili 10 çekirdek tablo
│   └── queries.sql                    ← analizlerde kullanılan SQL sorguları
├── scripts/
│   ├── grid_resolution_comparison.py  ← analiz 1 (250/500/1000 m + 10 m seyreklik)
│   ├── test_weight_sensitivity.py     ← analiz 2 (4 ağırlık seti × 6 senaryo × 3 profil)
│   ├── reference_xgboost_weekly_main_script.py  ← ana XGBoost eğitim script'i (referans)
│   └── reference_osm_road_import.py   ← OSM yol ağının DB'ye aktarım script'i (referans)
├── data/
│   ├── grid_resolution_summary.csv
│   ├── grid_resolution_cv_metrics.csv
│   ├── weight_sensitivity_routes.csv
│   └── weight_sensitivity_summary.csv
└── logs/
    └── run_log_grid_resolution.txt
```

> **Not:** `schema_*.sql` dosyaları canlı veritabanından `pg_dump --schema-only`
> ile üretilmiştir; tabloların/indekslerin birebir kaydıdır. Orijinal kurulum
> script'leri ayrıca saklanmamıştı.

---

## 3. Analiz 1 — Grid çözünürlüğü

**Amaç:** Aynı veri dönemi, temizleme kuralları (grid başına toplam suç ≥ 10),
suç kategorileri, hedef tanımı ve XGBoost ayarları korunarak 250 / 500 / 1000 m
çözünürlüklerinin karşılaştırılması. 10 m için tam model eğitilmez; yalnızca
seyreklik analizi yapılır.

**Çalıştırma:**
```bash
cd travelsafe-api
python grid_resolution_comparison.py
```
Gereksinim: `psycopg2`, `pandas`, `numpy`, `scikit-learn`, `xgboost`, `python-dotenv`;
`app/.env` içinde `DATABASE_URL` (veya script içindeki `DB_PARAMS`).

**Çıktılar:**
- `data/grid_resolution_summary.csv` — çözünürlük başına tüm metrikler (+ fold std'leri, 10 m seyreklik satırı)
- `data/grid_resolution_cv_metrics.csv` — fold bazlı (3 çözünürlük × 5 fold = 15 satır)
- `grid_resolution_summary.md` — kısa özet ve yorum

**Sonuç (özet):**

| m | Sıfır oranı | MAE | RMSE | R² | Normalize MAE | Model grid |
|---|---|---|---|---|---|---|
| 250 | %64,2 | 0,243 | 0,661 | 0,678 | 0,390 | 7.518 |
| 500 | %34,2 | 0,838 | 1,567 | 0,694 | 0,398 | 2.228 |
| 1000 | %16,6 | 2,051 | 3,385 | 0,833 | **0,282** | 646 |
| 10 | %97,6 | — | — | — | — | — |

10 m: 15.369.652 hücre, yalnızca %1,09'u aktif → haftalık tahmin için aşırı seyrek.

---

## 4. Analiz 2 — Ağırlık duyarlılığı

**Amaç:** Farklı kriminolojik önceliklerin rota seçimine etkisini ölçmek.
Aynı 3 senaryo × 2 mod × 3 profil (Shortest λ=0, Balanced λ=5, Safest λ=50)
4 ağırlık seti ile çalıştırılır → **72 rota kaydı**.

| Set | Violent | Property | Drug/Vice | Public-order |
|---|---|---|---|---|
| Base | 1.0 | 0.6 | 0.4 | 0.3 |
| Equal | 1.0 | 1.0 | 1.0 | 1.0 |
| Compressed | 1.0 | 0.8 | 0.6 | 0.4 |
| Violent-focused | 1.0 | 0.5 | 0.25 | 0.15 |

**Çalıştırma:**
```bash
cd travelsafe-api
python test_weight_sensitivity.py
```

**Çıktılar:**
- `data/weight_sensitivity_routes.csv` — her (ağırlık seti, senaryo, mod, profil) için:
  rota mesafesi, normalize risk, üretim süresi, `changed_vs_base`,
  `jaccard_vs_base`, `overlap_ratio_vs_base`
- `data/weight_sensitivity_summary.csv` — ağırlık seti bazında özet + sıralama korunumu
- `weight_sensitivity_summary.md` — kısa özet ve yorum

**Sonuç (özet):**

| Set | Değişen rota | Ort. Jaccard | Maks. risk sapması | Ort. mesafe sapması |
|---|---|---|---|---|
| Equal | 5/18 (%28) | 0,943 | 0,170 | 0,11 m |
| Compressed | 3/18 (%17) | 0,947 | 0,179 | 0,11 m |
| Violent-focused | 2/18 (%11) | 0,985 | 0,015 | 1,06 m |

**Değişim yalnızca Balanced profilinde**; Shortest riskten bağımsız olduğu için hiç
değişmez. Mesafe sıralaması (Shortest ≤ Balanced ≤ Safest) tüm ağırlık setlerinde
ve tüm senaryo/mod kombinasyonlarında korunur.

---

## 5. Sınırlar

- Ağırlık analizi yalnızca 3 O-D senaryosu × 2 mod üzerinde yapılmıştır; genel bir
  "ağırlık duyarsızlığı" iddiası için daha fazla O-D çifti gerekir.
- Grid analizindeki mutlak sayılar, ana `crime_grid_weekly` hattından farklı bir
  panel/orijin kurgusu kullandığı için makaledeki Tablo 3 değerleriyle birebir
  aynı olmayabilir; karşılaştırma **kendi içinde tutarlıdır**.
- 10 m için model eğitilmemiştir (hakemin de belirttiği gibi zorunlu değildir);
  yalnızca seyreklik göstergeleri raporlanmıştır.

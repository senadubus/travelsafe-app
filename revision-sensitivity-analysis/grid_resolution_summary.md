# Grid Çözünürlüğü Duyarlılık Analizi — Özet

**Amaç.** TravelSafe'te sabit 500 × 500 m grid ile üretilen haftalık suç tahmininin
mekânsal çözünürlüğe duyarlılığını incelemek. Aynı veri dönemi (2021-01-04 – 2025-08-04),
aynı temizleme kuralları (grid başına toplam suç ≥ 10), aynı suç kategorileri, aynı
salınımlı hedef (`z = log1p(y) − log1p(y^(4))`, makale Eq. 2), aynı XGBoost ayarları
(400 / lr 0.03 / depth 5 / mcw 15 / sub 0.7 / col 0.5 / α 1 / λ 5) ve aynı 5-katlı
kronolojik doğrulama (`TimeSeriesSplit`) ile 250 / 500 / 1000 m çözünürlükleri
karşılaştırılmıştır. Hakemin önerdiği 10 × 10 m için tam model eğitilmemiş, yalnızca
seyreklik analizi yapılmıştır.

## Sonuç tablosu

| Çözünürlük (m) | Toplam grid | Aktif grid | Aktif oran | Toplam grid-hafta | Sıfır grid-hafta oranı | Ort. suç/grid-hafta | Medyan suç/grid-hafta | Modelde kullanılan grid | MAE | RMSE | R² | Normalize MAE | Veri hazırlama (s) | Model (s) |
|---|---|---|---|---|---|---|---|---|---|---|---|---|---|---|
| 250 | 24.768 | 8.412 | 0,340 | 1.804.320 | **%64,2** | 0,605 | 0 | 7.518 | 0,243 | 0,661 | 0,678 | 0,390 | 12,87 | 46,16 |
| 500 | 6.192 | 2.377 | 0,384 | 534.720 | %34,2 | 2,045 | 1 | 2.228 | 0,838 | 1,567 | 0,694 | 0,398 | 2,61 | 13,22 |
| 1000 | 1.548 | 676 | 0,437 | 155.040 | %16,6 | 7,058 | 5 | 646 | 2,051 | 3,385 | **0,833** | **0,282** | 0,77 | 6,21 |
| 10 (yalnız seyreklik) | 15.369.652 | 166.872 | 0,011 | 40.049.280 | **%97,6** | 1,132 | 1 | — | — | — | — | — | 0,17 | — |

## Bulgular

1. **Sıfır enflasyonu çözünürlük inceldikçe hızla artıyor.** Sıfır grid-hafta oranı
   1000 m'de %16,6, 500 m'de %34,2, 250 m'de %64,2. Grid küçüldükçe hedeflerin büyük
   çoğunluğu sıfır oluyor; regresyon problemi sıfır-enflasyonlu (zero-inflated) yapıya
   dönüşüyor.

2. **Mutlak MAE yanıltıcı; adil karşılaştırma normalize MAE.** 250 m'de MAE (0,243)
   küçük görünüyor ama hücre başına ortalama suç da küçük (0,605). Normalize MAE =
   MAE / ortalama gözlenen suç: 1000 m'de **0,282** (en iyi), 250 m'de 0,390, 500 m'de
   0,398 (en kötü). Yani coarse grid göreli hatada daha başarılı.

3. **R² çözünürlükle artıyor.** 0,678 (250 m) → 0,694 (500 m) → 0,833 (1000 m).
   Coarse grid'de hücre başına suç sayısı büyüdüğü ve sinyal/gürültü oranı yükseldiği
   için açıklanan varyans belirgin şekilde artıyor.

4. **Maliyet–doğruluk dengesi.** Model süresi 46,2 s (250 m) → 13,2 s (500 m) →
   6,2 s (1000 m); model grid sayısı 7.518 → 2.228 → 646. 500 m, doğruluk
   (normalize MAE 0,398) ile maliyet (~13 s) arasında makul bir uzlaşma noktası veriyor;
   250 m belirgin bir kazanç sağlamıyor, aksine sıfır oranını %64'e çıkarıyor.

5. **10 × 10 m haftalık tahmin için pratik değil.** BBox içinde 15,37 milyon hücre var;
   yalnızca **%1,09'u** suç kaydı içeriyor ve grid-hafta'ların **%97,6'sı sıfır**.
   Bu düzeyde hücrelerin neredeyse tamamı haftada 0 ya da 1 olayla temsil edilir;
   haftalık regresyon hedefi sinyal taşımaz. 10 m ancak nokta düzeyinde yoğunluk
   görselleştirmesi (heatmap) için anlamlıdır, tahmin birimi olarak değil.



# Suç Kategorisi Ağırlıkları Duyarlılık Analizi 

**Amaç.** Mevcut temel ağırlıklar (Violent 1.0, Property 0.6, Drug/Vice 0.4,
Public-order 0.3) yerine alternatif ağırlık setleri kullanıldığında rota üretiminin
ne ölçüde değiştiğini göstermek. Aynı altı rota isteği (3 senaryo × 2 mod) ve aynı
üç rota profili (Shortest λ=0, Balanced λ=5, Safest λ=50) ile 4 ağırlık seti
çalıştırılmıştır → **4 × 3 × 2 × 3 = 72 rota kaydı**.

## Ağırlık setleri

| Set | Violent | Property | Drug/Vice | Public-order |
|---|---|---|---|---|
| Base | 1.0 | 0.6 | 0.4 | 0.3 |
| Equal | 1.0 | 1.0 | 1.0 | 1.0 |
| Compressed | 1.0 | 0.8 | 0.6 | 0.4 |
| Violent-focused | 1.0 | 0.5 | 0.25 | 0.15 |

## Sonuçlar (`weight_sensitivity_summary.csv`)

| Ağırlık seti | Değişen rota | Değişim oranı | Ort. Jaccard | Min. Jaccard | Ort. overlap | Maks. risk sapması | Ort. mesafe sapması (m) | Ort. süre (ms) |
|---|---|---|---|---|---|---|---|---|
| Base | 0/18 | 0,00 | 1,000 | 1,000 | 1,000 | 0,000 | 0,00 | 7451,80 |
| Equal | 5/18 | 0,28 | 0,943 | 0,611 | 0,970 | 0,170 | 0,11 | 7631,85 |
| Compressed | 3/18 | 0,17 | 0,947 | 0,611 | 0,972 | 0,179 | 0,11 | 7560,28 |
| Violent-focused | 2/18 | 0,11 | 0,985 | 0,758 | 0,992 | 0,015 | 1,06 | 7445,69 |

## Bulgular

1. **Rotalar ağırlık değişimine büyük ölçüde dayanıklı.** Equal sette bile 18 rotanın
   yalnızca 5'i (%28) değişiyor; Violent-focused sette bu sayı 2/18'e (%11) düşüyor.
   Ortalama Jaccard 0,94–0,99 aralığında, yani seçilen yol segmentlerinin ezici
   çoğunluğu korunuyor.

2. **Değişim yalnızca Balanced profilinde yoğunlaşıyor.** Değişen 10 rotanın tamamı
   Balanced (λ=5) profilinde. Shortest (λ=0) riskten bağımsız olduğu için hiç değişmiyor;
   Safest (λ=50) ise risk ağırlığındaki değişime karşı yeterince baskın olduğu için
   neredeyse hiç sapmıyor (yalnızca marjinal Jaccard 0,94–0,98).

3. **Profil sıralaması korunuyor.** Her (senaryo, mod, ağırlık seti) için mesafeye göre
   sıralama tutarlı: Shortest ≤ Balanced ≤ Safest. Ayrıca Safest rotasının normalize
   riski Shortest'ten düşük çıkıyor (6 durumda 5'inde). Yani ağırlıkların değişmesi
   rota alternatiflerinin *sıralamasını* bozmuyor, sadece Balanced'ın seçtiği segmentleri
   kaydırıyor.

4. **Mesafe etkisi ihmal edilebilir.** Ortalama mutlak mesafe sapması 0,11 m
   (Equal/Compressed) ve 1,06 m (Violent-focused). Yani ağırlıklandırma tercihi rota
   uzunluğunu pratikte değiştirmiyor.

5. **Süre sabit.** Ortalama rota üretim süresi tüm setlerde 7,45–7,63 s aralığında;
   ağırlık seti sayısı çalışma zamanını etkilemiyor (aynı graf ve aynı edge sayısı).

## Yorum

Ağırlıklandırma tercihi, seçilen rotaların **kimliğini** değil yalnızca **derecelendirmesini**
etkiliyor. Bu, makalede önerilen temel ağırlıkların (1.0/0.6/0.4/0.3) sonuçlarının
alternatif ağırlıklara karşı savunulabilir olduğunu gösteriyor: farklı bir kriminolojik
öncelik benimsenmesi durumunda bile aynı rota ailesi seçilmeye devam ediyor.

**Uyarı:** Bu analiz yalnızca 3 senaryo × 2 mod üzerinde yapılmıştır; genel bir
"ağırlık duyarsızlığı" iddiası için daha fazla O-D çifti gerekir.

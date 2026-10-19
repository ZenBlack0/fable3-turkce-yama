# Köylü / Ambient Diyalog Üslup Rehberi (blok 21–273)

## Hitap
- Köylü → Kahraman: **sen**. Çocuklar da "sen"; ebeveyne "anne/baba".
- "your majesty / my king / my queen" geçen HER satır: **siz** (QA uyarı verir). Hükümdarlık dönemi belli değilse "sen" kullan, `work/review/belirsiz_hitap_XX.txt` listesine ekle.
- Soylu, tüccar, görevli, muhafız (resmî ağız): "siz" (kahramana "efendim/hanımefendi" gender-split satırlarında).
- Sanayi işçisi / serseri / dilenci: "sen", konuşma dili.

## Şive / sınıf
- Köylü: sıcak, hafif konuşma dili ("bi", "valla", "yani") — ölçülü, imla bozulmaz.
- Sanayi işçisi/serseri: kaba, kısa cümleler ("abi", "ulan" yalnızca küfürlü satırlarda), argo yumuşatılmaz ama abartılmaz.
- Soylu: uzun, resmî cümle, "efendim", "lütfen".
- Çocuk: kısa cümle, "bi", "çok çok", "anneciğim" ölçüsünde; kekeleme/ses taklitleri aynen.
- Dilenci: "Bir bozuk para…", "Allah razı olsun" gibi dinî kalıp KULLANMA (oyun dünyasında yok); "Lütfen", "Yardım edin".

## Tepki kalıpları (tutarlı kullan)
| Tür | Kalıp |
|---|---|
| Selam | Selam! / Merhaba. / Hoş geldin. (siz: Hoş geldiniz.) |
| Hayranlık | Vay canına! / Harikasın! / Muhteşem! |
| İmza isteği | İmzanı alabilir miyim? (siz: İmzanızı alabilir miyim, Majesteleri?) |
| Korku | İmdat! / Yardım edin! / Yaklaşma! |
| İğrenme | Öğk! / İğrenç! / Pis! |
| Flört | Merhaba yakışıklı / güzelim; "bana bak" tonu, taciz tonuna kaçma |
| Dedikodu | Duydun mu? … / Söylenene göre … |
| Kovma (ev) | Burada işin yok. Çık. / Muhafızlar! |
| Teşekkür | Sağ ol! / Teşekkürler! |

## Teknik
- `[güler]`, `[inler]` gibi köşeli notlar çevrilir. `<laughs>` `<sighs>` `<hums>` (açılı) AYNEN kalır (`=`).
- `%1 %2 <img>` kodları korunur. `…` yok, `...` kullan.
- Küfür/ünlem hafifletilmez ama doğal olur: "Balls!" → "Kahretsin!".
- "you see" → "anlayacağın / biliyorsun ya"; "görüyorsun" değil.
- Kalıp (calque) çeviri yok; deyimin Türkçe karşılığını ara.
- "Hobb": hobbun, hobba, hobbu; çoğul Hobblar.
- Bahçe cücesi: "Bahçe Cücesi / Bahçe Cüceleri" (glossary). Kısa "cüce" yalnızca bağlam (Brian vb.) netse.
- Nanny = dadı; Balverin = Balverin; Mum/Mummy = Anne/Annecik; Dad/Daddy = Baba/Babacığım.

## Eklemeler (onaylı)
- **Çeşitlilik:** Tepki tablosu bir HAVUZDUR. Aynı durumun farklı İngilizce satırları ("Hello!", "Hi there!", "Morning!", "Well, hello!") farklı Türkçe karşılık alır (Selam! / Merhaba! / Günaydın! / Ooo, merhaba! / Selamlar!). qa.py: aynı blokta 3+ farklı İngilizce metin aynı çeviriye düşerse uyarır.
- **Dinî ifade yok:** İnşallah, Maşallah, Allah'ım, Allah razı olsun, Hamdolsun, (çok) şükür KULLANMA. "Valla" serbest. "Oh my god / Good God / Gods" → "Aman tanrım" / "Tanrılar aşkına"; "thank goodness" → "Tanrılara şükür" / "Neyse ki".
- **Tiksinti:** "Iyy!" ("Öğk" yalnızca kusma sesi).
- **İngiliz hitapları:** mate → dostum / ahbap (işçi için "kanka" değil); love / luv / dearie / duck → canım / güzelim / tatlım (kadın köylü ağzı); guv / guv'nor → patron / beyim; lad / lass → delikanlı / kızım; sir / madam (resmî) → efendim / hanımefendi.

## Calque kalıpları (qa.py uyarı verir)
- "I bet ..." → "bahse girerim" değil: "Eminim ...", "Kesin ...", "...dır kesin" (dönüşümlü).
- "How does it feel ..." → "nasıl hissettiriyor" değil: "nasıl bir duygu", "nasıl bir şey".
- "I must say / I must admit" → "söylemeliyim / itiraf etmeliyim" değil: "doğrusu", "hani".
- "Do you mind?" (sinirli) → "sakıncası var mı" değil: "rica etsem!", "lütfen ama!", "yapma şunu!".
- "quite / rather / really rather" → "oldukça / epey" çoğu zaman gereksiz; gerekirse "bayağı", "resmen", "...ötesi".
- Diğer sızanlar: "sana ne düşündürdü", "vahşi biri" (wild one), "aşk dolu" (amorous), "aşk modu", "o yoldan gitmem" (don't go that way).

## Calque kalıpları (tur_07 eki)
- "just" → her yerde "sadece" yapma: düpedüz / resmen / "o kadar", "hepsi bu" ya da at.
- Cümle başı "Why," → "Vay,", "Bak sen,", "Aa," (Neden değil).
- "I'd rather" → "...sam iyi olur / ...sam daha iyi"; resmî ağızda "...mayı yeğlerim". "tercih ederim" değil.
- "Yawn!" → ses: "Uaaahh!" / "Haaa-hım!" (esne değil).

# Photograph — Project Spec v3

> Tài liệu nguồn duy nhất cho dự án. Mọi quyết định sản phẩm và kỹ thuật đều nằm ở đây.
> Cập nhật: 2026-09-25 — v3: chuyển sang **chế độ 0đ** (không có Apple Developer Program trả phí), xem §3.

---

## 1. Tổng quan

- **Tên app:** Photograph
- **Nền tảng:** iOS only (iPhone). Không làm Android, không làm iPad ở giai đoạn này.
- **Đối tượng:** Các cặp đôi đang yêu (mô hình 1-1 khép kín tuyệt đối).
- **Giá trị cốt lõi:** Một "ngôi nhà kỹ thuật số" riêng cho 2 người — tập trung vào chiều sâu cảm xúc, thói quen tương tác hằng ngày, và lưu giữ kỷ niệm dài hạn. Không phải mạng xã hội.
- **Giai đoạn hiện tại:** Mới có ý tưởng, chưa có code.
- **Mục tiêu gần nhất:** MVP chạy trên đúng 2 iPhone, cài trực tiếp qua Xcode bằng Apple ID miễn phí.
- **Nguồn lực:** 1 dev solo, part-time (~8–10 giờ/tuần). Có máy Mac. **Không có** Apple Developer Program trả phí ($99/năm), **không** dùng gói Firebase trả phí (Blaze).

### Khác biệt với Locket

| Khía cạnh | Locket | Photograph |
|---|---|---|
| Mô hình | 1 – nhiều | **1 – 1 khép kín** |
| Nội dung | Ảnh/video ngắn | Ảnh, doodle, note, cảm xúc, trạng thái |
| Chiều sâu | Xem khoảnh khắc | Daily Question, Mood, Trạm hạ nhiệt |
| Dữ liệu | Feed trôi nhanh | Bảo tàng kỷ niệm, Love Wrapped |

---

## 2. Phạm vi

### MVP (v1.0) — bắt buộc

| # | Tính năng | Mô tả ngắn |
|---|---|---|
| F1 | Auth + Ghép đôi | Firebase Anonymous Auth; ghép bằng mã mời 6 ký tự; 1 user chỉ thuộc đúng 1 couple |
| F2 | Gửi khoảnh khắc | Ảnh hoặc note ngắn (≤80 ký tự); hiện trên widget của người kia ở lần widget làm mới kế tiếp (~15–60 phút), ngay lập tức khi người kia mở app |
| F3 | Widget | Home screen small/medium/large + lock screen; nút ❤️ tương tác |
| F4 | Nút ❤️ "Nhớ cậu" | Bấm trên widget → ghi Firestore; widget người kia hiện "💓 ×N" ở lần làm mới kế tiếp |
| F5 | Daily Question | 20:00 mỗi ngày (nhắc bằng local notification); **blind reveal**: phải trả lời mới xem được câu trả lời của người kia |
| F6 | Mood Check-in | Cảm xúc + năng lượng (Love Tank) + "Tớ đang cần…" |

### v1.1 — ngay sau MVP

| # | Tính năng | Mô tả ngắn |
|---|---|---|
| F7 | Trạm hạ nhiệt | Cơ chế hoà giải khi cãi vã (chi tiết ở §5) |
| F8 | Doodle | Vẽ tay bằng PencilKit |

### Giai đoạn 2 — chỉ khi có Apple Developer Program ($99)

Push thời gian thực qua APNs + Notification Service Extension (widget đổi ảnh trong ~5 giây, tim có âm thanh riêng) · Sign in with Apple · TestFlight. Thiết kế gốc giữ ở §3b.

### Backlog (KHÔNG làm bây giờ)

Gratitude Journal · Period tracker · Random date/food generator · Timeline kỷ niệm · Love Wrapped · Video · Android

---

## 3. Quyết định kỹ thuật (đã chốt)

### Chế độ 0đ — ràng buộc gốc

| Thứ | Giới hạn | Hệ quả |
|---|---|---|
| Apple ID miễn phí (Personal Team) | Không Push Notifications, không Sign in with Apple, không TestFlight. App **hết hạn sau 7 ngày**, tối đa 3 app tự ký/máy, tối đa 10 App ID mới / 7 ngày | Không có NSE. Cài lại cả 2 máy qua Xcode mỗi tuần |
| Firebase gói Spark (miễn phí) | Không Cloud Functions, không Cloud Storage. Firestore 1 GiB, 50k lượt đọc + 20k lượt ghi / ngày | Mọi logic chạy ở client + Firestore rules. Ảnh lưu thẳng trong Firestore |

### Stack

- **App:** Swift, SwiftUI, iOS 17+ (tối thiểu, để dùng interactive widget)
- **Widget:** WidgetKit + App Intents
- **Vẽ:** PencilKit (v1.1)
- **Backend:** Firebase gói Spark — Anonymous Auth, Firestore (kể cả ảnh), Security Rules
- **Thông báo:** chỉ local notification (`UNUserNotificationCenter`), không có push từ xa

### Cấu trúc target

Project sinh bằng **XcodeGen** từ `project.yml` (không commit `*.xcodeproj`).

```
project.yml
├── photograph            (app chính, bundle hwee.photograph)
├── PhotographWidget      (Widget Extension, bundle hwee.photograph.widget)
├── PhotographTests       (unit test cho logic thuần)
└── Shared/               (thư mục code biên dịch vào cả app lẫn widget: models, App Group I/O, Firestore REST client)
```

Capabilities: chỉ **App Groups** `group.hwee.photograph` cho app + widget. Không cần Keychain Sharing (widget không dùng Firebase Auth SDK).

### Cơ chế cập nhật widget (QUAN TRỌNG NHẤT)

Không có push nên không có cách đánh thức máy B. Widget tự kéo dữ liệu, trong phạm vi ngân sách làm mới iOS cấp (~40–70 lần/ngày):

```
Máy A gửi ảnh
  └─► app A: resize ~600px JPEG (~60KB) → ghi couples/{id}/moments/{momentId} (ảnh dạng Bytes)
        (app A cũng tự reloadAllTimelines() cho widget của chính mình)

Máy B — một trong hai đường:
  (1) Widget tự làm mới theo lịch (policy .after(~15 phút), iOS có thể giãn ra)
        └─► getTimeline: đổi refresh token (app ghi trong App Group) lấy ID token qua Secure Token REST
              → runQuery lấy metadata 10 moment mới nhất (không kèm ảnh), chọn cái của người kia
              → chỉ khi id mới: GET riêng imageData
              → ghi ảnh vào App Group → hiển thị
  (2) Người B mở app
        └─► Firestore snapshot listener → ghi App Group → WidgetCenter.reloadAllTimelines()
              (khi app ở foreground, lần reload này không tính vào ngân sách)
```

- Widget **không** nhúng Firestore SDK (quá nặng so với giới hạn bộ nhớ ~30MB); dùng REST + `URLSession`.
- Ảnh luôn resize ~600px **ở máy gửi**, trước khi lên Firestore. Firestore giới hạn 1 MiB/document; dùng kiểu `Bytes`, không base64.

**Tiêu chí nghiệm thu của spike tuần 1:** đo trong 1–2 ngày dùng thật trên máy B (app đã tắt hẳn, máy khóa, và riêng một buổi bật Low Power Mode):
- Mở app B → widget đổi ảnh gần như ngay lập tức.
- Không mở app → ghi lại độ trễ thực tế. Chấp nhận được nếu **trung vị ≤ 30 phút**.
- Xác nhận App Groups + Keychain Sharing chạy được với Personal Team.

### Nút ❤️ trên widget

```
Button(intent: SendHeartIntent) trong widget
  └─► AppIntent chạy nền (không mở app)
        └─► Firestore REST: tạo couples/{id}/hearts/{heartId}
              └─► widget người kia hiện "💓 ×N" (số tim chưa xem) ở lần làm mới kế tiếp
```

- Chống spam: rules giới hạn 1 tim / 10 giây mỗi người (so `request.time` với tim gần nhất).
- Widget người gửi hiện trạng thái "Đã gửi ❤️" vài giây.

### Thay cho Cloud Functions

| Việc | Cách làm ở chế độ 0đ |
|---|---|
| Ghép đôi (F1) | Transaction ở client; rules bắt buộc `users/{uid}.coupleId == null` và `members` đúng 2 phần tử |
| Câu hỏi 20:00 (F5) | Ngân hàng câu hỏi đóng gói trong app (JSON). Cả hai máy chọn cùng một câu theo công thức xác định từ ngày + `couples.startedAt`. Nhắc bằng local notification lặp hằng ngày lúc 20:00 |
| Push mood (F6) | Không có. Người kia thấy trên widget / Home ở lần làm mới kế tiếp |

### Điều KHÔNG làm được trên iOS (đã xác nhận)

- ❌ Chụp ảnh / vẽ **ngay trên** widget. Chạm widget chỉ mở app qua deep link.
- ❌ Nhấn giữ widget để gửi rung — nhấn giữ là thao tác hệ thống (chỉnh widget).
- ❌ Tự rung máy người kia khi app chạy nền.
- ❌ Lock screen widget hiển thị ảnh màu đẹp — loại này gần như đơn sắc, chỉ dùng cho text, emoji cảm xúc, số tim.
- ❌ (Chế độ 0đ) Đánh thức máy người kia ngay lập tức — cần APNs, tức cần tài khoản trả phí.

### 3b. Thiết kế Giai đoạn 2 — khi có Apple Developer Program

Giữ lại để nâng cấp, không làm bây giờ. Code phải để **đường nhận dữ liệu tháo lắp được** (một protocol kiểu `MomentDelivery`) để lúc đó chỉ thêm NSE, không viết lại widget.

```
Máy A gửi ảnh
  └─► Cloud Function: upload xong → gửi APNs push tới máy B
        payload: { mutable-content: 1, imageURL, momentId, type }
          └─► NSE trên máy B chạy nền: tải ảnh → resize ~600px → ghi App Group
                → WidgetCenter.shared.reloadAllTimelines()
```

Tim: push `interruption-level: time-sensitive`, âm thanh tim đập ~1s (.caf), gộp "💓 ×5". Thêm Sign in with Apple, Firebase Blaze (Functions + Storage), TestFlight.

---

## 4. Mô hình dữ liệu (Firestore)

```
users/{uid}
  displayName, photoURL, coupleId, fcmToken, createdAt

inviteCodes/{code}            # code 6 ký tự, TTL 24h
  creatorUid, createdAt, usedBy?

couples/{coupleId}
  members: [uidA, uidB]        # LUÔN đúng 2 phần tử
  startedAt                    # để tính "Ngày thứ N"
  createdAt

  moments/{momentId}
    authorUid, type: photo|note|doodle, imageData?: Bytes (JPEG ~600px), text?, createdAt, seenAt?

  hearts/{heartId}
    fromUid, createdAt

  questions/{yyyy-MM-dd}
    questionId, questionText, sentAt
    answers/{uid}
      text, createdAt          # rules: chỉ đọc được của người kia KHI mình đã có doc
    reactions/{uid}

  moods/{uid}                  # trạng thái hiện tại
    emotion: vui|binhyen|met|buon|lo|buc | null
    energy: 0-100
    need: om|yentinh|noichuyen|doan|duockhen|khongcangi | null
    isPrivate: bool            # "Tớ chưa muốn nói"
    updatedAt
    history/{yyyy-MM-dd}       # CHỈ chủ sở hữu đọc được

  cooldowns/{sessionId}        # v1.1, chi tiết §5
    status, initiatorUid, startedAt, returnAt, extensions: {uid: int}
    ready: {uid: bool}
    entries/{uid}: { feel, when, need, createdAt }
    resolution: { agreementNote?, resolvedAt }

# questionBank: ~60 câu, đóng gói trong app (Resources/questions.json), không nằm trên Firestore
#   { id, text, category, order }
```

### Nguyên tắc security rules

1. Mọi thứ dưới `couples/{id}` chỉ đọc/ghi được nếu `request.auth.uid in resource.data.members`.
2. **Blind reveal của Daily Question phải chặn ở server**, không chỉ blur ở client:
   `allow read: if exists(/databases/$(db)/documents/couples/$(cid)/questions/$(date)/answers/$(request.auth.uid))`
3. `moods/{uid}/history` chỉ chính chủ đọc được. Người kia chỉ thấy trạng thái hiện tại.
4. `cooldowns/{id}/entries/{uid}` của người kia chỉ đọc được khi `status == "listening"`.
5. Một user không được thuộc 2 couple. Ghép đôi bằng transaction ở client; rules chặn khi `users/{uid}.coupleId` đã có giá trị.
6. `moments.imageData` ≤ 200 KB (`request.resource.data.imageData.size()`), chặn ghi ảnh gốc lên Firestore.
7. `hearts`: chỉ tạo được nếu cách tim gần nhất của chính mình ≥ 10 giây.

---

## 5. Đặc tả tính năng chi tiết

### F5 — Daily Question (blind reveal)

- 20:00 giờ VN mỗi ngày, local notification nhắc cả hai; câu hỏi chọn theo công thức xác định (xem §3 "Thay cho Cloud Functions").
- 4 trạng thái UI:
  1. Chưa ai trả lời → ô nhập + nút "Gửi & mở khóa"
  2. Mình đã trả lời, người kia chưa → "Đang chờ… " + nút "Nhắc nhẹ 🔔"
  3. Người kia đã trả lời, mình chưa → thẻ blur + khóa: "Trả lời để xem câu trả lời của {tên}"
  4. Cả hai đã trả lời → reveal animation, hai câu cạnh nhau, reaction (❤️ 😂 🥹 😳) + 1 comment
- Streak hiển thị mềm: "12 ngày liền bên nhau", không có hình phạt khi đứt.

### F6 — Mood Check-in

Ba lớp, mỗi lớp 1 chạm, **đều không bắt buộc**:

1. **Cảm xúc:** Vui · Bình yên · Mệt · Buồn · Lo · Bực (mỗi loại 1 màu)
2. **Năng lượng:** slider 0–100% (chính là Love Tank), hiển thị dạng lọ thủy tinh đầy dần
3. **Tớ đang cần:** Một cái ôm · Yên tĩnh một chút · Nói chuyện · Đồ ăn ngon · Được khen · Không cần gì đâu

Người kia nhìn thấy ở: lock screen widget (emoji + vòng năng lượng), thẻ trên Home kèm **2 gợi ý hành động khớp với nhu cầu**. (Push: Giai đoạn 2.)

**Ràng buộc đạo đức — bắt buộc tuân thủ:**

- Không streak, không nhắc nhở dồn dập cho mood.
- Luôn có lựa chọn "Tớ chưa muốn nói".
- Lịch sử cảm xúc là **riêng tư**, chỉ chính chủ xem.
- (Giai đoạn 2) Push chỉ gửi khi năng lượng < 30% hoặc nhu cầu đổi; tối đa 2 lần/ngày.

### F7 — Trạm hạ nhiệt (v1.1)

Dựa trên nghiên cứu Gottman: cơ thể cần ≥20 phút để hạ nhiệt sinh lý, và khoảng lặng chỉ có ích khi **có hẹn quay lại**.

```
① TẠM DỪNG → ② HẠ NHIỆT → ③ SẴN SÀNG → ④ LẮNG NGHE → ⑤ LÀM LÀNH
```

1. **Tạm dừng:** một người bấm "Mình cần tạm dừng", chọn 20/30/60 phút.
   Người kia nhận: *"{tên} cần 30 phút để bình tĩnh. {tên} sẽ quay lại lúc 21:40 🤍"*
2. **Hạ nhiệt:** đếm ngược + bài thở 4-7-8. Note/ảnh gửi trong lúc này bị **giữ lại**, xong mới hiện.
   Mỗi người viết riêng theo khung: *"Tớ cảm thấy… khi… vì tớ cần…"*
3. **Sẵn sàng:** "Tớ sẵn sàng" hoặc "Cho tớ thêm 15 phút" (tối đa 2 lần). Phải **cả hai** sẵn sàng mới sang bước 4.
   Kết thúc sớm: chỉ khi **cả hai** cùng bấm.
4. **Lắng nghe:** hai đoạn viết mở cùng lúc (dùng lại cơ chế blind reveal), nút "Tớ hiểu cậu rồi", 1 câu phản hồi, gợi ý "Gọi cho nhau nhé?"
5. **Làm lành:** cử chỉ nhanh ("Tớ xin lỗi", "Ôm cái nhé", "Mình ổn rồi") → cả hai xác nhận "Mình làm lành rồi 🤍" → tuỳ chọn lưu "Thoả thuận nhỏ".

**Ràng buộc đạo đức — bắt buộc tuân thủ:**

- ❌ Không đếm số lần cãi nhau, không tính điểm đúng/sai.
- ❌ Không đưa cãi vã vào Timeline hay Love Wrapped.
- ❌ Không để tạm dừng kéo dài vô hạn — luôn có giờ quay lại rõ ràng.
- Có dòng lưu ý: app hỗ trợ bất đồng thường ngày, không thay thế tư vấn chuyên môn.

---

## 6. Design system

Xem chi tiết ở `DESIGN_PROMPTS.md`. Tóm tắt token:

- **Nền:** cream `#FBF6F0` (dark: `#1E1A19`)
- **Thẻ:** trắng 80% + shadow mềm (dark: `#2A2422`)
- **Accent chính:** terracotta rose `#E07A5F`
- **Phụ:** blush `#F4D6CC`, sage `#A8B5A2`
- **Chữ:** cocoa `#3D2C2E` (dark `#F3EAE3`), phụ `#8A7A76`
- **Tim:** `#E5484D`
- **Cool-down:** dusty blue `#9DB4C0` + lavender nhạt
- **Font:** SF Pro Rounded cho UI; New York (serif) cho nội dung cảm xúc
- **Style:** bo góc 24, khung polaroid, giấy có grain nhẹ, nghiêng tối đa 6°
- **Copy:** tiếng Việt, xưng "tớ/cậu", ấm áp, không sến

---

## 7. Lộ trình

| Tuần | Việc | Xong khi |
|---|---|---|
| 1 | **Spike:** Firestore → widget tự làm mới (chế độ 0đ) | Đạt tiêu chí ở §3; biết độ trễ thực tế |
| 2 | Design 5 màn hình chính | Có mockup |
| 3–4 | F1 Auth + ghép đôi + security rules | 2 máy ghép được với nhau |
| 5–6 | F2 + F3 gửi khoảnh khắc, widget thật | Dùng được hằng ngày |
| 7–8 | F5 Daily Question | Đủ 4 trạng thái |
| 9 | F6 Mood + F4 nút tim | — |
| 10 | Polish + cài qua Xcode | Chạy ổn trên 2 máy, quy trình cài lại 7 ngày gọn nhẹ |
| 11–12 | F7 Trạm hạ nhiệt (v1.1) | — |

Song song: viết **60 câu hỏi** cho `questionBank`. Nội dung quyết định chất lượng Daily Question nhiều hơn code.

---

## 8. Rủi ro

| Rủi ro | Mức | Xử lý |
|---|---|---|
| Widget làm mới quá thưa (iOS giãn lịch, nhất là Low Power Mode) | Cao | Spike tuần 1 đo thực tế; luôn refresh khi mở app; nếu quá tệ → cân nhắc Giai đoạn 2 |
| App hết hạn sau 7 ngày, nhất là máy người ấy | Cao | Đặt lịch cài lại cố định mỗi tuần; nếu hai người ở xa → thử SideStore để tự gia hạn trên máy |
| Bộ nhớ widget tràn khi load ảnh | Trung bình | Resize ~600px ở máy gửi, widget dùng REST thay vì Firestore SDK |
| Vượt hạn mức Firestore miễn phí | Thấp | 2 người × ảnh ~60KB × widget đọc ~70 lần/ngày là rất xa hạn mức; rules chặn ảnh >200KB |
| Firebase Auth trong widget extension | Trung bình | Đã chọn: app lưu refresh token vào App Group (file protection until-first-unlock), widget tự đổi lấy ID token qua REST; không nhúng Firebase SDK vào widget |
| Apple từ chối vì quyền riêng tư | Thấp | Không thu thập dữ liệu ngoài couple; viết privacy policy rõ ràng |
| Scope phình to | Cao | Backlog ở §2 là bất khả xâm phạm cho đến khi MVP chạy ổn trên 2 máy |

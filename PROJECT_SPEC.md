# Photograph — Project Spec v2

> Tài liệu nguồn duy nhất cho dự án. Mọi quyết định sản phẩm và kỹ thuật đều nằm ở đây.
> Cập nhật: 2026-09-25

---

## 1. Tổng quan

- **Tên app:** Photograph
- **Nền tảng:** iOS only (iPhone). Không làm Android, không làm iPad ở giai đoạn này.
- **Đối tượng:** Các cặp đôi đang yêu (mô hình 1-1 khép kín tuyệt đối).
- **Giá trị cốt lõi:** Một "ngôi nhà kỹ thuật số" riêng cho 2 người — tập trung vào chiều sâu cảm xúc, thói quen tương tác hằng ngày, và lưu giữ kỷ niệm dài hạn. Không phải mạng xã hội.
- **Giai đoạn hiện tại:** Mới có ý tưởng, chưa có code.
- **Mục tiêu gần nhất:** MVP để đúng 2 người dùng thử qua TestFlight.
- **Nguồn lực:** 1 dev solo, part-time (~8–10 giờ/tuần). Đã có tài khoản Apple Developer.

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
| F1 | Auth + Ghép đôi | Sign in with Apple; ghép bằng mã mời 6 ký tự; 1 user chỉ thuộc đúng 1 couple |
| F2 | Gửi khoảnh khắc | Ảnh hoặc note ngắn (≤80 ký tự); hiện trên widget của người kia trong vài giây |
| F3 | Widget | Home screen small/medium/large + lock screen; nút ❤️ tương tác |
| F4 | Nút ❤️ "Nhớ cậu" | Bấm trên widget → push tới người kia, có âm thanh riêng |
| F5 | Daily Question | 20:00 mỗi ngày; **blind reveal**: phải trả lời mới xem được câu trả lời của người kia |
| F6 | Mood Check-in | Cảm xúc + năng lượng (Love Tank) + "Tớ đang cần…" |

### v1.1 — ngay sau MVP

| # | Tính năng | Mô tả ngắn |
|---|---|---|
| F7 | Trạm hạ nhiệt | Cơ chế hoà giải khi cãi vã (chi tiết ở §5) |
| F8 | Doodle | Vẽ tay bằng PencilKit |

### Backlog (KHÔNG làm bây giờ)

Gratitude Journal · Period tracker · Random date/food generator · Timeline kỷ niệm · Love Wrapped · Video · Android

---

## 3. Quyết định kỹ thuật (đã chốt)

### Stack

- **App:** Swift, SwiftUI, iOS 17+ (tối thiểu, để dùng interactive widget)
- **Widget:** WidgetKit + App Intents
- **Vẽ:** PencilKit (v1.1)
- **Backend:** Firebase — Auth, Firestore, Storage, Cloud Functions, FCM
- **Push:** APNs qua FCM, có APNs Auth Key (.p8)

### Cấu trúc target

```
Photograph.xcodeproj
├── Photograph            (app chính)
├── PhotographWidget      (Widget Extension)
├── PhotographNSE         (Notification Service Extension)
└── PhotographShared      (framework dùng chung: models, App Group I/O)
```

Capabilities cần bật cho các target liên quan:

- **App Group:** `group.<bundle-prefix>.photograph` — bật cho cả 3 target
- **Push Notifications** — app target
- **Keychain Sharing** — app + widget (để `Auth.auth().useUserAccessGroup()` chia sẻ phiên đăng nhập)
- **Background Modes → Remote notifications**

### Cơ chế cập nhật widget (QUAN TRỌNG NHẤT)

iOS giới hạn số lần widget tự làm mới, nên **không** dùng timeline polling. Luồng đúng:

```
Máy A gửi ảnh
  └─► Cloud Function: upload xong → gửi APNs push tới máy B
        payload: { mutable-content: 1, imageURL, momentId, type }
          └─► NSE trên máy B chạy nền:
                1. tải ảnh
                2. resize còn ~600px cạnh dài (widget có giới hạn bộ nhớ ~30MB)
                3. ghi vào App Group container
                4. WidgetCenter.shared.reloadAllTimelines()
                  └─► Widget đọc file mới nhất từ App Group và hiển thị
```

**Tiêu chí nghiệm thu của spike tuần 1:** widget máy B đổi ảnh trong vòng ~5 giây, kể cả khi app máy B đã bị tắt hẳn, máy đang khóa, và đang bật Low Power Mode.

### Nút ❤️ trên widget

```
Button(intent: SendHeartIntent) trong widget
  └─► AppIntent chạy nền (không mở app)
        └─► gọi Cloud Function sendHeart(coupleId)
              └─► push tới người kia:
                   • âm thanh riêng: tiếng tim đập ~1s (.caf)
                   • interruption-level: time-sensitive
                   • body: "💓 {tên} đang nhớ cậu"
```

- Chống spam: server giới hạn 1 tim / 10 giây mỗi người; gộp nhiều lần thành "💓 ×5".
- Widget người gửi hiện trạng thái "Đã gửi ❤️" vài giây.

### Điều KHÔNG làm được trên iOS (đã xác nhận)

- ❌ Chụp ảnh / vẽ **ngay trên** widget. Chạm widget chỉ mở app qua deep link.
- ❌ Nhấn giữ widget để gửi rung — nhấn giữ là thao tác hệ thống (chỉnh widget).
- ❌ Tự rung máy người kia khi app chạy nền. **Thay bằng push có âm thanh riêng.**
- ❌ Lock screen widget hiển thị ảnh màu đẹp — loại này gần như đơn sắc, chỉ dùng cho text, emoji cảm xúc, số tim.

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
    authorUid, type: photo|note|doodle, storageePath?, text?, createdAt, seenAt?

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

questionBank/{questionId}      # ~60 câu, seed sẵn
  text, category, order
```

### Nguyên tắc security rules

1. Mọi thứ dưới `couples/{id}` chỉ đọc/ghi được nếu `request.auth.uid in resource.data.members`.
2. **Blind reveal của Daily Question phải chặn ở server**, không chỉ blur ở client:
   `allow read: if exists(/databases/$(db)/documents/couples/$(cid)/questions/$(date)/answers/$(request.auth.uid))`
3. `moods/{uid}/history` chỉ chính chủ đọc được. Người kia chỉ thấy trạng thái hiện tại.
4. `cooldowns/{id}/entries/{uid}` của người kia chỉ đọc được khi `status == "listening"`.
5. Một user không được thuộc 2 couple. Ghép đôi xử lý trong Cloud Function bằng transaction.

---

## 5. Đặc tả tính năng chi tiết

### F5 — Daily Question (blind reveal)

- 20:00 giờ VN mỗi ngày, Cloud Function (scheduled) chọn câu từ `questionBank` và push cho cả hai.
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

Người kia nhìn thấy ở: lock screen widget (emoji + vòng năng lượng), thẻ trên Home kèm **2 gợi ý hành động khớp với nhu cầu**, và push.

**Ràng buộc đạo đức — bắt buộc tuân thủ:**

- Không streak, không nhắc nhở dồn dập cho mood.
- Luôn có lựa chọn "Tớ chưa muốn nói".
- Lịch sử cảm xúc là **riêng tư**, chỉ chính chủ xem.
- Push chỉ gửi khi năng lượng < 30% hoặc nhu cầu đổi; tối đa 2 lần/ngày.

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
| 1 | **Spike:** push → NSE → widget | Widget máy B đổi ảnh <5s khi app đã tắt |
| 2 | Design 5 màn hình chính | Có mockup |
| 3–4 | F1 Auth + ghép đôi + security rules | 2 máy ghép được với nhau |
| 5–6 | F2 + F3 gửi khoảnh khắc, widget thật | Dùng được hằng ngày |
| 7–8 | F5 Daily Question | Đủ 4 trạng thái |
| 9 | F6 Mood + F4 nút tim | — |
| 10 | Polish + TestFlight | Cài được trên 2 máy |
| 11–12 | F7 Trạm hạ nhiệt (v1.1) | — |

Song song: viết **60 câu hỏi** cho `questionBank`. Nội dung quyết định chất lượng Daily Question nhiều hơn code.

---

## 8. Rủi ro

| Rủi ro | Mức | Xử lý |
|---|---|---|
| Widget không cập nhật ổn định qua push | Cao | Spike ngay tuần 1; nếu hỏng, hạ kỳ vọng xuống "cập nhật trong vài phút" + refresh khi mở app |
| Bộ nhớ widget tràn khi load ảnh | Trung bình | Resize xuống ~600px trong NSE, không bao giờ load ảnh gốc |
| Firebase Auth trong widget extension | Trung bình | Keychain Sharing + `useUserAccessGroup()`; fallback: lưu custom token trong App Group |
| Apple từ chối vì quyền riêng tư | Thấp | Không thu thập dữ liệu ngoài couple; viết privacy policy rõ ràng |
| Scope phình to | Cao | Backlog ở §2 là bất khả xâm phạm cho đến khi MVP lên TestFlight |

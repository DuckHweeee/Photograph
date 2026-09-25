# Spike tuần 1 — Bước 2: Chạy thử trên Simulator

> Mục tiêu: chứng minh **đường code** chạy đúng trước khi lên máy thật.
> Simulator A gửi ảnh/note → Firestore → widget trên Simulator B tự đổi, kể cả khi app B đã tắt.
>
> Simulator **không** đo được: ngân sách làm mới thật của iOS, Low Power Mode, máy khóa, ký app bằng Apple ID miễn phí. Mấy thứ đó để bước 3 (2 iPhone thật).

Thời gian ước tính: 45–60 phút (phần lớn là chờ Xcode tải Firebase SDK).

---

## Code gồm những gì

| Thư mục / file | Vai trò |
|---|---|
| `project.yml` | Mô tả toàn bộ project cho **XcodeGen**. `photograph.xcodeproj` được sinh ra từ đây, không commit, không sửa tay |
| `Shared/` | Code dùng chung cho app + widget: model, resize ảnh 600px, lưu App Group, client Firestore REST |
| `photograph/` | App: đăng nhập ẩn danh, màn hình thử nghiệm (gửi ảnh/note, xem khoảnh khắc của người kia, nhật ký làm mới) |
| `PhotographWidget/` | Widget small + medium: tự gọi Firestore REST mỗi ~15 phút, hiện ảnh/note mới nhất của người kia |
| `PhotographTests/` | 21 unit test cho phần logic thuần (đọc JSON Firestore, đổi token, resize ảnh) |
| `firestore.rules` + `firestore-tests/` | Rules tạm cho spike + 11 test chạy trên emulator (đã pass) |

**Widget không nhúng Firebase SDK.** App ghi *refresh token* vào App Group; widget tự đổi lấy ID token rồi gọi Firestore qua REST. Nhẹ hơn nhiều so với giới hạn bộ nhớ widget, và **không cần Keychain Sharing**.

---

## 1. Cài công cụ (một lần)

```bash
# Homebrew, nếu chưa có: xem https://brew.sh
brew install xcodegen
npm install -g firebase-tools     # nếu chưa cài ở bước 1
firebase login
```

## 2. Kéo code về

**Đóng Xcode trước**, rồi trong thư mục repo:

```bash
git pull origin claude/new-session-p2qocy
```

Project cũ `photograph.xcodeproj` sẽ bị xoá khỏi repo — đúng như dự kiến, XcodeGen sẽ sinh lại.

## 3. Firebase Console

Nếu chưa làm ở bước 1 (checklist phần C):

- [ ] Tạo project Firebase, **giữ gói Spark**.
- [ ] **Add app → iOS**, bundle ID `hwee.photograph` → tải `GoogleService-Info.plist` → đặt vào **`photograph/GoogleService-Info.plist`** (cạnh `photographApp.swift`). File này đã bị `.gitignore` chặn.
- [ ] **Authentication → Sign-in method → Anonymous → Enable**.
- [ ] **Firestore Database → Create database** → `asia-southeast1` → production mode.

## 4. Deploy rules

```bash
firebase use --add                      # chọn project vừa tạo, alias: default
firebase deploy --only firestore:rules
```

Thấy `✔ Deploy complete!` là được.

## 5. Sinh project và mở Xcode

```bash
xcodegen generate
open photograph.xcodeproj
```

- Lần đầu Xcode tải Firebase SDK (thanh tiến trình góc trên), mất vài phút. Chờ xong rồi mới build.
- **Mỗi lần kéo code mới có thêm/xoá file**, chạy lại `xcodegen generate`.
- Nếu `GoogleService-Info.plist` được thêm **sau** khi đã chạy `xcodegen generate`, chạy lại lệnh này để nó vào project.

## 6. Chạy unit test

- [ ] Chọn scheme **photograph** + một Simulator bất kỳ (ví dụ iPhone 17 Pro) → **⌘U**.
- [ ] Kỳ vọng: **21 test pass** (17 `FirestoreRESTTests` + 4 `ImageResizerTests`).

## 7. Mở 2 Simulator = 2 người

- [ ] Chọn Simulator **A** (ví dụ *iPhone 17 Pro*) → **⌘R**. App mở, dòng đầu hiện "Đã đăng nhập · uid …".
- [ ] Đổi đích chạy sang Simulator **B** (ví dụ *iPhone 17*) → **⌘R**. Simulator A vẫn mở, app A vẫn còn trên đó.
- [ ] Trên **B**: về màn hình chính (⌘⇧H) → nhấn giữ chỗ trống → **Edit → Add Widget** → tìm **Photograph** → thêm cỡ **nhỏ** và **vừa**. Widget hiện "Chưa có gì — gửi người ấy một khoảnh khắc nhé".

Hai Simulator có hai uid ẩn danh khác nhau, nên đóng vai hai người thật.

## 8. Kịch bản kiểm tra

| # | Làm gì | Kỳ vọng |
|---|---|---|
| T1 | Trên **A**: gõ note "nhớ cậu quá 🥺" → **Gửi** | A hiện "Đã gửi 💌" |
| T2 | Mở app **B** | Mục "Khoảnh khắc mới nhất của người ấy" hiện note. Nhật ký có `[app] NEW note via listener`. Về màn hình chính: widget đã đổi |
| T3 | Trên **A**: **Chọn ảnh** (Simulator có sẵn ảnh mẫu) + caption → **Gửi** | B (app đang mở) hiện ảnh ngay; widget đổi ảnh |
| T4 ⭐ | Trên **B**: tắt hẳn app (⌘⇧H hai lần → vuốt app lên). Trên **A**: gửi một ảnh khác. **Không mở app B**, chờ và nhìn widget B | Trong khoảng **~15–20 phút** widget B tự đổi ảnh. Sau đó mở app B: nhật ký có `[widget] NEW photo (sent …s ago)` — con số đó là độ trễ thật |
| T5 | Trên **B**: bấm **Làm mới widget ngay** | Nhật ký thêm một dòng `[widget] no change` |

T4 là bài kiểm tra quan trọng nhất: nó chứng minh widget tự kéo dữ liệu khi app không chạy.

## 9. Gửi lại cho tớ

- Số test pass/fail ở bước 6 (nếu fail: tên test + thông báo lỗi).
- Ảnh chụp widget B sau T4 và **5–10 dòng đầu của nhật ký làm mới** trên B.
- Mọi lỗi build màu đỏ trong Xcode (chụp màn hình hoặc copy chữ).

---

## Gỡ lỗi nhanh

| Triệu chứng | Nguyên nhân / cách xử lý |
|---|---|
| App hiện "Thiếu GoogleService-Info.plist…" | File chưa ở `photograph/` hoặc chưa chạy lại `xcodegen generate` |
| Nhật ký: `error: HTTP 403 … PERMISSION_DENIED` | Chưa deploy rules (bước 4) hoặc deploy nhầm project |
| Nhật ký: `error: HTTP 400/403 … API key … blocked` | API key bị giới hạn theo ứng dụng trong Google Cloud Console — gửi tớ nguyên dòng lỗi |
| Nhật ký: `[widget] no session (open the app once)` | Mở app trên máy đó một lần để nó đăng nhập và ghi session |
| Đăng nhập lỗi `ADMIN_ONLY_OPERATION` / `operation-not-allowed` | Chưa bật Anonymous trong Authentication |
| Build báo `requires a development team` | Chọn *Personal Team* ở Signing & Capabilities cho **photograph** và **PhotographWidget**, rồi báo tớ để tớ ghi vào `project.yml` (vì `xcodegen generate` sẽ xoá lựa chọn đó) |
| Widget không có trong danh sách Add Widget | Chạy app một lần trên chính Simulator đó; nếu vẫn không có, khởi động lại Simulator |

## Lưu ý an toàn

Rules hiện tại cho **mọi người dùng đã đăng nhập** đọc được `couples/spike`. Đừng gửi ảnh riêng tư trong giai đoạn spike. Rules theo từng cặp đôi sẽ có ở F1 (ghép đôi).

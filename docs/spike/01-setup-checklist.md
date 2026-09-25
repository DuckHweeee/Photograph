# Spike tuần 1 — Bước 1: Việc cậu tự làm trong Xcode và Firebase (chế độ 0đ)

> Mục tiêu spike (§3 spec): máy A gửi ảnh → widget máy B tự đổi ảnh **mà không cần push**, và đo độ trễ thực tế khi app B đã tắt hẳn, máy khóa, Low Power Mode.
>
> Không cần Apple Developer Program trả phí, không cần thẻ thanh toán cho Firebase.
>
> Bước này **chưa có code**. Làm xong checklist dưới đây thì mình sang bước 2 (code widget + App Group + Firestore REST + màn gửi thử).

Bộ tên đã chốt (**dùng đúng bộ tên này cho mọi chỗ**, đừng đổi giữa chừng vì mỗi lần đổi tốn 1 trong 10 App ID/tuần):

| Thứ | Giá trị mẫu |
|---|---|
| Bundle ID app | `hwee.photograph` |
| Bundle ID widget | `hwee.photograph.widget` |
| App Group | `group.hwee.photograph` |

Project đã tạo với Bundle ID `hwee.photograph` (Product Name `photograph`, viết thường), nên mọi tên khác đi theo prefix này.

Thời gian ước tính: 1–2 giờ.

---

## Giới hạn của Apple ID miễn phí — đọc trước

- App cài bằng tài khoản miễn phí **hết hạn sau 7 ngày**. Hết hạn thì app không mở được, widget cũng ngừng. Cách xử lý: cắm máy vào Mac → bấm Run lại. Dữ liệu vẫn còn.
- Tối đa **10 App ID mới mỗi 7 ngày**. Mỗi target (app, widget) chiếm 1 App ID. **Đừng tạo/xoá target hay đổi Bundle ID nhiều lần**, không thì phải chờ một tuần.
- Tối đa 3 app tự ký trên mỗi máy — đừng cài thêm app tự ký khác lên 2 máy này.
- Không có Push Notifications, không có Sign in with Apple. Nếu Xcode đề nghị thêm hai capability này, bỏ qua.

---

## A. Chuẩn bị

- [ ] Xcode bản mới nhất (từ App Store).
- [ ] **2 iPhone thật** chạy iOS 17+. Simulator không kiểm được Low Power Mode, khóa máy, và lịch làm mới widget thật.
- [ ] Xcode → **Settings… → Accounts** → **+** → **Apple ID** → đăng nhập Apple ID thường của cậu. Sẽ thấy một team tên "*Tên cậu* (Personal Team)".
- [ ] Cắm từng iPhone vào Mac, mở Xcode một lần, rồi trên iPhone: *Cài đặt → Quyền riêng tư & Bảo mật → Chế độ nhà phát triển* → bật (máy khởi động lại).
- [ ] Cài Node.js 20+ và Firebase CLI (dùng để deploy Firestore rules, miễn phí):
  ```bash
  npm install -g firebase-tools
  firebase login
  ```

---

## B. Xcode — ~~tạo target bằng tay~~ (đã thay bằng XcodeGen)

Không cần tạo target, capability hay thêm Firebase SDK bằng tay nữa. Toàn bộ nằm trong `project.yml`; chỉ cần `xcodegen generate`. Xem `docs/spike/02-simulator-test.md`.

Việc tay duy nhất còn lại trong Xcode là chọn **Personal Team** khi chạy lên **máy thật** (bước 3), Simulator thì không cần.

---

## C. Firebase Console (gói Spark, không cần thẻ)

- [ ] console.firebase.google.com → **Add project** → tên `photograph` → tắt Google Analytics. Giữ nguyên gói **Spark**, **không** nâng lên Blaze.
- [ ] **Add app → iOS**:
  - Apple bundle ID: `hwee.photograph` (bundle của **app**)
  - Tải `GoogleService-Info.plist` → đặt vào thư mục **`photograph/`** của repo (cạnh `photographApp.swift`). Không cần kéo vào Xcode — `xcodegen generate` tự thêm.
  - Các bước "Add Firebase SDK" và "Add initialization code" → bỏ qua (Next), code làm ở bước 2.
  - ⚠️ File này đã nằm trong `.gitignore`. Trước mỗi lần commit, chạy `git status` và xác nhận nó **không** xuất hiện.
- [ ] **Build → Authentication → Get started → Sign-in method → Anonymous → Enable → Save**.
- [ ] **Build → Firestore Database → Create database** → region `asia-southeast1` (Singapore) → **Start in production mode**. Rules thật tớ viết ở bước 2.
- [ ] **Không** bật Storage, **không** tạo Cloud Functions — cả hai đều đòi Blaze.

---

## D. Liên kết repo với Firebase

Trong thư mục repo:

```bash
firebase use --add        # chọn project photograph, alias: default
```

Chưa cần `firebase init` — ở bước 2 tớ sẽ đưa sẵn `firebase.json` và `firestore.rules`.

---

## Xong bước 1 khi

- [ ] Firebase có Anonymous Auth và Firestore, vẫn ở gói Spark.
- [ ] `photograph/GoogleService-Info.plist` nằm đúng chỗ, và `git status` **không** thấy nó.

Sau đó sang `docs/spike/02-simulator-test.md`.

---

## Những điều cần biết trước bước 2

1. **Widget không được "đánh thức" từ xa.** iOS tự quyết khi nào widget làm mới (thường vài chục lần/ngày, thưa hơn khi Low Power Mode hoặc khi ít nhìn màn hình chính). Tớ sẽ xin làm mới mỗi ~15 phút, iOS có thể giãn ra. Spike sẽ ghi log mỗi lần widget làm mới để mình có số liệu thật.
2. **Mở app = cập nhật ngay.** Khi app ở foreground, nó nghe Firestore trực tiếp và reload widget; lần reload này không tính vào ngân sách của iOS.
3. **Ảnh resize ở máy gửi** (~600px, JPEG ~60KB) rồi lưu thẳng trong Firestore, vì gói miễn phí không có Storage. Widget không bao giờ giải mã ảnh lớn.
4. **Lịch cài lại 7 ngày:** chọn một ngày cố định trong tuần (ví dụ tối Chủ nhật) để cắm cả 2 máy vào Mac và bấm Run.

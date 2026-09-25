# Spike tuần 1 — Bước 1: Việc cậu tự làm trong Xcode và Firebase (chế độ 0đ)

> Mục tiêu spike (§3 spec): máy A gửi ảnh → widget máy B tự đổi ảnh **mà không cần push**, và đo độ trễ thực tế khi app B đã tắt hẳn, máy khóa, Low Power Mode.
>
> Không cần Apple Developer Program trả phí, không cần thẻ thanh toán cho Firebase.
>
> Bước này **chưa có code**. Làm xong checklist dưới đây thì mình sang bước 2 (code widget + App Group + Firestore REST + màn gửi thử).

Bộ tên đã chốt (**dùng đúng bộ tên này cho mọi chỗ**, đừng đổi giữa chừng vì mỗi lần đổi tốn 1 trong 10 App ID/tuần):

| Thứ | Giá trị mẫu |
|---|---|
| Bundle ID app | `com.hwee.photograph` |
| Bundle ID widget | `com.hwee.photograph.widget` |
| App Group | `group.com.hwee.photograph` |
| Keychain group | `com.hwee.photograph.shared` |

Nếu Xcode báo Bundle ID đã bị người khác dùng, đổi `hwee` thành `hwee2026` cho **tất cả** các dòng trên và báo tớ.

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

## B. Xcode — tạo project và 3 target

### B1. Project + app target

- [ ] **File → New → Project → iOS → App**.
  - Product Name: `Photograph`
  - Team: **Personal Team** của cậu
  - Organization Identifier: `com.hwee` → Bundle ID thành `com.hwee.photograph`
  - Interface: **SwiftUI**, Language: **Swift**, Storage: **None**, bỏ tick Include Tests
- [ ] Lưu project **vào chính thư mục repo này** (bỏ tick "Create Git repository" vì repo đã có).
- [ ] Target **Photograph** → **General** → **Minimum Deployments: iOS 17.0**.

### B2. Widget Extension

- [ ] **File → New → Target → iOS → Widget Extension** → Next.
  - Product Name: `PhotographWidget`
  - **Bỏ tick** Include Live Activity
  - **Bỏ tick** Include Configuration App Intent
- [ ] "Activate PhotographWidget scheme?" → **Activate**.
- [ ] Target PhotographWidget → General → **Minimum Deployments: iOS 17.0** ⚠️ Xcode mặc định đặt bản iOS mới nhất cho target mới — quên bước này thì widget không cài được.
- [ ] Signing & Capabilities → Team: **Personal Team**. Bundle ID là `com.hwee.photograph.widget`.

### B3. Framework dùng chung

- [ ] **File → New → Target → iOS → Framework** → Next.
  - Product Name: `PhotographShared`, Embed in Application: **Photograph**
- [ ] General → **Minimum Deployments: iOS 17.0**.
- [ ] **Build Settings** → ô tìm kiếm gõ `extension` → **Require Only App-Extension-Safe API = Yes**.
- [ ] Target **PhotographWidget** → General → **Frameworks and Libraries** → **+** → `PhotographShared.framework` → Embed: **Do Not Embed**.
- [ ] Target **Photograph** → Frameworks and Libraries: `PhotographShared.framework` là **Embed & Sign**.

> Framework không chiếm App ID, không tính vào giới hạn 10 App ID.

### B4. Capabilities

Chọn target → tab **Signing & Capabilities** → **+ Capability**.

| Capability | Photograph | PhotographWidget |
|---|:-:|:-:|
| **App Groups** → **+** → `group.com.hwee.photograph` | ✅ | ✅ (tick group đã tạo, đừng tạo mới) |
| **Keychain Sharing** → **+** → `com.hwee.photograph.shared` | ✅ | ✅ (cùng tên group) |

- [ ] Nếu tên group hiện màu đỏ, bấm nút refresh nhỏ cạnh đó.
- [ ] ⚠️ **Nếu Xcode báo "Personal development teams … do not support the App Groups capability"** (hoặc Keychain Sharing): dừng lại, chụp màn hình gửi tớ. Tớ tin là cả hai đều có với Personal Team, nhưng đây chính là điều spike cần xác nhận, và tớ có phương án dự phòng.

### B5. Thêm Firebase SDK

- [ ] **File → Add Package Dependencies…** → dán `https://github.com/firebase/firebase-ios-sdk` → **Up to Next Major Version** → Add Package.
- [ ] Ở màn chọn product:
  - **FirebaseAuth** → target **Photograph**
  - **FirebaseFirestore** → target **Photograph**
- [ ] Sau đó thêm FirebaseAuth cho widget: target **PhotographWidget** → General → Frameworks and Libraries → **+** → **FirebaseAuth**.
  - Widget chỉ dùng Auth để lấy token, rồi gọi Firestore qua REST. **Không** thêm FirebaseFirestore vào widget (quá nặng so với giới hạn bộ nhớ widget).

### B6. Kiểm tra build trên cả 2 máy

- [ ] Cắm iPhone B → chọn scheme **Photograph** + thiết bị → **Run** (⌘R).
- [ ] Lần đầu iPhone báo "Untrusted Developer": *Cài đặt → Cài đặt chung → Quản lý VPN & Thiết bị* → chọn Apple ID của cậu → **Tin cậy**. Rồi Run lại.
- [ ] Ra màn hình chính → nhấn giữ → **+** → tìm "Photograph" → thêm widget mẫu. Thấy widget hiện là đạt.
- [ ] Lặp lại với iPhone A (máy người ấy cũng cài bằng Apple ID của cậu được, chỉ cần cắm vào Mac của cậu).

---

## C. Firebase Console (gói Spark, không cần thẻ)

- [ ] console.firebase.google.com → **Add project** → tên `photograph` → tắt Google Analytics. Giữ nguyên gói **Spark**, **không** nâng lên Blaze.
- [ ] **Add app → iOS**:
  - Apple bundle ID: `com.hwee.photograph` (bundle của **app**)
  - Tải `GoogleService-Info.plist` → kéo vào Xcode, thả vào nhóm `Photograph`, tick **cả 2 target Photograph và PhotographWidget** (widget cần nó để khởi tạo FirebaseAuth).
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

- [ ] Project build và chạy trên **cả 2 iPhone**, mỗi máy thêm được widget mẫu.
- [ ] App Groups + Keychain Sharing bật được cho cả app và widget, không lỗi signing.
- [ ] Firebase có Anonymous Auth và Firestore, vẫn ở gói Spark.
- [ ] `git status` không thấy `GoogleService-Info.plist`.

Khi xong, commit project Xcode rỗng này rồi báo tớ **Bundle ID**, **App Group** và **Keychain group** thật để tớ điền vào code ở bước 2.

---

## Những điều cần biết trước bước 2

1. **Widget không được "đánh thức" từ xa.** iOS tự quyết khi nào widget làm mới (thường vài chục lần/ngày, thưa hơn khi Low Power Mode hoặc khi ít nhìn màn hình chính). Tớ sẽ xin làm mới mỗi ~15 phút, iOS có thể giãn ra. Spike sẽ ghi log mỗi lần widget làm mới để mình có số liệu thật.
2. **Mở app = cập nhật ngay.** Khi app ở foreground, nó nghe Firestore trực tiếp và reload widget; lần reload này không tính vào ngân sách của iOS.
3. **Ảnh resize ở máy gửi** (~600px, JPEG ~60KB) rồi lưu thẳng trong Firestore, vì gói miễn phí không có Storage. Widget không bao giờ giải mã ảnh lớn.
4. **Lịch cài lại 7 ngày:** chọn một ngày cố định trong tuần (ví dụ tối Chủ nhật) để cắm cả 2 máy vào Mac và bấm Run.

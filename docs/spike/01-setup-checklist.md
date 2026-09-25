# Spike tuần 1 — Bước 1: Việc cậu tự làm trong Apple Developer, Xcode và Firebase

> Mục tiêu spike (§3 spec): máy A gửi ảnh → widget máy B đổi ảnh trong ~5 giây, kể cả khi app B đã tắt hẳn, máy đang khóa, đang bật Low Power Mode.
>
> Bước này **chưa có code**. Làm xong checklist dưới đây thì mình sang bước 2 (code NSE + widget + App Group + Cloud Function).

Quy ước trong tài liệu (thay bằng giá trị thật của cậu, và **dùng đúng một bộ tên này cho mọi chỗ**):

| Thứ | Giá trị mẫu |
|---|---|
| Bundle ID app | `com.tencau.photograph` |
| Bundle ID widget | `com.tencau.photograph.widget` |
| Bundle ID NSE | `com.tencau.photograph.nse` |
| App Group | `group.com.tencau.photograph` |

Thời gian ước tính: 1.5–2.5 giờ nếu chưa làm bao giờ.

---

## A. Chuẩn bị

- [ ] Máy Mac có Xcode bản mới nhất (từ App Store).
- [ ] **2 iPhone thật** chạy iOS 17+. Simulator không kiểm được Low Power Mode, khóa máy, và hành vi widget thật.
- [ ] Trên cả 2 iPhone: *Cài đặt → Quyền riêng tư & Bảo mật → Chế độ nhà phát triển* → bật (máy sẽ khởi động lại). Mục này chỉ hiện sau khi cắm máy vào Mac và mở Xcode một lần.
- [ ] Cài Node.js 20+ và Firebase CLI:
  ```bash
  npm install -g firebase-tools
  firebase login
  ```

---

## B. Apple Developer — tạo APNs Auth Key (.p8)

Làm trên trình duyệt, tại developer.apple.com → **Certificates, Identifiers & Profiles**.

- [ ] Vào **Keys** → nút **+**.
- [ ] Đặt tên, ví dụ `Photograph APNs`. Tick **Apple Push Notifications service (APNs)** → nếu có nút **Configure** thì chọn môi trường **Sandbox & Production**.
- [ ] **Continue → Register → Download**. File `AuthKey_XXXXXXXXXX.p8` **chỉ tải được đúng 1 lần** — cất vào trình quản lý mật khẩu hoặc thư mục ngoài repo.
- [ ] Ghi lại 2 giá trị:
  - **Key ID** (10 ký tự, hiện ngay trên trang key)
  - **Team ID** (góc phải trên, hoặc mục **Membership details**)

> Không cần tự tạo App ID hay App Group ở đây — Xcode (automatic signing) sẽ tự đăng ký khi cậu bật capability ở phần C.

---

## C. Xcode — tạo project và 4 target

### C1. Project + app target

- [ ] **File → New → Project → iOS → App**.
  - Product Name: `Photograph`
  - Interface: **SwiftUI**, Language: **Swift**
  - Storage: **None**, bỏ tick Include Tests (spike không cần)
  - Organization Identifier: `com.tencau` → Bundle ID thành `com.tencau.photograph`
- [ ] Lưu project **vào chính thư mục repo này** (bỏ tick "Create Git repository" vì repo đã có).
- [ ] Chọn project (icon xanh trên cùng) → target **Photograph** → **General** → **Minimum Deployments: iOS 17.0**.
- [ ] **Signing & Capabilities** → tick **Automatically manage signing** → chọn **Team** của cậu.

### C2. Widget Extension

- [ ] **File → New → Target → iOS → Widget Extension** → Next.
  - Product Name: `PhotographWidget`
  - **Bỏ tick** Include Live Activity
  - **Bỏ tick** Include Configuration App Intent (spike dùng widget tĩnh; nút ❤️ làm ở F4 sau)
- [ ] Hộp thoại "Activate PhotographWidget scheme?" → **Activate**.
- [ ] Target PhotographWidget → General → **Minimum Deployments: iOS 17.0** ⚠️ Xcode mặc định đặt bản iOS mới nhất cho target mới — nếu quên, widget sẽ không cài được lên máy chạy iOS thấp hơn.
- [ ] Kiểm tra Bundle ID là `com.tencau.photograph.widget`.

### C3. Notification Service Extension

- [ ] **File → New → Target → iOS → Notification Service Extension** → Next.
  - Product Name: `PhotographNSE`
- [ ] "Activate scheme?" → **Activate**.
- [ ] General → **Minimum Deployments: iOS 17.0**.
- [ ] Bundle ID là `com.tencau.photograph.nse`.

### C4. Framework dùng chung

- [ ] **File → New → Target → iOS → Framework** → Next.
  - Product Name: `PhotographShared`
  - Embed in Application: **Photograph**
- [ ] Target PhotographShared → General → **Minimum Deployments: iOS 17.0**.
- [ ] Target PhotographShared → **Build Settings** → ô tìm kiếm gõ `extension` → **Require Only App-Extension-Safe API = Yes**. (Bắt buộc để widget và NSE link được framework này.)
- [ ] Target **PhotographWidget** → General → **Frameworks and Libraries** → **+** → chọn `PhotographShared.framework` → cột Embed chọn **Do Not Embed**.
- [ ] Làm y hệt cho target **PhotographNSE**.
- [ ] Target **Photograph** (app) → Frameworks and Libraries: `PhotographShared.framework` phải là **Embed & Sign** (Xcode thường đã tự đặt).

### C5. Capabilities

Mỗi capability: chọn target → tab **Signing & Capabilities** → nút **+ Capability**.

| Capability | Photograph | PhotographWidget | PhotographNSE |
|---|:-:|:-:|:-:|
| **App Groups** → bấm **+** → `group.com.tencau.photograph` | ✅ | ✅ | ✅ |
| **Push Notifications** | ✅ | | |
| **Background Modes** → tick **Remote notifications** | ✅ | | |
| **Keychain Sharing** | để tuần 3–4 (auth) | để tuần 3–4 | |

- [ ] Với App Groups: ở target thứ 2 và 3, **tick vào group đã tạo**, đừng tạo group mới. Nếu tên group hiện màu đỏ, bấm nút refresh nhỏ cạnh đó.
- [ ] Framework **PhotographShared không cần** capability nào.

### C6. Thêm Firebase SDK (chỉ cho app target)

- [ ] **File → Add Package Dependencies…** → dán `https://github.com/firebase/firebase-ios-sdk` → Dependency Rule: **Up to Next Major Version** → Add Package.
- [ ] Ở màn chọn product: chỉ tick **FirebaseMessaging**, target **Photograph**. Không thêm Firebase vào widget hay NSE — NSE sẽ tự tải ảnh bằng `URLSession`, giữ extension nhẹ để không vượt giới hạn bộ nhớ.

### C7. Kiểm tra build

- [ ] Cắm iPhone B → chọn scheme **Photograph** + thiết bị → **Run** (⌘R). Lần đầu iPhone sẽ hỏi tin cậy nhà phát triển: *Cài đặt → Cài đặt chung → Quản lý VPN & Thiết bị* → tin cậy.
- [ ] Ra màn hình chính → nhấn giữ → **+** → tìm "Photograph" → thêm widget mẫu của Xcode. Thấy widget hiện là đạt.
- [ ] Lặp lại với iPhone A.

---

## D. Firebase Console

- [ ] console.firebase.google.com → **Add project** → tên `photograph` (tắt Google Analytics cho gọn).
- [ ] **Nâng lên gói Blaze** (Cloud Functions bắt buộc). Vào *Usage and billing → Details & settings → Budget alert* đặt ngưỡng nhỏ, ví dụ 5 USD, để yên tâm. Với 2 người dùng, chi phí thực tế gần như 0.
- [ ] **Add app → iOS**:
  - Apple bundle ID: `com.tencau.photograph` (bundle của **app**, không phải widget/NSE)
  - Tải `GoogleService-Info.plist` → kéo vào Xcode, thả vào nhóm `Photograph`, **chỉ tick target Photograph**.
  - Các bước "Add Firebase SDK" và "Add initialization code" → bỏ qua (Next), phần code mình làm ở bước 2.
  - ⚠️ File này đã nằm trong `.gitignore`. Trước mỗi lần commit, chạy `git status` và xác nhận nó **không** xuất hiện.
- [ ] **Project settings (⚙️) → Cloud Messaging → Apple app configuration → APNs Authentication Key → Upload**: chọn file `.p8`, điền Key ID và Team ID ở phần B.
- [ ] **Build → Storage → Get started** → chọn region gần VN (ví dụ `asia-southeast1`) → start in **production mode** (rules mình viết sau).
- [ ] **Build → Firestore Database → Create database** → cùng region → **production mode**.
- [ ] Service account cho script gửi push thử (bước 3): **Project settings → Service accounts → Generate new private key** → lưu file JSON **ngoài repo**, ví dụ `~/.secrets/photograph-sa.json`.

---

## E. Liên kết repo với Firebase

Trong thư mục repo:

```bash
firebase use --add        # chọn project photograph, alias: default
```

Chưa cần `firebase init` — ở bước 2 tớ sẽ đưa sẵn `firebase.json` và thư mục `functions/`.

---

## Xong bước 1 khi

- [ ] Project build được và chạy trên **cả 2 iPhone**, mỗi máy thêm được widget mẫu.
- [ ] 3 target (app, widget, NSE) cùng dùng App Group `group.com.tencau.photograph`.
- [ ] Firebase đã có APNs key, Storage, Firestore, gói Blaze.
- [ ] Có file service account JSON nằm ngoài repo.
- [ ] `git status` không thấy `GoogleService-Info.plist`, `.p8` hay file JSON service account.

Khi xong, commit project Xcode rỗng này rồi báo tớ **Bundle ID thật** và **App Group thật** để tớ điền vào code ở bước 2.

---

## Những điều cần biết trước bước 2 (ảnh hưởng thiết kế)

1. **NSE chỉ chạy với push hiển thị** (có `alert`) và `mutable-content: 1`. Silent push (`content-available`) **không** kích hoạt NSE, và bị iOS bóp mạnh khi app đã tắt hoặc Low Power Mode. Vì vậy mỗi khoảnh khắc mới sẽ đi kèm một thông báo thấy được ("Mèo vừa gửi một khoảnh khắc") — cũng khớp với thiết kế ở Prompt 6.
2. **Nếu người nhận tắt thông báo của app, NSE không chạy → widget không tự đổi.** Fallback theo §8 spec: app tải khoảnh khắc mới nhất mỗi lần được mở và reload widget.
3. **NSE có ~30 giây và giới hạn bộ nhớ rất thấp (~24MB).** Tớ sẽ resize bằng ImageIO (`CGImageSourceCreateThumbnailAtIndex`) để không bao giờ giải mã ảnh gốc vào RAM.
4. **Ngân sách reload widget:** `reloadAllTimelines()` gọi từ extension có thể bị iOS giới hạn khi gọi quá nhiều trong ngày. Với nhịp gửi của 2 người thì ổn, nhưng spike sẽ đo thực tế — đây chính là rủi ro "Cao" ở §8.

# CLAUDE.md — Photograph

Đặt file này ở thư mục gốc của repo. Claude Code đọc nó tự động ở mỗi phiên.

## Dự án là gì

Photograph — app iOS riêng tư cho **đúng 2 người yêu nhau**. Widget chia sẻ khoảnh khắc, câu hỏi hằng ngày cơ chế blind-reveal, chia sẻ cảm xúc, và cơ chế hoà giải khi cãi vã.

**Đọc `PROJECT_SPEC.md` trước khi làm bất cứ việc gì.** Đó là nguồn duy nhất cho phạm vi, mô hình dữ liệu và các quyết định kỹ thuật.

## Ngôn ngữ

- Trao đổi với tớ bằng **tiếng Việt**, xưng "tớ/cậu".
- Code, tên biến, comment: **tiếng Anh**.
- Chuỗi hiển thị trên UI: **tiếng Việt**, để trong `Localizable.strings`, không hardcode.

## Stack

Swift + SwiftUI, iOS 17+ · WidgetKit + App Intents · Firebase gói Spark (Anonymous Auth, Firestore, Security Rules).

**Chế độ 0đ:** không có Apple Developer Program trả phí và không dùng Firebase Blaze → **không** push/APNs, NSE, Sign in with Apple, TestFlight, Cloud Functions, Cloud Storage. Đừng đề xuất code dùng những thứ này trừ khi tớ nói đã chuyển sang Giai đoạn 2 (§3b spec).

## Quy tắc bắt buộc

1. **Cấu trúc 1-1:** mọi schema, API và rule đều giả định couple có **đúng 2 thành viên**. Không bao giờ thiết kế cho nhóm.
2. **Blind reveal chặn ở server.** Câu trả lời Daily Question và bài viết trong Trạm hạ nhiệt phải được chặn bằng Firestore rules, không chỉ blur ở client. Luôn kèm rule khi thêm tính năng loại này.
3. **Ảnh cho widget luôn resize ~600px** trước khi ghi vào App Group. Widget extension có giới hạn bộ nhớ rất chặt.
4. **Không thêm tính năng ngoài phạm vi.** Danh sách backlog ở §2 của spec là cấm cho tới khi MVP lên TestFlight. Nếu thấy nên thêm gì, nói cho tớ biết chứ đừng tự code.
5. **Ràng buộc đạo đức** ở §5 của spec (không streak ép buộc cho mood, lịch sử cảm xúc riêng tư, không đếm số lần cãi nhau) là yêu cầu sản phẩm, không phải gợi ý.
6. **Không có secret trong repo.** `GoogleService-Info.plist`, APNs key `.p8` đều nằm trong `.gitignore`.

## Cách làm việc tớ muốn

- Làm từng bước nhỏ, chạy được rồi mới đi tiếp. Tớ làm part-time nên mỗi lần chỉ tiêu hoá được một phần.
- Trước khi viết code cho tính năng mới: nói ngắn gọn cách làm để tớ duyệt.
- Nêu rõ những bước **tớ phải tự làm trong Xcode hay Firebase Console** (bật capability, tải key, tạo index…), vì cậu không làm hộ được.
- Khi sửa nhiều file, tóm tắt file nào đổi gì.
- Không viết test cho UI ở giai đoạn MVP. Có test cho Cloud Functions và logic thuần Swift thì tốt.

## Lệnh hay dùng

```bash
# Firestore rules
firebase deploy --only firestore:rules
firebase emulators:start

# Build app (chạy trên máy Mac)
xcodebuild -scheme photograph -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build
```

## Trạng thái hiện tại

Chưa có code. Việc đầu tiên: spike tuần 1 — Firestore → widget tự làm mới (chế độ 0đ). Xem §3 của spec để biết tiêu chí nghiệm thu.

- Spike tuần 1, bước 1 (thiết lập Xcode + Firebase, việc tay): `docs/spike/01-setup-checklist.md`
- Bundle ID thật: `hwee.photograph` · widget `hwee.photograph.widget` · App Group `group.hwee.photograph` · Keychain group `hwee.photograph.shared`

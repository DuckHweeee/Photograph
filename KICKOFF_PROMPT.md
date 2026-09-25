# Prompt mở màn — dán vào phiên Claude mới

## Cách 1: Claude Code trên máy Mac (khuyến nghị, vì có Xcode ở đó)

```bash
mkdir ~/Projects/photograph && cd ~/Projects/photograph
git init
# copy PROJECT_SPEC.md, CLAUDE.md, DESIGN_PROMPTS.md vào đây
claude
```

Rồi dán prompt này:

```
Đọc CLAUDE.md và PROJECT_SPEC.md trong thư mục này trước.

Tớ đang bắt đầu dự án Photograph từ con số 0. Việc đầu tiên là spike tuần 1
trong §3 của spec: chứng minh luồng push → Notification Service Extension →
widget cập nhật chạy được.

Tiêu chí nghiệm thu: máy A gửi ảnh, widget máy B đổi ảnh trong vòng ~5 giây,
kể cả khi app máy B đã bị tắt hẳn, máy đang khóa, và đang bật Low Power Mode.

Cho tớ:
1. Danh sách các bước tớ phải tự làm trong Xcode và Firebase Console, theo
   đúng thứ tự (tạo target, bật capability, tải APNs key...). Càng cụ thể càng tốt,
   tớ chưa làm widget extension bao giờ.
2. Code cho: Notification Service Extension, widget (TimelineProvider + view),
   lớp đọc/ghi App Group dùng chung, và Cloud Function gửi push.
3. Một script để tớ tự gửi push test mà không cần build app gửi.

Làm từng bước một, đừng đổ hết ra cùng lúc. Bắt đầu từ bước 1.
```

---

## Cách 2: Chat claude.ai / Claude trên desktop (nếu chỉ muốn bàn tiếp, chưa code)

Mở chat mới, đính kèm `PROJECT_SPEC.md`, rồi dán:

```
Đây là spec dự án Photograph của tớ — app iOS riêng tư cho 2 người yêu nhau.
Đọc kỹ trước khi trả lời, và trao đổi với tớ bằng tiếng Việt, xưng "tớ/cậu".

Bối cảnh: tớ làm một mình, part-time khoảng 8-10 tiếng/tuần, chưa có code,
mục tiêu là MVP cho đúng 2 người dùng thử qua TestFlight.

[Viết vào đây việc cậu muốn làm trong phiên này, ví dụ:]
- Viết 60 câu hỏi cho questionBank theo §4 của spec
- Viết Firestore security rules đầy đủ cho toàn bộ schema ở §4
- Review lại lộ trình ở §7 xem có chỗ nào phi thực tế không
```

---

## Cách 3: Giao cho Claude làm việc dài trên cloud

Nếu muốn giao một việc lớn rồi quay lại sau, mở một task mới trong app desktop, đính kèm
`PROJECT_SPEC.md` và dán:

```
Đính kèm là spec dự án Photograph. Tớ giao cậu làm việc này, cứ làm hết rồi
báo lại, không cần hỏi tớ giữa chừng — tớ sẽ quay lại sau.

Việc: [ví dụ] viết toàn bộ Firestore security rules theo §4 của spec, kèm bộ
test cho rules bằng @firebase/rules-unit-testing, phủ các ca:
- người ngoài couple không đọc được gì
- không xem được câu trả lời Daily Question khi mình chưa trả lời
- không xem được mood history của người kia
- không xem được bài viết cool-down của người kia trước bước "lắng nghe"

Xuất ra file firestore.rules và thư mục test chạy được bằng npm test.

Nếu có chỗ nào trong spec chưa rõ, cứ chọn phương án hợp lý nhất, ghi lại
giả định đó trong phần báo cáo cuối, rồi làm tiếp.
```

---

## Mẹo dùng cho hiệu quả

- **Luôn để `CLAUDE.md` ở gốc repo.** Claude Code đọc nó mỗi phiên, cậu không phải nhắc lại bối cảnh.
- **Cập nhật `PROJECT_SPEC.md` khi có quyết định mới**, thay vì để quyết định nằm rải rác trong các đoạn chat. Chat sẽ mất, file thì còn.
- **Mỗi phiên làm một việc.** Đừng gộp "làm auth + widget + câu hỏi" vào một phiên, chất lượng sẽ loãng.
- Khi chạy lệch hướng, nhắc thẳng: *"Cái này ngoài phạm vi MVP ở §2, bỏ qua."*

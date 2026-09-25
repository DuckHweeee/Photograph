# Photograph — Design Prompts

Cách dùng: dán **Prompt 0** trước để khóa style, rồi dán lần lượt từng prompt màn hình.
Nếu công cụ không nhớ ngữ cảnh giữa các lần tạo, dán lại Prompt 0 ở đầu mỗi prompt.

Thứ tự nên làm: **Prompt 5 (widget) trước**, vì widget là bộ mặt của app và quyết định tông màu cho mọi màn hình còn lại.

---

## Prompt 0 — Context + Design System

```
You are designing "Photograph", a private iOS app for exactly two people in a romantic relationship (strict 1-to-1, never groups or social). It is a warm, intimate "digital home" for the couple: they send photos, short notes and doodles that appear on each other's home screen widget, tap a heart to say "I miss you", answer one daily question together with a blind-reveal mechanic, share how they feel, and use a guided cool-down flow when they argue.

Platform: iPhone only, latest iOS design language (follow Apple HIG, native components, SF Symbols, subtle translucent/glass materials where iOS uses them). Frame: iPhone 16 Pro, 393×852pt. Deliver both Light and Dark mode.

Mood & principles:
- Warm, cozy, private, calm — like a handwritten letter or a polaroid on the fridge. NOT a social feed, no like counts, no follower UI, no ads.
- Minimal friction: every core action reachable in 1–2 taps.
- Emotional micro-details: soft paper textures, gentle grain, rounded corners, slight polaroid-style photo frames.

Color tokens:
- Background: cream #FBF6F0 (dark: warm charcoal #1E1A19)
- Surface/card: #FFFFFF at 80% with soft shadow (dark: #2A2422)
- Primary accent: terracotta rose #E07A5F
- Secondary: blush #F4D6CC, sage #A8B5A2
- Text primary: deep cocoa #3D2C2E (dark: #F3EAE3); secondary: #8A7A76
- Heart/love state: #E5484D
- Cool-down mode: dusty blue #9DB4C0 + soft lavender

Typography:
- UI: SF Pro Rounded (Regular/Semibold).
- Emotional content (daily question, notes): New York serif, slightly larger, generous line height.
- All UI copy is in Vietnamese, friendly "tớ/cậu" tone. Must render Vietnamese diacritics cleanly.

Components: large rounded cards (radius 24), pill buttons, polaroid photo frame (white border, max 6° tilt), avatar pair (two overlapping circles), soft blur for locked content.
```

---

## Prompt 1 — Onboarding & Pairing

```
Using the Photograph design system, design the onboarding + pairing flow (4 screens):

1. Welcome: illustration of two small overlapping polaroids, title "Ngôi nhà nhỏ của hai đứa", subtitle "Chỉ dành cho tớ và cậu.", primary button "Đăng nhập với Apple" (native Sign in with Apple style).
2. Choose role: two large cards — "Tạo mã mời" and "Tớ có mã rồi".
3a. Show invite code: big 6-character code in monospaced rounded digits (e.g. "K7 M2 Q9"), buttons "Sao chép" and "Gửi cho người ấy" (share sheet), waiting state "Đang chờ người ấy nhập mã…" with a gently pulsing heart.
3b. Enter code: 6 separate input boxes, auto-advance, keyboard visible.
4. Paired success: both avatars slide together into one, confetti of tiny hearts, text "Hai đứa mình đã về chung nhà 🏡", button "Thêm widget vào màn hình chính" leading to a 3-step visual guide.
```

---

## Prompt 2 — Home

```
Using the Photograph design system, design the Home screen:

- Top: avatar pair + partner name "Mèo" and relationship counter "Ngày thứ 412".
- Hero: partner's latest moment as a large polaroid card (photo, or note in serif on paper texture, or doodle on cream canvas), timestamp "2 phút trước", double-tap hint to send a heart.
- Partner mood card: avatar with colored mood aura, "Mèo đang thấy: Mệt · 30% · cần yên tĩnh", 2 suggested actions matching the need.
- Big round heart button "Nhớ cậu" with pressed state "Đã gửi ❤️" and a soft ripple.
- "Câu hỏi hôm nay" card: serif question text + status chip ("Cậu chưa trả lời" / "Người ấy đã trả lời 🔒" / "Đã mở khóa ✨").
- Horizontal strip "Gần đây" of small polaroids from both people.
- Floating primary button bottom-center: camera icon "Gửi khoảnh khắc".
At most 3 tabs: Nhà, Câu hỏi, Kỷ niệm.
```

---

## Prompt 3 — Quick Send

```
Using the Photograph design system, design the Quick Send modal (full-height sheet) with a segmented control: "Ảnh" | "Vẽ" | "Note".

- Ảnh: full camera viewfinder with rounded corners, big shutter, flip camera, flash; after capture, preview inside a polaroid frame with optional caption field "Viết gì đó…".
- Vẽ: cream canvas, minimal toolbar (3 brush sizes, 6 warm colors, eraser, undo), optional photo background.
- Note: serif text on paper texture, max 80 characters with counter, 4 paper colors (cream, blush, sage, sky).
- Send button (terracotta, paper-plane icon) → sending state → success "Đã hiện trên màn hình của người ấy 💌".
Include a small preview of how it will look on the partner's widget before sending.
```

---

## Prompt 4 — Daily Question (Blind Reveal)

```
Using the Photograph design system, design the Daily Question screen in 4 states. Question example (serif, large): "Khoảnh khắc nào tuần này khiến cậu thấy thương tớ nhất?"

1. Neither answered: question card + input "Câu trả lời của cậu…", button "Gửi & mở khóa".
2. I answered, partner hasn't: my answer visible, partner's card shows animated dots "Đang chờ Mèo trả lời…", option "Nhắc nhẹ người ấy 🔔".
3. Partner answered, I haven't: their answer heavily blurred with a lock icon, label "Trả lời để xem câu trả lời của Mèo".
4. Both answered — reveal: two answer cards, 3 keyframes of the unblur animation, reactions row (❤️ 😂 🥹 😳), single comment field.
Also a history list "Những ngày trước" with a soft streak indicator ("12 ngày liền bên nhau") — no pressure, no punishment for breaking it.
```

---

## Prompt 5 — Widgets

```
Using the Photograph design system, design iOS home screen and lock screen widgets, shown on a realistic iPhone home screen wallpaper, Light and Dark:

Home screen:
- Small (2×2): partner's latest photo full-bleed, tiny partner avatar + "2p" timestamp in corner.
- Medium (4×2): photo left; right side shows note/caption in serif + an interactive heart button "Nhớ cậu".
- Large (4×4): polaroid photo, caption, heart button, today's question status chip.
States for each: new photo, text note, doodle, "Đã gửi ❤️" confirmation, empty state "Chưa có gì — gửi người ấy một khoảnh khắc nhé".

Lock screen (monochrome/tinted rendering):
- Circular: partner's mood emoji on a ring that reflects their energy %.
- Rectangular: latest short note "Mèo: nhớ cậu quá 🥺".
- Inline: "💓 Mèo vừa gửi ảnh mới".
Respect iOS widget constraints: no scrolling, no text input, only simple buttons.
```

---

## Prompt 6 — Push Notifications & App Icon

```
Using the Photograph design system, design iOS push notification mockups on lock screen and as banners:
- Heart: "💓 Mèo đang nhớ cậu" (time-sensitive style) and grouped "💓 ×5 Mèo đang nhớ cậu".
- New moment: rich notification with photo thumbnail "Mèo vừa gửi một khoảnh khắc".
- Daily question at 20:00: "Câu hỏi tối nay đã tới 🌙".
- Partner answered: "Mèo đã trả lời — tới lượt cậu mở khóa 🔒".
- Low energy: "Mèo đang cần một chút yên tĩnh 🌙".
Also the app icon: minimal overlapping polaroids with a small heart, terracotta on cream.
```

---

## Prompt 7 — Mood Check-in

```
Using the Photograph design system, design the Mood Check-in feature:
1. Check-in sheet (half-height): 6 mood chips with soft color + emoji (Vui, Bình yên, Mệt, Buồn, Lo, Bực); an energy slider shown as a small glass jar filling with warm liquid (0–100%); then "Tớ đang cần…" chips (Một cái ôm, Yên tĩnh một chút, Nói chuyện, Đồ ăn ngon, Được khen, Không cần gì đâu); plus an option "Tớ chưa muốn nói". Button "Chia sẻ với Mèo".
2. Partner mood card on Home: partner avatar with colored mood aura, "Mèo đang thấy: Mệt · 30% · cần yên tĩnh", and 2 suggested actions matching the need (e.g. "Gửi note nhẹ nhàng", "Đặt đồ ăn cho Mèo").
3. Low-energy state (<30%): card becomes softer and warmer, "Mèo đang cạn năng lượng, một chút quan tâm sẽ giúp nhiều đó".
4. Private mood history for self: month calendar with small colored dots. No scores, no judgment.
5. Lock screen circular widget: partner's mood emoji on an energy ring.
```

---

## Prompt 8 — Trạm hạ nhiệt (Cool-down & Reconciliation)

```
Using the Photograph design system, design the "Trạm hạ nhiệt" (cool-down & reconciliation) flow. Tone: calm, safe, non-judgmental. Use cooler muted colors (dusty blue #9DB4C0, soft lavender) during cool-down, returning to the warm palette at reconciliation.

1. Start: button "Mình cần tạm dừng" → sheet choosing 20/30/60 phút, with a preview of what the partner will see.
2. Partner receives: calm full-screen card "Mèo cần 30 phút để bình tĩnh. Mèo sẽ quay lại lúc 21:40 🤍".
3. Cool-down screen: large soft countdown ring, breathing animation (inhale/hold/exhale), guided writing card with fill-in prompts "Tớ cảm thấy… / khi… / vì tớ cần…", and a note that messages are paused.
4. Ready check: "Tớ sẵn sàng" / "Cho tớ thêm 15 phút"; state showing one ready, waiting for the other.
5. Listening: both written entries revealed side by side with a gentle unblur, button "Tớ hiểu cậu rồi", one-line reply, suggestion "Gọi cho nhau nhé?".
6. Making up: quick gestures ("Tớ xin lỗi", "Ôm cái nhé", "Mình ổn rồi"), shared confirmation "Mình làm lành rồi 🤍" with warm color returning, optional "Thoả thuận nhỏ" note card.
No scores, no blame, no counters of fights anywhere. Include a small footnote that the app supports everyday disagreements and is not a substitute for professional help.
```

---

## Ghi chú

- Tên "Mèo" và "Ngày thứ 412" chỉ là dữ liệu mẫu — thay bằng tên thật khi xem để cảm nhận đúng.
- Kiểm tra dấu tiếng Việt hiển thị đúng ở mọi font, đặc biệt là các dấu chồng như "ế", "ỡ", "ộ".

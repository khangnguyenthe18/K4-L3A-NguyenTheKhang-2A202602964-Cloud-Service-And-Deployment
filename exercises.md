# Phiếu Phản Ánh — K4 Level 3A, Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
>
> Cách trả lời: điền câu trả lời bên dưới mỗi câu hỏi.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Nguyễn Thế Khang | Mã học viên: 2A202602964

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `agent_api_key` không có giá trị mặc định nên app chết ngay
khi khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà
việc "chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

Tình huống: Khi deploy service lên môi trường mới hoặc production mà người vận hành quên cấu hình biến `AGENT_API_KEY`.
- Nếu để mặc định `"changeme"`: Service vẫn khởi động bình thường, orchestrator báo healthy, nhưng bất kỳ ai thử khóa mặc định `"changeme"` đều truy cập được và làm tiêu tốn ngân sách API LLM. Ngược lại, người dùng thật gửi đúng key lại bị lỗi 401.
- Khi "chết sớm" (Fail fast): Pydantic ném lỗi `ValidationError` ngay lúc đọc cấu hình và app dừng lại ngay lập tức, giúp phát hiện và sửa biến môi trường trước khi dịch vụ mở public ra Internet.

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/ask` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

Dòng log JSON thu được:
```json
{"timestamp": "2026-09-28T09:39:37.123456Z", "level": "INFO", "event": "ask_success", "user_id": "sv-test", "cost_usd": 0.00009585, "tokens_in": 451, "tokens_out": 47, "duration_ms": 35.2}
```

Hai việc làm được với log JSON có cấu trúc:
1. **Truy vấn và tổng hợp định lượng tự động (Log Aggregation):** Các hệ thống như Elasticsearch, Loki hay Datadog có thể index từng trường để lọc theo `user_id`, tính tổng chi phí `sum(cost_usd)`, đo độ trễ `avg(duration_ms)` mà không cần viết regex bóc tách chuỗi phức tạp.
2. **Cấu hình cảnh báo tự động (Alerting):** Dễ dàng thiết lập ngưỡng cảnh báo khi `duration_ms > 2000` hoặc khi xuất hiện log `"event": "cost_limit_exceeded"` để gửi thông báo sự cố ngay lập tức.

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t agent:single .
docker build -t agent:multi .
docker images | grep agent
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | ~320 MB |
| Multi-stage | ~110 MB |

Giải thích: Phần dung lượng chênh lệch (~210 MB) là bộ công cụ biên dịch (`gcc`, `musl-dev`, `python3-dev`), bộ nhớ cache của pip (`~/.cache/pip`), các header/file `.o` tạm thời được sử dụng ở builder stage nhưng bị loại bỏ hoàn toàn khỏi runtime image cuối.

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

- Khi chỉ sửa `app/main.py`: Các layer từ đầu đến `COPY requirements.txt` và `RUN pip install` đều được tái sử dụng từ cache (`CACHED`). Chỉ layer `COPY app/ ./app/` và các bước kế tiếp mới phải build lại (mất chưa đầy 1 giây).
- Nếu đặt `COPY . .` lên trước `RUN pip install`: Mọi thay đổi trong mã nguồn sẽ làm thay đổi hash của layer `COPY`, vô hiệu hóa toàn bộ cache bên dưới và buộc Docker phải tải/cài đặt lại toàn bộ thư viện dependencies từ đầu mỗi lần build.

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

- Chuỗi sự kiện leo quyền:
  1. Kẻ tấn công khai thác lỗ hổng thực thi mã từ xa (RCE) trong code Python.
  2. Kẻ tấn công chiếm được shell với quyền `root` (UID 0) bên trong container.
  3. Từ quyền root container, kẻ tấn công khai thác lỗ hổng kernel Linux hoặc cấu hình volume/docker-socket để thoát khỏi container (container escape).
  4. Do tiến trình ban đầu là UID 0, khi thoát ra ngoài, kẻ tấn công chiếm luôn quyền root trên máy host vật lý.
- Vị trí lệnh `USER appuser` cắt đứt: Lệnh này cắt đứt ngay từ bước 2. Khi chạy với non-root (UID 1000), tiến trình không có các Linux capabilities đặc quyền (`CAP_SYS_ADMIN`), không ghi đè được file hệ thống trong container và không thể thực hiện leo quyền ra máy host.

---

### Câu 6 — Cửa sổ trượt (CP3)

Rate limit của bạn dùng sliding window 60 giây. Nếu thay bằng cách đếm theo
phút đồng hồ (reset lúc giây 00), một người dùng có thể gửi tối đa bao nhiêu
request trong 2 giây liên tiếp khi hạn mức là 10/phút? Giải thích cách đạt được
con số đó.

- Con số tối đa: **20 request** trong 2 giây liên tiếp.
- Giải thích: Với Fixed Window (reset lúc giây 00), người dùng gửi 10 request ở giây 12:00:59 (hợp lệ trong phút 12:00). Ngay giây tiếp theo 12:01:00, bộ đếm bị reset về 0 nên người dùng gửi thêm tiếp 10 request nữa (hợp lệ trong phút 12:01). Như vậy trong 2 giây liên tiếp, server phải nhận tổng cộng 20 request, gấp đôi hạn mức quy định.

---

### Câu 7 — Rate limit và cost guard (CP3)

Hai cơ chế này khác nhau ở điểm nào? Cho một tình huống mà rate limit cho qua
nhưng cost guard phải chặn, và một tình huống ngược lại.

- Khác biệt: Rate limit bảo vệ tài nguyên máy chủ (CPU, RAM, network) khỏi bị quá tải trong khung thời gian ngắn (phút); Cost guard bảo vệ ngân sách tài chính (USD) trong chu kỳ dài (tháng).
- Rate limit cho qua, Cost guard chặn: Người dùng gửi 1 request duy nhất trong ngày (tốc độ hoàn toàn hợp lệ), nhưng tài khoản trong tháng đã chạm ngưỡng chi phí 10.0 USD $\rightarrow$ Cost guard chặn với mã `402 Payment Required`.
- Cost guard cho qua, Rate limit chặn: Người dùng mới sử dụng, số dư còn nguyên 10 USD nhưng gửi dồn dập 15 request trong 3 giây $\rightarrow$ Chi phí chưa vượt ngân sách nhưng Rate limit chặn từ request thứ 11 với mã `429 Too Many Requests`.

---

### Câu 8 — /health khác /ready (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

Thứ tự sự kiện:
1. Redis bị mất kết nối hoặc khởi động lại trong 30 giây.
2. Endpoint gộp kiểm tra Redis thấy thất bại $\rightarrow$ Trả về mã 503.
3. Orchestrator coi liveness probe thất bại, phán đoán container bị treo/hỏng và gửi tín hiệu kill/restart liên tục cả 3 container (crash looping).
4. Các request đang xử lý bị ngắt đột ngột, server tốn nhiều CPU để khởi động lại tiến trình Python liên tục.
5. Khi Redis phục hồi, cả 3 container vừa khởi động lại đồng loạt kết nối dồn dập tới Redis (thundering herd), có nguy cơ làm Redis sập lại.

---

### Câu 9 — Stateless (CP4)

Chạy `docker compose up --scale agent=3` rồi gọi `/ask` nhiều lần với cùng một
`X-User-Id`. Quan sát `history_length` trong response. Nếu lịch sử được lưu
trong một dict Python thay vì Redis, bạn sẽ thấy con số đó thay đổi thế nào?

- Khi lưu trong Redis (Stateless): Dù load balancer định tuyến request đến container nào, tất cả đều truy cập chung một Redis DB, do đó `history_length` tăng tuần tự và liên tục: 1, 2, 3, 4,...
- Nếu lưu trong dict Python (Stateful): Mỗi container giữ một dict riêng trong RAM. Khi load balancer chia đều round-robin qua 3 container, `history_length` sẽ nhảy lộn xộn (ví dụ: request 1 được 1, request 2 lại là 1, request 3 là 1, request 4 là 2...), khiến bot bị "mất trí nhớ" và không hiểu ngữ cảnh đối thoại trước đó.

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

- Thông báo lỗi: Khi chạy lệnh cấu hình biến môi trường trên Railway bằng PowerShell, lệnh báo lỗi: `Use '{ instead of { in variable names` và `Missing expression after unary operator '--'`.
- Cách tìm nguyên nhân: Nhận thấy PowerShell tự động diễn giải cú pháp `${...}` trong dấu nháy kép thành biến nội suy của PowerShell; đồng thời chạy `railway variable --help` phát hiện flag `--set` là cú pháp legacy của CLI cũ.
- Cách sửa: Chuyển sang dùng cú pháp chuẩn mới `railway variable set` của Railway CLI v5 và bọc biến tham chiếu Redis trong dấu nháy đơn `'${{Redis.REDIS_URL}}'` để ngăn PowerShell parse chuỗi. Sau khi sửa, app kết nối thành công với Redis private network.

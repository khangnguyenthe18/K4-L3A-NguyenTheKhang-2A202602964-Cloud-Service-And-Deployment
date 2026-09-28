# ═══════════════════════════════════════════════════════════════════
# CP2 — Multi-stage Dockerfile cho Agent Service (Alpine)
# ═══════════════════════════════════════════════════════════════════

# Stage 1: Builder — Cài đặt thư viện phụ thuộc
FROM python:3.11-alpine AS builder

WORKDIR /app

RUN python -m venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

COPY requirements.txt .
RUN pip install --no-cache-dir --default-timeout=100 --retries 10 --prefer-binary -r requirements.txt

# Stage 2: Runtime — Image tối giản, non-root, có health check
FROM python:3.11-alpine AS runner

WORKDIR /app

# Tạo non-root user (sử dụng adduser built-in của busybox)
RUN adduser -D -u 1000 appuser

# Copy virtualenv từ stage builder
COPY --from=builder /opt/venv /opt/venv
ENV PATH="/opt/venv/bin:$PATH"

# Copy mã nguồn sau khi cài đặt dependency để tận dụng cache layer
COPY . .

# Phân quyền cho non-root user
RUN chown -R appuser:appuser /app

# Chuyển sang user thường (bảo mật non-root)
USER appuser

# Cổng HTTP đọc từ biến môi trường PORT (mặc định 8000)
ENV PORT=8000
EXPOSE 8000

# Health check kiểm tra endpoint /health bằng python urllib (không cần cài curl ngoài)
HEALTHCHECK --interval=10s --timeout=3s --retries=3 \
    CMD python -c "import urllib.request, os; port = os.environ.get('PORT', 8000); urllib.request.urlopen(f'http://localhost:{port}/health')" || exit 1

# Chạy tiến trình qua exec để nhận tín hiệu SIGTERM/SIGINT xử lý graceful shutdown
CMD ["sh", "-c", "exec uvicorn app.main:app --host 0.0.0.0 --port ${PORT:-8000}"]

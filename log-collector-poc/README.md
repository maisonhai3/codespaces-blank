# Log Collector PoC - AiScout Project

## Mục tiêu

PoC này nhằm so sánh 4 công cụ log collection: **Fluent Bit**, **Filebeat**, **Vector**, và **Logstash** trong bối cảnh dự án AiScout (edge device, offline support, JSON logs).

## Kiến trúc môi trường thử nghiệm

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  Log Generator  │───▶│ Log Collector   │───▶│ Elasticsearch   │
│   (Python)      │    │ (4 tools test)  │    │   + Kibana      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

## Cấu trúc thư mục

```
log-collector-poc/
├── docker-compose.yml          # Môi trường chính
├── log-generator/             # Service tạo log
├── collectors/                # Cấu hình cho 4 tools
│   ├── fluent-bit/
│   ├── filebeat/
│   ├── vector/
│   └── logstash/
├── scripts/                   # Scripts thử nghiệm
└── results/                   # Kết quả đo lường
```

## Các kịch bản thử nghiệm

### 1. Baseline Performance
- Đo CPU/RAM usage và throughput bình thường
- Tốc độ: 10000 logs/second trong 10 phút

### 2. Offline Resilience 
- Test khả năng recover khi mất kết nối
- Ngắt mạng 2 phút, đo thời gian phục hồi

### 3. Backpressure Handling
- Test với high load: 1000 logs/second
- Giả lập Elasticsearch chậm với toxiproxy

## Metrics đo lường

### Quantitative:
- CPU Usage (%)
- Memory Usage (MB) 
- Throughput (logs/sec)
- Recovery Time (seconds)
- Disk Buffer Usage (MB)

### Qualitative:
- Configuration Complexity
- Documentation Quality
- Community & Ecosystem
- Observability Features

## Cách sử dụng

### Quick Start với Makefile

```bash
# 1. Kiểm tra requirements
make check

# 2. Setup và smoke test (5 phút)
make setup

# 3. Chạy test đầy đủ (4-5 giờ)
make test-all

# 4. Xem kết quả
make results
```

### Các lệnh hữu ích

```bash
# Test từng tool riêng lẻ (~30 phút mỗi tool)
make test-fluent-bit
make test-filebeat
make test-vector
make test-logstash

# Monitoring trong lúc test
make logs                    # Tất cả logs
make stats                   # Docker stats
make count-logs             # Đếm logs trong ES
make kibana                 # Mở Kibana

# Quản lý services
make start                  # Khởi động core services
make stop                   # Dừng tất cả
make clean                  # Cleanup containers
```

### Manual Scripts (nếu không dùng Makefile)

```bash
# Setup môi trường
./scripts/quick-test.sh

# Test từng tool
./scripts/test-fluent-bit.sh
./scripts/test-filebeat.sh
./scripts/test-vector.sh
./scripts/test-logstash.sh

# Test toàn bộ
./scripts/run-all-tests.sh
```

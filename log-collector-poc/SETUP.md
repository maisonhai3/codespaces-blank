# Log Collector PoC - Setup và Installation Guide

## Prerequisites

Đảm bảo bạn đã cài đặt:

- **Docker** (version 20.10+)
- **Docker Compose** (version 2.0+)
- **jq** (để parse JSON)
- **bc** (để tính toán)
- Ít nhất **5GB** dung lượng trống

### Installation trên Ubuntu/Debian:
```bash
# Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Dependencies
sudo apt update
sudo apt install -y jq bc curl

# Logout và login lại để áp dụng Docker group
```

## Quick Start

### 1. Smoke Test (5 phút)
Kiểm tra xem environment có hoạt động không:

```bash
cd log-collector-poc
./scripts/quick-test.sh
```

### 2. Chạy test cho 1 tool cụ thể
```bash
# Test Fluent Bit (khoảng 30 phút)
./scripts/test-fluent-bit.sh

# Test Filebeat (khoảng 30 phút)  
./scripts/test-filebeat.sh

# Test Vector (khoảng 30 phút)
./scripts/test-vector.sh

# Test Logstash (khoảng 30 phút)
./scripts/test-logstash.sh
```

### 3. Chạy toàn bộ test suite
```bash
# Chạy tất cả tests (khoảng 4-5 giờ)
./scripts/run-all-tests.sh
```

## Monitoring trong lúc test

### 1. Xem logs realtime:
```bash
# Xem logs của collector đang test
docker-compose logs -f fluent-bit

# Xem logs của log generator
docker-compose logs -f log-generator

# Xem logs của Elasticsearch
docker-compose logs -f elasticsearch
```

### 2. Kiểm tra resource usage:
```bash
# Xem stats của tất cả containers
docker stats

# Xem stats của container cụ thể
docker stats log-collector-poc-fluent-bit-1
```

### 3. Truy cập Kibana dashboard:
```bash
# Mở browser tới:
http://localhost:5601

# Tạo index pattern: aiscout-logs
# Xem data realtime trong Discover tab
```

### 4. Query Elasticsearch trực tiếp:
```bash
# Đếm số logs
curl -X GET "localhost:9200/aiscout-logs/_count"

# Search logs
curl -X GET "localhost:9200/aiscout-logs/_search?pretty&size=5"
```

## Troubleshooting

### Lỗi thường gặp:

**1. Docker daemon not running:**
```bash
sudo systemctl start docker
```

**2. Port đã bị sử dụng (9200, 5601):**
```bash
# Kiểm tra process đang dùng port
sudo netstat -tulpn | grep :9200
sudo kill <PID>
```

**3. Elasticsearch không start được:**
```bash
# Tăng virtual memory limit
sudo sysctl -w vm.max_map_count=262144
echo 'vm.max_map_count=262144' | sudo tee -a /etc/sysctl.conf
```

**4. Out of disk space:**
```bash
# Dọn dẹp Docker
docker system prune -f
docker volume prune -f

# Kiểm tra dung lượng
df -h
```

### Reset hoàn toàn environment:
```bash
# Dừng tất cả và xóa data
docker-compose down -v
docker system prune -f

# Xóa results cũ
rm -rf results/*
```

## Tùy chỉnh tests

### Thay đổi thời gian test:
Sửa trong từng script `test-*.sh`:
```bash
# Baseline test duration (mặc định 600s = 10 phút)
local test_duration=300  # Giảm xuống 5 phút

# Backpressure test duration (mặc định 300s = 5 phút)  
local test_duration=120  # Giảm xuống 2 phút
```

### Thay đổi log rate:
Sửa trong `docker-compose.yml`:
```yaml
log-generator:
  environment:
    - LOG_RATE=100  # Thay đổi từ 50 thành 100 logs/second
```

### Thêm tool mới:
1. Tạo thư mục `collectors/new-tool/`
2. Thêm config files
3. Thêm service trong `docker-compose.yml`
4. Tạo `scripts/test-new-tool.sh`
5. Thêm vào `scripts/run-all-tests.sh`

## Kết quả và báo cáo

Sau khi chạy xong, bạn sẽ có:

```
results/
├── fluent-bit-results.md           # Báo cáo chi tiết Fluent Bit
├── filebeat-results.md             # Báo cáo chi tiết Filebeat  
├── vector-results.md               # Báo cáo chi tiết Vector
├── logstash-results.md             # Báo cáo chi tiết Logstash
├── comparison-report.md            # Báo cáo so sánh tổng hợp
├── *-baseline-stats.csv           # Raw data baseline tests
├── *-offline-stats.csv            # Raw data offline tests
└── *-backpressure-stats.csv       # Raw data backpressure tests
```

## Lưu ý quan trọng

1. **Thời gian chạy:** Full test suite mất 4-5 giờ. Hãy chạy khi có thời gian.

2. **Resource requirements:** Elasticsearch cần ít nhất 2GB RAM. Đảm bảo máy có đủ resource.

3. **Network stability:** Tránh chạy test khi mạng không ổn định vì có test network disruption.

4. **Results analysis:** Một số metrics cần phân tích thủ công sau khi chạy xong.

5. **Production readiness:** Đây là PoC environment, cần điều chỉnh config cho production.

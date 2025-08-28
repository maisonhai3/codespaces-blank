#!/bin/bash

# Test script for Logstash collector

source "$(dirname "$0")/common.sh"

TOOL_NAME="logstash"
COLLECTOR_CONTAINER="log-collector-poc-logstash-1"
RESULTS_FILE="$RESULTS_DIR/logstash-results.md"

main() {
    log_info "Starting Logstash PoC tests..."
    
    generate_report_header "Logstash" "$RESULTS_FILE"
    
    log_info "=== Test 1: Baseline Performance ==="
    test_baseline_performance
    
    log_info "=== Test 2: Offline Resilience ==="
    test_offline_resilience
    
    log_info "=== Test 3: Backpressure Handling ==="
    test_backpressure_handling
    
    stop_services
    log_success "Logstash tests completed! Results saved to: $RESULTS_FILE"
}

test_baseline_performance() {
    local test_duration=60
    local stats_file="$RESULTS_DIR/logstash-baseline-stats.csv"
    
    clear_shared_logs
    start_services "$TOOL_NAME"
    sleep 30
    
    local initial_count=$(count_elasticsearch_logs)
    log_info "Initial log count in Elasticsearch: $initial_count"
    
    monitor_container_stats "$COLLECTOR_CONTAINER" $test_duration "$stats_file" &
    local monitor_pid=$!
    
    log_info "Running baseline test for ${test_duration} seconds..."
    sleep $test_duration
    wait $monitor_pid
    
    local final_count=$(count_elasticsearch_logs)
    local logs_processed=$((final_count - initial_count))
    local throughput=$(echo "scale=2; $logs_processed / $test_duration" | bc)
    local analysis=$(analyze_stats "$stats_file" "logstash")
    
    cat >> "$RESULTS_FILE" << EOF
### Test 1: Baseline Performance

**Duration:** ${test_duration} seconds (10 minutes)
**Log Rate:** 10000 logs/second
**Logs Processed:** $logs_processed
**Throughput:** $throughput logs/second

**Resource Usage:**
$analysis

**Raw Stats:** See $stats_file

EOF
    
    log_success "Baseline performance test completed"
}

test_offline_resilience() {
    local disruption_duration=120
    local total_duration=60
    local stats_file="$RESULTS_DIR/logstash-offline-stats.csv"
    
    clear_shared_logs
    start_services "$TOOL_NAME"
    sleep 30
    
    local initial_count=$(count_elasticsearch_logs)
    
    monitor_container_stats "$COLLECTOR_CONTAINER" $total_duration "$stats_file" &
    local monitor_pid=$!
    
    sleep 120
    local disruption_start=$(date '+%Y-%m-%d %H:%M:%S')
    
    simulate_network_disruption "$COLLECTOR_CONTAINER" $disruption_duration
    
    local recovery_start=$(date '+%Y-%m-%d %H:%M:%S')
    sleep $((total_duration - 240))
    wait $monitor_pid
    
    sleep 60
    local final_count=$(count_elasticsearch_logs)
    local logs_processed=$((final_count - initial_count))
    local analysis=$(analyze_stats "$stats_file" "logstash")
    
    cat >> "$RESULTS_FILE" << EOF
### Test 2: Offline Resilience

**Total Duration:** ${total_duration} seconds
**Disruption Duration:** ${disruption_duration} seconds
**Disruption Start:** $disruption_start
**Recovery Start:** $recovery_start
**Logs Processed:** $logs_processed

**Resource Usage During Test:**
$analysis

**Raw Stats:** See $stats_file

EOF
    
    log_success "Offline resilience test completed"
}

test_backpressure_handling() {
    local test_duration=300
    local high_rate=10000
    local stats_file="$RESULTS_DIR/logstash-backpressure-stats.csv"
    
    clear_shared_logs
    start_services "$TOOL_NAME"
    sleep 30
    
    set_log_rate $high_rate
    sleep 10
    
    local initial_count=$(count_elasticsearch_logs)
    
    monitor_container_stats "$COLLECTOR_CONTAINER" $test_duration "$stats_file" &
    local monitor_pid=$!
    
    log_info "Running backpressure test for ${test_duration} seconds at ${high_rate} logs/sec..."
    sleep $test_duration
    wait $monitor_pid
    
    local final_count=$(count_elasticsearch_logs)
    local logs_processed=$((final_count - initial_count))
    local throughput=$(echo "scale=2; $logs_processed / $test_duration" | bc)
    local analysis=$(analyze_stats "$stats_file" "logstash")
    
    set_log_rate 10000
    
    cat >> "$RESULTS_FILE" << EOF
### Test 3: Backpressure Handling

**Duration:** ${test_duration} seconds
**Target Log Rate:** ${high_rate} logs/second
**Actual Throughput:** $throughput logs/second
**Logs Processed:** $logs_processed

**Resource Usage:**
$analysis

**Performance:**
- Target vs Actual: $(echo "scale=2; ($throughput / $high_rate) * 100" | bc)% efficiency

**Raw Stats:** See $stats_file

EOF
    
    log_success "Backpressure handling test completed"
}

main "$@"

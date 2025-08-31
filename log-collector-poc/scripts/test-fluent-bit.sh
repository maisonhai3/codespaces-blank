#!/bin/bash

# Test script for Fluent Bit collector
# This script runs all 3 test scenarios for Fluent Bit

source "$(dirname "$0")/common.sh"

TOOL_NAME="fluent-bit"
COLLECTOR_CONTAINER="log-collector-poc-fluent-bit-1"
RESULTS_FILE="$RESULTS_DIR/fluent-bit-results.md"

main() {
    log_info "Starting Fluent Bit PoC tests..."
    
    # Generate report header
    generate_report_header "Fluent Bit" "$RESULTS_FILE"
    
    # Test 1: Baseline Performance
    log_info "=== Test 1: Baseline Performance ==="
    test_baseline_performance
    
    # Test 2: Offline Resilience  
    log_info "=== Test 2: Offline Resilience ==="
    test_offline_resilience
    
    # Test 3: Backpressure Handling
    log_info "=== Test 3: Backpressure Handling ==="
    test_backpressure_handling
    
    # Cleanup
    stop_services
    
    log_success "Fluent Bit tests completed! Results saved to: $RESULTS_FILE"
}

test_baseline_performance() {
    local test_duration=60  # 10 minutes
    local stats_file="$RESULTS_DIR/fluent-bit-baseline-stats.csv"
    
    # Clear logs and start services
    clear_shared_logs
    start_services "$TOOL_NAME"
    
    # Wait for initial startup
    sleep 30
    
    # Get initial log count
    local initial_count=$(count_elasticsearch_logs)
    log_info "Initial log count in Elasticsearch: $initial_count"
    
    # Monitor stats during the test
    monitor_container_stats "$COLLECTOR_CONTAINER" $test_duration "$stats_file" &
    local monitor_pid=$!
    
    # Wait for test to complete
    log_info "Running baseline test for ${test_duration} seconds..."
    sleep $test_duration
    
    # Stop monitoring
    wait $monitor_pid
    
    # Get final log count
    local final_count=$(count_elasticsearch_logs)
    local logs_processed=$((final_count - initial_count))
    local throughput=$(echo "scale=2; $logs_processed / $test_duration" | bc)
    
    # Analyze results
    local analysis=$(analyze_stats "$stats_file" "fluent-bit")
    
    # Write results
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
    local disruption_duration=120  # 2 minutes
    local total_duration=360       # 10 minutes total
    local stats_file="$RESULTS_DIR/fluent-bit-offline-stats.csv"
    
    # Clear logs and restart services
    clear_shared_logs
    start_services "$TOOL_NAME"
    
    # Wait for initial startup
    sleep 30
    
    # Get initial log count
    local initial_count=$(count_elasticsearch_logs)
    
    # Start monitoring
    monitor_container_stats "$COLLECTOR_CONTAINER" $total_duration "$stats_file" &
    local monitor_pid=$!
    
    # Let it run normally for 2 minutes
    sleep 120
    
    # Record time of disruption start
    local disruption_start=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Simulate network disruption
    simulate_network_disruption "$COLLECTOR_CONTAINER" $disruption_duration
    
    # Record time of recovery start  
    local recovery_start=$(date '+%Y-%m-%d %H:%M:%S')
    
    # Wait for remaining time
    sleep $((total_duration - 240))  # 240 = 120 (initial) + 120 (disruption)
    
    # Stop monitoring
    wait $monitor_pid
    
    # Get final count and calculate recovery
    sleep 60  # Wait a bit more for recovery
    local final_count=$(count_elasticsearch_logs)
    local logs_processed=$((final_count - initial_count))
    
    # Analyze results
    local analysis=$(analyze_stats "$stats_file" "fluent-bit")
    
    # Write results
    cat >> "$RESULTS_FILE" << EOF
### Test 2: Offline Resilience

**Total Duration:** ${total_duration} seconds
**Disruption Duration:** ${disruption_duration} seconds
**Disruption Start:** $disruption_start
**Recovery Start:** $recovery_start
**Logs Processed:** $logs_processed

**Resource Usage During Test:**
$analysis

**Observations:**
- Network was disconnected for ${disruption_duration} seconds
- Recovery behavior: [Manual observation required]
- Log loss: [Manual verification required]

**Raw Stats:** See $stats_file

EOF
    
    log_success "Offline resilience test completed"
}

test_backpressure_handling() {
    local test_duration=300  # 5 minutes
    local high_rate=10000     # 10000 logs/second
    local stats_file="$RESULTS_DIR/fluent-bit-backpressure-stats.csv"
    
    # Clear logs and start services
    clear_shared_logs
    start_services "$TOOL_NAME"
    
    # Wait for initial startup
    sleep 30
    
    # Set high log generation rate
    set_log_rate $high_rate
    
    # Wait a bit for rate change to take effect
    sleep 10
    
    # Get initial log count
    local initial_count=$(count_elasticsearch_logs)
    
    # Start monitoring
    monitor_container_stats "$COLLECTOR_CONTAINER" $test_duration "$stats_file" &
    local monitor_pid=$!
    
    # Run test
    log_info "Running backpressure test for ${test_duration} seconds at ${high_rate} logs/sec..."
    sleep $test_duration
    
    # Stop monitoring
    wait $monitor_pid
    
    # Get final count
    local final_count=$(count_elasticsearch_logs)
    local logs_processed=$((final_count - initial_count))
    local throughput=$(echo "scale=2; $logs_processed / $test_duration" | bc)
    
    # Analyze results
    local analysis=$(analyze_stats "$stats_file" "fluent-bit")
    
    # Reset log rate
    set_log_rate 10000
    
    # Write results
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
- Backpressure handling: [Manual observation of memory usage required]

**Raw Stats:** See $stats_file

EOF
    
    log_success "Backpressure handling test completed"
}

# Run main function
main "$@"

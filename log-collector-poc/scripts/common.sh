#!/bin/bash

# Common functions for testing log collectors
# Source this file in other test scripts

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
RESULTS_DIR="./results"
LOG_DIR="./shared-logs"

# Ensure results directory exists
mkdir -p "${RESULTS_DIR}"

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to get container stats
get_container_stats() {
    local container_name=$1
    local output_file=$2
    
    log_info "Collecting stats for container: $container_name"
    
    # Check if container exists and is running
    if ! docker ps --format "table {{.Names}}" | grep -q "^${container_name}$"; then
        log_error "Container $container_name is not running!"
        return 1
    fi
    
    # Get current stats (one-time)
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}" "$container_name" >> "$output_file"
}

# Function to monitor container stats for a duration
monitor_container_stats() {
    local container_name=$1
    local duration=$2
    local output_file=$3
    
    log_info "Monitoring $container_name for ${duration} seconds..."
    
    # Header
    echo "Timestamp,Container,CPU%,Memory,MemoryPerc,NetworkIO,BlockIO" > "$output_file"
    
    local end_time=$((SECONDS + duration))
    
    while [ $SECONDS -lt $end_time ]; do
        local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        local stats=$(docker stats --no-stream --format "{{.Container}},{{.CPUPerc}},{{.MemUsage}},{{.MemPerc}},{{.NetIO}},{{.BlockIO}}" "$container_name" 2>/dev/null || echo "N/A,N/A,N/A,N/A,N/A,N/A")
        echo "${timestamp},${stats}" >> "$output_file"
        sleep 5
    done
    
    log_success "Monitoring completed for $container_name"
}

# Function to count logs in Elasticsearch
count_elasticsearch_logs() {
    local index_name=${1:-"aiscout-logs"}
    local max_retries=${2:-30}
    local retry_count=0
    
    while [ $retry_count -lt $max_retries ]; do
        local response=$(curl -s -X GET "http://localhost:9200/${index_name}/_count" 2>/dev/null || echo "")
        
        # If we get a count response, return it
        if echo "$response" | grep -q "count"; then
            local count=$(echo "$response" | jq -r '.count' 2>/dev/null || echo "0")
            echo "$count"
            return 0
        fi
        
        # If index doesn't exist, that's fine - just means no logs yet
        if echo "$response" | grep -q "index_not_found_exception"; then
            echo "0"
            return 0
        fi
        
        # Only retry if we have a real connection issue
        log_warning "Elasticsearch not ready, retrying... ($((retry_count + 1))/$max_retries)" >&2
        sleep 2
        ((retry_count++))
    done
    
    log_error "Failed to connect to Elasticsearch after $max_retries attempts" >&2
    echo "0"
}

# Function to wait for Elasticsearch to be ready
wait_for_elasticsearch() {
    local max_retries=${1:-60}
    local retry_count=0
    
    log_info "Waiting for Elasticsearch to be ready..."
    
    while [ $retry_count -lt $max_retries ]; do
        # Check cluster health directly
        local health_response=$(curl -s "http://localhost:9200/_cluster/health" 2>/dev/null || echo "")
        
        if echo "$health_response" | grep -q '"status":"green\|yellow"'; then
            local status=$(echo "$health_response" | jq -r '.status' 2>/dev/null || echo "unknown")
            log_success "Elasticsearch is ready with status: $status"
            return 0
        fi
        
        log_info "Elasticsearch cluster not ready, waiting... ($((retry_count + 1))/$max_retries)"
        sleep 3
        ((retry_count++))
    done
    
    log_error "Elasticsearch failed to become ready after $max_retries attempts"
    log_error "Final health check: $(curl -s http://localhost:9200/_cluster/health 2>/dev/null || echo 'No response')"
    return 1
}

# Function to clear shared logs directory
clear_shared_logs() {
    log_info "Clearing shared logs directory..."
    rm -rf "${LOG_DIR}"/*
    log_success "Shared logs cleared"
}

# Function to start services
start_services() {
    local collector_profile=$1
    
    log_info "Starting core services..."
    docker-compose up -d log-generator elasticsearch kibana
    
    log_info "Waiting for Elasticsearch to be ready..."
    wait_for_elasticsearch
    
    log_info "Starting $collector_profile collector..."
    docker-compose --profile "$collector_profile" up -d "$collector_profile"
    
    # Wait a bit for the collector to start
    sleep 10
}

# Function to stop services
stop_services() {
    log_info "Stopping all services..."
    docker-compose down
    log_success "All services stopped"
}

# Function to clean up environment
cleanup() {
    log_info "Cleaning up..."
    docker-compose down -v
    docker system prune -f
    log_success "Cleanup completed"
}

# Function to set log generation rate
set_log_rate() {
    local rate=$1
    
    log_info "Setting log generation rate to $rate logs/second..."
    
    # Stop current log generator
    docker-compose stop log-generator
    
    # Update environment and restart
    LOG_RATE=$rate docker-compose up -d log-generator
    
    log_success "Log generation rate set to $rate logs/second"
}

# Function to simulate network disruption
simulate_network_disruption() {
    local collector_name=$1
    local duration=${2:-120}  # Default 2 minutes
    
    log_warning "Simulating network disruption for $collector_name (${duration}s)..."
    
    # Disconnect collector from elasticsearch
    docker network disconnect log-collector-poc_log-network "$collector_name" || true
    
    sleep "$duration"
    
    # Reconnect collector to elasticsearch
    docker network connect log-collector-poc_log-network "$collector_name" || true
    
    log_success "Network disruption simulation completed"
}

# Function to generate test report header
generate_report_header() {
    local tool_name=$1
    local output_file=$2
    
    cat > "$output_file" << EOF
# Log Collector PoC Results - $tool_name

**Test Date:** $(date '+%Y-%m-%d %H:%M:%S')
**Tool:** $tool_name
**Test Environment:** Docker Compose
**Host:** $(hostname)

## Test Summary

EOF
}

# Function to analyze CSV stats file and generate summary
analyze_stats() {
    local stats_file=$1
    local tool_name=$2
    
    if [ ! -f "$stats_file" ]; then
        log_error "Stats file $stats_file not found!"
        return 1
    fi
    
    # Skip header and calculate averages (simplified)
    local cpu_avg=$(tail -n +2 "$stats_file" | awk -F',' '{gsub(/%/, "", $3); sum+=$3; count++} END {if(count>0) printf "%.2f", sum/count}')
    local mem_usage=$(tail -n +2 "$stats_file" | awk -F',' '{print $4}' | head -1)  # Get first memory reading
    
    echo "Average CPU Usage: ${cpu_avg}%"
    echo "Memory Usage: ${mem_usage}"
    
    return 0
}

export -f log_info log_success log_warning log_error
export -f get_container_stats monitor_container_stats count_elasticsearch_logs
export -f wait_for_elasticsearch clear_shared_logs start_services stop_services cleanup
export -f set_log_rate simulate_network_disruption generate_report_header analyze_stats

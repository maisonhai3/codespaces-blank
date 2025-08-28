#!/bin/bash

# Quick setup and smoke test script

source "$(dirname "$0")/common.sh"

main() {
    log_info "Starting quick setup and smoke test..."
    
    # Build log generator
    log_info "Building log generator..."
    docker-compose build log-generator
    
    # Start core services
    log_info "Starting core services (Elasticsearch, Kibana, Log Generator)..."
    docker-compose up -d log-generator elasticsearch kibana
    
    # Wait for Elasticsearch
    wait_for_elasticsearch
    
    # Test Fluent Bit quickly (1 minute test)
    log_info "Running quick Fluent Bit test (1 minute)..."
    docker-compose --profile fluent-bit up -d fluent-bit
    
    # Let it run for 1 minute
    sleep 60
    
    # Check log count
    local log_count=$(count_elasticsearch_logs)
    log_info "Logs in Elasticsearch after 1 minute: $log_count"
    
    if [ "$log_count" -gt 0 ]; then
        log_success "Smoke test PASSED! System is working correctly."
        log_info "You can now run full tests with: ./scripts/run-all-tests.sh"
    else
        log_error "Smoke test FAILED! No logs found in Elasticsearch."
        log_info "Check logs with: docker-compose logs"
    fi
    
    # Show running containers
    log_info "Currently running containers:"
    docker-compose ps
    
    # Show Kibana access info
    log_info "Access Kibana at: http://localhost:5601"
    log_info "Access Elasticsearch at: http://localhost:9200"
    
    # Cleanup option
    read -p "Do you want to stop all services? [y/N]: " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        stop_services
    fi
}

main "$@"

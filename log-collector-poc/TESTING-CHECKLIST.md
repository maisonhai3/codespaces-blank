# Log Collector PoC Testing Checklist

## Pre-Test Checklist ✓

### System Requirements
- [ ] Docker installed and running (version 20.10+)
- [ ] Docker Compose installed (version 2.0+)
- [ ] Dependencies installed: `jq`, `bc`, `curl`
- [ ] At least 5GB free disk space
- [ ] At least 4GB free RAM
- [ ] No other services using ports 9200, 5601, 9300

### Environment Preparation
- [ ] Clone/download PoC repository
- [ ] All scripts are executable (`chmod +x scripts/*.sh`)
- [ ] Run `make check` to verify requirements
- [ ] Run `make setup` and verify smoke test passes

## Testing Process Checklist

### Phase 1: Individual Tool Testing (Optional)
**Test each tool individually to identify any immediate issues**

#### Fluent Bit Test (~30 minutes)
- [ ] Start: `make test-fluent-bit` or `./scripts/test-fluent-bit.sh`
- [ ] Monitor progress: `make logs-collector TOOL=fluent-bit`
- [ ] Check logs are flowing: `make count-logs` (should increase)
- [ ] Verify results file created: `results/fluent-bit-results.md`
- [ ] Clean up: `make stop`

#### Filebeat Test (~30 minutes)
- [ ] Start: `make test-filebeat` or `./scripts/test-filebeat.sh`
- [ ] Monitor progress: `make logs-collector TOOL=filebeat`
- [ ] Check logs are flowing: `make count-logs`
- [ ] Verify results file created: `results/filebeat-results.md`
- [ ] Clean up: `make stop`

#### Vector Test (~30 minutes)
- [ ] Start: `make test-vector` or `./scripts/test-vector.sh`
- [ ] Monitor progress: `make logs-collector TOOL=vector`
- [ ] Check logs are flowing: `make count-logs`
- [ ] Verify results file created: `results/vector-results.md`
- [ ] Clean up: `make stop`

#### Logstash Test (~30 minutes)
- [ ] Start: `make test-logstash` or `./scripts/test-logstash.sh`
- [ ] Monitor progress: `make logs-collector TOOL=logstash`
- [ ] Check logs are flowing: `make count-logs`
- [ ] Verify results file created: `results/logstash-results.md`
- [ ] Clean up: `make stop`

### Phase 2: Complete Test Suite (4-5 hours)
**Run comprehensive testing of all tools**

#### Pre-Run Checks
- [ ] Sufficient time available (4-5 hours uninterrupted)
- [ ] System resources available (check with `htop` or `docker stats`)
- [ ] Network connection stable
- [ ] Clean environment: `make clean-all`

#### Test Execution
- [ ] Start complete test: `make test-all` or `./scripts/run-all-tests.sh`
- [ ] Monitor overall progress in terminal output
- [ ] Occasionally check system resources: `make stats`
- [ ] Note any error messages or warnings

#### Per-Tool Monitoring (during full test run)
For each tool being tested, verify:
- [ ] **Baseline Test (10 min)**: Container starts, logs flow to ES
- [ ] **Offline Test (10 min)**: Network disruption occurs, recovery happens
- [ ] **Backpressure Test (5 min)**: High-rate logging, resource monitoring

## Post-Test Analysis Checklist

### Results Verification
- [ ] All individual result files exist:
  - [ ] `results/fluent-bit-results.md`
  - [ ] `results/filebeat-results.md`
  - [ ] `results/vector-results.md`
  - [ ] `results/logstash-results.md`
- [ ] Comparison report exists: `results/comparison-report.md`
- [ ] CSV stats files exist for each test scenario
- [ ] Check results with: `make results`

### Data Quality Checks
For each tool's results, verify:
- [ ] **Baseline Performance**: 
  - [ ] CPU/Memory stats collected
  - [ ] Throughput calculated (~50 logs/sec expected)
  - [ ] No errors in logs
- [ ] **Offline Resilience**:
  - [ ] Network disruption occurred at correct time
  - [ ] Recovery time measured
  - [ ] No critical data loss
- [ ] **Backpressure Handling**:
  - [ ] High load applied (1000 logs/sec target)
  - [ ] Resource usage measured under stress
  - [ ] System remained stable

### Manual Verification Steps
- [ ] **Kibana Check**: Open `http://localhost:5601`, create index pattern `aiscout-logs`
- [ ] **Data Inspection**: Verify log format and structure in Kibana
- [ ] **Resource Analysis**: Review Docker stats during test runs
- [ ] **Error Log Review**: Check for any errors in container logs

## Final Assessment Checklist

### Quantitative Analysis
For each tool, collect and compare:
- [ ] **CPU Usage**: Average and peak percentages
- [ ] **Memory Usage**: Average consumption in MB/GB
- [ ] **Throughput**: Actual vs expected logs/second
- [ ] **Recovery Time**: Seconds to recover from network issues
- [ ] **Disk Usage**: Buffering/queue space used

### Qualitative Analysis
For each tool, assess:
- [ ] **Configuration Complexity**: How easy was setup?
- [ ] **Documentation Quality**: How complete were docs?
- [ ] **Error Handling**: How gracefully did it handle issues?
- [ ] **Observability**: How easy to monitor/troubleshoot?
- [ ] **Resource Efficiency**: Suitable for edge deployment?

### Decision Framework
- [ ] **Primary Recommendation**: Based on test results, which tool performs best overall?
- [ ] **Edge Suitability**: Which tool best fits edge device constraints?
- [ ] **Operational Overhead**: Which tool is easiest to maintain?
- [ ] **Risk Assessment**: Any concerning behaviors observed?

## Documentation Checklist

### Report Completion
- [ ] Update comparison report with actual metrics
- [ ] Add screenshots from Kibana if helpful
- [ ] Document any issues encountered during testing
- [ ] Include recommendations and next steps
- [ ] Archive raw data files for future reference

### Knowledge Transfer
- [ ] Prepare summary presentation for stakeholders
- [ ] Document any configuration tweaks made during testing
- [ ] Create operational runbooks for chosen solution
- [ ] Plan pilot deployment strategy

## Cleanup Checklist

### Environment Cleanup
- [ ] Save results: `cp -r results/ ../log-collector-poc-results-$(date +%Y%m%d)/`
- [ ] Full cleanup: `make clean-all`
- [ ] Verify disk space recovered: `df -h`
- [ ] Remove temporary files if needed

### Post-Test Actions
- [ ] Schedule team review meeting
- [ ] Prepare production pilot plan
- [ ] Update architecture documentation
- [ ] Plan team training if needed

---

## Time Estimates

| Phase | Duration | Description |
|-------|----------|-------------|
| Setup | 15-30 min | Environment preparation and smoke test |
| Individual Tests | 2-3 hours | Test each tool separately (optional) |
| Full Test Suite | 4-5 hours | Complete automated testing |
| Analysis | 1-2 hours | Review results and create recommendations |
| **Total** | **5-8 hours** | Complete PoC from start to finish |

## Troubleshooting Reference

### Common Issues
- **Elasticsearch won't start**: Check memory limits, increase `vm.max_map_count`
- **Port conflicts**: Kill processes using ports 9200, 5601, 9300
- **Docker out of space**: Run `docker system prune -f`
- **Tests fail to start**: Check all scripts are executable
- **Network issues**: Ensure Docker can create bridge networks

### Emergency Cleanup
If anything goes wrong:
```bash
make clean-all
docker system prune -f -a --volumes
sudo systemctl restart docker
```

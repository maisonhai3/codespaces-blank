# Log Collector PoC Makefile
# Usage: make [target]

.PHONY: help setup smoke-test test-all test-fluent-bit test-filebeat test-vector test-logstash clean logs kibana results

# Default target
help: ## Show this help message
	@echo "Log Collector PoC - Available commands:"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 }' $(MAKEFILE_LIST)

setup: ## Setup environment and run smoke test
	@echo "Setting up environment..."
	docker-compose build log-generator
	./scripts/quick-test.sh

smoke-test: ## Run quick smoke test (5 minutes)
	./scripts/quick-test.sh

test-all: ## Run complete test suite for all tools (4-5 hours)
	./scripts/run-all-tests.sh

test-fluent-bit: ## Test Fluent Bit only (~30 minutes)
	./scripts/test-fluent-bit.sh

test-filebeat: ## Test Filebeat only (~30 minutes)
	./scripts/test-filebeat.sh

test-vector: ## Test Vector only (~30 minutes)
	./scripts/test-vector.sh

test-logstash: ## Test Logstash only (~30 minutes)
	./scripts/test-logstash.sh

# Service management
start: ## Start core services (Elasticsearch, Kibana, Log Generator)
	docker-compose up -d log-generator elasticsearch kibana

stop: ## Stop all services
	docker-compose down

restart: ## Restart all services
	docker-compose restart

# Monitoring and debugging
logs: ## Show logs for all services
	docker-compose logs -f

logs-collector: ## Show logs for currently running collector (specify TOOL=fluent-bit)
	@if [ -z "$(TOOL)" ]; then \
		echo "Usage: make logs-collector TOOL=fluent-bit|filebeat|vector|logstash"; \
	else \
		docker-compose logs -f $(TOOL); \
	fi

logs-generator: ## Show logs for log generator
	docker-compose logs -f log-generator

logs-elasticsearch: ## Show logs for Elasticsearch
	docker-compose logs -f elasticsearch

stats: ## Show Docker stats for all containers
	docker stats

kibana: ## Open Kibana in browser (http://localhost:5601)
	@echo "Opening Kibana at http://localhost:5601"
	@echo "Create index pattern: aiscout-logs"
	@which xdg-open >/dev/null && xdg-open http://localhost:5601 || \
	 which open >/dev/null && open http://localhost:5601 || \
	 echo "Please open http://localhost:5601 in your browser"

# Utility commands
count-logs: ## Count logs in Elasticsearch
	@curl -s -X GET "http://localhost:9200/aiscout-logs/_count" | jq -r '.count // "Elasticsearch not available"'

search-logs: ## Show latest 5 logs from Elasticsearch
	@curl -s -X GET "http://localhost:9200/aiscout-logs/_search?pretty&size=5&sort=@timestamp:desc"

clear-logs: ## Clear all logs from shared directory
	@echo "Clearing shared logs directory..."
	@rm -rf ./shared-logs/* || true
	@echo "Logs cleared"

clear-es: ## Clear Elasticsearch index
	@echo "Clearing Elasticsearch index..."
	@curl -s -X DELETE "http://localhost:9200/aiscout-logs" >/dev/null || true
	@echo "Elasticsearch index cleared"

results: ## Show test results summary
	@echo "Test Results Summary:"
	@echo "===================="
	@if [ -f results/comparison-report.md ]; then \
		cat results/comparison-report.md | head -50; \
		echo ""; \
		echo "Full report: results/comparison-report.md"; \
	else \
		echo "No results found. Run tests first with: make test-all"; \
	fi

# Cleanup commands
clean: ## Stop services and remove containers
	docker-compose down
	docker system prune -f

clean-all: ## Stop services, remove containers, volumes, and results
	docker-compose down -v
	docker system prune -f -a
	rm -rf results/*
	@echo "Complete cleanup done"

# Development helpers
build: ## Build log generator image
	docker-compose build log-generator

ps: ## Show running containers
	docker-compose ps

config: ## Validate docker-compose configuration
	docker-compose config

# Quick tests for individual scenarios
test-baseline: ## Run baseline test only (specify TOOL=fluent-bit)
	@if [ -z "$(TOOL)" ]; then \
		echo "Usage: make test-baseline TOOL=fluent-bit|filebeat|vector|logstash"; \
	else \
		echo "Running baseline test for $(TOOL)..."; \
		docker-compose down; \
		LOG_RATE=10000 docker-compose --profile $(TOOL) up -d; \
		sleep 60; \
		echo "Test running... Check with: make count-logs"; \
	fi

# System checks
check: ## Check system requirements
	@echo "Checking system requirements..."
	@which docker >/dev/null || (echo "❌ Docker not found" && exit 1)
	@which docker-compose >/dev/null || (echo "❌ Docker Compose not found" && exit 1)
	@which jq >/dev/null || (echo "❌ jq not found" && exit 1)
	@which bc >/dev/null || (echo "❌ bc not found" && exit 1)
	@docker info >/dev/null 2>&1 || (echo "❌ Docker daemon not running" && exit 1)
	@echo "✅ All requirements met"

# Documentation
docs: ## Show setup documentation
	@cat SETUP.md

# Installation helpers
install-deps-ubuntu: ## Install dependencies on Ubuntu/Debian
	sudo apt update
	sudo apt install -y jq bc curl
	@echo "Dependencies installed. Docker installation may be needed separately."

install-deps-macos: ## Install dependencies on macOS
	brew install jq bc
	@echo "Dependencies installed. Docker Desktop may be needed separately."

# Example usage targets
example-fluent-bit: ## Example: Quick Fluent Bit test
	@echo "Starting Fluent Bit example..."
	make clean
	make start
	sleep 30
	docker-compose --profile fluent-bit up -d fluent-bit
	@echo "Fluent Bit is running. Check logs with: make logs-collector TOOL=fluent-bit"
	@echo "Check log count with: make count-logs"
	@echo "Access Kibana with: make kibana"

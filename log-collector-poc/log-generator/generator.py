#!/usr/bin/env python3
import json
import time
import os
import uuid
from datetime import datetime
import random
import signal
import sys
import logging

class LogGenerator:
    def __init__(self, log_dir="/shared-logs", rate=50):
        """
        Initialize Log Generator
        :param log_dir: Directory to write logs
        :param rate: Logs per second
        """
        self.log_dir = log_dir
        self.rate = rate
        self.running = True
        self.log_count = 0
        
        # Ensure log directory exists
        os.makedirs(log_dir, exist_ok=True)
        
        # Setup logging for the generator itself
        logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(message)s')
        self.logger = logging.getLogger(__name__)
        
        # Handle shutdown gracefully
        signal.signal(signal.SIGINT, self._signal_handler)
        signal.signal(signal.SIGTERM, self._signal_handler)
        
    def _signal_handler(self, signum, frame):
        self.logger.info(f"Received signal {signum}, shutting down gracefully...")
        self.running = False
        
    def _generate_log_entry(self):
        """Generate a single log entry similar to AiScout format"""
        run_id = str(uuid.uuid4())
        timestamp = datetime.utcnow().isoformat() + "Z"
        
        # Simulate different log types similar to AiScout
        log_types = ["detection", "system", "error", "performance"]
        log_type = random.choice(log_types)
        
        if log_type == "detection":
            log_data = {
                "run_id": run_id,
                "timestamp": timestamp,
                "type": "detection",
                "camera_id": f"cam_{random.randint(1, 4)}",
                "objects_detected": random.randint(0, 5),
                "confidence_scores": [round(random.uniform(0.5, 0.99), 2) for _ in range(random.randint(1, 3))],
                "processing_time_ms": random.randint(50, 500),
                "image_size": {
                    "width": 1920,
                    "height": 1080
                }
            }
        elif log_type == "system":
            log_data = {
                "run_id": run_id,
                "timestamp": timestamp,
                "type": "system",
                "cpu_usage": round(random.uniform(10, 80), 2),
                "memory_usage": round(random.uniform(30, 90), 2),
                "disk_usage": round(random.uniform(20, 70), 2),
                "temperature": round(random.uniform(35, 75), 1),
                "uptime_seconds": random.randint(1000, 86400)
            }
        elif log_type == "error":
            log_data = {
                "run_id": run_id,
                "timestamp": timestamp,
                "type": "error",
                "error_code": f"E{random.randint(1000, 9999)}",
                "error_message": random.choice([
                    "Camera connection lost",
                    "Insufficient memory for processing",
                    "Network timeout",
                    "Model loading failed"
                ]),
                "severity": random.choice(["WARNING", "ERROR", "CRITICAL"]),
                "component": random.choice(["camera", "ml_engine", "network", "storage"])
            }
        else:  # performance
            log_data = {
                "run_id": run_id,
                "timestamp": timestamp,
                "type": "performance",
                "fps": round(random.uniform(15, 30), 2),
                "latency_ms": random.randint(20, 200),
                "queue_size": random.randint(0, 10),
                "batch_size": random.randint(1, 8),
                "model_inference_time": random.randint(10, 100)
            }
            
        return log_data
    
    def _write_log_file(self, log_data):
        """Write log data to single aiscout.log file"""
        filepath = os.path.join(self.log_dir, "aiscout.log")
        
        try:
            with open(filepath, 'a') as f:
                json.dump(log_data, f, separators=(',', ':'))
                f.write('\n')
            return True
        except Exception as e:
            self.logger.error(f"Failed to write log file {filepath}: {e}")
            return False
    
    def start_generation(self):
        """Start generating logs at the specified rate"""
        self.logger.info(f"Starting log generation at {self.rate} logs/second")
        self.logger.info(f"Writing logs to: {self.log_dir}")
        
        interval = 1.0 / self.rate if self.rate > 0 else 1.0
        
        while self.running:
            start_time = time.time()
            
            # Generate and write log
            log_data = self._generate_log_entry()
            if self._write_log_file(log_data):
                self.log_count += 1
                
                # Log progress every 100 entries
                if self.log_count % 100 == 0:
                    self.logger.info(f"Generated {self.log_count} logs")
            
            # Control rate
            elapsed = time.time() - start_time
            sleep_time = interval - elapsed
            if sleep_time > 0:
                time.sleep(sleep_time)
        
        self.logger.info(f"Log generation stopped. Total logs generated: {self.log_count}")

def main():
    # Get configuration from environment variables
    log_dir = os.getenv('LOG_DIR', '/shared-logs')
    rate = int(os.getenv('LOG_RATE', '50'))
    
    generator = LogGenerator(log_dir=log_dir, rate=rate)
    generator.start_generation()

if __name__ == "__main__":
    main()

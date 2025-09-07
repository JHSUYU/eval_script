#!/usr/bin/env python3
"""
Simple monitor tools for processing JVMTop logs
"""

import sys
import glob
import re

def parse_memory_mb(mem_str):
    """
    Parse memory string to MB
    """
    mem_str = mem_str.strip().lower()

    if mem_str.endswith('g'):
        return float(mem_str[:-1]) * 1024
    elif mem_str.endswith('m'):
        return float(mem_str[:-1])
    elif mem_str.endswith('k'):
        return float(mem_str[:-1]) / 1024
    else:
        try:
            return float(mem_str)
        except:
            return 0.0

def process_service_logs(service):
    """
    Process all log files for a specific service and calculate averages
    """
    print(f"\nProcessing {service} logs...")

    # Find all log files for this service
    log_files = glob.glob(f"logs/*_{service}_*_raw.log")

    if not log_files:
        print(f"  No logs found for {service}")
        return

    # Process each log file
    for log_file in log_files:
        # Extract server and process name from filename
        filename = log_file.split('/')[-1]
        parts = filename.replace('_raw.log', '').split('_')
        server = parts[0]
        process_name = parts[2] if len(parts) > 2 else "unknown"

        total_cpu = 0.0
        total_memory = 0.0
        count = 0

        try:
            with open(log_file, 'r') as f:
                for line in f:
                    # Parse line: CPU:  1.84% GC:  0.00% HEAP: 289m /15935m NONHEAP: 123m /  n/a
                    cpu_match = re.search(r'CPU:\s+([\d.]+)%', line)
                    heap_match = re.search(r'HEAP:\s+(\d+[gmk]?)', line)

                    if cpu_match and heap_match:
                        cpu_value = float(cpu_match.group(1))
                        memory_value = parse_memory_mb(heap_match.group(1))

                        total_cpu += cpu_value
                        total_memory += memory_value
                        count += 1

        except Exception as e:
            print(f"  Error processing {log_file}: {e}")
            continue

        # Calculate and print averages
        if count > 0:
            avg_cpu = total_cpu / count
            avg_memory = total_memory / count
            print(f"  {server} {process_name}: CPU: {avg_cpu:.2f}%, Memory: {avg_memory:.2f}MB (Samples: {count})")
        else:
            print(f"  {server} {process_name}: No valid data found")

def main():
    if len(sys.argv) != 3 or sys.argv[1] != "process":
        print("Usage: python3 monitor_tools.py process <service>")
        sys.exit(1)

    service = sys.argv[2]

    if service == "all":
        # Process all known services
        for svc in ["cassandra", "zookeeper", "hdfs", "hbase", "yarn"]:
            process_service_logs(svc)
    else:
        process_service_logs(service)

if __name__ == "__main__":
    main()
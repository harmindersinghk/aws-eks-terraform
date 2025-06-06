#!/usr/bin/env python3
"""
Local test script for validating Locust configuration.
Run this script to test the locustfile locally before deploying to Kubernetes.
"""

import sys
import os
import subprocess
import time
import requests
from pathlib import Path

def check_prerequisites():
    """Check if required tools are installed."""
    print("Checking prerequisites...")
    
    # Check if locust is installed
    try:
        result = subprocess.run(['locust', '--version'], capture_output=True, text=True)
        print(f"✓ Locust version: {result.stdout.strip()}")
    except FileNotFoundError:
        print("✗ Locust not found. Install with: pip install locust")
        return False
    
    # Check if kubectl is available
    try:
        result = subprocess.run(['kubectl', 'version', '--client'], capture_output=True, text=True)
        print("✓ kubectl is available")
    except FileNotFoundError:
        print("✗ kubectl not found. Please install kubectl")
        return False
    
    return True

def check_online_boutique():
    """Check if Online Boutique is accessible."""
    print("Checking Online Boutique accessibility...")
    
    try:
        # Check if we can access the cluster
        result = subprocess.run(['kubectl', 'get', 'service', 'frontend-external', '-n', 'app'], 
                              capture_output=True, text=True)
        if result.returncode == 0:
            print("✓ Online Boutique service found")
            return True
        else:
            print("✗ Online Boutique service not found")
            return False
    except Exception as e:
        print(f"✗ Error checking Online Boutique: {e}")
        return False

def run_local_test():
    """Run a local Locust test."""
    print("Starting local Locust test...")
    
    # Get the directory containing this script
    script_dir = Path(__file__).parent
    locust_dir = script_dir.parent / 'locust'
    locustfile = locust_dir / 'locustfile.py'
    
    if not locustfile.exists():
        print(f"✗ Locustfile not found at {locustfile}")
        return False
    
    print("Starting Locust web UI...")
    print("Open http://localhost:8089 in your browser")
    print("Use 'http://localhost:8080' as the host (with port-forward)")
    print("Press Ctrl+C to stop")
    
    try:
        # Start locust
        subprocess.run([
            'locust',
            '-f', str(locustfile),
            '--web-host', '0.0.0.0',
            '--web-port', '8089'
        ])
    except KeyboardInterrupt:
        print("\nStopping Locust...")
        return True

def setup_port_forward():
    """Set up port forwarding to Online Boutique."""
    print("Setting up port forwarding to Online Boutique...")
    print("This will forward localhost:8080 to the frontend service")
    print("Run this in a separate terminal:")
    print("kubectl port-forward service/frontend-external 8080:80 -n app")
    print()
    
    response = input("Have you set up port forwarding? (y/n): ")
    return response.lower() == 'y'

def validate_locustfile():
    """Validate the locustfile syntax."""
    print("Validating locustfile syntax...")
    
    script_dir = Path(__file__).parent
    locust_dir = script_dir.parent / 'locust'
    locustfile = locust_dir / 'locustfile.py'
    
    try:
        # Try to compile the locustfile
        with open(locustfile, 'r') as f:
            code = f.read()
        
        compile(code, str(locustfile), 'exec')
        print("✓ Locustfile syntax is valid")
        return True
    except SyntaxError as e:
        print(f"✗ Syntax error in locustfile: {e}")
        return False
    except Exception as e:
        print(f"✗ Error validating locustfile: {e}")
        return False

def main():
    """Main function."""
    print("=== Locust Local Test Script ===")
    print()
    
    if not check_prerequisites():
        print("Please install missing prerequisites and try again.")
        sys.exit(1)
    
    if not validate_locustfile():
        print("Please fix the locustfile and try again.")
        sys.exit(1)
    
    print("Choose an option:")
    print("1. Run local test with port-forward")
    print("2. Validate configuration only")
    print("3. Check Online Boutique status")
    
    choice = input("Enter choice (1-3): ").strip()
    
    if choice == '1':
        if not setup_port_forward():
            print("Please set up port forwarding first.")
            sys.exit(1)
        run_local_test()
    elif choice == '2':
        print("Configuration validation completed.")
    elif choice == '3':
        if check_online_boutique():
            print("Online Boutique is accessible.")
        else:
            print("Online Boutique is not accessible.")
    else:
        print("Invalid choice.")
        sys.exit(1)

if __name__ == '__main__':
    main()

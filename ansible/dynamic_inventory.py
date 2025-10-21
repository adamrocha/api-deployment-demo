#!/usr/bin/env python3

import json
import sys
import os

def get_inventory():
    """Generate dynamic inventory based on server roles"""
    inventory = {
        "db": {
            "hosts": [
                "db-staging",
                "db-prod-1", 
                "db-prod-2"
            ],
            "vars": {
                "server_role": "database",
                "postgresql_version": "15",
                "monitoring_enabled": True
            }
        },
        "web": {
            "hosts": [
                "web-staging",
                "web-prod-1",
                "web-prod-2"
            ],
            "vars": {
                "server_role": "web",
                "nginx_enabled": True,
                "ssl_enabled": True
            }
        },
        "staging": {
            "hosts": [
                "db-staging",
                "web-staging"
            ],
            "vars": {
                "environment": "staging",
                "debug_mode": True
            }
        },
        "production": {
            "hosts": [
                "db-prod-1",
                "db-prod-2", 
                "web-prod-1",
                "web-prod-2"
            ],
            "vars": {
                "environment": "production",
                "debug_mode": False
            }
        },
        "_meta": {
            "hostvars": {
                "db-staging": {
                    "ansible_host": "10.0.1.101",
                    "ansible_user": "ubuntu",
                    "ansible_ssh_private_key_file": "~/.ssh/staging-key.pem",
                    "server_role": "database",
                    "environment": "staging"
                },
                "db-prod-1": {
                    "ansible_host": "10.0.2.102",
                    "ansible_user": "ubuntu", 
                    "ansible_ssh_private_key_file": "~/.ssh/prod-key.pem",
                    "server_role": "database",
                    "environment": "production"
                },
                "db-prod-2": {
                    "ansible_host": "10.0.2.103",
                    "ansible_user": "ubuntu",
                    "ansible_ssh_private_key_file": "~/.ssh/prod-key.pem", 
                    "server_role": "database",
                    "environment": "production"
                },
                "web-staging": {
                    "ansible_host": "10.0.1.100",
                    "ansible_user": "ubuntu",
                    "ansible_ssh_private_key_file": "~/.ssh/staging-key.pem",
                    "server_role": "web", 
                    "environment": "staging"
                },
                "web-prod-1": {
                    "ansible_host": "10.0.2.100",
                    "ansible_user": "ubuntu",
                    "ansible_ssh_private_key_file": "~/.ssh/prod-key.pem",
                    "server_role": "web",
                    "environment": "production"
                },
                "web-prod-2": {
                    "ansible_host": "10.0.2.101",
                    "ansible_user": "ubuntu",
                    "ansible_ssh_private_key_file": "~/.ssh/prod-key.pem",
                    "server_role": "web", 
                    "environment": "production"
                }
            }
        }
    }
    return inventory

def get_host_vars(host):
    """Get variables for a specific host"""
    inventory = get_inventory()
    return inventory.get("_meta", {}).get("hostvars", {}).get(host, {})

if __name__ == "__main__":
    if len(sys.argv) == 2 and sys.argv[1] == "--list":
        print(json.dumps(get_inventory(), indent=2))
    elif len(sys.argv) == 3 and sys.argv[1] == "--host":
        print(json.dumps(get_host_vars(sys.argv[2]), indent=2))
    else:
        print("Usage: %s --list | --host <hostname>" % sys.argv[0])
        sys.exit(1)
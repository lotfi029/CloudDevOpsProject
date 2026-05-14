# 4. Configuration Management with Ansible

## ✅ Requirement Status

| Requirement | Status |
|-------------|--------|
| Install Java | ✅ Done — `java` role installs OpenJDK 21 |
| Install Jenkins | ✅ Done — `jenkins` role installs Jenkins LTS |
| Install Docker | ✅ Done — `packages` role installs Docker CE |
| Install Trivy | ✅ Done — `packages` role installs Trivy |
| Use Ansible roles | ✅ Done — 3 roles: `java`, `jenkins`, `packages` |
| Use Dynamic Inventory | ✅ Done — `amazon.aws.aws_ec2` plugin, filters by `tag:Role=jenkins` |
| Ansible modules committed | ✅ Done |

---

## Directory Structure

```
ansible/
├── ansible.cfg                        ← Configures roles path, host key checking, inventory plugin
├── inventory/
│   └── aws_ec2.yml                    ← Dynamic inventory (discovers EC2 by tag)
├── playbooks/
│   └── configure_jenkins.yml          ← Main playbook
└── roles/
    ├── java/tasks/main.yml            ← Installs OpenJDK 21
    ├── jenkins/tasks/main.yml         ← Installs Jenkins LTS
    └── packages/tasks/main.yml        ← Installs Docker, Trivy, AWS CLI, kubectl
```

---

## `ansible.cfg`

```ini
[defaults]
deprecation_warnings = False
host_key_checking = False
roles_path = /mnt/d/IVolve/CloudDevOpsProject/ansible/roles

[inventory]
enable_plugins = amazon.aws.aws_ec2, auto, yaml, ini
```

---

## Dynamic Inventory — `inventory/aws_ec2.yml`

Discovers Jenkins EC2 automatically using AWS tags — no manual IP management:

```yaml
plugin: amazon.aws.aws_ec2
regions:
  - us-east-1
filters:
  tag:Role: jenkins
  instance-state-name: running
hostnames:
  - public-ip-address
compose:
  ansible_host: public_ip_address
keyed_groups:
  - key: tags.Role
    prefix: role
```

The Jenkins instance is tagged `Role=jenkins` by Terraform, so Ansible finds it automatically and groups it under `role_jenkins`.

---

## Main Playbook — `playbooks/configure_jenkins.yml`

```yaml
- name: Configure Jenkins EC2 Instance
  hosts: role_jenkins
  become: true
  remote_user: ubuntu
  roles:
    - java
    - jenkins
    - packages
```

---

## Role Summary

### `java` role

- Installs `openjdk-21-jdk` (Jenkins 2.x requires Java 21 minimum)
- Sets `JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64` in `/etc/environment`

> ⚠️ Java 17 was originally used but Jenkins LTS now requires Java 21+

### `jenkins` role

- Downloads and dearmors Jenkins GPG key using `gpg --dearmor` (modern apt requirement on Ubuntu 22.04+)
- Imports the updated signing key `7198F4B714ABFC68` from Ubuntu keyserver
- Adds Jenkins apt repository with `signed-by=` syntax
- Installs Jenkins, creates systemd override to set `JAVA_HOME`
- Starts and enables Jenkins service
- Prints initial admin password

> ⚠️ `apt_key` module is deprecated on Ubuntu 22.04+ — the role uses `get_url` + `gpg --dearmor` instead

### `packages` role

- Installs Docker CE + CLI + containerd
- Adds `jenkins` and `ubuntu` users to the `docker` group
- Installs Trivy (vulnerability scanner) from aquasecurity repo
- Installs AWS CLI v2 from official zip
- Installs `kubectl` latest stable

---

## Prerequisites

```bash
# Activate virtual environment
source ~/.ansible-venv/bin/activate

# Install dependencies
pip install boto3 botocore
ansible-galaxy collection install amazon.aws

# Configure AWS credentials
aws configure
```

## Running the Playbook

```bash
cd /path/to/CloudDevOpsProject

# Test connectivity
ansible -i ansible/inventory/aws_ec2.yml all -m ping \
  --private-key ~/.ssh/jenkins-key.pem -u ubuntu

# Run full configuration
ansible-playbook -i ansible/inventory/aws_ec2.yml \
  ansible/playbooks/configure_jenkins.yml \
  --private-key ~/.ssh/jenkins-key.pem
```

## Expected Output

```
TASK [java : Print Java version]
ok: [x.x.x.x] => {
    "msg": "openjdk version \"21.x.x\" ..."
}

TASK [jenkins : Print Jenkins initial admin password]
ok: [x.x.x.x] => {
    "msg": "Jenkins Initial Password: xxxxxxxxxxxxxxxxxxxx"
}

PLAY RECAP
x.x.x.x : ok=N  changed=N  unreachable=0  failed=0
```
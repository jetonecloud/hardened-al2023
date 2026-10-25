SHELL := /bin/bash
PACKER_DIR := packer
ANSIBLE_DIR := ansible
VARS_FILE ?= $(PACKER_DIR)/local.pkrvars.hcl

.PHONY: help init fmt validate lint build test scan clean

help:
	@echo "Targets:"
	@echo "  init      - install packer plugins + ansible collections"
	@echo "  fmt       - packer fmt (writes changes)"
	@echo "  validate  - packer validate"
	@echo "  lint      - ansible-lint + yamllint"
	@echo "  build     - packer build (requires AWS credentials + $(VARS_FILE))"
	@echo "  test      - run the goss profile against a live host (GOSS_ADDR=user@host)"
	@echo "  scan      - run trivy filesystem scan locally against this repo's IaC"
	@echo "  clean     - remove local build artifacts"

init:
	cd $(PACKER_DIR) && packer init al2023.pkr.hcl
	ansible-galaxy collection install -r $(ANSIBLE_DIR)/requirements.yml

fmt:
	cd $(PACKER_DIR) && packer fmt .

validate: init
	cd $(PACKER_DIR) && packer validate -var-file=$(VARS_FILE) al2023.pkr.hcl

lint:
	ansible-lint $(ANSIBLE_DIR)/playbook.yml
	yamllint .

build: init
	cd $(PACKER_DIR) && PACKER_LOG=1 packer build -var-file=$(VARS_FILE) al2023.pkr.hcl

test:
	@test -n "$(GOSS_ADDR)" || (echo "usage: make test GOSS_ADDR=ec2-user@<host>"; exit 1)
	ssh $(GOSS_ADDR) 'sudo GOSS_FILES_PATH=/tmp/goss goss validate --format documentation'

scan:
	trivy config --severity CRITICAL,HIGH $(PACKER_DIR) $(ANSIBLE_DIR)

clean:
	rm -rf $(PACKER_DIR)/packer_cache $(PACKER_DIR)/manifest.json artifacts reports *.log

## mkpm bootstrap
ifndef mkpm_included
ifeq ($(filter grouped-target,$(.FEATURES)),)
$(error mkpm requires GNU Make >= 4.3 (found $(MAKE_VERSION)). On macOS: brew install make, then use 'gmake')
endif
mkpm_dir := $(subst mkpm_dir=,,$(filter mkpm_dir=%,$(or $(file < .mkpmrc.local),$(file < .mkpmrc))))
ifneq ($(mkpm_dir),)
include $(if $(filter /%,$(mkpm_dir)),$(mkpm_dir),$(abspath $(mkpm_dir)))/Makefile
else
mkpm: REMOTE ?= https://mkpm.io/Makefile
mkpm:
	@curl -fsSL $(REMOTE) -o $@ || { echo "Failed to download $@ from $(REMOTE)" >&2; exit 1; }
include mkpm
endif
endif
## /mkpm bootstrap

define mkpm_sshrc_get
$(call mkpm_get,$(file < .sshrc),$(1))
endef

ssh_host ?= $(call mkpm_sshrc_get,host)
ssh_user ?= $(call mkpm_sshrc_get,user)
ssh_key ?= $(call mkpm_sshrc_get,key)

$(call mkpm_help,ssh,SSH into machine. Usage: make ssh host=<host> user=<user> key=<key>)
ssh:
	ssh$(if $(ssh_key), -i $(ssh_key)) $(ssh_user)@$(ssh_host)

$(call mkpm_help,ssh-remove-from-known-hosts,Remove machine from known_hosts. Usage: make ssh-remove-from-known-hosts host=<host>)
ssh-remove-from-known-hosts:
	$(if $(ssh_host),,$(error "ssh_host is not set. Please set it to the SSH host of the machine."))
	@ssh-keygen -f ~/.ssh/known_hosts -R "$(ssh_host)"

$(call mkpm_help,ssh-run,Run an arbitrary command on the machine via SSH, e.g. make ssh-run cmd="ls -la /root")
ssh-run: cmd ?=
ssh-run: 
	$(if $(ssh_host),,$(error "ssh_host is not set. Please set it to the SSH host of the machine."))
	@ssh$(if $(ssh_key), -i $(ssh_key)) $(ssh_user)@$(ssh_host) "$(strip $(cmd))"
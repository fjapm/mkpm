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

define terraform_call
@docker run -i -t --user $(shell id -u):$(shell id -g) -v $(CURDIR):/workspace $(if $(@hetzner_vps_tf_module_dir),-v $(@hetzner_vps_tf_module_dir):$(@hetzner_vps_tf_module_dir):ro) -w /workspace hashicorp/terraform:latest $(1) $(strip $(2))
endef

$(call mkpm_help,ln-tf-modules,Create a symlink to the terraform modules directory)
ln-tf-modules: tf_modules_dir := $(call mkpm_mkpmrc_get,hetzner_vps_tf_module_dir) 
ln-tf-modules:
	$(if $(call mkpm_mkpmrc_get,hetzner_vps_tf_module_dir),,$(error "hetzner_vps_tf_module_dir is not set. Please set it to the path of the terraform-modules directory."))
	$(quiet)mkdir -p .tf-modules
	cd .tf-modules && ln -sf $(call mkpm_mkpmrc_get,hetzner_vps_tf_module_dir) .

$(call mkpm_help,tf-init,Run <terraform init>)
tf-init:
	$(call terraform_call,init)

$(call mkpm_help,tf-plan,Run <terraform plan>)
tf-plan: tf-init
	$(call terraform_call,plan)

$(call mkpm_help,tf-output,Run <terraform output>)
tf-output:
	$(call terraform_call,output)

$(call mkpm_help,tf-output-public-ip,Run <terraform output -raw public_ip>)
tf-output-public-ip:
	$(call terraform_call,output -raw public_ip)

$(call mkpm_help,tf-output-%,Run <terraform output -raw <attributes>)
tf-output-%:
	$(call terraform_call,output -raw $*)

$(call mkpm_help,tf-apply,Run <terraform apply>)
tf-apply: tf-init ssh-remove-from-known-hosts
	$(call terraform_call,apply)
	$(call terraform_on_after_tf_apply)

$(call mkpm_help,tf-destroy,Run <terraform destroy>)
tf-destroy:
	$(call terraform_call,destroy)
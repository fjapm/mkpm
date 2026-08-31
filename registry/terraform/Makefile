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

# define terraform_call
# $(quiet)docker run -i -t --user $(shell id -u):$(shell id -g) -v $(CURDIR):/workspace $(if $(@hetzner_vps_tf_module_dir),-v $(@hetzner_vps_tf_module_dir):$(@hetzner_vps_tf_module_dir):ro) -w /workspace hashicorp/terraform:latest $(1) $(strip $(2))
# endef

define terraform_modules_dir
$(call mkpm_get,$(file < .terraformrc.local),modules_dir)
endef

define terraform_call
docker run -i -t --user $(shell id -u):$(shell id -g) \
	-v $(CURDIR):/workspace \
	$(if $(call terraform_modules_dir),-v $(call terraform_modules_dir):/workspace/.tf-modules:ro) \
	-w /workspace hashicorp/terraform:latest $(1) $(strip $(2))
endef

define terraform_shell
docker run -i -t --user $(shell id -u):$(shell id -g) \
	-v $(CURDIR):/workspace \
	$(if $(call terraform_modules_dir),-v $(call terraform_modules_dir):/workspace/.tf-modules:ro) \
	--entrypoint /bin/sh \
	-w /workspace hashicorp/terraform:latest $(1) $(strip $(2))
endef

# $(call mkpm_help,ln-tf-modules,Create a symlink to a local terraform modules directory)
# ln-tf-modules: tf_modules_dir ?=
# ln-tf-modules:
# 	$(if $(tf_modules_dir),,$(error "tf_modules_dir is not set. Please set it to the local path of a terraform modules directory."))
# 	$(quiet)mkdir -p .tf-modules
# 	cd .tf-modules && ln -sf $(tf_modules_dir) .

$(call mkpm_help,tf-shell,Run <terraform shell>)
tf-shell:
	$(quiet)$(call terraform_shell)

$(call mkpm_help,tf-help,Run <terraform help>)
tf-help:
	$(quiet)$(call terraform_call,-help)

$(call mkpm_help,tf-init,Run <terraform init>)
tf-init:
	$(quiet)$(call terraform_call,init)

$(call mkpm_help,tf-plan,Run <terraform plan>)
tf-plan: tf-init
	$(quiet)$(call terraform_call,plan)

$(call mkpm_help,tf-apply,Run <terraform apply>)
tf-apply: tf-init
	$(quiet)$(call terraform_call,apply)
	$(call terraform_on_after_tf_apply)

$(call mkpm_help,tf-destroy,Run <terraform destroy>)
tf-destroy:
	$(quiet)$(call terraform_call,destroy)
	$(call terraform_on_after_tf_destroy)

$(call mkpm_help,tf-output,Run <terraform output>)
tf-output:
	$(quiet)$(call terraform_call,output)

$(call mkpm_help,tf-output-raw-%,Run <terraform output -raw <attribute>>)
tf-output-raw-%:
	$(quiet)$(call terraform_call,output -raw $*)


$(call mkpm_help,tf-<cmd>,Run <terraform <cmd>>)
tf-%:
	$(call terraform_call,$(subst -,$(space),$*))
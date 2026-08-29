.DELETE_ON_ERROR:
.DEFAULT_GOAL := help

# When $(CURDIR) != $(PWD) it means that -C was set
ifneq ($(CURDIR),$(PWD))
# special target namespace variable: path of CURDIR relative to PWD, so
# a -C into a nested dir (e.g. -C apps/web) namespaces as "apps/web", not just "web"
mkpm_target_ns = $(patsubst $(PWD)/%,%,$(CURDIR))
endif

mkpm_this := $(lastword $(dir $(abspath $(MAKEFILE_LIST))))
mkpm_version := 0.1.0
mkpm_os := $(shell uname -s | tr '[:upper:]' '[:lower:]')
mkpm_arch := $(patsubst x86_64,amd64,$(patsubst aarch64,arm64,$(shell uname -m)))

$(if $(filter-out linux darwin,$(mkpm_os)),$(error unsupported OS: $(mkpm_os)))
$(if $(filter-out amd64 arm64,$(mkpm_arch)),$(error unsupported arch: $(mkpm_arch)))

quiet ?= @

MAKEFLAGS += $(file < .makeflags)

define newline


endef

empty :=
space := $(empty) $(empty)
comma := ,
hash  := \#
sentinel := §

mkpm_help_text :=

define mkpm_help
$(eval mkpm_help_text := $(mkpm_help_text)$(if $(mkpm_target_ns),$(mkpm_target_ns)/)$(strip $(1))|$(strip $(2))@@)
endef

mkpm_pkgs_dir := .mkpkgs
mkpm_pkgs_loaded :=

define mkpm_write_config_file
$(file > $(1),$(subst $(space),$(newline),$(strip $(2))))
endef

define mkpm_read_config
$(subst $(sentinel),$(empty),$(filter-out $(hash)%,$(subst $(sentinel)$(hash),$(space)$(hash),$(filter-out $(hash)%,$(subst $(space),$(sentinel),$(1))))))
endef

#$(call mkpm_get,contents,key)
define mkpm_get
$(subst $(2)=,,$(filter $(2)=%,$(call mkpm_read_config,$(1))))
endef

#$(call mkpm_get,key,mkpkg_file = $(file < mkpkg))
define mkpm_mkpkg_get
$(call mkpm_get,$(file < $(or $(2),$(CURDIR))/mkpkg),$(1))
endef

#$(call mkpm_mkpkg_set,key,val,mkpkg_file = mkpkg)
define mkpm_mkpkg_set
$(call mkpm_write_config_file,$(or $(3),mkpkg),$(subst $(1)=$(call mkpm_mkpkg_get,$(1),$(3)),$(1)=$(2),$(file < $(or $(3),mkpkg))))
endef

define mkpm_pkg_name
$(call mkpm_mkpkg_get,name,$(1))
endef

define mkpm_pkg_version
$(or $(call mkpm_mkpkg_get,version,$(1)),latest)
endef

define mkpm_pkg_templates
$(subst $(comma), ,$(call mkpm_mkpkg_get,templates,$(1)))
endef

define mkpm_pkg_files
$(subst $(comma), ,$(call mkpm_mkpkg_get,files,$(1)))
endef

define mkpm_pkg_main
$(or $(call mkpm_mkpkg_get,main,$(1)),Makefile)
endef

#$(call mkpmrc_get,key,mkpmrc_file = $(file < .mkpmrc))
define mkpm_mkpmrc_get
$(subst $(comma), ,$(call mkpm_get,$(or $(2),$(filter $(1)=%,$(file < .mkpmrc.local)),$(filter $(1)=%,$(file < .mkpmrc))),$(1)))
endef

define mkpm_is_rel_dir
$(if $(filter /%,$(strip $(1))),,t)
endef

define mkpm_dir ?=
$(if $(call mkpm_mkpmrc_get,mkpm_dir),$(if $(filter /%,$(call mkpm_mkpmrc_get,mkpm_dir)),$(call mkpm_mkpmrc_get,mkpm_dir),$(abspath $(call mkpm_mkpmrc_get,mkpm_dir))))
endef

define mkpm_ws
$(call mkpm_mkpmrc_get,ws)
endef

define mkpm_ws_dir
$(if $(mkpm_ws),$(if $(call mkpm_is_rel_dir,$(mkpm_ws)),$(abspath $(mkpm_ws)),$(mkpm_ws)))
endef

define mkpm_plugins
$(or $(call mkpm_mkpmrc_get,plugins),+mkpm-oras-docker +_mkpm-oras-common)
endef

define mkpm_pkg
$(call mkpm_pkg_name)@$(call mkpm_pkg_version)
endef

# Deps
define mkpm_split
$(subst $(or $(2),@), ,$(1))
endef

# <name>@<version>
define mkpm_dep_name
$(if $(strip $(word 2,$(call mkpm_split,$(1)))),$(word 1,$(call mkpm_split,$(1))),$(1))
endef

define mkpm_dep_version
$(word 2,$(subst @, ,$(1)))
endef

define mkpm_dep
$(call mkpm_dep_name,$(1))$(if $(call mkpm_dep_version,$(1)),@$(call mkpm_dep_version,$(1)),)
endef

define mkpm_pack_files
tar -czf $(call mkpm_pkg).tgz -C $(CURDIR) $(strip $(call mkpm_pkg_main) $(call mkpm_pkg_templates) $(call mkpm_pkg_files))
endef

define mkpm_unpack_files
f=$$(ls -1 $(call mkpm_dep_name,$(1))@*.tgz 2>/dev/null | head -n1); tar -xf "$${f:-$(1).tgz}" -C $(or $(2),$(mkpm_pkgs_dir))/$(1)
endef

define mkpm_semver_major
$(word 1,$(subst ., ,$(call mkpm_pkg_version)))
endef

define mkpm_semver_minor
$(word 2,$(subst ., ,$(call mkpm_pkg_version)))
endef

define mkpm_semver_patch
$(word 3,$(subst ., ,$(call mkpm_pkg_version)))
endef

define mkpm_copy_local_pkg_templates
$(if $(strip $(2)),$(shell for f in $(2); do \
  if [ ! -e "$(CURDIR)/$$f" ]; then \
    mkdir -p "$(CURDIR)/$$(dirname "$$f")"; \
    cp "$(1)/$$f" "$(CURDIR)/$$f"; \
  fi; \
done))
endef

define mkpm_computed_local_pkg_dir
$(join $(mkpm_ws_dir),/$(call mkpm_dep_name,$(1)))
endef

define mkpm_load_local_pkg
$(eval include $(call mkpm_computed_local_pkg_dir,$(1))/Makefile)
mkpm_loaded_pkgs += $(call mkpm_dep_name,$(1))
$(call mkpm_copy_local_pkg_templates,$(call mkpm_computed_local_pkg_dir,$(1)),$(call mkpm_pkg_templates,$(call mkpm_computed_local_pkg_dir,$(1))))
endef

define mkpm_load_remote_pkg
include $(mkpm_pkgs_dir)/$(1)/Makefile
mkpm_loaded_pkgs += $(1)
$(mkpm_pkgs_dir)/$(1)/Makefile: | $(mkpm_default_plugins) $(mkpm_custom_plugins)
	$(quiet)set -e
	$(quiet)$$(call mkpm_download,$(1))
	$(quiet)mkdir -p $(mkpm_pkgs_dir)/$(1)
	$(quiet)$$(call mkpm_unpack_files,$(1))
	$(quiet)rm -f $(call mkpm_dep_name,$(1))@*.tgz $(1).tgz
endef

define mkpm_is_pkg_loaded
$(filter $(call mkpm_dep_name,$(1)),$(mkpm_loaded_pkgs))
endef

define mkpm_is_pkg_in_ws
$(and $(mkpm_ws),$(wildcard $(mkpm_ws_dir)/$(call mkpm_dep_name,$(1))))
endef

#$(call mkpm_load,pkg)
define mkpm_load
$(if $(filter mkpm-%,$(MAKECMDGOALS)),,$(if $(call mkpm_is_pkg_loaded,$(1)),,$(eval $(if $(call mkpm_is_pkg_in_ws,$(1)),$(call mkpm_load_local_pkg,$(1)),$(call mkpm_load_remote_pkg,$(1))))))
endef

## Registry Plugin
## mkpm_publish and mkpm_download must be implemented by a publishing plugin
# $(1) = pack file, $(2) = pkg name,  $(3) = pkg version
#$(or $(call mkpmmkpmrc_get,reg),$(MKPM_REGISTRY),$(error registry is missing.$(newline)$(space)$(space) Define reg=<registry_url> in .mkpmrc or set MKPM_REGISTRY env var))
define mkpm_registry
$(or $(call mkpm_mkpmrc_get,reg),$(MKPM_REGISTRY))
endef

define mkpm_registry_token
$(or $(call mkpm_mkpmrc_get,reg_token),$(MKPM_REGISTRY_TOKEN))
endef

#$(or $(call mkpmmkpmrc_get,reg_user),$(MKPM_REGISTRY_USER),github,$(error registry user is missing.$(newline)$(space)$(space) Define reg_user=<registry_user> in .mkpmrc or set MKPM_REGISTRY_USER env var))
define mkpm_registry_user
$(or $(call mkpm_mkpmrc_get,reg_user),$(MKPM_REGISTRY_USER),github)
endef

define mkpm_publish
$(error mkpm_publish is not implemented.$(newline)$(space)$(space)1. Enable a plugin in .mkpmrc: plugins=+mkpm-oras-docker$(space)or$(space)plugins=+default$(newline)$(space)$(space)2. Or define mkpm_publish yourself (args: $$(1)=pack file, $$(2)=name, $$(3)=version))
endef

define mkpm_download
$(error mkpm_download is not implemented.$(newline)$(space)$(space)1. Enable a plugin in .mkpmrc: plugins=+mkpm-oras-docker$(space)or$(space)plugins=+default$(newline)$(space)$(space)2. Or define mkpm_download yourself (args: $$(1)=pkg name, $$(2)=version))
endef
##

define mkpm_mkpkg
$(file < $(or $(2),mkpkg),name=$(1)$(newline)version=0.0.1$(newline)main=Makefile)
endef

define mkpm_mkpmrc
$(file < $(or $(2),.mkpmrc),reg=ghcr.io/<gh_username>$(newline)plugins=+mkpm-oras-docker)
endef

define mkpm_default_plugins
$(subst +,$(if $(mkpm_dir),$(mkpm_dir)/plugins/,.mkpm_plugins/),$(filter +%,$(call mkpm_plugins)))
endef

define mkpm_custom_plugins 
$(addprefix .mkpm_plugins/,$(filter-out +%,$(call mkpm_plugins)))
endef

define mkpm_ensure_plugin_fetched
$(if $(wildcard $(1)),,$(shell mkdir -p $(dir $(1)) 2>/dev/null; curl -fsSL https://raw.githubusercontent.com/codextremist/mkpm/refs/heads/master/plugins/$(notdir $(1)) -o $(1) 2>/dev/null || rm -f $(1)))
endef

$(foreach mkpm_p,$(filter .mkpm_plugins/%,$(mkpm_default_plugins) $(mkpm_custom_plugins)),$(call mkpm_ensure_plugin_fetched,$(mkpm_p)))

-include $(mkpm_default_plugins)
-include $(mkpm_custom_plugins)

ifneq ($(strip $(mkpm_dir)),)
$(mkpm_dir)/plugins/%:
	$(error mkpm plugin '$*' not found in $(mkpm_dir))
endif

.mkpm_plugins/%: REMOTE ?= https://raw.githubusercontent.com/codextremist/mkpm/refs/heads/master/plugins/$*
.mkpm_plugins/%:
	@mkdir -p $(@D)
	@curl -fsSL $(REMOTE) -o $@ || { \
	  echo "mkpm: failed to download plugin '$*' from $(REMOTE)" >&2; \
	  exit 1; \
	}

help:
	@printf '\033[95m%s\033[0m\n' '$(if $(mkpm_target_ns),$(call mkpm_target_ns),$(lastword $(subst /, ,$(CURDIR))))'
	@printf '%s' '$(mkpm_help_text)' | awk '{n=split($$0,a,"@@"); for(i=1;i<=n;i++) if(split(a[i],b,"|")==2) {sub(/^[ \t]+/,"",b[1]); sub(/^[ \t]+/,"",b[2]); printf " \033[90m└\033[0m\033[36m%-40s\033[0m %s\n", b[1], b[2]}}'
	$(call help_hook)

ifneq ($(file < mkpkg),)
.PHONY: mkpm-pack
$(call mkpm_help,mkpm-pack,Pack <$(call mkpm_pkg_name)@$(call mkpm_pkg_version)> into a .tgz distribution file)
mkpm-pack:
	$(quiet)$(call mkpm_pack_files)
	@echo Pack $(call mkpm_pkg).tgz created

$(call mkpm_help,mkpm-pack-rm,Delete any local <$(call mkpm_pkg_name)@*.tgz> distribution files)
.PHONY: mkpm-pack-rm
mkpm-pack-rm:
	$(quiet)rm -f $(call mkpm_pkg_name)@*.tgz

$(call mkpm_help,mkpm-publish,Pack and publish <$(call mkpm_pkg_name)@$(call mkpm_pkg_version)> to the registry)
.PHONY: mkpm-publish
mkpm-publish: mkpm-pack
	$(quiet)$(call mkpm_publish,$(call mkpm_pkg).tgz,$(call mkpm_pkg_name),$(call mkpm_pkg_version))

$(call mkpm_help,mkpm-deploy,Pack and deploy <$(call mkpm_pkg_name)@$(call mkpm_pkg_version)> to a remote server via SSH)
mkpm-deploy: ssh_user ?= root
mkpm-deploy: ssh_host ?=
mkpm-deploy: ssh_remote_path ?=
mkpm-deploy: mkpm-pack
	$(quiet)$(if $(ssh_host),,$(error Missing ssh_host. Usage: make mkpm-deploy ssh_host=<host> [ssh_user=<user>] [ssh_remote_path=<path>]))
	$(quiet)$(if $(ssh_remote_path),,$(error Missing ssh_remote_path. Usage: make mkpm-deploy ssh_remote_path=<path> [ssh_user=<user>] [ssh_host=<host>]))
	$(quiet)ssh $(ssh_user)@$(ssh_host) 'mkdir -p $(ssh_remote_path) && tar -xzf - -C $(ssh_remote_path)' < $(call mkpm_pkg).tgz

$(call mkpm_help,mkpm-semver-bump,Set the package version explicitly. Usage: make mkpm-semver-bump ver=<version>)
.PHONY: mkpm-semver-bump
mkpm-semver-bump: ver ?=
mkpm-semver-bump:
	$(if $(ver),,$(error Missing version. Usage: mkpm-semver-bump ver=1.5.4))
	$(call mkpm_mkpkg_set,version,$(ver))
	@echo New version $(call mkpm_mkpkg_get,version)

$(call mkpm_help,mkpm-semver-major,Bump <$(call mkpm_pkg_name)> major version (X.y.z -> X+1.0.0))
.PHONY: mkpm-semver-major
mkpm-semver-major:
	$(call mkpm_mkpkg_set,version,$(shell echo $$(($(call mkpm_semver_major) + 1))).$(call mkpm_semver_minor).$(call mkpm_semver_patch))
	@echo New version $(call mkpm_mkpkg_get,version)

$(call mkpm_help,mkpm-semver-minor,Bump <$(call mkpm_pkg_name)> minor version (x.Y.z -> x.Y+1.0))
.PHONY: mkpm-semver-minor
mkpm-semver-minor:
	$(call mkpm_mkpkg_set,version,$(call mkpm_semver_major).$(shell echo $$(($(call mkpm_semver_minor) + 1))).$(call mkpm_semver_patch))
	@echo New version $(call mkpm_mkpkg_get,version)

$(call mkpm_help,mkpm-semver-patch,Bump <$(call mkpm_pkg_name)> patch version (x.y.Z -> x.y.Z+1))
.PHONY: mkpm-semver-patch
mkpm-semver-patch:
	$(call mkpm_mkpkg_set,version,$(call mkpm_semver_major).$(call mkpm_semver_minor).$(shell echo $$(($(call mkpm_semver_patch) + 1))))
	@echo New version $(call mkpm_mkpkg_get,version)
else
mkpm-pack mkpm-publish mkpm-semver-bump mkpm-semver-major mkpm-semver-minor mkpm-semver-patch mkpm-pack-rm:
	$(error Missing mkpkg file)
endif

ifneq ($(wildcard .mkpm_plugins),)
$(call mkpm_help,mkpm-plugins-rm,Delete .mkpm_plugins folder)
.PHONY: mkpm-plugins-rm
mkpm-plugins-rm:
	rm -rf ./mkpm_plugins
endif

$(call mkpm_help,mkpm-init,Initialize a new package (optional: name=<pkg>) in this directory)
.PHONY: mkpm-init
mkpm-init: name ?=
mkpm-init:
	$(quiet)pkg="$(name)"; \
	if [ -z "$$pkg" ]; then \
	  printf "New package name: "; \
	  read -r pkg; \
	fi; \
	case "$$pkg" in \
	  '') echo "mkpm: package name required" >&2; exit 1 ;; \
	  *[!a-zA-Z0-9_-]*) \
	    echo "mkpm: invalid package name '$$pkg'" >&2; \
	    echo "mkpm: only letters, digits, '-' and '_' are allowed" >&2; \
	    exit 1 ;; \
	esac; \
	printf 'name=%s\nversion=0.0.1\nmain=Makefile\n' "$$pkg" > mkpkg; \
	for entry in .mkpmrc.local .mkpm_plugins .mkpkgs *.tgz; do \
	  grep -qxF "$$entry" .gitignore 2>/dev/null || echo "$$entry" >> .gitignore; \
	done; \
	echo "Initialized package '$$pkg'"

-include $(mkpm_this)/introspect.mk
-include $(mkpm_this)/local/Makefile

mkpm_included := true
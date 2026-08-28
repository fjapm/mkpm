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


define docker_compose_load_env_file
$(call mkpm_read_config,$(file < $(1)))
endef

define docker_compose_call
$(quiet)docker compose $(1) $(strip $(2))
endef

docker_compose_user ?= $(shell id -u):$(shell id -g)

# `docker compose config --services` order is not stable, so sort for a deterministic fallback
_docker_compose_services = $(sort $(shell docker compose config --services))
_docker_compose_default_service = $(or \
	$(shell for s in $(_docker_compose_services); do \
		docker compose config "$$s" | grep -qE '^ +main: "?true"?$$' && { echo "$$s"; break; }; \
	done),\
	$(firstword $(_docker_compose_services)))

define docker_compose_run
$(quiet)docker compose run --rm $(if $(docker_compose_user),--user $(docker_compose_user) )$(1) $(strip $(2))
endef

$(call mkpm_help,up,Start $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )stack)
up:
	$(call docker_compose_call,up,-d --remove-orphans)

$(call mkpm_help,up-fg,Start $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )stack in foreground)
up-fg:
	$(call docker_compose_call,up,--remove-orphans)

$(call mkpm_help,up-fg-<service>,Start $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )<service> from stack)
up-fg-%:
	$(call docker_compose_call,up --remove-orphans,$*)

$(call mkpm_help,down,Stop $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )stack)
down:
	$(call docker_compose_call,down)

$(call mkpm_help,down-v,Stop $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )stack and remove volumes)
down-v: opts ?=
down-v:
	$(call docker_compose_call,down,-v$(opts))

$(call mkpm_help,restart,Stop $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )stack, then start it again)
restart: opts ?=
restart: down
	$(call docker_compose_call,up,-d)

$(call mkpm_help,image-ls,List $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )images)
image-ls: opts ?=
image-ls:
	$(call docker_compose_call,images,$(opts))

$(call mkpm_help,image-build,Build $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )images)
image-build: opts ?=
image-build:
	$(call docker_compose_call,build,$(opts))

$(call mkpm_help,image-push,Push $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )images)
image-push: opts ?=
image-push:
	$(call docker_compose_call,push,$(opts))

$(call mkpm_help,image-push-include-deps,Push $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )images with --include-deps)
image-push-include-deps: opts ?= --include-deps
image-push-include-deps: 
	$(call docker_compose_call,push,$(opts))

$(call mkpm_help,image-pull,Pull $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )images)
image-pull: opts ?=
image-pull:
	$(call docker_compose_call,pull,$(opts))

$(call mkpm_help,image-pull-include-deps,Pull $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )images with --include-deps)
image-pull-include-deps: opts ?= 
image-pull-include-deps: 
	$(call docker_compose_call,pull,--include-deps $(opts))

$(call mkpm_help,shell,Exec into the main $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )container (the service labelled main=true). E.g. `make shell service="other-service"` to exec into other-service container)
shell: service ?= $(_docker_compose_default_service)
shell:
	$(call docker_compose_run,$(service),--entrypoint=/bin/bash)

$(call mkpm_help,ps,Check $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )container status)
ps: opts ?=
ps:
	$(quiet)$(call docker_compose_call,ps,$(opts))

$(call mkpm_help,ps-all,Check $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )	container status for all containers)
ps-all: opts ?=
ps-all:
	$(call docker_compose_call,ps,--all $(opts))

$(call mkpm_help,ps-filter,Check $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )container status with filter. E.g. `make ps-filter opts="status=running"` to show only running containers)
ps-filter: opts ?=
ps-filter:
	$(call docker_compose_call,ps,--filter $(opts))

$(call mkpm_help,logs-f,Check $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )container logs with -f. E.g. `make logs-f` to follow logs for the web service)
logs-f:
	$(call docker_compose_call,logs,-f)

$(call mkpm_help,logs-f-<service>,Check $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )container logs with -f. E.g. `make logs-f-<service> opts="web"` to follow logs for the web service)
logs-f-%: opts ?=
logs-f-%:
	$(call docker_compose_call,logs,-f $(notdir $*))

$(call mkpm_help,logs-until,Check $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )container logs with --until. E.g. `make logs-until until_args="2024-06-01T12:00:00"`)
logs-until: until_args ?= 
logs-until: opts ?= 
logs-until:
	$(call docker_compose_call,logs,--until=$(until_args)$(opts))

$(call mkpm_help,volumes,List $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )volumes)
volumes:
	$(call docker_compose_call,volumes)

$(call mkpm_help,services,List $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )services)
services:
	$(call docker_compose_call,config,--services)

$(call mkpm_help,exec,Exec into the main $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )container (the service labelled main=true). E.g. `make exec opts="web bash"` to exec into the web service container with bash instead)
exec: opts ?= $(_docker_compose_default_service) bash
exec:
	$(call docker_compose_call,exec,$(opts))

$(call mkpm_help,exec-<container>,Exec into the $(if $(mkpm_target_ns),<$(mkpm_target_ns)> )$(1) container. E.g. `make exec-<container> opts="sh"` to exec into the container with sh)
exec-%: opts ?= bash
exec-%:
	$(call docker_compose_call,exec,$* $(opts))

# Docker context
# since context opens an SSH connection per command, add this to ~/.ssh/config so
# repeated ps/logs calls reuse one connection:
# Host server.example.com
# 	ControlMaster auto
#   ControlPath ~/.ssh/cm-%r@%h:%p
#   ControlPersist 10m
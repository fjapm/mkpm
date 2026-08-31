docker_compose_dir := $(lastword $(dir $(abspath $(MAKEFILE_LIST))))

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

docker_compose_files := docker-compose.common.yml docker-compose.$(ENV).yml

define pgkit_set_project_name
$(eval export pgkit_project_name := $(1))
endef

define pgkit_export_env_files
$(foreach var,$(call docker_compose_load_env_file,$(1)),$(eval export $(var)))
endef

$(call mkpm_load,docker_compose)

$(call mkpm_help,gen-postgresql-conf,Generate a sample PostgreSQL configuration file from the running container)
gen-postgresql-conf:
	$(call docker_compose_call,exec,postgres cat /var/lib/postgresql/data/postgresql.conf > ./postgresql.conf.sample)

$(call mkpm_help,dump-ls,List all PostgreSQL dump files in ./backups)
dump-ls:
	@cd ./backups && ls -sh *.dump 2>/dev/null || echo "No dump files found in ./backups"

$(call mkpm_help,dump-restore,Restore a PostgreSQL database from a dump file)
dump-restore: dump ?= $(shell cd ./backups && ls -1 *.dump 2>/dev/null | head -n 1)
dump-restore:
	$(call docker_compose_call,exec,postgres pg_restore -U postgres -c --if-exists -d $(POSTGRES_DB) /backups/$(dump))

$(call mkpm_help,dump-restore-plain,Restore a PostgreSQL database from a plain SQL dump file)
dump-restore-plain: dump ?= $(shell cd ./backups && ls -1 *.{sql,dump} 2>/dev/null | head -n 1)
dump-restore-plain:
	$(call docker_compose_call,exec,postgres psql -v ON_ERROR_STOP=1 -U postgres -d $(POSTGRES_DB) -f /backups/$(dump))

$(call mkpm_help,dump,Dump a PostgreSQL database to a file)
dump:
	$(call docker_compose_call,exec,postgres pg_dump -U postgres -d $(POSTGRES_DB) -f /backups/$(dump))
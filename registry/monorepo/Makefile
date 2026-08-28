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

MAKEFLAGS += --no-print-directory

define monorepo_submake
$(MAKE) -C ./$(1) $(2)
endef

FORCE:
.PHONY: FORCE

define monorepo_submake_rule
$(1): FORCE
	$(quiet)$$(call monorepo_submake,$$(@D),$$(notdir $$@))
endef

# Command line goals get an explicit rule on top of the `<dir>/%` pattern rule.
# The pattern rule alone is not enough: make picks the matching pattern rule
# with the shortest stem, so any slashless `<something>-%` rule from a loaded
# package steals the goal (`logs-f-%` matches `db/logs-f-web` with the stem
# `db/web`, which is shorter than `db/%`'s stem `logs-f-web`). Explicit rules
# always beat pattern rules.
define monorepo_set_dirs
$(if $(monorepo_dirs),$(error monorepo_dirs already set: monorepo_dirs = $(monorepo_dirs)))$(eval
monorepo_dirs := $(strip $(1))
)$(foreach monorepo_target,$(addsuffix /%,$(strip $(1))) $(sort $(filter $(addsuffix /%,$(strip $(1))),$(MAKECMDGOALS))),$(eval $(call monorepo_submake_rule,$(monorepo_target))))
endef

# Global help hook
define help_hook
$(quiet)$(foreach dir,$(monorepo_dirs),$(call monorepo_submake,$(dir),help) &&) true
endef
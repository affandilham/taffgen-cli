# --- Extract version argument (e.g., 1.0.1) ---
ifeq (update-version,$(firstword $(MAKECMDGOALS)))
  VERSION_ARG := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
  $(eval $(VERSION_ARG):;@:)
endif

# --- Main Target ---
update-version:
	@if [ -z "$(VERSION_ARG)" ]; then \
		echo "⚠️  Error: Target version is required! (example: make update-version 1.0.1)"; \
		exit 1; \
	fi
	@echo "🚀 Starting version synchronization to $(VERSION_ARG)..."
	@dart release.dart $(VERSION_ARG)
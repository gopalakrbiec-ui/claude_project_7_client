SPEC_URL  := https://claudeproject7-production.up.railway.app/openapi.json
SPEC_FILE := api-contract/openapi.json

.PHONY: sync-contract gen-api help

## Fetch the latest OpenAPI spec from the live backend and save it locally.
## Run this whenever the backend changes before regenerating the client.
sync-contract:
	@echo "→ Fetching OpenAPI spec from $(SPEC_URL)"
	@mkdir -p api-contract
	curl -fsSL "$(SPEC_URL)" -o "$(SPEC_FILE)"
	@echo "✓ Saved to $(SPEC_FILE)"

## Generate the Dart Dio API client + freezed models from api-contract/openapi.json.
## Requires: Flutter SDK on PATH.
## Generated files land in lib/api/generated/ — never edit them by hand.
gen-api: $(SPEC_FILE)
	@echo "→ Installing pub dependencies"
	dart pub get
	@echo "→ Running openapi_generator via build_runner"
	dart run build_runner build --delete-conflicting-outputs
	@echo "✓ Generated files written to lib/api/generated/"
	@echo "   Models:"
	@find lib/api/generated -name "*.dart" | sort | sed 's|^|   |'

## Full refresh: pull latest spec then regenerate everything.
sync-and-gen: sync-contract gen-api

help:
	@echo ""
	@echo "Usage:"
	@echo "  make sync-contract   Pull latest OpenAPI spec from the backend"
	@echo "  make gen-api         Generate Dart client + models from the spec"
	@echo "  make sync-and-gen    Do both in one step"
	@echo ""

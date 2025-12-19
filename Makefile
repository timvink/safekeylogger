build:
	./scripts/create-dmg.sh

install: build
	@echo "🛑 Stopping SafeKeylogger if running..."
	@killall SafeKeylogger 2>/dev/null || true
	@sleep 1
	@echo "📦 Installing to /Applications..."
	@# Use rsync to update in-place, preserving the app's identity for macOS permissions
	@# The -a flag preserves permissions, and --delete removes old files
	@rsync -a --delete build/SafeKeylogger.app/ /Applications/SafeKeylogger.app/
	@# Touch the app to update modification time
	@touch /Applications/SafeKeylogger.app
	@echo "✅ Installed to /Applications/SafeKeylogger.app"

run: install
	@echo "🚀 Launching SafeKeylogger..."
	@open /Applications/SafeKeylogger.app

release: build
	@VERSION=$$(grep 'VERSION=' scripts/create-dmg.sh | head -1 | cut -d'"' -f2); \
	DMG_PATH="build/SafeKeylogger-$${VERSION}.dmg"; \
	if [ ! -f "$$DMG_PATH" ]; then \
		echo "Error: DMG not found at $$DMG_PATH"; \
		exit 1; \
	fi; \
	echo "Creating GitHub release v$${VERSION}..."; \
	gh release create "v$${VERSION}" "$$DMG_PATH" \
		--title "SafeKeylogger v$${VERSION}" \
		--notes "Release v$${VERSION}" \
		--draft; \
	echo "Draft release created. Review and publish at:"; \
	gh release view "v$${VERSION}" --web || echo "Visit GitHub to publish the release"

.PHONY: build install run release
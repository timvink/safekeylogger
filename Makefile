build:
	./Scripts/create-dmg.sh

install: build
	@echo "🛑 Stopping SafeKeylogger if running..."
	@killall SafeKeylogger 2>/dev/null || true
	@sleep 1
	@echo "📦 Installing to /Applications..."
	@rm -rf /Applications/SafeKeylogger.app
	@cp -R build/SafeKeylogger.app /Applications/
	@echo "✅ Installed to /Applications/SafeKeylogger.app"

run: install
	@echo "🚀 Launching SafeKeylogger..."
	@open /Applications/SafeKeylogger.app

.PHONY: build install run
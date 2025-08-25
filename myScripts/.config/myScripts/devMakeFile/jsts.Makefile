# === Config ===
SRC_DIR = src
DIST_DIR = dist
HTML_SRC = public/index.html
CSS_SRC = $(SRC_DIR)/styles/main.css
TS_SRC = $(SRC_DIR)/scripts/index.ts
JS_OUT = $(DIST_DIR)/scripts/index.js
CSS_OUT = $(DIST_DIR)/styles/main.css
HTML_OUT = $(DIST_DIR)/index.html

# === Targets ===

init:
	mkdir -p $(SRC_DIR)/styles $(SRC_DIR)/scripts $(DIST_DIR)/styles $(DIST_DIR)/scripts
	mkdir -p public
	echo "<!DOCTYPE html>\n<html>\n<head><link rel='stylesheet' href='styles/main.css'></head>\n<body>\n  <script src='scripts/index.js'></script>\n</body>\n</html>" > $(HTML_SRC)
	echo "body { font-family: sans-serif; }" > $(CSS_SRC)
	echo "console.log('Hello from TypeScript');" > $(TS_SRC)
	npm init -y
	npm install -D typescript ts-node ts-node-dev \
	  eslint @eslint/js globals \
	  @typescript-eslint/parser @typescript-eslint/eslint-plugin
	npx tsc --init
	@printf '{\n  "compilerOptions": {\n    "target": "es6",\n    "module": "esnext",\n    "rootDir": "./src",\n    "outDir": "./dist",\n    "strict": true,\n    "esModuleInterop": true\n  },\n  "include": ["src"]\n}\n' > tsconfig.json
	@printf 'import js from "@eslint/js";\nimport globals from "globals";\nimport parserTs from "@typescript-eslint/parser";\nimport pluginTs from "@typescript-eslint/eslint-plugin";\n\nexport default [\n  js.configs.recommended,\n  {\n    files: ["**/*.ts"],\n    languageOptions: {\n      parser: parserTs,\n      parserOptions: {\n        ecmaVersion: 2021,\n        sourceType: "module"\n      },\n      globals: { ...globals.browser }\n    },\n    plugins: { "@typescript-eslint": pluginTs },\n    rules: {}\n  }\n];\n' > eslint.config.mjs
	@echo "✅ Project initialized with TypeScript + ESLint"

gitignore:
	@touch .gitignore
	@grep -qxF "# Node modules" .gitignore || echo "# Node modules" >> .gitignore
	@grep -qxF "node_modules/" .gitignore || echo "node_modules/" >> .gitignore
	@grep -qxF "" .gitignore || echo "" >> .gitignore
	@grep -qxF "# Build output" .gitignore || echo "# Build output" >> .gitignore
	@grep -qxF "dist/" .gitignore || echo "dist/" >> .gitignore
	@grep -qxF "" .gitignore || echo "" >> .gitignore
	@grep -qxF "# Optional dev server / Python server cache" .gitignore || echo "# Optional dev server / Python server cache" >> .gitignore
	@grep -qxF "__pycache__/" .gitignore || echo "__pycache__/" >> .gitignore
	@grep -qxF "" .gitignore || echo "" >> .gitignore
	@grep -qxF "# Logs" .gitignore || echo "# Logs" >> .gitignore
	@grep -qxF "npm-debug.log*" .gitignore || echo "npm-debug.log*" >> .gitignore
	@grep -qxF "yarn-debug.log*" .gitignore || echo "yarn-debug.log*" >> .gitignore
	@grep -qxF "yarn-error.log*" .gitignore || echo "yarn-error.log*" >> .gitignore
	@grep -qxF "" .gitignore || echo "" >> .gitignore
	@grep -qxF "# Environment variables" .gitignore || echo "# Environment variables" >> .gitignore
	@grep -qxF ".env" .gitignore || echo ".env" >> .gitignore
	@grep -qxF ".env.*" .gitignore || echo ".env.*" >> .gitignore
	@grep -qxF "" .gitignore || echo "" >> .gitignore
	@grep -qxF "# VS Code workspace settings (optional)" .gitignore || echo "# VS Code workspace settings (optional)" >> .gitignore
	@grep -qxF ".vscode/" .gitignore || echo ".vscode/" >> .gitignore
	@grep -qxF "" .gitignore || echo "" >> .gitignore
	@grep -qxF "# TypeScript cache" .gitignore || echo "# TypeScript cache" >> .gitignore
	@grep -qxF "*.tsbuildinfo" .gitignore || echo "*.tsbuildinfo" >> .gitignore
	@grep -qxF "" .gitignore || echo "" >> .gitignore
	@grep -qxF "# System files" .gitignore || echo "# System files" >> .gitignore
	@grep -qxF ".DS_Store" .gitignore || echo ".DS_Store" >> .gitignore
	@grep -qxF "Thumbs.db" .gitignore || echo "Thumbs.db" >> .gitignore


build: clean
	mkdir -p $(DIST_DIR)/styles $(DIST_DIR)/scripts
	cp $(CSS_SRC) $(CSS_OUT)
	cp $(HTML_SRC) $(HTML_OUT)
	# cp -r public/docs $(DIST_DIR)/docs         
	npx tsc $(TS_SRC) --outFile $(JS_OUT)

dev:
	npx ts-node $(TS_SRC)

serve:
	npx serve

pyserve:
	python3 -m http.server --directory $(DIST_DIR) 8080

watch:
	npx tsc --watch

clean:
	rm -rf $(DIST_DIR)

rebuild: clean build

.PHONY: init build dev serve watch clean rebuild gitignore pyserve

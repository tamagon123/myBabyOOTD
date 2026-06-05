# myBabyOOTD 管理ツール Makefile

.PHONY: start setup install clean

# 管理ツール起動（最もよく使うコマンド）
start:
	@bash start.sh

# 初回セットアップ
setup:
	python3 -m venv venv
	venv/bin/pip install -r requirements.txt
	@echo "✅ セットアップ完了。次は 'make start' で起動してください"

# 依存パッケージインストール
install:
	venv/bin/pip install -r requirements.txt

# 仮想環境・キャッシュ削除
clean:
	rm -rf venv
	find . -type d -name __pycache__ -exec rm -rf {} +
	@echo "🧹 クリーンアップ完了"

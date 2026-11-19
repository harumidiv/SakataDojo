#!/bin/zsh
# App Store の検索結果（3840×2560）・製品ページヘッダー（3840×1646）用の動画を書き出す
# 使い方（リポジトリのルートで）:
#   AppStoreScreenshots/PromoVideo/render.sh            # 日本語の動画を2本書き出す
#   AppStoreScreenshots/PromoVideo/render.sh --stills   # 確認用の静止画だけ書き出す（黄色の枠がセーフエリア）
#   AppStoreScreenshots/PromoVideo/render.sh --images   # ヘッダーの静止画（PNG）を AppStoreScreenshots/HeaderImage/<言語>/ に書き出す
#   AppStoreScreenshots/PromoVideo/render.sh ja en      # 言語を指定する
# 入力: AppStoreScreenshots/PromoVideo/shots/<言語>/{title,pattern,answer,study}.png（iPhone の画面）
# 出力: AppStoreScreenshots/PromoVideo/output/<言語>/{search_3840x2560,header_3840x1646}.mp4
set -euo pipefail
ROOT=$(cd "$(dirname "$0")/../.." && pwd)
BUILD_DIR=${TMPDIR:-/tmp}/sakata_promo_video
mkdir -p "$BUILD_DIR"
swiftc -O -o "$BUILD_DIR/render_promo" \
  "$ROOT/AppStoreScreenshots/PromoVideo/main.swift" \
  "$ROOT/SakataChartQuiz/Models.swift" \
  "$ROOT/SakataChartQuiz/IdealPatterns.swift"
cd "$ROOT"
"$BUILD_DIR/render_promo" "$@"

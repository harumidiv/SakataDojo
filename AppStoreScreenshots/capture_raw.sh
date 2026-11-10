#!/bin/zsh
# 各言語・各デバイスのシミュレータでアプリを起動し、App Store用の素材スクショ（raw）を撮影する
# 使い方: AppStoreScreenshots/capture_raw.sh <SakataChartQuiz.app のパス> [locale ...]
#   例: AppStoreScreenshots/capture_raw.sh build/Debug-iphonesimulator/SakataChartQuiz.app en ko
#   locale を省略すると ja en ko zh-Hant vi をすべて撮影する
#   ONLY_DEVICES="iphone duo" のように指定すると対象デバイスを絞れる
# 出力: AppStoreScreenshots/raw/<locale>/<device>_<state>.png
# 注意: iPad はステータスバーの日付も揃えるため、システム言語を切り替えて再起動する
#       iPhone Duo は事前に Simulator.app で開き、内側の画面が見える状態にしておくこと
set -euo pipefail

APP_PATH=${1:?"SakataChartQuiz.app のパスを指定してください"}
shift
BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print CFBundleIdentifier" "$APP_PATH/Info.plist")
ROOT=$(cd "$(dirname "$0")" && pwd)

# rawPrefix:シミュレータ名:ランタイム（iOS 26.3 のシミュレータは繁体字中国語のフォントがなく□になるため iOS 27 系を使う）
DEVICES=(
  "iphone:iPhone 18 Pro:iOS 27.0"
  "ipad:iPad Pro 13-inch (M5):iOS 27.0"
  "duo:iPhone Duo:iOS 27.1"
)
STATES=(title direction pattern answer study)
typeset -A REGION=(ja ja_JP en en_US ko ko_KR zh-Hant zh_TW vi vi_VN)
if (( $# )); then LOCALES=("$@"); else LOCALES=(ja en ko zh-Hant vi); fi

udid_for() {
  local name=$1 runtime=$2
  xcrun simctl list devices available \
    | awk -v name="    $name (" -v runtime="-- $runtime --" '
        /^-- / { in_runtime = ($0 == runtime) }
        in_runtime && index($0, name) == 1 { print; exit }' \
    | sed -E 's/.*\(([0-9A-F-]{36})\).*/\1/'
}

boot_with_language() {
  local udid=$1 locale=$2 prefix=$3
  xcrun simctl boot "$udid" 2>/dev/null || true
  xcrun simctl bootstatus "$udid" -b >/dev/null
  # iPhone系のステータスバーは時刻のみなので再起動不要。Duo は再起動すると折りたたみ状態に戻り内側画面が真っ黒になる
  if [[ $prefix != ipad ]]; then
    xcrun simctl ui "$udid" appearance light
    xcrun simctl status_bar "$udid" override --time "9:41" --batteryState discharging --batteryLevel 100 --wifiBars 3
    return
  fi
  xcrun simctl spawn "$udid" defaults write -g AppleLanguages -array "$locale"
  xcrun simctl spawn "$udid" defaults write -g AppleLocale -string "${REGION[$locale]}"
  # 言語設定をシステム全体（ステータスバー含む）に反映させるため再起動する
  xcrun simctl shutdown "$udid"
  xcrun simctl boot "$udid"
  xcrun simctl bootstatus "$udid" -b >/dev/null
  xcrun simctl ui "$udid" appearance light
  xcrun simctl status_bar "$udid" override --time "9:41" --batteryState discharging --batteryLevel 100 --wifiBars 3
}

for entry in $DEVICES; do
  prefix=${entry%%:*}
  rest=${entry#*:}
  name=${rest%%:*}
  runtime=${rest#*:}
  if [[ -n ${ONLY_DEVICES:-} && " $ONLY_DEVICES " != *" $prefix "* ]]; then continue; fi
  udid=$(udid_for "$name" "$runtime")
  if [[ -z $udid ]]; then echo "Simulator not found: $name" >&2; exit 1; fi

  # iPhone Duo は画面が2つあるので内側（2007x2853）を指定する
  display_opt=()
  [[ $prefix == duo ]] && display_opt=(--display=3)

  for locale in $LOCALES; do
    boot_with_language "$udid" "$locale" "$prefix"
    xcrun simctl install "$udid" "$APP_PATH"
    mkdir -p "$ROOT/raw/$locale"
    for state in $STATES; do
      xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
      xcrun simctl launch "$udid" "$BUNDLE_ID" \
        -AppleLanguages "($locale)" -AppleLocale "${REGION[$locale]}" \
        "--screenshot-state=$state" >/dev/null
      sleep 6
      xcrun simctl io "$udid" screenshot $display_opt "$ROOT/raw/$locale/${prefix}_${state}.png" 2>/dev/null
      echo "$locale/${prefix}_${state}.png"
    done
    xcrun simctl terminate "$udid" "$BUNDLE_ID" 2>/dev/null || true
  done
  xcrun simctl status_bar "$udid" clear
done

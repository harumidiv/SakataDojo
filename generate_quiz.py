# -*- coding: utf-8 -*-
"""
酒田五法クイズ用JSONデータ生成スクリプト（複数パターン・複数銘柄対応版）
JPX上場銘柄（プライム・スタンダード）を全件スキャンして各パターン最大100件収集する。
"""

import io
import json
import os
import time
import requests
import yfinance as yf
import pandas as pd

# ========== 設定 ==========
PERIOD = "5y"
QUIZ_CANDLES = 20       # クイズ部分のローソク足本数（固定）
ANSWER_DAYS = 20        # 答え部分のローソク足本数
MIN_CONFIRM_DAYS = 5    # 方向確認に使う日数
MIN_MOVE_PCT = 0.02     # 確認に使う最低変動率（2%）
MAX_EXAMPLES = 100      # パターンごとの最大収集件数
MAX_PER_TICKER = 2      # 同一銘柄から1パターンで取る最大件数
MIN_OVERLAP_DAYS = 30   # 同一銘柄で重複を避ける最小間隔（日）
BATCH_SIZE = 100
OUTPUT_DIR = "SakataChartQuiz/patterns"

JPX_LIST_URL = "https://www.jpx.co.jp/markets/statistics-equities/misc/tvdivq0000001vg2-att/data_j.xls"
MARKETS = ["プライム（内国株式）", "スタンダード（内国株式）"]
# ==========================


# ─────────────────────────────
#  パターン検出関数（末尾インデックスのリストを返す）
# ─────────────────────────────

def detect_sansenpei(df):
    """赤三兵: 3本連続陽線、終値が順に上昇"""
    o, c = df["Open"].values, df["Close"].values
    return [i for i in range(2, len(df))
            if c[i] > o[i] and c[i-1] > o[i-1] and c[i-2] > o[i-2]
            and c[i] > c[i-1] > c[i-2]]


def detect_sankrasu(df):
    """三羽烏: 3本連続陰線、終値が順に下降"""
    o, c = df["Open"].values, df["Close"].values
    return [i for i in range(2, len(df))
            if c[i] < o[i] and c[i-1] < o[i-1] and c[i-2] < o[i-2]
            and c[i] < c[i-1] < c[i-2]]


def detect_morning_star(df):
    """明けの明星: 大陰線→小実体→大陽線（Day3がDay1の中間以上まで戻す）"""
    o, c = df["Open"].values, df["Close"].values
    result = []
    for i in range(2, len(df)):
        b1 = abs(c[i-2] - o[i-2])
        b2 = abs(c[i-1] - o[i-1])
        b3 = abs(c[i] - o[i])
        if b1 == 0 or b3 == 0:
            continue
        avg = (b1 + b3) / 2
        if (c[i-2] < o[i-2] and b1 > avg * 0.5   # 大陰線
                and b2 < b1 * 0.4                  # 小実体
                and c[i] > o[i] and b3 > avg * 0.5 # 大陽線
                and c[i] > (o[i-2] + c[i-2]) / 2): # 中間以上回復
            result.append(i)
    return result


def detect_evening_star(df):
    """宵の明星: 大陽線→小実体→大陰線（Day3がDay1の中間以下まで下落）"""
    o, c = df["Open"].values, df["Close"].values
    result = []
    for i in range(2, len(df)):
        b1 = abs(c[i-2] - o[i-2])
        b2 = abs(c[i-1] - o[i-1])
        b3 = abs(c[i] - o[i])
        if b1 == 0 or b3 == 0:
            continue
        avg = (b1 + b3) / 2
        if (c[i-2] > o[i-2] and b1 > avg * 0.5   # 大陽線
                and b2 < b1 * 0.4                  # 小実体
                and c[i] < o[i] and b3 > avg * 0.5 # 大陰線
                and c[i] < (o[i-2] + c[i-2]) / 2): # 中間以下下落
            result.append(i)
    return result


def detect_bullish_engulfing(df):
    """包み足陽線: 陰線→その実体を完全に包む陽線"""
    o, c = df["Open"].values, df["Close"].values
    return [i for i in range(1, len(df))
            if c[i-1] < o[i-1]                    # 前日陰線
            and c[i] > o[i]                        # 当日陽線
            and o[i] <= c[i-1] and c[i] >= o[i-1]] # 包み込み


def detect_bearish_engulfing(df):
    """包み足陰線: 陽線→その実体を完全に包む陰線"""
    o, c = df["Open"].values, df["Close"].values
    return [i for i in range(1, len(df))
            if c[i-1] > o[i-1]
            and c[i] < o[i]
            and o[i] >= c[i-1] and c[i] <= o[i-1]]


def detect_bullish_harami(df):
    """はらみ足陽線: 大陰線の実体に収まる小陽線"""
    o, c = df["Open"].values, df["Close"].values
    return [i for i in range(1, len(df))
            if c[i-1] < o[i-1]                     # 前日大陰線
            and c[i] > o[i]                         # 当日陽線
            and o[i] > c[i-1] and c[i] < o[i-1]    # 前日実体内に収まる
            and abs(c[i] - o[i]) < abs(c[i-1] - o[i-1]) * 0.5]


def detect_bearish_harami(df):
    """はらみ足陰線: 大陽線の実体に収まる小陰線"""
    o, c = df["Open"].values, df["Close"].values
    return [i for i in range(1, len(df))
            if c[i-1] > o[i-1]
            and c[i] < o[i]
            and o[i] < c[i-1] and c[i] > o[i-1]
            and abs(c[i] - o[i]) < abs(c[i-1] - o[i-1]) * 0.5]


# ─────────────────────────────
#  方向確認・ユーティリティ
# ─────────────────────────────

def confirmed_rise(df, end_idx):
    base = float(df["Close"].iloc[end_idx])
    future = df["Close"].iloc[end_idx + 1: end_idx + 1 + MIN_CONFIRM_DAYS]
    return not future.empty and float(future.max()) >= base * (1 + MIN_MOVE_PCT)


def confirmed_fall(df, end_idx):
    base = float(df["Close"].iloc[end_idx])
    future = df["Close"].iloc[end_idx + 1: end_idx + 1 + MIN_CONFIRM_DAYS]
    return not future.empty and float(future.min()) <= base * (1 - MIN_MOVE_PCT)


def to_candles(df):
    return [
        {
            "date": ts.strftime("%Y-%m-%d"),
            "open": round(float(row["Open"]), 2),
            "high": round(float(row["High"]), 2),
            "low": round(float(row["Low"]), 2),
            "close": round(float(row["Close"]), 2),
            "volume": int(row["Volume"]),
        }
        for ts, row in df.iterrows()
    ]


def build_example(df, ticker, name, end_idx):
    start = end_idx - QUIZ_CANDLES + 1
    ans_end = end_idx + 1 + ANSWER_DAYS
    if start < 0 or ans_end > len(df):
        return None
    date_str = df.index[end_idx].strftime("%Y-%m-%d")
    return {
        "id": f"{ticker.replace('.T', '')}_{date_str}",
        "ticker": ticker.replace(".T", ""),
        "name": name,
        "quiz_candles": to_candles(df.iloc[start:end_idx + 1]),
        "answer_candles": to_candles(df.iloc[end_idx + 1:ans_end]),
    }


# ─────────────────────────────
#  パターン定義
# ─────────────────────────────

PATTERNS = [
    {
        "name": "赤三兵",
        "direction": "bullish",
        "description": "3本連続して陽線が並び、終値が順に上昇。上昇継続のサイン。",
        "detect": detect_sansenpei,
        "confirm": confirmed_rise,
    },
    {
        "name": "三羽烏",
        "direction": "bearish",
        "description": "3本連続して陰線が並び、終値が順に下降。下落継続のサイン。",
        "detect": detect_sankrasu,
        "confirm": confirmed_fall,
    },
    {
        "name": "明けの明星",
        "direction": "bullish",
        "description": "大陰線・小実体・大陽線の3本組合せ。底打ちからの上昇転換サイン。",
        "detect": detect_morning_star,
        "confirm": confirmed_rise,
    },
    {
        "name": "宵の明星",
        "direction": "bearish",
        "description": "大陽線・小実体・大陰線の3本組合せ。天井からの下落転換サイン。",
        "detect": detect_evening_star,
        "confirm": confirmed_fall,
    },
    {
        "name": "包み足陽線",
        "direction": "bullish",
        "description": "前日の陰線を今日の陽線が完全に包み込む。強い買い圧力を示す上昇転換サイン。",
        "detect": detect_bullish_engulfing,
        "confirm": confirmed_rise,
    },
    {
        "name": "包み足陰線",
        "direction": "bearish",
        "description": "前日の陽線を今日の陰線が完全に包み込む。強い売り圧力を示す下落転換サイン。",
        "detect": detect_bearish_engulfing,
        "confirm": confirmed_fall,
    },
    {
        "name": "はらみ足陽線",
        "direction": "bullish",
        "description": "大陰線の実体内に小陽線が収まる。売り勢力の弱まりを示す反転サイン。",
        "detect": detect_bullish_harami,
        "confirm": confirmed_rise,
    },
    {
        "name": "はらみ足陰線",
        "direction": "bearish",
        "description": "大陽線の実体内に小陰線が収まる。買い勢力の弱まりを示す反転サイン。",
        "detect": detect_bearish_harami,
        "confirm": confirmed_fall,
    },
]


# ─────────────────────────────
#  銘柄一覧取得
# ─────────────────────────────

def get_ticker_list():
    print("JPXから銘柄一覧を取得中...")
    resp = requests.get(JPX_LIST_URL, timeout=60)
    resp.raise_for_status()
    df = pd.read_excel(io.BytesIO(resp.content))
    df.columns = [str(c).strip() for c in df.columns]
    df = df[df["市場・商品区分"].isin(MARKETS)]
    if "規模区分" in df.columns:
        df = df[df["規模区分"] != "小型株"]
    df["コード"] = df["コード"].astype(str).str.strip()
    df["ticker"] = df["コード"] + ".T"
    name_map = dict(zip(df["ticker"], df["銘柄名"]))
    print(f"対象銘柄数: {len(df)}")
    return df["ticker"].tolist(), name_map


# ─────────────────────────────
#  メイン
# ─────────────────────────────

def main():
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    tickers, name_map = get_ticker_list()

    # パターンごとの収集状態を管理
    buckets = {p["name"]: [] for p in PATTERNS}
    seen = {p["name"]: {} for p in PATTERNS}  # {pattern_name: {ticker: [dates]}}

    def all_full():
        return all(len(buckets[p["name"]]) >= MAX_EXAMPLES for p in PATTERNS)

    for i in range(0, len(tickers), BATCH_SIZE):
        if all_full():
            break
        batch = tickers[i:i + BATCH_SIZE]
        print(f"\nバッチ {i + 1}〜{min(i + BATCH_SIZE, len(tickers))} / {len(tickers)} 取得中...")
        try:
            raw = yf.download(batch, period=PERIOD, interval="1d",
                              group_by="ticker", auto_adjust=False,
                              threads=True, progress=False)
        except Exception as e:
            print(f"  取得失敗: {e}")
            time.sleep(2)
            continue

        for ticker in batch:
            try:
                df = raw[ticker] if len(batch) > 1 else raw
                if isinstance(df.columns, pd.MultiIndex):
                    df.columns = df.columns.get_level_values(0)
                df = df.dropna(subset=["Open", "High", "Low", "Close", "Volume"])
                if len(df) < QUIZ_CANDLES + ANSWER_DAYS + 10:
                    continue
            except Exception:
                continue

            name = name_map.get(ticker, ticker)

            for pat in PATTERNS:
                pname = pat["name"]
                if len(buckets[pname]) >= MAX_EXAMPLES:
                    continue

                if ticker not in seen[pname]:
                    seen[pname][ticker] = []

                for idx in pat["detect"](df):
                    if len(buckets[pname]) >= MAX_EXAMPLES:
                        break
                    date_str = df.index[idx].strftime("%Y-%m-%d")

                    # 同一銘柄の上限チェック
                    if len(seen[pname][ticker]) >= MAX_PER_TICKER:
                        break

                    # 同一銘柄の直近パターンと重複しないかチェック
                    overlap = any(
                        abs((pd.Timestamp(date_str) - pd.Timestamp(d)).days) < MIN_OVERLAP_DAYS
                        for d in seen[pname][ticker]
                    )
                    if overlap:
                        continue

                    if not pat["confirm"](df, idx):
                        continue

                    ex = build_example(df, ticker, name, idx)
                    if ex:
                        buckets[pname].append(ex)
                        seen[pname][ticker].append(date_str)

        time.sleep(1)

        # 進捗表示
        for pat in PATTERNS:
            pname = pat["name"]
            print(f"  {pname}: {len(buckets[pname])} 件")

    # JSON書き出し
    print("\n=== 書き出し ===")
    for pat in PATTERNS:
        pname = pat["name"]
        output = {
            "pattern": pname,
            "direction": pat["direction"],
            "description": pat["description"],
            "examples": buckets[pname],
        }
        out_path = os.path.join(OUTPUT_DIR, f"{pname}.json")
        with open(out_path, "w", encoding="utf-8") as f:
            json.dump(output, f, ensure_ascii=False, indent=2)
        print(f"  {out_path}: {len(buckets[pname])} 件")


if __name__ == "__main__":
    main()

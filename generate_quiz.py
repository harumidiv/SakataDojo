# -*- coding: utf-8 -*-
"""
酒田五法クイズ用JSONデータ生成スクリプト
検証用：トヨタ(7203.T)で赤三兵を検出してJSONに書き出す
"""

import json
import os
import time
import yfinance as yf
import pandas as pd
from datetime import timedelta

# ========== 設定 ==========
TICKER = "7203.T"
NAME = "トヨタ自動車"
PERIOD = "5y"           # 取得期間
CONTEXT_BEFORE = 20     # パターン前に含めるローソク足本数（約1ヶ月）
ANSWER_DAYS = 20        # その後何日分を正解チャートとして持つか（約1ヶ月）
MIN_CONFIRM_DAYS = 5    # 上昇確認に使う日数
MIN_RISE_PCT = 0.02     # 上昇確認の最低騰落率（2%）
OUTPUT_DIR = "patterns"
# ==========================


def fetch_ohlcv(ticker: str) -> pd.DataFrame:
    print(f"{ticker} のデータ取得中...")
    df = yf.download(ticker, period=PERIOD, interval="1d",
                     auto_adjust=False, progress=False)
    if isinstance(df.columns, pd.MultiIndex):
        df.columns = df.columns.get_level_values(0)
    df = df.dropna(subset=["Open", "High", "Low", "Close", "Volume"])
    print(f"  {len(df)} 行取得")
    return df


def to_candles(df: pd.DataFrame) -> list[dict]:
    rows = []
    for ts, row in df.iterrows():
        rows.append({
            "date": ts.strftime("%Y-%m-%d"),
            "open": round(float(row["Open"]), 2),
            "high": round(float(row["High"]), 2),
            "low": round(float(row["Low"]), 2),
            "close": round(float(row["Close"]), 2),
            "volume": int(row["Volume"]),
        })
    return rows


def detect_sansenpei(df: pd.DataFrame) -> list[int]:
    """赤三兵（連続3本陽線）のパターン末尾インデックスを返す"""
    indices = []
    closes = df["Close"].values
    opens = df["Open"].values
    for i in range(2, len(df)):
        bullish = all(closes[i - k] > opens[i - k] for k in range(3))
        ascending = closes[i] > closes[i - 1] > closes[i - 2]
        if bullish and ascending:
            indices.append(i)
    return indices


def confirmed_bullish(df: pd.DataFrame, pattern_end_idx: int) -> bool:
    """パターン後 MIN_CONFIRM_DAYS 日以内に MIN_RISE_PCT 以上上昇したか確認"""
    base = float(df["Close"].iloc[pattern_end_idx])
    end = min(pattern_end_idx + MIN_CONFIRM_DAYS + 1, len(df))
    future = df["Close"].iloc[pattern_end_idx + 1:end]
    if future.empty:
        return False
    return float(future.max()) >= base * (1 + MIN_RISE_PCT)


def build_example(df: pd.DataFrame, pattern_end_idx: int, example_id: str):
    start = pattern_end_idx - 2 - CONTEXT_BEFORE  # 赤三兵3本 + 前文脈
    if start < 0:
        return None
    ans_end = pattern_end_idx + 1 + ANSWER_DAYS
    if ans_end > len(df):
        return None

    quiz_df = df.iloc[start:pattern_end_idx + 1]
    answer_df = df.iloc[pattern_end_idx + 1:ans_end]

    return {
        "id": example_id,
        "ticker": TICKER.replace(".T", ""),
        "name": NAME,
        "quiz_candles": to_candles(quiz_df),
        "answer_candles": to_candles(answer_df),
    }


def main():
    df = fetch_ohlcv(TICKER)
    pattern_indices = detect_sansenpei(df)
    print(f"赤三兵 候補: {len(pattern_indices)} 件")

    examples = []
    seen_dates = set()
    for idx in pattern_indices:
        date_str = df.index[idx].strftime("%Y-%m-%d")

        # 直近パターンと重複しないようにスキップ（30営業日以内は除外）
        skip = any(
            abs((pd.Timestamp(date_str) - pd.Timestamp(d)).days) < 30
            for d in seen_dates
        )
        if skip:
            continue

        if not confirmed_bullish(df, idx):
            continue

        example_id = f"{TICKER.replace('.T', '')}_{date_str}"
        ex = build_example(df, idx, example_id)
        if ex:
            examples.append(ex)
            seen_dates.add(date_str)

    print(f"成功例（上昇確認済み）: {len(examples)} 件")

    os.makedirs(OUTPUT_DIR, exist_ok=True)
    output = {
        "pattern": "赤三兵",
        "direction": "bullish",
        "description": "3本連続して陽線が並び、それぞれ前日終値より高く始まり高く終わる。上昇継続のサイン。",
        "examples": examples,
    }
    out_path = os.path.join(OUTPUT_DIR, "赤三兵.json")
    with open(out_path, "w", encoding="utf-8") as f:
        json.dump(output, f, ensure_ascii=False, indent=2)
    print(f"書き出し完了: {out_path}  ({len(examples)} 件)")


if __name__ == "__main__":
    main()

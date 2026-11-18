# -*- coding: utf-8 -*-
"""
酒田五法クイズ用JSONデータ生成スクリプト（全42パターン対応版）
JPX上場銘柄（プライム・スタンダード）を全件スキャンして各パターン最大500件収集する。
"""

import argparse
import io
import json
import os
import time
import requests
import yfinance as yf
import pandas as pd

# ========== 設定 ==========
PERIOD = "10y"
QUIZ_CANDLES = 20
ANSWER_DAYS = 20
MIN_CONFIRM_DAYS = 5
MIN_MOVE_PCT = 0.02
MAX_EXAMPLES = 500
MAX_PER_TICKER = 5
MIN_OVERLAP_DAYS = 30
BATCH_SIZE = 100
OUTPUT_DIR = "SakataChartQuiz/patterns"
MIN_PRICE = 200       # quiz期間の平均終値がこれ未満の銘柄を除外（円）
MIN_RANGE_PCT = 0.03  # quiz期間の高値-安値がこれ未満の銘柄を除外（平均終値比）
MIN_DAILY_TURNOVER = 100_000_000  # パターン成立日の概算売買代金（終値×出来高、円）
HEAD_SHOULDERS_LOOKBACK = 35      # 三尊・逆三尊の山（谷）を探す範囲（本）
HEAD_SHOULDERS_QUIZ_CANDLES = 40  # 三尊・逆三尊は形が長いので出題チャートを長めにする

JPX_LIST_URL = "https://www.jpx.co.jp/markets/statistics-equities/misc/tvdivq0000001vg2-att/data_j.xlsx"
MARKETS = ["プライム（内国株式）", "スタンダード（内国株式）"]
# ==========================


# ─────────────────────────────
#  トレンド判定ヘルパー
# ─────────────────────────────

def is_uptrend(closes, idx, n=10):
    return idx >= n and closes[idx] > closes[idx - n] * 1.02

def is_downtrend(closes, idx, n=10):
    return idx >= n and closes[idx] < closes[idx - n] * 0.98


# ─────────────────────────────
#  単体足ヘルパー
# ─────────────────────────────

def _body(o, c):       return abs(c - o)
def _upper(o, h, c):   return h - max(o, c)
def _lower(o, l, c):   return min(o, c) - l
def _range(h, l):      return h - l

def _is_hammer_shape(o, h, l, c):
    """下ヒゲ長い（カラカサ/首吊り型）"""
    b, ls, us, tr = _body(o, c), _lower(o, l, c), _upper(o, h, c), _range(h, l)
    if tr == 0 or b == 0: return False
    return ls >= b * 2.0 and us <= b * 0.5

def _is_inverted_hammer_shape(o, h, l, c):
    """上ヒゲ長い（トンカチ/流れ星型）"""
    b, us, ls, tr = _body(o, c), _upper(o, h, c), _lower(o, l, c), _range(h, l)
    if tr == 0 or b == 0: return False
    return us >= b * 2.0 and ls <= b * 0.5


# ─────────────────────────────
#  パターン検出関数
# ─────────────────────────────

def detect_sansenpei(df):
    """赤三兵: 3本連続陽線、終値が順に上昇"""
    o, c = df["Open"].values, df["Close"].values
    return [i for i in range(2, len(df))
            if c[i]>o[i] and c[i-1]>o[i-1] and c[i-2]>o[i-2]
            and c[i]>c[i-1]>c[i-2]]

def detect_sankrasu(df):
    """三羽烏: 3本連続陰線、終値が順に下降"""
    o, c = df["Open"].values, df["Close"].values
    return [i for i in range(2, len(df))
            if c[i]<o[i] and c[i-1]<o[i-1] and c[i-2]<o[i-2]
            and c[i]<c[i-1]<c[i-2]]

def detect_morning_star(df):
    """明けの明星: 大陰線→小実体→大陽線（中間以上回復）"""
    o, c = df["Open"].values, df["Close"].values
    result = []
    for i in range(2, len(df)):
        b1,b2,b3 = _body(o[i-2],c[i-2]), _body(o[i-1],c[i-1]), _body(o[i],c[i])
        if b1==0 or b3==0: continue
        avg = (b1+b3)/2
        if (c[i-2]<o[i-2] and b1>avg*0.5
                and b2<b1*0.4
                and c[i]>o[i] and b3>avg*0.5
                and c[i]>(o[i-2]+c[i-2])/2):
            result.append(i)
    return result

def detect_evening_star(df):
    """宵の明星: 大陽線→小実体→大陰線（中間以下下落）"""
    o, c = df["Open"].values, df["Close"].values
    result = []
    for i in range(2, len(df)):
        b1,b2,b3 = _body(o[i-2],c[i-2]), _body(o[i-1],c[i-1]), _body(o[i],c[i])
        if b1==0 or b3==0: continue
        avg = (b1+b3)/2
        if (c[i-2]>o[i-2] and b1>avg*0.5
                and b2<b1*0.4
                and c[i]<o[i] and b3>avg*0.5
                and c[i]<(o[i-2]+c[i-2])/2):
            result.append(i)
    return result

def detect_yang_tasuki(df):
    """上放れタスキ: ギャップアップ後2本陽線→陰線がギャップを埋めきれない（上昇継続）"""
    o, h, l, c = df["Open"].values, df["High"].values, df["Low"].values, df["Close"].values
    result = []
    for i in range(2, len(df)):
        if c[i-2]<=o[i-2]: continue           # Day1 陽線
        if o[i-1]<=h[i-2]: continue           # Day2 ギャップアップ
        if c[i-1]<=o[i-1]: continue           # Day2 陽線
        if c[i]>=o[i]: continue               # Day3 陰線
        if o[i]<c[i-1] and o[i]>o[i-1] and c[i]>c[i-2]:
            result.append(i)
    return result

def detect_yin_tasuki(df):
    """下放れタスキ: ギャップダウン後2本陰線→陽線がギャップを埋めきれない（下降継続）"""
    o, h, l, c = df["Open"].values, df["High"].values, df["Low"].values, df["Close"].values
    result = []
    for i in range(2, len(df)):
        if c[i-2]>=o[i-2]: continue           # Day1 陰線
        if o[i-1]>=l[i-2]: continue           # Day2 ギャップダウン
        if c[i-1]>=o[i-1]: continue           # Day2 陰線
        if c[i]<=o[i]: continue               # Day3 陽線
        if o[i]>c[i-1] and o[i]<o[i-1] and c[i]<c[i-2]:
            result.append(i)
    return result

def detect_stalling(df):
    """赤三兵思案星: 上昇中の3本陽線で3本目の実体が極小（上昇の失速）"""
    o, c = df["Open"].values, df["Close"].values
    result = []
    for i in range(12, len(df)):
        if not is_uptrend(c, i): continue
        if not (c[i]>o[i] and c[i-1]>o[i-1] and c[i-2]>o[i-2]): continue
        b1,b2,b3 = _body(o[i-2],c[i-2]), _body(o[i-1],c[i-1]), _body(o[i],c[i])
        avg = (b1+b2)/2
        if avg>0 and b3<avg*0.35:
            result.append(i)
    return result

def detect_bullish_engulfing(df):
    """陽の包み線: 陰線→その実体を完全に包む大陽線"""
    o, c = df["Open"].values, df["Close"].values
    return [i for i in range(1, len(df))
            if c[i-1]<o[i-1] and c[i]>o[i]
            and o[i]<=c[i-1] and c[i]>=o[i-1]]

def detect_bearish_engulfing(df):
    """陰の包み線: 陽線→その実体を完全に包む大陰線"""
    o, c = df["Open"].values, df["Close"].values
    return [i for i in range(1, len(df))
            if c[i-1]>o[i-1] and c[i]<o[i]
            and o[i]>=c[i-1] and c[i]<=o[i-1]]

def detect_bullish_harami(df):
    """陽のはらみ線: 大陰線の実体内に収まる小陽線"""
    o, c = df["Open"].values, df["Close"].values
    return [i for i in range(1, len(df))
            if c[i-1]<o[i-1] and c[i]>o[i]
            and o[i]>c[i-1] and c[i]<o[i-1]
            and _body(o[i],c[i])<_body(o[i-1],c[i-1])*0.5]

def detect_bearish_harami(df):
    """陰のはらみ線: 大陽線の実体内に収まる小陰線"""
    o, c = df["Open"].values, df["Close"].values
    return [i for i in range(1, len(df))
            if c[i-1]>o[i-1] and c[i]<o[i]
            and o[i]<c[i-1] and c[i]>o[i-1]
            and _body(o[i],c[i])<_body(o[i-1],c[i-1])*0.5]

def detect_piercing_line(df):
    """切り込み線: 陰線→低く始まって陰線の半値以上まで戻す陽線"""
    o, l, c = df["Open"].values, df["Low"].values, df["Close"].values
    result = []
    for i in range(1, len(df)):
        if c[i-1]>=o[i-1]: continue   # 前日陰線
        if c[i]<=o[i]: continue       # 当日陽線
        midpoint = (o[i-1]+c[i-1])/2
        if o[i]<l[i-1] and c[i]>midpoint and c[i]<o[i-1]:
            result.append(i)
    return result

def detect_dark_cloud_cover(df):
    """かぶせ線: 陽線→高く始まって陽線の半値以下まで食い込む陰線"""
    o, h, c = df["Open"].values, df["High"].values, df["Close"].values
    result = []
    for i in range(1, len(df)):
        if c[i-1]<=o[i-1]: continue   # 前日陽線
        if c[i]>=o[i]: continue       # 当日陰線
        midpoint = (o[i-1]+c[i-1])/2
        if o[i]>h[i-1] and c[i]<midpoint and c[i]>o[i-1]:
            result.append(i)
    return result

def detect_tweezers_bottom(df):
    """毛抜き底: 2本の安値がほぼ同じで下降トレンド後"""
    o, l, c = df["Open"].values, df["Low"].values, df["Close"].values
    result = []
    for i in range(11, len(df)):
        if not is_downtrend(c, i): continue
        if l[i]>0 and abs(l[i]-l[i-1])/l[i] <= 0.003:
            result.append(i)
    return result

def detect_tweezers_top(df):
    """毛抜き天井: 2本の高値がほぼ同じで上昇トレンド後"""
    o, h, c = df["Open"].values, df["High"].values, df["Close"].values
    result = []
    for i in range(11, len(df)):
        if not is_uptrend(c, i): continue
        if h[i]>0 and abs(h[i]-h[i-1])/h[i] <= 0.003:
            result.append(i)
    return result

def detect_last_engulfing_bull(df):
    """最後の抱き陽線: 上昇トレンド末期に小陰線を大陽線が包む（売り転換）"""
    o, c = df["Open"].values, df["Close"].values
    result = []
    for i in range(11, len(df)):
        if not is_uptrend(c, i): continue
        if c[i-1]>=o[i-1] or c[i]<=o[i]: continue
        if not (o[i]<=c[i-1] and c[i]>=o[i-1]): continue
        if c[i]>0 and _body(o[i],c[i])/c[i]>=0.02:
            result.append(i)
    return result

def detect_last_engulfing_bear(df):
    """最後の抱き陰線: 下降トレンド末期に小陽線を大陰線が包む（買い転換）"""
    o, c = df["Open"].values, df["Close"].values
    result = []
    for i in range(11, len(df)):
        if not is_downtrend(c, i): continue
        if c[i-1]<=o[i-1] or c[i]>=o[i]: continue
        if not (o[i]>=c[i-1] and c[i]<=o[i-1]): continue
        if c[i]>0 and _body(o[i],c[i])/c[i]>=0.02:
            result.append(i)
    return result

def detect_hammer(df):
    """カラカサ/たくり線: 下降トレンド後の下ヒゲ長い足 → 買い"""
    o, h, l, c = df["Open"].values, df["High"].values, df["Low"].values, df["Close"].values
    return [i for i in range(10, len(df))
            if _is_hammer_shape(o[i],h[i],l[i],c[i]) and is_downtrend(c, i)]

def detect_hanging_man(df):
    """首吊り線: 上昇トレンド後の下ヒゲ長い足 → 売り"""
    o, h, l, c = df["Open"].values, df["High"].values, df["Low"].values, df["Close"].values
    return [i for i in range(10, len(df))
            if _is_hammer_shape(o[i],h[i],l[i],c[i]) and is_uptrend(c, i)]

def detect_shooting_star(df):
    """流れ星: 上昇トレンド後の上ヒゲ長い足 → 売り"""
    o, h, l, c = df["Open"].values, df["High"].values, df["Low"].values, df["Close"].values
    return [i for i in range(10, len(df))
            if _is_inverted_hammer_shape(o[i],h[i],l[i],c[i]) and is_uptrend(c, i)]

def detect_tonbo(df):
    """トンボ: 下降トレンド後の下ヒゲのみの十字線 → 買い"""
    o, h, l, c = df["Open"].values, df["High"].values, df["Low"].values, df["Close"].values
    result = []
    for i in range(10, len(df)):
        if not is_downtrend(c, i): continue
        tr = _range(h[i], l[i])
        if tr == 0: continue
        b  = _body(o[i], c[i])
        us = _upper(o[i], h[i], c[i])
        ls = _lower(o[i], l[i], c[i])
        if b/tr<=0.1 and ls>=tr*0.6 and us<=tr*0.1:
            result.append(i)
    return result

def detect_gravestone(df):
    """塔婆/トウバ: 上昇トレンド後の上ヒゲのみの十字線 → 売り"""
    o, h, l, c = df["Open"].values, df["High"].values, df["Low"].values, df["Close"].values
    result = []
    for i in range(10, len(df)):
        if not is_uptrend(c, i): continue
        tr = _range(h[i], l[i])
        if tr == 0: continue
        b  = _body(o[i], c[i])
        us = _upper(o[i], h[i], c[i])
        ls = _lower(o[i], l[i], c[i])
        if b/tr<=0.1 and us>=tr*0.6 and ls<=tr*0.1:
            result.append(i)
    return result


def detect_uwabanaare_narabiari(df):
    """上放れ並び赤: ギャップアップ後に似た大きさの陽線2本が並ぶ（上昇継続）"""
    o, h, c = df["Open"].values, df["High"].values, df["Close"].values
    result = []
    for i in range(2, len(df)):
        if not is_uptrend(c, i-2): continue
        if o[i-1] <= h[i-2]: continue          # Day2 ギャップアップ
        if c[i-1] <= o[i-1]: continue          # Day2 陽線
        if c[i] <= o[i]: continue              # Day3 陽線
        b2, b3 = _body(o[i-1],c[i-1]), _body(o[i],c[i])
        if b2 == 0: continue
        if 0.7 <= b3/b2 <= 1.3 and o[i] >= o[i-1]*0.99:
            result.append(i)
    return result

def detect_uwabanaare_narabikuro(df):
    """上放れ並び黒: 上昇途中のギャップアップ後に似た大きさの陰線2本（押し目候補）"""
    o, h, c = df["Open"].values, df["High"].values, df["Close"].values
    result = []
    for i in range(2, len(df)):
        if not is_uptrend(c, i-2): continue
        if o[i-1] <= h[i-2]: continue          # Day2 ギャップアップ
        if c[i-1] >= o[i-1]: continue          # Day2 陰線
        if c[i] >= o[i]: continue              # Day3 陰線
        b2, b3 = _body(o[i-1],c[i-1]), _body(o[i],c[i])
        if b2 == 0: continue
        if 0.7 <= b3/b2 <= 1.3 and o[i] >= o[i-1]*0.99:
            result.append(i)
    return result

def detect_uwabanaare_juji(df):
    """上放れの星: 上昇トレンド中のギャップアップ後に十字線（天井転換警戒）"""
    o, h, l, c = df["Open"].values, df["High"].values, df["Low"].values, df["Close"].values
    result = []
    for i in range(10, len(df)):
        if not is_uptrend(c, i): continue
        if o[i] <= h[i-1]: continue            # ギャップアップ
        tr = _range(h[i], l[i])
        if tr == 0: continue
        if _body(o[i], c[i]) / tr <= 0.1:
            result.append(i)
    return result

def detect_sankuu_uwa(df):
    """上放れ三手放れ寄せ線: 3回連続ギャップアップ後に小実体（天井サイン）"""
    o, h, l, c = df["Open"].values, df["High"].values, df["Low"].values, df["Close"].values
    result = []
    for i in range(3, len(df)):
        if not (o[i-2]>h[i-3] and o[i-1]>h[i-2] and o[i]>h[i-1]): continue
        tr = _range(h[i], l[i])
        if tr == 0: continue
        if _body(o[i], c[i]) / tr <= 0.25:
            result.append(i)
    return result

def detect_sagari_narabiari(df):
    """下放れ並び赤: ギャップダウン後に陽線2本（ギャップが戻り抵抗→下落継続）"""
    o, l, c = df["Open"].values, df["Low"].values, df["Close"].values
    result = []
    for i in range(2, len(df)):
        if o[i-1] >= l[i-2]: continue          # Day2 ギャップダウン
        if c[i-1] <= o[i-1]: continue          # Day2 陽線
        if c[i] <= o[i]: continue              # Day3 陽線
        b2, b3 = _body(o[i-1],c[i-1]), _body(o[i],c[i])
        if b2 == 0: continue
        if 0.7 <= b3/b2 <= 1.3 and o[i] <= o[i-1]*1.01:
            result.append(i)
    return result

def detect_sagari_kuro2(df):
    """下放れ二本黒: ギャップダウン後に陰線2本（売り継続）"""
    o, l, c = df["Open"].values, df["Low"].values, df["Close"].values
    result = []
    for i in range(2, len(df)):
        if o[i-1] >= l[i-2]: continue          # Day2 ギャップダウン
        if c[i-1] >= o[i-1]: continue          # Day2 陰線
        if c[i] >= o[i]: continue              # Day3 陰線
        b2, b3 = _body(o[i-1],c[i-1]), _body(o[i],c[i])
        if b2 == 0: continue
        if 0.7 <= b3/b2 <= 1.3:
            result.append(i)
    return result

def detect_sagari_juji(df):
    """下放れの星: 下降トレンド中のギャップダウン後に十字線（底値転換警戒）"""
    o, h, l, c = df["Open"].values, df["High"].values, df["Low"].values, df["Close"].values
    result = []
    for i in range(10, len(df)):
        if not is_downtrend(c, i): continue
        if o[i] >= l[i-1]: continue            # ギャップダウン
        tr = _range(h[i], l[i])
        if tr == 0: continue
        if _body(o[i], c[i]) / tr <= 0.1:
            result.append(i)
    return result

def detect_sankuu_shita(df):
    """下放れ三手放れ寄せ線: 3回連続ギャップダウン後に小実体（買いサイン）"""
    o, h, l, c = df["Open"].values, df["High"].values, df["Low"].values, df["Close"].values
    result = []
    for i in range(3, len(df)):
        if not (o[i-2]<l[i-3] and o[i-1]<l[i-2] and o[i]<l[i-1]): continue
        tr = _range(h[i], l[i])
        if tr == 0: continue
        if _body(o[i], c[i]) / tr <= 0.25:
            result.append(i)
    return result


# ─────────────────────────────
#  追加パターン
# ─────────────────────────────

def detect_inverted_hammer(df):
    """トンカチ: 下降トレンド後の上ヒゲ長い小実体 → 買い"""
    o, h, l, c = df["Open"].values, df["High"].values, df["Low"].values, df["Close"].values
    return [i for i in range(10, len(df))
            if _is_inverted_hammer_shape(o[i],h[i],l[i],c[i]) and is_downtrend(c, i)]


def _swing_points(values, w, kind):
    """前後w本の中で最大（最小）になる足のインデックス"""
    result = []
    for k in range(w, len(values) - w):
        seg = values[k-w:k+w+1]
        if (kind == "max" and values[k] == seg.max()) or (kind == "min" and values[k] == seg.min()):
            result.append(k)
    return result


def _detect_three_peaks(df, inverse):
    """三尊（inverse=Falseで天井、Trueで逆三尊）: 直近3つの山（谷）の中央が最も高く（深く）、
    ネックラインを終値で抜けた日をシグナルとする"""
    import bisect
    h, l, c = df["High"].values, df["Low"].values, df["Close"].values
    W = 3
    extremes = _swing_points(l if inverse else h, W, "min" if inverse else "max")
    values = l if inverse else h
    result = []
    for i in range(30, len(df)):
        # 判定日までに確定している山（谷）だけを使う
        usable = extremes[:bisect.bisect_right(extremes, i - 1 - W)]
        usable = [k for k in usable if k >= i - HEAD_SHOULDERS_LOOKBACK]
        if len(usable) < 3:
            continue
        p1, p2, p3 = usable[-3:]
        if p2 - p1 < 3 or p3 - p2 < 3:
            continue
        v1, v2, v3 = values[p1], values[p2], values[p3]
        if inverse:
            if not (v2 < v1 * 0.98 and v2 < v3 * 0.98): continue
            neck = max(h[p1:p2+1].max(), h[p2:p3+1].max())
            if abs(v1 - v3) / neck > 0.04: continue
            if (neck - v2) / neck < 0.04: continue
            if not (c[i] > neck and c[i-1] <= neck): continue
            if c[p3+1:i].max(initial=0) > neck: continue
        else:
            if not (v2 > v1 * 1.02 and v2 > v3 * 1.02): continue
            neck = min(l[p1:p2+1].min(), l[p2:p3+1].min())
            if abs(v1 - v3) / v2 > 0.04: continue
            if (v2 - neck) / v2 < 0.04: continue
            if not (c[i] < neck and c[i-1] >= neck): continue
            if c[p3+1:i].min(initial=float("inf")) < neck: continue
        result.append(i)
    return result

def detect_head_and_shoulders(df):
    return _detect_three_peaks(df, inverse=False)

def detect_inverse_head_and_shoulders(df):
    return _detect_three_peaks(df, inverse=True)


def detect_three_gaps_up(df):
    """三空踏み上げ: 窓を開けた陽線が3回続く（寄せ線で終わるものは三手放れ寄せ線として除外）"""
    o, h, l, c = df["Open"].values, df["High"].values, df["Low"].values, df["Close"].values
    result = []
    for i in range(3, len(df)):
        if not (o[i-2]>h[i-3] and o[i-1]>h[i-2] and o[i]>h[i-1]): continue
        if not (c[i-2]>o[i-2] and c[i-1]>o[i-1] and c[i]>o[i]): continue
        tr = _range(h[i], l[i])
        if tr == 0 or _body(o[i], c[i]) / tr <= 0.25: continue
        result.append(i)
    return result

def detect_three_gaps_down(df):
    """三空叩き込み: 窓を開けた陰線が3回続く（寄せ線で終わるものは除外）"""
    o, h, l, c = df["Open"].values, df["High"].values, df["Low"].values, df["Close"].values
    result = []
    for i in range(3, len(df)):
        if not (o[i-2]<l[i-3] and o[i-1]<l[i-2] and o[i]<l[i-1]): continue
        if not (c[i-2]<o[i-2] and c[i-1]<o[i-1] and c[i]<o[i]): continue
        tr = _range(h[i], l[i])
        if tr == 0 or _body(o[i], c[i]) / tr <= 0.25: continue
        result.append(i)
    return result


def _detect_three_methods(df, rising):
    """上げ三法 / 下げ三法: 大きな足 → 値幅内の小さな足3本 → 同じ向きの足が1本目の終値を更新"""
    o, h, l, c = df["Open"].values, df["High"].values, df["Low"].values, df["Close"].values
    result = []
    for i in range(4, len(df)):
        k = i - 4
        b1 = _body(o[k], c[k])
        tr1 = _range(h[k], l[k])
        if tr1 == 0 or c[k] == 0: continue
        if rising and not c[k] > o[k]: continue
        if not rising and not c[k] < o[k]: continue
        if b1 / c[k] < 0.015 or b1 / tr1 < 0.5: continue
        middle = range(k+1, i)
        if any(h[m] > h[k] or l[m] < l[k] or _body(o[m], c[m]) > b1 * 0.6 for m in middle): continue
        counter = sum(1 for m in middle if (c[m] < o[m]) == rising)
        if counter < 1: continue
        if rising and not (c[i] > o[i] and c[i] > c[k]): continue
        if not rising and not (c[i] < o[i] and c[i] < c[k]): continue
        if _body(o[i], c[i]) < b1 * 0.5: continue
        result.append(i)
    return result

def detect_rising_three_methods(df):
    return _detect_three_methods(df, rising=True)

def detect_falling_three_methods(df):
    return _detect_three_methods(df, rising=False)


def detect_bullish_tasuki_line(df):
    """陽のたすき線: 下降中の陰線→前日実体内で寄り、前日高値を超えて引ける陽線"""
    o, h, c = df["Open"].values, df["High"].values, df["Close"].values
    result = []
    for i in range(11, len(df)):
        if not is_downtrend(c, i-1): continue
        if not (c[i-1] < o[i-1] and c[i] > o[i]): continue
        if c[i-1] == 0 or _body(o[i-1], c[i-1]) / c[i-1] < 0.01: continue
        if c[i-1] < o[i] < o[i-1] and c[i] > h[i-1]:
            result.append(i)
    return result

def detect_bearish_tasuki_line(df):
    """陰のたすき線: 上昇中の陽線→前日実体内で寄り、前日安値を下回って引ける陰線"""
    o, l, c = df["Open"].values, df["Low"].values, df["Close"].values
    result = []
    for i in range(11, len(df)):
        if not is_uptrend(c, i-1): continue
        if not (c[i-1] > o[i-1] and c[i] < o[i]): continue
        if c[i-1] == 0 or _body(o[i-1], c[i-1]) / c[i-1] < 0.01: continue
        if o[i-1] < o[i] < c[i-1] and c[i] < l[i-1]:
            result.append(i)
    return result


def _neck_line_candidates(df):
    """あて首・入り首・差し込み線の共通条件: 下降中の大陰線 → 前日安値より安く寄った陽線"""
    o, l, c = df["Open"].values, df["Low"].values, df["Close"].values
    for i in range(11, len(df)):
        if not is_downtrend(c, i-1): continue
        if not (c[i-1] < o[i-1] and c[i] > o[i]): continue
        if c[i-1] == 0 or _body(o[i-1], c[i-1]) / c[i-1] < 0.015: continue
        if o[i] >= l[i-1]: continue
        yield i

def detect_on_neck(df):
    """あて首線: 陽線が前日の安値付近までしか戻らない"""
    l, c = df["Low"].values, df["Close"].values
    return [i for i in _neck_line_candidates(df)
            if abs(c[i] - l[i-1]) <= l[i-1] * 0.003 and c[i] <= c[i-1]]

def detect_in_neck(df):
    """入り首線: 陽線が前日の終値をわずかに上回って引ける"""
    o, c = df["Open"].values, df["Close"].values
    return [i for i in _neck_line_candidates(df)
            if c[i-1] < c[i] <= c[i-1] + _body(o[i-1], c[i-1]) * 0.15]

def detect_thrusting(df):
    """差し込み線: 陽線が前日の実体に食い込むが、半値には届かない"""
    o, c = df["Open"].values, df["Close"].values
    result = []
    for i in _neck_line_candidates(df):
        b1 = _body(o[i-1], c[i-1])
        midpoint = (o[i-1] + c[i-1]) / 2
        if c[i-1] + b1 * 0.15 < c[i] < midpoint:
            result.append(i)
    return result


# ─────────────────────────────
#  方向確認
# ─────────────────────────────

def confirmed_rise(df, end_idx):
    base = float(df["Close"].iloc[end_idx])
    future = df["Close"].iloc[end_idx+1 : end_idx+1+MIN_CONFIRM_DAYS]
    return not future.empty and float(future.max()) >= base*(1+MIN_MOVE_PCT)

def confirmed_fall(df, end_idx):
    base = float(df["Close"].iloc[end_idx])
    future = df["Close"].iloc[end_idx+1 : end_idx+1+MIN_CONFIRM_DAYS]
    return not future.empty and float(future.min()) <= base*(1-MIN_MOVE_PCT)


# ─────────────────────────────
#  ユーティリティ
# ─────────────────────────────

def to_candles(df):
    return [
        {"date": ts.strftime("%Y-%m-%d"),
         "open":  round(float(row["Open"]),  2),
         "high":  round(float(row["High"]),  2),
         "low":   round(float(row["Low"]),   2),
         "close": round(float(row["Close"]), 2),
         "volume": int(row["Volume"])}
        for ts, row in df.iterrows()
    ]


def daily_turnover(close, volume):
    """日足データから概算売買代金（終値×出来高）を返す。"""
    return float(close) * int(volume)


def has_sufficient_turnover(close, volume):
    """1億円以下を除外するため、基準を超える場合だけTrueを返す。"""
    return daily_turnover(close, volume) > MIN_DAILY_TURNOVER


def build_example(df, ticker, name, end_idx, quiz_candles=QUIZ_CANDLES):
    start   = end_idx - quiz_candles + 1
    ans_end = end_idx + 1 + ANSWER_DAYS
    if start < 0 or ans_end > len(df):
        return None

    if not has_sufficient_turnover(
        df["Close"].iloc[end_idx],
        df["Volume"].iloc[end_idx],
    ):
        return None

    quiz_df = df.iloc[start:end_idx+1]
    avg_close = float(quiz_df["Close"].mean())
    price_range = float(quiz_df["High"].max()) - float(quiz_df["Low"].min())
    if avg_close < MIN_PRICE:
        return None
    if avg_close > 0 and price_range / avg_close < MIN_RANGE_PCT:
        return None

    date_str = df.index[end_idx].strftime("%Y-%m-%d")
    return {
        "id":      f"{ticker.replace('.T','')}_{date_str}",
        "ticker":  ticker.replace(".T", ""),
        "name":    name,
        "quiz_candles":   to_candles(df.iloc[start:end_idx+1]),
        "answer_candles": to_candles(df.iloc[end_idx+1:ans_end]),
    }


def filter_existing_examples():
    """既存JSONからパターン成立日の売買代金が1億円以下の実例を除外する。"""
    total_before = 0
    total_after = 0

    for pattern in PATTERNS:
        pattern_name = pattern["name"]
        path = os.path.join(OUTPUT_DIR, f"{pattern_name}.json")
        if not os.path.exists(path):
            print(f"  {pattern_name}: ファイルなし → {path}")
            continue

        with open(path, encoding="utf-8") as f:
            data = json.load(f)

        examples = data.get("examples", [])
        filtered = []
        for example in examples:
            quiz_candles = example.get("quiz_candles", [])
            if not quiz_candles:
                continue
            signal_candle = quiz_candles[-1]
            if has_sufficient_turnover(
                signal_candle.get("close", 0),
                signal_candle.get("volume", 0),
            ):
                filtered.append(example)

        total_before += len(examples)
        total_after += len(filtered)
        data["examples"] = filtered

        temp_path = f"{path}.tmp"
        with open(temp_path, "w", encoding="utf-8") as f:
            json.dump(data, f, ensure_ascii=False, indent=2)
        os.replace(temp_path, path)

        print(
            f"  {pattern_name}: {len(examples)} → {len(filtered)} 件 "
            f"（{len(examples) - len(filtered)} 件除外）"
        )

    print(
        f"\n合計: {total_before} → {total_after} 件 "
        f"（{total_before - total_after} 件除外）"
    )


# ─────────────────────────────
#  パターン定義
# ─────────────────────────────

PATTERNS = [
    # ── 3本足：上昇 ──
    {"name": "赤三兵",     "direction": "bullish",
     "description": "3本連続陽線で終値が順に上昇。上昇継続のサイン。",
     "detect": detect_sansenpei, "confirm": confirmed_rise},
    {"name": "明けの明星", "direction": "bullish",
     "description": "大陰線・小実体・大陽線の3本。底打ちからの上昇転換サイン。",
     "detect": detect_morning_star, "confirm": confirmed_rise},
    {"name": "上放れタスキ", "direction": "bullish",
     "description": "ギャップアップ後2本陽線、その後の陰線がギャップを埋めきれない。上昇継続サイン。",
     "detect": detect_yang_tasuki, "confirm": confirmed_rise},
    # ── 3本足：下降 ──
    {"name": "三羽烏",     "direction": "bearish",
     "description": "3本連続陰線で終値が順に下降。下落継続のサイン。",
     "detect": detect_sankrasu, "confirm": confirmed_fall},
    {"name": "宵の明星",   "direction": "bearish",
     "description": "大陽線・小実体・大陰線の3本。天井からの下落転換サイン。",
     "detect": detect_evening_star, "confirm": confirmed_fall},
    {"name": "下放れタスキ", "direction": "bearish",
     "description": "ギャップダウン後2本陰線、その後の陽線がギャップを埋めきれない。下落継続サイン。",
     "detect": detect_yin_tasuki, "confirm": confirmed_fall},
    {"name": "赤三兵思案星", "direction": "bearish",
     "description": "上昇中に陽線が3本続き、3本目の実体が極小（星）になる形。買い勢力の迷いを示す天井転換サイン。",
     "detect": detect_stalling, "confirm": confirmed_fall},
    # ── 2本足：上昇 ──
    {"name": "陽の包み線", "direction": "bullish",
     "description": "前日陰線を大陽線が完全に包む。強い買い圧力の上昇転換サイン。",
     "detect": detect_bullish_engulfing, "confirm": confirmed_rise},
    {"name": "陽のはらみ線", "direction": "bullish",
     "description": "大陰線の実体内に小陽線が収まる。売り勢力の弱まりを示す反転サイン。",
     "detect": detect_bullish_harami, "confirm": confirmed_rise},
    {"name": "切り込み線", "direction": "bullish",
     "description": "陰線の後、低く始まって陰線の半値以上まで戻す陽線。底からの反発サイン。",
     "detect": detect_piercing_line, "confirm": confirmed_rise},
    {"name": "毛抜き底",   "direction": "bullish",
     "description": "2本の安値がほぼ同じ水準で並ぶ。強いサポートの存在を示す底打ちサイン。",
     "detect": detect_tweezers_bottom, "confirm": confirmed_rise},
    {"name": "最後の抱き陰線", "direction": "bullish",
     "description": "下降トレンド末期に、小陽線を大陰線が包む形。翌日の上寄りで底入れを確認する買い転換サイン。",
     "detect": detect_last_engulfing_bear, "confirm": confirmed_rise},
    # ── 2本足：下降 ──
    {"name": "陰の包み線", "direction": "bearish",
     "description": "前日陽線を大陰線が完全に包む。強い売り圧力の下落転換サイン。",
     "detect": detect_bearish_engulfing, "confirm": confirmed_fall},
    {"name": "陰のはらみ線", "direction": "bearish",
     "description": "大陽線の実体内に小陰線が収まる。買い勢力の弱まりを示す反転サイン。",
     "detect": detect_bearish_harami, "confirm": confirmed_fall},
    {"name": "かぶせ線",   "direction": "bearish",
     "description": "陽線の後、高く始まって陽線の半値以下まで食い込む陰線。天井からの反落サイン。",
     "detect": detect_dark_cloud_cover, "confirm": confirmed_fall},
    {"name": "毛抜き天井", "direction": "bearish",
     "description": "2本の高値がほぼ同じ水準で並ぶ。強いレジスタンスを示す天井打ちサイン。",
     "detect": detect_tweezers_top, "confirm": confirmed_fall},
    {"name": "最後の抱き陽線", "direction": "bearish",
     "description": "上昇トレンド末期に、小陰線を大陽線が包む形。翌日の下寄りで天井を確認する売り転換サイン。",
     "detect": detect_last_engulfing_bull, "confirm": confirmed_fall},
    # ── 1本足：上昇 ──
    {"name": "カラカサ",   "direction": "bullish",
     "description": "下降トレンド後の下ヒゲが長い足。底値圏での強い買い意欲を示す反転サイン。",
     "detect": detect_hammer, "confirm": confirmed_rise},
    {"name": "トンボ",     "direction": "bullish",
     "description": "下降トレンド後の下ヒゲのみの十字線。売り方の失速と買い方の出現を示す反転サイン。",
     "detect": detect_tonbo, "confirm": confirmed_rise},
    # ── 1本足：下降 ──
    {"name": "首吊り線",   "direction": "bearish",
     "description": "上昇トレンド後の下ヒゲが長い足。高値圏での不安定さを示す天井転換サイン。",
     "detect": detect_hanging_man, "confirm": confirmed_fall},
    {"name": "流れ星",   "direction": "bearish",
     "description": "上昇トレンド後の上ヒゲが長い足。高値で売りに押された天井転換サイン。",
     "detect": detect_shooting_star, "confirm": confirmed_fall},
    {"name": "塔婆",       "direction": "bearish",
     "description": "上昇トレンド後の上ヒゲのみの十字線。高値での買い失速と売り圧力を示す天井サイン。",
     "detect": detect_gravestone, "confirm": confirmed_fall},
    # ── 上放れ系 ──
    {"name": "上放れ並び赤", "direction": "bullish",
     "description": "ギャップアップ後に同じ大きさの陽線が2本並ぶ。強い買い勢いの継続サイン。",
     "detect": detect_uwabanaare_narabiari, "confirm": confirmed_rise},
    {"name": "上放れ並び黒", "direction": "bullish",
     "description": "上昇途中のギャップアップ後に同程度の陰線が2本並ぶ。押し目からの上昇継続候補だが、確認を要する弱いサイン。",
     "detect": detect_uwabanaare_narabikuro, "confirm": confirmed_rise},
    {"name": "上放れの星", "direction": "bearish",
     "description": "上昇中に窓を開けて上放れた後、十字線（星）が出る形。上昇の終局を示す天井転換警戒サイン。",
     "detect": detect_uwabanaare_juji, "confirm": confirmed_fall},
    {"name": "上放れ三手放れ寄せ線", "direction": "bearish",
     "description": "3回連続のギャップアップ後に小実体（寄せ線）が出現。買われ過ぎの強い天井サイン。",
     "detect": detect_sankuu_uwa, "confirm": confirmed_fall},
    # ── 下放れ系 ──
    {"name": "下放れ並び赤", "direction": "bearish",
     "description": "ギャップダウン後に陽線2本が並ぶが窓を埋めきれない。下落継続の意外な継続サイン。",
     "detect": detect_sagari_narabiari, "confirm": confirmed_fall},
    {"name": "下放れ二本黒", "direction": "bearish",
     "description": "ギャップダウン後に陰線2本が続く。強い売り勢いの継続を示すサイン。",
     "detect": detect_sagari_kuro2, "confirm": confirmed_fall},
    {"name": "下放れの星", "direction": "bullish",
     "description": "下降中に窓を開けて下放れた後、十字線（星）が出る形。下落の終局を示す底値転換警戒サイン。",
     "detect": detect_sagari_juji, "confirm": confirmed_rise},
    {"name": "下放れ三手放れ寄せ線", "direction": "bullish",
     "description": "3回連続のギャップダウン後に小実体（寄せ線）が出現。売られ過ぎの強い底値サイン。",
     "detect": detect_sankuu_shita, "confirm": confirmed_rise},
    # ── 追加パターン ──
    {"name": "トンカチ", "direction": "bullish",
     "description": "下降トレンド後に出る、上ヒゲが長く実体が小さい足。安値圏で買いが入り始めたことを示す底打ちサイン。",
     "detect": detect_inverted_hammer, "confirm": confirmed_rise},
    {"name": "三尊", "direction": "bearish",
     "description": "3つの山のうち中央が最も高い形。ネックラインを割り込むと天井確定とされる代表的な売りサイン。",
     "detect": detect_head_and_shoulders, "confirm": confirmed_fall, "quiz_candles": HEAD_SHOULDERS_QUIZ_CANDLES},
    {"name": "逆三尊", "direction": "bullish",
     "description": "3つの谷のうち中央が最も深い形。ネックラインを上抜けると底入れ確定とされる代表的な買いサイン。",
     "detect": detect_inverse_head_and_shoulders, "confirm": confirmed_rise, "quiz_candles": HEAD_SHOULDERS_QUIZ_CANDLES},
    {"name": "三空踏み上げ", "direction": "bearish",
     "description": "窓を開けた陽線が3回続く形。買われ過ぎを示し、売り方の買い戻しが一巡した天井サイン。",
     "detect": detect_three_gaps_up, "confirm": confirmed_fall},
    {"name": "三空叩き込み", "direction": "bullish",
     "description": "窓を開けた陰線が3回続く形。売られ過ぎを示し、投げ売りが出尽くした底値サイン。",
     "detect": detect_three_gaps_down, "confirm": confirmed_rise},
    {"name": "上げ三法", "direction": "bullish",
     "description": "大陽線の後、その値幅内に小さな足が3本ほど続き、再び陽線が高値を更新する形。一服後の上昇継続サイン。",
     "detect": detect_rising_three_methods, "confirm": confirmed_rise},
    {"name": "下げ三法", "direction": "bearish",
     "description": "大陰線の後、その値幅内に小さな足が3本ほど続き、再び陰線が安値を更新する形。一服後の下落継続サイン。",
     "detect": detect_falling_three_methods, "confirm": confirmed_fall},
    {"name": "陽のたすき線", "direction": "bullish",
     "description": "陰線の翌日、前日の実体内から始まり前日の高値を超えて引ける陽線。安値圏で下落の勢いを打ち消す上昇転換サイン。",
     "detect": detect_bullish_tasuki_line, "confirm": confirmed_rise},
    {"name": "陰のたすき線", "direction": "bearish",
     "description": "陽線の翌日、前日の実体内から始まり前日の安値を下回って引ける陰線。高値圏で上昇の勢いを打ち消す下落転換サイン。",
     "detect": detect_bearish_tasuki_line, "confirm": confirmed_fall},
    {"name": "あて首線", "direction": "bearish",
     "description": "下降中の大陰線の翌日、安く始まった陽線が前日の安値付近までしか戻らない形。戻りの弱さを示す下落継続サイン。",
     "detect": detect_on_neck, "confirm": confirmed_fall},
    {"name": "入り首線", "direction": "bearish",
     "description": "下降中の大陰線の翌日、安く始まった陽線が前日の終値をわずかに上回るだけで終わる形。戻りの弱さを示す下落継続サイン。",
     "detect": detect_in_neck, "confirm": confirmed_fall},
    {"name": "差し込み線", "direction": "bearish",
     "description": "下降中の大陰線の翌日、安く始まった陽線が前日の実体に食い込むが半値まで届かない形。戻り売りを示す下落継続サイン。",
     "detect": detect_thrusting, "confirm": confirmed_fall},
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

def main(only=None):
    patterns = [p for p in PATTERNS if not only or p["name"] in only]
    unknown = set(only or []) - {p["name"] for p in PATTERNS}
    if unknown:
        raise SystemExit(f"不明なパターン: {sorted(unknown)}")
    os.makedirs(OUTPUT_DIR, exist_ok=True)
    tickers, name_map = get_ticker_list()

    buckets = {p["name"]: [] for p in patterns}
    seen    = {p["name"]: {} for p in patterns}

    def all_full():
        return all(len(buckets[p["name"]]) >= MAX_EXAMPLES for p in patterns)

    for i in range(0, len(tickers), BATCH_SIZE):
        if all_full():
            break
        batch = tickers[i:i+BATCH_SIZE]
        print(f"\nバッチ {i+1}〜{min(i+BATCH_SIZE, len(tickers))} / {len(tickers)}")
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
                df = df.dropna(subset=["Open","High","Low","Close","Volume"])
                if len(df) < QUIZ_CANDLES + ANSWER_DAYS + 15:
                    continue
            except Exception:
                continue

            name = name_map.get(ticker, ticker)

            for pat in patterns:
                pname = pat["name"]
                if len(buckets[pname]) >= MAX_EXAMPLES:
                    continue
                if ticker not in seen[pname]:
                    seen[pname][ticker] = []
                for idx in pat["detect"](df):
                    if len(buckets[pname]) >= MAX_EXAMPLES:
                        break
                    if len(seen[pname][ticker]) >= MAX_PER_TICKER:
                        break
                    date_str = df.index[idx].strftime("%Y-%m-%d")
                    overlap = any(
                        abs((pd.Timestamp(date_str)-pd.Timestamp(d)).days) < MIN_OVERLAP_DAYS
                        for d in seen[pname][ticker]
                    )
                    if overlap:
                        continue
                    if not pat["confirm"](df, idx):
                        continue
                    ex = build_example(df, ticker, name, idx,
                                       pat.get("quiz_candles", QUIZ_CANDLES))
                    if ex:
                        buckets[pname].append(ex)
                        seen[pname][ticker].append(date_str)

        time.sleep(1)
        for pat in patterns:
            pname = pat["name"]
            print(f"  {pname}: {len(buckets[pname])} 件", end="  ")
        print()

    print("\n=== 書き出し ===")
    for pat in patterns:
        pname = pat["name"]
        out = {"pattern": pname, "direction": pat["direction"],
               "description": pat["description"], "examples": buckets[pname]}
        path = os.path.join(OUTPUT_DIR, f"{pname}.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(out, f, ensure_ascii=False, indent=2)
        print(f"  {pname}: {len(buckets[pname])} 件 → {path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="酒田五法クイズ用JSONデータ生成")
    parser.add_argument(
        "--filter-existing",
        action="store_true",
        help="既存JSONからパターン成立日の売買代金が1億円以下の実例を除外する",
    )
    parser.add_argument(
        "--only",
        nargs="+",
        metavar="PATTERN",
        help="指定したパターンだけを生成する（他のJSONは変更しない）",
    )
    args = parser.parse_args()

    if args.filter_existing:
        filter_existing_examples()
    else:
        main(args.only)


from __future__ import annotations

import random
from dataclasses import dataclass
from typing import List, Tuple, Sequence, Optional, Union, Dict
from flask_cors import CORS

from flask import Flask, request, jsonify

try:
    import eval7  # type: ignore
except Exception as e:
    # Provide a clear error at import time if eval7 isn't available.
    raise RuntimeError("This server requires the 'eval7' package. Install with `pip install eval7`.") from e


app = Flask(__name__)
CORS(app) # Add this line to enable CORS for all routes

# ------------------------------
# Utilities
# ------------------------------

Card2 = List[eval7.Card]  # a two-card hand
Board = List[eval7.Card]  # 0 to 5 cards


def parse_two_card_hand(s: str) -> Card2:
    s = s.strip()
    if len(s) != 4:
        raise ValueError(f"Two-card hand must be exactly 4 chars like 'AsKs', got {s!r}")
    return [eval7.Card(s[:2]), eval7.Card(s[2:])]


def parse_board(s: str) -> Board:
    s = s.strip()
    if s == "":
        return []
    if len(s) % 2 != 0:
        raise ValueError("Board string must have even length: e.g., 'QsJsTs'")
    cards = [eval7.Card(s[i:i+2]) for i in range(0, len(s), 2)]
    if len(cards) not in (0, 3, 4, 5):
        raise ValueError("Board must be 0 (pre), 3 (flop), 4 (turn), or 5 (river) cards")
    return cards


def cards_to_str(cards: Sequence[eval7.Card]) -> str:
    return "".join(str(c) for c in cards)


def best5_eval(seven_cards: Sequence[eval7.Card]) -> int:
    """Return integer rank for best 5 out of the given 7."""
    return eval7.evaluate(list(seven_cards))


def deal_remaining(dead: Sequence[eval7.Card], n: int, rng: random.Random) -> List[eval7.Card]:
    deck = [c for c in eval7.Deck() if c not in dead]
    rng.shuffle(deck)
    return deck[:n]


# ------------------------------
# Range sampling
# ------------------------------

@dataclass
class Sampler:
    """Wraps either a fixed hand or an eval7.HandRange for sampling without collisions."""
    text: str
    is_range: bool

    def __post_init__(self):
        if self.is_range:
            # Rely on eval7.HandRange parsing (supports weights like 0.4(AsKs), AQs+, etc).
            self.hr = eval7.HandRange(self.text)
        else:
            self.fixed = parse_two_card_hand(self.text)

    def sample(self, rng: random.Random, dead: Sequence[eval7.Card]) -> Card2:
        dead_set = set(dead)
        if not self.is_range:
            if any(c in dead_set for c in self.fixed):
                raise ValueError("Fixed hand collides with dead cards")
            return list(self.fixed)

        # eval7.HandRange exposes .hands (list of tuples) or is iterable yielding (Card, Card, weight).
        # We'll build a cumulative weighted list of all live combos each trial for clean blocker handling.
        live: List[Tuple[Card2, float]] = []
        try:
            iterable = list(self.hr)  # type: ignore[attr-defined]
        except Exception:
            # Fallback: attribute 'hands' in some eval7 versions
            iterable = getattr(self.hr, "hands")  # type: ignore[attr-defined]

        for item in iterable:
            # item might be (eval7.Card, eval7.Card, weight) or ((Card, Card), weight)
            if isinstance(item, tuple) and len(item) == 3 and isinstance(item[0], eval7.Card):
                c1, c2, w = item  # type: ignore[misc]
                combo = [c1, c2]
            elif isinstance(item, tuple) and len(item) == 2:
                (c1, c2), w = item  # type: ignore[misc]
                combo = [c1, c2]
            else:
                # As a last resort attempt unpack
                try:
                    (c1, c2), w = item  # type: ignore[misc]
                    combo = [c1, c2]
                except Exception as e:
                    raise ValueError(f"Unsupported hand range element format: {item!r}") from e

            if combo[0] in dead_set or combo[1] in dead_set:
                continue
            if combo[0] == combo[1]:
                continue  # defensive
            live.append((combo, float(w)))

        if not live:
            raise ValueError(f"No live combos left in range {self.text!r} after blockers")

        # weighted sample
        total_w = sum(w for _, w in live)
        r = rng.random() * total_w
        acc = 0.0
        for combo, w in live:
            acc += w
            if r <= acc:
                return [combo[0], combo[1]]
        # Fallback
        return [live[-1][0][0], live[-1][0][1]]


def detect_is_range(s: str) -> bool:
    """Heuristically detect if input is a range (not a fixed 2-card string)."""
    s = s.strip()
    if len(s) == 4:
        # Could be a fixed two-card hand (e.g., 'AsKs'). If it contains delimiters, treat as range.
        return any(ch in s for ch in ",;+() ")
    # Anything not exactly 4 chars we treat as a range description.
    return True


# ------------------------------
# Core equity loop (heads-up)
# ------------------------------

def equity_hu(
    hero_src: Union[str, Sampler],
    vill_src: Union[str, Sampler],
    board: Optional[Board] = None,
    iters: int = 100_000,
    seed: Optional[int] = None,
) -> Dict[str, float]:
    """
    Compute heads-up equity given hero and villain sources, which may be fixed hands or ranges.
    If `board` is provided with 0/3/4/5 cards, the sim respects street state.
    """
    rng = random.Random(seed)

    hero_sampler = hero_src if isinstance(hero_src, Sampler) else Sampler(hero_src, detect_is_range(hero_src))
    vill_sampler = vill_src if isinstance(vill_src, Sampler) else Sampler(vill_src, detect_is_range(vill_src))

    board = board or []
    if len(board) not in (0, 3, 4, 5):
        raise ValueError("Board must have 0 (pre), 3 (flop), 4 (turn), or 5 (river) cards")

    h_w = v_w = ties = 0

    for _ in range(iters):
        # Sample hole cards with blocker awareness
        hero = hero_sampler.sample(rng, dead=board)
        vill = vill_sampler.sample(rng, dead=board + hero)
        # If we accidentally collided (shouldn't), resample villain once:
        if len({*hero, *vill, *board}) != (len(hero) + len(vill) + len(board)):
            # Try sampling villain again
            vill = vill_sampler.sample(rng, dead=board + hero)
            if len({*hero, *vill, *board}) != (len(hero) + len(vill) + len(board)):
                # Give up this trial and continue
                continue

        dead = [*hero, *vill, *board]
        remain = 5 - len(board)
        draw = deal_remaining(dead, remain, rng)
        full_board = [*board, *draw]

        hs = best5_eval(hero + full_board)
        vs = best5_eval(vill + full_board)

        if hs > vs:
            h_w += 1
        elif vs > hs:
            v_w += 1
        else:
            ties += 1

    total = h_w + v_w + ties
    if total == 0:
        raise RuntimeError("Simulation produced zero completed trials (blockers too tight?)")

    hero_eq = (h_w + 0.5 * ties) / total
    vill_eq = (v_w + 0.5 * ties) / total

    return {
        "hero_equity": hero_eq,
        "villain_equity": vill_eq,
        "hero_wins": h_w,
        "villain_wins": v_w,
        "ties": ties,
        "iters": total,
    }


# ------------------------------
# HTTP Endpoints
# ------------------------------

@app.post("/equity/preflop")
def api_equity_preflop():
    """
    JSON body:
    {
        "hero": "AsKs" | "AQs+, 0.4(AsKs)",
        "villain": "77+" | "random" (optional: not implemented explicitly),
        "iters": 50000,
        "seed": 42
    }
    """
    try:
        data = request.get_json(force=True) or {}
        hero = data["hands"][0]
        villain = data["hands"][1]
        iters = int(100_000)
        seed = 40

        res = equity_hu(hero, villain, board=[], iters=iters, seed=seed)
        return jsonify({
            "street": "preflop",
            "input": {"hero": hero, "villain": villain, "iters": iters, "seed": seed},
            "result": res,
        })
    except Exception as e:
        return jsonify(error=str(e)), 400


@app.post("/equity/street")
def api_equity_street():
    """
    JSON body:
    {
        "hero": "AsKs" | "AQs+",
        "villain": "77+",
        "board": "QsJsTs" | "QsJsTs2d" | "QsJsTs2d2c" | "",
        "iters": 50000,
        "seed": 123
    }
    """
    try:
        data = request.get_json(force=True) or {}
        hero = data["hero"]
        villain = data["villain"]
        board_str = data.get("board", "")
        board = parse_board(board_str)
        iters = int(data.get("iters", 100_000))
        seed = data.get("seed", None)

        res = equity_hu(hero, villain, board=board, iters=iters, seed=seed)
        return jsonify({
            "street": {0: "preflop", 3: "flop", 4: "turn", 5: "river"}[len(board)],
            "input": {"hero": hero, "villain": villain, "board": board_str, "iters": iters, "seed": seed},
            "result": res,
        })
    except Exception as e:
        return jsonify(error=str(e)), 400


# Health check
@app.get("/healthz")
def healthz():
    return jsonify(status="ok")


if __name__ == "__main__":
    # Default run (no debug in production)
    app.run(host="0.0.0.0", port=8000, debug=False)

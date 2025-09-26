
from concurrent.futures import ProcessPoolExecutor
from pokerkit import (
    parse_range, Card, Deck, StandardHighHand, calculate_equities
)
from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)  # Enable CORS for all routes
EXECUTOR = ProcessPoolExecutor()  # reuse across requests

def parse_cards(text):
    # Accept "AsKs" or ["As","Ks"] or "" for none
    if not text:
        return ()
    if isinstance(text, list):
        text = "".join(text)
    return Card.parse(text)

@app.post("/equity")
def equity_route():
    """
    JSON body:
    {
      "players": ["AsKh", "7d7c", "QJo"], // ranges or specific hands
      "board": "Js8s5d",                 // optional: flop/turn/river as string
    }
    """
    try:
        data = request.get_json(force=True)
        print(f"Received request data: {data}")

        # 'players' can be range strings ("JJ+,AKs,AQs") or specific hands like "AsKs"
        ranges = tuple(parse_range(p) for p in data["players"])
        board = parse_cards(data.get("board", ""))

        # Default values for Texas Hold'em
        hole_deals = 2
        board_deals = 5
        samples = 100_000  # A reasonable default for speed vs. accuracy

        equities = calculate_equities(
            ranges,
            board,
            hole_deals,
            board_deals,
            Deck.STANDARD,
            (StandardHighHand,),
            sample_count=samples,
            executor=EXECUTOR,   # parallelize
        )

        return jsonify({
            "equities": equities,
        })
    except Exception as e:
        print(f"An error occurred: {e}")
        return jsonify(error=str(e)), 500

if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001, debug=True)

from flask import Flask, request, jsonify
from flask_cors import CORS

app = Flask(__name__)
CORS(app)
@app.route("/", methods=["GET"])
def home():
    return (
        "<h1>Cricket Scorer API</h1>"
        "<p>Use /score, /ball (POST), and /reset (POST) endpoints.</p>"
    )

# In-memory match state
match_state = {
    "history": [],                 # list of events (balls, extras, adjustments)
    "runs": 0,
    "wickets": 0,
    "legal_balls": 0,              # only legal balls (no wides / no-balls)
    "current_over": [],            # symbols for current over
    "extras": 0,                   # total extras
    "innings": 1,                  # 1 or 2
    "team_a": "Team A",
    "team_b": "Team B",
    "batting_team": "Team A",
    "bowling_team": "Team B",
    "overs_limit": 20,             # total overs per innings
    "first_innings_total": None,
    "target": None,                # target for team batting in innings 2
}


def format_overs(legal_balls: int) -> str:
    overs = legal_balls // 6
    balls_in_over = legal_balls % 6
    return f"{overs}.{balls_in_over}"


def recompute_state():
    """Rebuild totals from history (used for undo and adjustments)."""
    match_state["runs"] = 0
    match_state["wickets"] = 0
    match_state["legal_balls"] = 0
    match_state["current_over"] = []
    match_state["extras"] = 0

    legal_in_this_over = 0

    for ev in match_state["history"]:
        match_state["runs"] += ev["runs"]
        if ev.get("is_wicket"):
            match_state["wickets"] += 1

        # Adjustments have empty symbol -> invisible in current_over
        symbol = ev.get("symbol")
        if symbol:
            match_state["current_over"].append(symbol)

        if ev.get("is_extra", False):
            match_state["extras"] += ev["runs"]

        if ev.get("legal", False):
            match_state["legal_balls"] += 1
            legal_in_this_over += 1

        # Start a new over after 6 legal balls
        if legal_in_this_over == 6:
            legal_in_this_over = 0
            match_state["current_over"] = []


def score_payload(message: str = ""):
    overs = format_overs(match_state["legal_balls"])
    return {
        "message": message,
        "runs": match_state["runs"],
        "wickets": match_state["wickets"],
        "overs": overs,
        "current_over": match_state["current_over"],
        "extras": match_state["extras"],
        "innings": match_state["innings"],
        "team_a": match_state["team_a"],
        "team_b": match_state["team_b"],
        "batting_team": match_state["batting_team"],
        "overs_limit": match_state["overs_limit"],
        "target": match_state["target"],
    }


@app.route("/score", methods=["GET"])
def get_score():
    return jsonify(score_payload())


@app.route("/ball", methods=["POST"])
def add_ball():
    """
    Add a ball / extra.

    JSON body:
    {
      "runs": 1,
      "is_wicket": false,
      "symbol": "1",
      "legal": true,      # false for wides / no-balls
      "is_extra": false   # true for wides / no-balls / other extras
    }
    """
    data = request.get_json()
    runs = int(data.get("runs", 0))
    is_wicket = bool(data.get("is_wicket", False))
    symbol = data.get("symbol", str(runs))
    legal = bool(data.get("legal", True))
    is_extra = bool(data.get("is_extra", False))

    event = {
        "runs": runs,
        "is_wicket": is_wicket,
        "symbol": symbol,
        "legal": legal,
        "is_extra": is_extra,
    }
    match_state["history"].append(event)

    recompute_state()
    return jsonify(score_payload("Ball recorded"))


@app.route("/undo", methods=["POST"])
def undo_last():
    """Undo the last event (ball, extra, or adjustment)."""
    if not match_state["history"]:
        return jsonify(score_payload("Nothing to undo"))
    match_state["history"].pop()
    recompute_state()
    return jsonify(score_payload("Last event undone"))


@app.route("/adjust", methods=["POST"])
def adjust_score():
    """
    Adjust total runs by a delta without changing overs / current over.

    JSON body:
    { "delta_runs": 3 }   # can be negative
    """
    data = request.get_json()
    delta_runs = int(data.get("delta_runs", 0))

    # Adjustment event: not legal, no wicket, no symbol, not extra
    event = {
        "runs": delta_runs,
        "is_wicket": False,
        "symbol": "",
        "legal": False,
        "is_extra": False,
    }
    match_state["history"].append(event)
    recompute_state()

    return jsonify(score_payload("Score adjusted"))


@app.route("/reset", methods=["POST"])
def reset_match():
    """Full match reset, back to innings 1."""
    match_state["history"] = []
    match_state["innings"] = 1
    match_state["batting_team"] = match_state["team_a"]
    match_state["bowling_team"] = match_state["team_b"]
    match_state["first_innings_total"] = None
    match_state["target"] = None
    recompute_state()
    return jsonify(score_payload("Match reset"))


@app.route("/setup_match", methods=["POST"])
def setup_match():
    """
    Set team names and overs, and reset match.
    JSON:
    {
      "team_a": "Team A",
      "team_b": "Team B",
      "overs_limit": 20
    }
    """
    data = request.get_json() or {}
    team_a = data.get("team_a") or "Team A"
    team_b = data.get("team_b") or "Team B"
    overs_limit = int(data.get("overs_limit", 20))

    match_state["team_a"] = team_a
    match_state["team_b"] = team_b
    match_state["overs_limit"] = overs_limit
    match_state["innings"] = 1
    match_state["batting_team"] = team_a
    match_state["bowling_team"] = team_b
    match_state["first_innings_total"] = None
    match_state["target"] = None
    match_state["history"] = []
    recompute_state()

    return jsonify(score_payload("Match setup updated"))


@app.route("/end_innings", methods=["POST"])
def end_innings():
    """
    End current innings.
    - If innings 1 ends -> store total, set target, reset score, start innings 2.
    - If innings 2 ends -> just mark message (no extra logic for now).
    """
    if match_state["innings"] == 1:
        total = match_state["runs"]
        match_state["first_innings_total"] = total
        match_state["target"] = total + 1
        match_state["innings"] = 2

        # Swap batting/bowling
        old_batting = match_state["batting_team"]
        old_bowling = match_state["bowling_team"]
        match_state["batting_team"] = old_bowling
        match_state["bowling_team"] = old_batting

        # Clear events for new innings
        match_state["history"] = []
        recompute_state()
        return jsonify(score_payload("Innings 1 ended, innings 2 started"))
    else:
        # For now, just say match complete
        return jsonify(score_payload("Innings 2 ended (match complete)"))


if __name__ == "__main__":
    app.run(debug=False)

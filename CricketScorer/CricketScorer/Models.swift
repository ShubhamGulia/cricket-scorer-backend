import Foundation

struct ScoreResponse: Codable {
    let runs: Int
    let wickets: Int
    let overs: String
    let current_over: [String]
    let extras: Int
    let innings: Int
    let team_a: String
    let team_b: String
    let batting_team: String
    let overs_limit: Int
    let target: Int?
}

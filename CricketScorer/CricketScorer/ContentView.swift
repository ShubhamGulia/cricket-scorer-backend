import SwiftUI
import Combine

class ScoreViewModel: ObservableObject {
    @Published var runs: Int = 0
    @Published var wickets: Int = 0
    @Published var overs: String = "0.0"
    @Published var currentOver: [String] = []
    @Published var extras: Int = 0
    @Published var innings: Int = 1
    @Published var teamA: String = "Team A"
    @Published var teamB: String = "Team B"
    @Published var battingTeam: String = "Team A"
    @Published var oversLimit: Int = 20
    @Published var target: Int? = nil
    
    let baseURL = "http://127.0.0.1:5000"
    
    // MARK: - Helpers
    
    private func update(from response: ScoreResponse) {
        runs = response.runs
        wickets = response.wickets
        overs = response.overs
        currentOver = response.current_over
        extras = response.extras
        innings = response.innings
        teamA = response.team_a
        teamB = response.team_b
        battingTeam = response.batting_team
        oversLimit = response.overs_limit
        target = response.target
    }
    
    // MARK: - API calls
    
    func fetchScore() {
        guard let url = URL(string: "\(baseURL)/score") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let response = try? JSONDecoder().decode(ScoreResponse.self, from: data) else { return }
            DispatchQueue.main.async {
                self.update(from: response)
            }
        }.resume()
    }
    
    func sendBall(runs: Int, isWicket: Bool = false,
                  symbol: String? = nil,
                  legal: Bool = true,
                  isExtra: Bool = false) {
        guard let url = URL(string: "\(baseURL)/ball") else { return }
        
        let body: [String: Any] = [
            "runs": runs,
            "is_wicket": isWicket,
            "symbol": symbol ?? (isWicket ? "W" : String(runs)),
            "legal": legal,
            "is_extra": isExtra
        ]
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let response = try? JSONDecoder().decode(ScoreResponse.self, from: data) else {
                self.fetchScore()
                return
            }
            DispatchQueue.main.async {
                self.update(from: response)
            }
        }.resume()
    }
    
    func undoLast() {
        guard let url = URL(string: "\(baseURL)/undo") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let response = try? JSONDecoder().decode(ScoreResponse.self, from: data) else { return }
            DispatchQueue.main.async {
                self.update(from: response)
            }
        }.resume()
    }
    
    func resetMatch() {
        guard let url = URL(string: "\(baseURL)/reset") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let response = try? JSONDecoder().decode(ScoreResponse.self, from: data) else { return }
            DispatchQueue.main.async {
                self.update(from: response)
            }
        }.resume()
    }
    
    func setScore(to newTotal: Int) {
        let delta = newTotal - runs
        guard delta != 0 else { return }
        guard let url = URL(string: "\(baseURL)/adjust") else { return }
        
        let body: [String: Any] = ["delta_runs": delta]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let response = try? JSONDecoder().decode(ScoreResponse.self, from: data) else { return }
            DispatchQueue.main.async {
                self.update(from: response)
            }
        }.resume()
    }
    
    func setupMatch(teamA: String, teamB: String, oversLimit: Int) {
        guard let url = URL(string: "\(baseURL)/setup_match") else { return }
        let body: [String: Any] = [
            "team_a": teamA,
            "team_b": teamB,
            "overs_limit": oversLimit
        ]
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body, options: [])
        
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let response = try? JSONDecoder().decode(ScoreResponse.self, from: data) else { return }
            DispatchQueue.main.async {
                self.update(from: response)
            }
        }.resume()
    }
    
    func endInnings() {
        guard let url = URL(string: "\(baseURL)/end_innings") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data,
                  let response = try? JSONDecoder().decode(ScoreResponse.self, from: data) else { return }
            DispatchQueue.main.async {
                self.update(from: response)
            }
        }.resume()
    }
}

struct ContentView: View {
    @StateObject private var vm = ScoreViewModel()
    
    @State private var showWideDialog = false
    @State private var showNoBallDialog = false
    @State private var showEditSheet = false
    @State private var showSetupSheet = false
    
    @State private var editedRunsText = ""
    @State private var teamAInput = ""
    @State private var teamBInput = ""
    @State private var oversLimitInput = "20"
    
    var body: some View {
        VStack(spacing: 20) {
            // Match header
            VStack(spacing: 4) {
                Text("\(vm.teamA) vs \(vm.teamB)")
                    .font(.title2)
                    .bold()
                Text("Batting: \(vm.battingTeam)  •  Innings \(vm.innings)")
                    .font(.subheadline)
                Text("Overs: \(vm.overs) / \(vm.oversLimit)")
                    .font(.subheadline)
                if let target = vm.target, vm.innings == 2 {
                    Text("Target: \(target)")
                        .font(.headline)
                        .foregroundColor(.blue)
                }
            }
            
            // Score
            Text("Score: \(vm.runs)/\(vm.wickets)")
                .font(.title)
            Text("Extras: \(vm.extras)")
                .font(.subheadline)
            
            // Current over
            HStack {
                Text("Current over:")
                ForEach(vm.currentOver, id: \.self) { ball in
                    Text(ball)
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4).stroke()
                        )
                }
            }
            .font(.subheadline)
            
            // Add Ball section
            VStack(spacing: 12) {
                Text("Add Ball")
                    .font(.headline)
                
                HStack {
                    ForEach([0,1,2,3,4,6], id: \.self) { r in
                        Button("\(r)") {
                            vm.sendBall(runs: r, legal: true, isExtra: false)
                        }
                        .padding()
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke())
                    }
                }
                
                HStack {
                    Button("Wide") {
                        showWideDialog = true
                    }
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke())
                    
                    Button("No ball") {
                        showNoBallDialog = true
                    }
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke())
                    
                    Button("Wicket") {
                        vm.sendBall(runs: 0, isWicket: true, symbol: "W", legal: true, isExtra: false)
                    }
                    .padding()
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke())
                }
            }
            
            // Control buttons
            VStack(spacing: 10) {
                HStack(spacing: 20) {
                    Button("Undo Last") {
                        vm.undoLast()
                    }
                    .padding()
                    
                    Button("Edit Score") {
                        editedRunsText = String(vm.runs)
                        showEditSheet = true
                    }
                    .padding()
                }
                
                HStack(spacing: 20) {
                    Button("Match Setup") {
                        teamAInput = vm.teamA
                        teamBInput = vm.teamB
                        oversLimitInput = String(vm.oversLimit)
                        showSetupSheet = true
                    }
                    .padding()
                    
                    Button("End Innings") {
                        vm.endInnings()
                    }
                    .padding()
                }
                
                Button("Reset Match") {
                    vm.resetMatch()
                }
                .padding()
                .foregroundColor(.red)
            }
            
            Spacer()
        }
        .padding()
        .onAppear { vm.fetchScore() }
        
        // Wide dialog (with overthrows)
        .confirmationDialog(
            "Wide - total runs (incl. overthrows)",
            isPresented: $showWideDialog
        ) {
            ForEach(1...6, id: \.self) { r in
                Button("\(r) run\(r > 1 ? "s" : "")") {
                    vm.sendBall(runs: r, symbol: "Wd\(r)", legal: false, isExtra: true)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        
        // No-ball dialog (with overthrows)
        .confirmationDialog(
            "No ball - total runs (incl. overthrows)",
            isPresented: $showNoBallDialog
        ) {
            ForEach(1...6, id: \.self) { r in
                Button("\(r) run\(r > 1 ? "s" : "")") {
                    vm.sendBall(runs: r, symbol: "Nb\(r)", legal: false, isExtra: true)
                }
            }
            Button("Cancel", role: .cancel) {}
        }
        
        // Edit Score sheet
        .sheet(isPresented: $showEditSheet) {
            NavigationView {
                Form {
                    Section(header: Text("Correct total runs")) {
                        TextField("Total runs", text: $editedRunsText)
                            .keyboardType(.numberPad)
                    }
                    
                    Section {
                        Button("Save") {
                            if let newTotal = Int(editedRunsText) {
                                vm.setScore(to: newTotal)
                            }
                            showEditSheet = false
                        }
                        Button("Cancel", role: .cancel) {
                            showEditSheet = false
                        }
                    }
                }
                .navigationTitle("Edit Score")
            }
        }
        
        // Match setup sheet
        .sheet(isPresented: $showSetupSheet) {
            NavigationView {
                Form {
                    Section(header: Text("Teams")) {
                        TextField("Team A", text: $teamAInput)
                        TextField("Team B", text: $teamBInput)
                    }
                    Section(header: Text("Overs per innings")) {
                        TextField("Overs", text: $oversLimitInput)
                            .keyboardType(.numberPad)
                    }
                    Section {
                        Button("Save") {
                            let overs = Int(oversLimitInput) ?? 20
                            vm.setupMatch(teamA: teamAInput.isEmpty ? "Team A" : teamAInput,
                                          teamB: teamBInput.isEmpty ? "Team B" : teamBInput,
                                          oversLimit: overs)
                            showSetupSheet = false
                        }
                        Button("Cancel", role: .cancel) {
                            showSetupSheet = false
                        }
                    }
                }
                .navigationTitle("Match Setup")
            }
        }
    }
}

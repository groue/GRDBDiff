import UIKit
import GRDB
import GRDBDiff
import Differ

class PlayersViewController: UITableViewController {
    // An enum that describes a players ordering
    enum Ordering: Equatable {
        case byScore
        case byName
        
        var request: QueryInterfaceRequest<Player> {
            switch self {
            case .byScore: return Player.orderedByScore()
            case .byName: return Player.orderedByName()
            }
        }
        
        var localizedName: String {
            switch self {
            case .byScore: return "Score ⬇︎"
            case .byName: return "Name ⬆︎"
            }
        }
    }
    
    // The user can change the players ordering
    private var ordering: Ordering = .byScore {
        didSet {
            setupOrderingBarButtonItem()
            setupTableView()
        }
    }
    
    private var players: [Player] = []
    private var playersObserver: TransactionObserver?
    private var playerCountObserver: TransactionObserver?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupTitle()
        setupOrderingBarButtonItem()
        setupToolbar()
        setupTableView()
    }
}

// MARK: - Actions

extension PlayersViewController {
    @IBAction func sortByName() {
        ordering = .byName
    }
    
    @IBAction func sortByScore() {
        ordering = .byScore
    }
    
    @IBAction func deletePlayers() {
        try! dbPool.writeInTransaction { db in
            try Player.deleteAll(db)
            return .commit
        }
    }
    
    @IBAction func refresh() {
        try! dbPool.writeInTransaction { db in
            if try Player.fetchCount(db) == 0 {
                // Insert players
                for _ in 0..<8 {
                    var player = Player(id: nil, name: Player.randomName(), score: Player.randomScore())
                    try player.insert(db)
                }
            } else {
                // Insert a player
                if arc4random_uniform(2) == 0 {
                    var player = Player(id: nil, name: Player.randomName(), score: Player.randomScore())
                    try player.insert(db)
                }
                // Delete a random player
                if arc4random_uniform(2) == 0 {
                    try Player.order(sql: "RANDOM()").limit(1).deleteAll(db)
                }
                // Update some players
                for player in try Player.fetchAll(db) where arc4random_uniform(2) == 0 {
                    var player = player
                    player.score = Player.randomScore()
                    try player.update(db)
                }
            }
            return .commit
        }
    }
    
    @IBAction func stressTest() {
        for _ in 0..<50 {
            DispatchQueue.global().async {
                self.refresh()
            }
        }
    }
}

// MARK: - Views

extension PlayersViewController {
    private func setupTitle() {
        playerCountObserver = try! ValueObservation
            .trackingCount(Player.all())
            .start(in: dbPool) { [unowned self] count in
                switch count {
                case 0: self.navigationItem.title = "No Player"
                case 1: self.navigationItem.title = "1 Player"
                default: self.navigationItem.title = "\(count) Players"
                }
        }
    }
    
    private func setupOrderingBarButtonItem() {
        let action: Selector
        switch ordering {
        case .byScore: action = #selector(sortByName)
        case .byName: action = #selector(sortByScore)
        }
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: ordering.localizedName, style: .plain, target: self, action: action)
    }
    
    private func setupToolbar() {
        toolbarItems = [
            UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(deletePlayers)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .refresh, target: self, action: #selector(refresh)),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(title: "💣", style: .plain, target: self, action: #selector(stressTest)),
        ]
    }
}

// MARK: - Table View

extension PlayersViewController {
    private func setupTableView() {
        playersObserver = try! ValueObservation
            .trackingAll(ordering.request)
            .start(in: dbPool) { [unowned self] newPlayers in
                self.updateTableView(with: newPlayers)
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return players.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Player", for: indexPath)
        configure(cell, at: indexPath)
        return cell
    }
    
    private func configure(_ cell: UITableViewCell, at indexPath: IndexPath) {
        let player = players[indexPath.row]
        cell.textLabel?.text = player.name
        cell.detailTextLabel?.text = "\(player.score)"
    }
    
    private func updateTableView(with newPlayers: [Player]) {
        let diff = players.extendedDiff(newPlayers)
        players = newPlayers
        tableView.apply(diff, deletionAnimation: .fade, insertionAnimation: .fade)
    }
}

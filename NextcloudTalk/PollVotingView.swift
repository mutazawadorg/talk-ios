//
// Copyright (c) 2022 Ivan Sein <ivan@nextcloud.com>
//
// Author Ivan Sein <ivan@nextcloud.com>
//
// GNU GPL version 3 or any later version
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

import UIKit

@objcMembers class PollVotingView: UITableViewController {

    enum PollSection: Int {
        case kPollSectionQuestion = 0
        case kPollSectionOptions
        case kPollSectionCount
    }

    var poll: NCPoll?
    var room: String = ""
    var isPollOpen: Bool = false
    var isOwnPoll: Bool = false
    var userVoted: Bool = false
    var editingVote: Bool = false
    var showPollResults: Bool = false
    let footerView = PollFooterView(frame: CGRect.zero)
    var pollBackgroundView: PlaceholderView = PlaceholderView(for: .grouped)
    var userSelectedOptions: [Int] = []

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.initPollView()
    }

    required override init(style: UITableView.Style) {
        super.init(style: style)
        self.initPollView()
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: NCAppBranding.themeTextColor()]
        self.navigationController?.navigationBar.tintColor = NCAppBranding.themeTextColor()
        self.navigationController?.navigationBar.barTintColor = NCAppBranding.themeColor()
        self.navigationController?.navigationBar.isTranslucent = false
        self.navigationItem.title = NSLocalizedString("Poll", comment: "")

        if #available(iOS 13.0, *) {
            let appearance = UINavigationBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.titleTextAttributes = [.foregroundColor: NCAppBranding.themeTextColor()]
            appearance.backgroundColor = NCAppBranding.themeColor()
            self.navigationItem.standardAppearance = appearance
            self.navigationItem.compactAppearance = appearance
            self.navigationItem.scrollEdgeAppearance = appearance
        }

        pollBackgroundView.placeholderView.isHidden = true
        pollBackgroundView.loadingView.startAnimating()
        self.tableView.backgroundView = pollBackgroundView

        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(self.cancelButtonPressed))
        self.navigationItem.leftBarButtonItem?.tintColor = NCAppBranding.themeTextColor()
    }

    func cancelButtonPressed() {
        self.dismiss(animated: true, completion: nil)
    }

    func initPollView() {
        self.tableView.dataSource = self
        self.tableView.delegate = self
        self.tableView.register(UINib(nibName: kShareTableCellNibName, bundle: .main), forCellReuseIdentifier: kShareCellIdentifier)
    }

    func setupPollView() {
        guard let poll = poll else {return}
        // Set poll settings
        let activeAccountId = NCDatabaseManager.sharedInstance().activeAccount().accountId
        self.isPollOpen = poll.status == NCPollStatusOpen
        self.isOwnPoll = poll.actorId == activeAccountId && poll.actorType == "users"
        self.userVoted = !poll.votedSelf.isEmpty
        self.showPollResults = (self.userVoted && !self.editingVote) || !self.isPollOpen
        // Set footer buttons
        self.tableView.tableFooterView = pollFooterView()
        // Set vote button state
        self.setVoteButtonState()
        // Reload table view
        self.tableView.reloadData()
    }

    func pollFooterView() -> UIView {
        var footerRect = CGRect(x: 0, y: 0, width: 0, height: 120)
        footerView.secondaryButton.isHidden = true
        if isPollOpen {
            if userVoted && !editingVote {
                footerView.primaryButton.setTitle(NSLocalizedString("Edit vote", comment: ""), for: .normal)
                footerView.setPrimaryButtonAction(target: self, selector: #selector(editVoteButtonPressed))
            } else {
                footerView.primaryButton.setTitle(NSLocalizedString("Vote", comment: ""), for: .normal)
                footerView.setPrimaryButtonAction(target: self, selector: #selector(voteButtonPressed))
            }
            if isOwnPoll {
                footerView.secondaryButton.setTitle(NSLocalizedString("End poll", comment: ""), for: .normal)
                footerView.secondaryButton.isHidden = false
            }
            if editingVote {
                footerView.secondaryButton.setTitle(NSLocalizedString("Dismiss", comment: ""), for: .normal)
                footerView.secondaryButton.isHidden = false
                footerView.secondaryButton.addTarget(self, action: #selector(dismissButtonPressed), for: .touchUpInside)
            }
        } else {
            footerRect.size.height = 0
        }
        footerView.frame = footerRect
        return footerView
    }

    func voteButtonPressed() {
        guard let poll = poll else {return}
        NCAPIController.sharedInstance().voteOnPoll(withId: poll.pollId, inRoom: room, withOptions: userSelectedOptions,
        for: NCDatabaseManager.sharedInstance().activeAccount()) { responsePoll, error, _ in
            if let responsePoll = responsePoll, error == nil {
                self.poll = responsePoll
            }
        }
    }

    func editVoteButtonPressed() {
        self.editingVote = true
        self.setupPollView()
    }

    func dismissButtonPressed() {
        self.editingVote = false
        self.userSelectedOptions = []
        self.setupPollView()
    }

    func setVoteButtonState() {
        if userSelectedOptions.isEmpty && isPollOpen && (!userVoted || editingVote) {
            footerView.primaryButton.backgroundColor = NCAppBranding.themeColor().withAlphaComponent(0.5)
            footerView.primaryButton.isEnabled = false
        } else {
            footerView.primaryButton.backgroundColor = NCAppBranding.themeColor()
            footerView.primaryButton.isEnabled = true
        }
    }

    func updatePoll(poll: NCPoll) {
        self.poll = poll
        pollBackgroundView.loadingView.stopAnimating()
        pollBackgroundView.loadingView.isHidden = true
        setupPollView()
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return PollSection.kPollSectionCount.rawValue
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch section {
        case PollSection.kPollSectionQuestion.rawValue:
            return poll?.question != nil ?  1 : 0
        case PollSection.kPollSectionOptions.rawValue:
            return poll?.options?.count ?? 0
        default:
            return 0
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let pollQuestionCellIdentifier = "pollQuestionCellIdentifier"
        let pollOptionCellIdentifier = "pollOptionCellIdentifier"
        var cell = UITableViewCell()

        switch indexPath.section {
        case PollSection.kPollSectionQuestion.rawValue:
            cell = UITableViewCell(style: .default, reuseIdentifier: pollQuestionCellIdentifier)
            cell.textLabel?.text = poll?.question
            cell.textLabel?.numberOfLines = 4
            cell.textLabel?.lineBreakMode = .byWordWrapping
            cell.textLabel?.sizeToFit()
            cell.imageView?.image = UIImage(named: "poll")?.withRenderingMode(.alwaysTemplate)
            cell.imageView?.tintColor = NCAppBranding.placeholderColor()
        case PollSection.kPollSectionOptions.rawValue:
            cell = UITableViewCell(style: .value1, reuseIdentifier: pollOptionCellIdentifier)
            cell.textLabel?.text = poll?.options[indexPath.row] as? String
            cell.textLabel?.numberOfLines = 4
            cell.textLabel?.lineBreakMode = .byWordWrapping
            cell.textLabel?.sizeToFit()
            if !showPollResults {
                var checkboxImageView = UIImageView(image: UIImage(named: "checkbox-unchecked")?.withRenderingMode(.alwaysTemplate))
                checkboxImageView.tintColor = NCAppBranding.placeholderColor()
                if userSelectedOptions.contains(indexPath.row) {
                    checkboxImageView = UIImageView(image: UIImage(named: "checkbox-checked")?.withRenderingMode(.alwaysTemplate))
                    checkboxImageView.tintColor = NCAppBranding.elementColor()
                }
                cell.accessoryView = checkboxImageView
            }
        default:
            break
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section != PollSection.kPollSectionOptions.rawValue || showPollResults {
            tableView.deselectRow(at: indexPath, animated: true)
            return
        }

        guard let poll = poll else {return}

        if let index = userSelectedOptions.firstIndex(of: indexPath.row), poll.maxVotes != 1 {
            userSelectedOptions.remove(at: index)
        } else {
            if poll.maxVotes == 1 {
                userSelectedOptions.removeAll()
            } else if poll.maxVotes > 1 && poll.maxVotes == userSelectedOptions.count {
                return
            }
            userSelectedOptions.append(indexPath.row)
        }
        setVoteButtonState()
        tableView.reloadSections(IndexSet(integer: PollSection.kPollSectionOptions.rawValue), with: .automatic)
        tableView.deselectRow(at: indexPath, animated: true)
    }
}

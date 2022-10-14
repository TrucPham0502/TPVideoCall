//
//  ViewController.swift
//  TPVideoCall
//
//  Created by Truc Pham on 23/05/2022.
//

import UIKit
import AVFoundation
import WebRTC

class ViewController: UIViewController {
    private var signalClient : SignalingClient!
    var data : [String] = []
    private lazy var tableView : UITableView = {
        let v = UITableView()
        v.translatesAutoresizingMaskIntoConstraints = false
        v.register(UserTableViewCell.self, forCellReuseIdentifier: "UserTableViewCell")
        v.backgroundColor = .red
        v.dataSource = self
        return v
    }()
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        self.view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            tableView.topAnchor.constraint(equalTo: self.view.topAnchor),
            tableView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            tableView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        buildSignalingClient()
    }
    private func buildSignalingClient() {
        self.signalClient = .init()
        self.signalClient.delegate = self
        self.signalClient.connect()
    }
    
    
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.signalClient.delegate = self
    }
    
    @objc func answerTap(){
        //        self.webRTCClient.answer {[weak self] (localSdp) in
        //            guard let _self = self else { return }
        //            _self.signalClient.send(sdp: localSdp, room: _self.roomId)
        //        }
    }
    
    @objc func offerTap(){
        //        self.webRTCClient.offer {[weak self] (sdp) in
        //            guard let _self = self else { return }
        //            _self.signalClient.send(sdp: sdp, room: _self.roomId)
        //        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
    }
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
    }
    
    func showConfirm(_ message: String , confirm :@escaping () -> (), cancel : @escaping () -> ()){
        DispatchQueue.main.async {
            let alert = UIAlertController(title: "Alert", message: message, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Cancel", style: .destructive, handler: { action in
                cancel()
            }))
            alert.addAction(UIAlertAction(title: "Ok", style: .default, handler: {action in
                confirm()
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }
}

extension ViewController : UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "UserTableViewCell", for: indexPath)
        if let cell = cell as? UserTableViewCell {
            cell.lbTitle.text = data[indexPath.row]
            cell.cellSelected = {[weak self] in
                guard let _self = self else { return }
                DispatchQueue.main.async {
                    let vc = StreamController()
                    vc.modalPresentationStyle = .fullScreen
                    vc.callType = .call(toIds: [_self.data[indexPath.row]])
                    _self.present(vc, animated: true)
                }
            }
        }
        return cell
    }
    
    
}

extension ViewController : SignalClientDelegate {
    func signalClientDidConnect(_ signalClient: SignalingClient) {
        tableView.backgroundColor = .green
    }
    
    func signalClientDidDisconnect(_ signalClient: SignalingClient) {
        tableView.backgroundColor = .red
    }
    
    func signalClient(_ signalClient: SignalingClient, clientsConnected data: SignalResponse<ClientsConnected>) {
        self.data = data.data?.clients.filter{ $0 != Config.default.id } ?? []
        DispatchQueue.main.async {
            self.tableView.reloadData()
        }
        
    }
    func signalClient(_ signalClient: SignalingClient, clientsDisonnected data: SignalResponse<ClientsDisconnected>) {
        if let idx = self.data.firstIndex(where: { $0 == data.id }){
            self.data.remove(at: idx)
            DispatchQueue.main.async {
                self.tableView.reloadData()
            }
        }
    }
    func signalClient(_ signalClient: SignalingClient, request data: Request) {
        switch data {
        case let .call(id, scrWith, scrHeight, encode, os):
            showConfirm("Received call from \(id)") {[weak self] in
                guard let _self = self else { return }
                DispatchQueue.main.async {
                    let vc = StreamController()
                    vc.modalPresentationStyle = .fullScreen
                    vc.callType = .receive(fromId: id, fromSysInfo: (scrWith : scrWith, scrHeight : scrHeight, encode : encode, os: os))
                    _self.present(vc, animated: true)
                }
            } cancel: {[weak self] in
                guard let _self = self else { return }
                _self.signalClient.sendResponseTo(response: .call(id: Config.default.id, scrWith: Int(UIScreen.main.bounds.width), scrHeight: Int(UIScreen.main.bounds.height), encode: EncodeType.support.rawValue, os: UIDevice.current.systemVersion, accept: false), sendTo: .user(id: id))
            }
        default: break;
        }
        
    }
}

class UserTableViewCell : UITableViewCell {
    var cellSelected : () -> () = {}
    lazy var lbTitle : UILabel = {
        let v = UILabel()
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        prepareUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    @objc func cellTap(){
        cellSelected()
    }
    private func prepareUI(){
        self.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(cellTap)))
        self.contentView.addSubview(lbTitle)
        NSLayoutConstraint.activate([
            lbTitle.leadingAnchor.constraint(equalTo: self.contentView.leadingAnchor, constant: 24),
            lbTitle.trailingAnchor.constraint(equalTo: self.contentView.trailingAnchor, constant: -24),
            lbTitle.topAnchor.constraint(equalTo: self.contentView.topAnchor, constant: 20),
            lbTitle.bottomAnchor.constraint(lessThanOrEqualTo: self.contentView.bottomAnchor, constant: -20),
        ])
    }
}

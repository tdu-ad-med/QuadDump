import UIKit

class ViewController: UIViewController {
    var quadRecorder: QuadRecorder!

    override func viewDidLoad() {
        super.viewDidLoad()

        // フレームサイズの取得
        let width: CGFloat = self.view.frame.width;
        let height: CGFloat = self.view.frame.height;

        // 背景色の指定
        view.backgroundColor = UIColor(hex: 0x292929)

        // プレビューの作成
        let previewImageView = UIImageView()
        previewImageView.bounds = CGRect(x: 0, y: 0, width: width, height: width * 16 / 9)
        previewImageView.center = self.view.center
        previewImageView.backgroundColor = UIColor(hex: 0x000000)
        self.view.addSubview(previewImageView)

        // ステータスを表示するラベルの作成 
        let statusTextView = UITextView()
        statusTextView.bounds = CGRect(
            x: 0, y: 0,
            width: previewImageView.bounds.width - 60,
            height: previewImageView.bounds.height - 60
        )
        statusTextView.center = self.view.center
        statusTextView.isEditable = false
        statusTextView.isSelectable = false
        statusTextView.font = UIFont.systemFont(ofSize: 16)
        statusTextView.text = "status"
        statusTextView.textColor = UIColor(hex: 0xF5F5F5)
        self.view.addSubview(statusTextView)

        // 録画ボタンの作成
        let recordButton = UIButton()
        recordButton.bounds = CGRect(x: 0, y: 0, width: 160, height: 80)
        recordButton.center = CGPoint(x: width / 2, y: height - 80)
        recordButton.titleLabel?.font = UIFont.systemFont(ofSize: 24)
        recordButton.backgroundColor = UIColor(hex: 0xF5F5F5)
        recordButton.layer.borderColor = UIColor(hex: 0xF5F5F5).cgColor
        recordButton.layer.borderWidth = 4
        recordButton.layer.cornerRadius = recordButton.bounds.height / 2
        recordButton.setTitleColor(UIColor(hex: 0x292929), for: .normal)
        recordButton.setTitle("Record", for: .normal)
        recordButton.addTarget(self, action: #selector(ViewController.recordSwitcher), for: .touchUpInside)
        self.view.addSubview(recordButton)

        // QuadRecorderのインスタンスを作成
        quadRecorder = QuadRecorder()
    }

    @objc func recordSwitcher(_ button: UIButton) {
        // 録画の状態を切り替え
        var result: Result<(), QuadRecorder.RecordError> = .success(())
        if case .recording = quadRecorder.status {
            result = quadRecorder.stop()
        }
        else {
            result = quadRecorder.start()
        }

        // 処理が失敗した場合はアラートを表示
        if case let .failure(e) = result {
            let alert = UIAlertController(title: "Error", message: e.description, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .default){_ in })
            present(alert, animated: true, completion: nil)
        }

        // 録画ボタンの表示を切り替え
        if case .recording = self.quadRecorder.status {
            button.backgroundColor = UIColor(hex: 0xFF053F)
            button.setTitleColor(UIColor(hex: 0xF5F5F5), for: .normal)
            button.setTitle("Stop", for: .normal)
        }
        else {
            button.backgroundColor = UIColor(hex: 0xF5F5F5)
            button.setTitleColor(UIColor(hex: 0x292929), for: .normal)
            button.setTitle("Record", for: .normal)
        }
    }
}

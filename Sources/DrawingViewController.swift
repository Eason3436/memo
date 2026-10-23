import UIKit
import PencilKit

/// PencilKit 繪圖畫面：手指或 Apple Pencil 都能畫
final class DrawingViewController: UIViewController {

    /// 按「完成」時呼叫，帶回畫好的圖與畫布寬度
    var onDone: ((PKDrawing, CGFloat) -> Void)?

    private let canvasView = PKCanvasView()
    private let toolPicker = PKToolPicker()
    private let initialDrawing: PKDrawing

    init(drawing: PKDrawing) {
        self.initialDrawing = drawing
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "繪圖"
        // 白紙黑墨，和存進備忘錄的圖一致
        overrideUserInterfaceStyle = .light
        view.backgroundColor = .white

        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.drawing = initialDrawing
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .white
        canvasView.alwaysBounceVertical = true
        view.addSubview(canvasView)
        NSLayoutConstraint.activate([
            canvasView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        navigationItem.leftBarButtonItem = UIBarButtonItem(systemItem: .cancel, primaryAction: UIAction { [weak self] _ in
            self?.dismiss(animated: true)
        })
        navigationItem.rightBarButtonItem = UIBarButtonItem(systemItem: .done, primaryAction: UIAction { [weak self] _ in
            guard let self else { return }
            self.onDone?(self.canvasView.drawing, self.canvasView.bounds.width)
            self.dismiss(animated: true)
        })
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        toolPicker.addObserver(canvasView)
        toolPicker.setVisible(true, forFirstResponder: canvasView)
        canvasView.becomeFirstResponder()
    }
}

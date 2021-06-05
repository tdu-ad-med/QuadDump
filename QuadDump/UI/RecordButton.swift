import SwiftUI
import AudioToolbox

// 録画ボタン
struct RecordButton: View {
    @Binding private var isRecording: Bool          // 録画状態
    @State private var isHighlight: Bool = false    // ボタンがハイライトされているかどうが
    let buttonRadius: CGFloat  // ボタンの半径

    // 録画開始時に呼ばれるコールバック関数
    private var beginRecord: (() -> ())? = nil

    // 録画終了時に呼ばれるコールバック関数
    private var endRecord: (() -> ())? = nil

    init(state: Binding<Bool>, radius: CGFloat = 36, begin: (() -> ())? = nil, end: (() -> ())? = nil) {
        /*
        メモ
        isRecordingはProperty Wrappersでラップされており
        ラップ元のプロパティ名は先頭にアンダースコアが追加される
        */

        _isRecording = state
        buttonRadius = radius  // ボタンの円の半径
        beginRecord  = begin   // 録画開始時のコールバック関数
        endRecord    = end     // 録画終了時のコールバック関数
    }

    var body: some View {
        let backgroundDiameter = buttonRadius * 2 * 37 / 36
        let buttonDiameter = buttonRadius * 2
        ZStack(alignment: .center) {
            // 背景
            Circle()
                .fill(Color(hex: 0x000000, alpha: 0.1))
                .scaledToFit()
                .frame(width: backgroundDiameter, height: backgroundDiameter)

            // 内側の赤い円
            InnerShape(buttonRadius: buttonRadius, isRecording: isRecording ? 1 : 0, isHighlight: isHighlight ? 1 : 0)
                .fill(Color(hex: 0xfe3b30))
                .animation(buttonAnimation, value: isRecording)
                .animation(buttonAnimation, value: isHighlight)

            // 外側の白い円
            OuterShape(buttonRadius: buttonRadius)
                .fill(Color(hex: 0xfeffff))
        }
        // サイズの修正
        .frame(width: buttonDiameter, height: buttonDiameter)
        // 当たり判定の修正
        .contentShape(Circle())
        // タップイベントの処理
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                // 長押し時にボタンをハイライトする
                .onChanged { value in
                    isHighlight = dragHitTest(value)
                }
                // タップ時に録画の開始/停止を切り替える
                .onEnded { value in
                    isHighlight = false
                    if dragHitTest(value) { switchRecord() }
                }
        )
    }

    // バネマスダンパー系で臨界減衰となるようなアニメーションの作成
    //   臨界減衰となる条件: damping = sqrt(stiffness) * 2
    private var buttonAnimation: Animation {
        Animation.interpolatingSpring(mass: 1.0, stiffness: 300, damping: sqrt(300) * 2)
    }

    // 録画開始/停止の切り替え
    private func switchRecord() {
        // 現在の録画状態を記憶
        let wasRecording = isRecording

        // 録画状態を切り替え
        isRecording = !isRecording

        // コールバック関数を呼び出し
        if isRecording { beginRecord?() }
        else { endRecord?() }

        // 録画状態の切り替えがコールバック関数によって戻されていれば何もせずに処理を終了
        //   ( isRecordingはBindingであるためコールバック関数内で変更可能 )
        if wasRecording == isRecording { return }

        // 録画開始/停止のシステムサウンドを再生する
        AudioServicesPlaySystemSoundWithCompletion(isRecording ? 1113 : 1114, nil)
    }

    // 録画ボタンの外側の白い部分の形
    private struct OuterShape: Shape {
        let buttonRadius: CGFloat

        func path(in rect: CGRect) -> Path {
            let outerRadius = buttonRadius
            let innerRadius = buttonRadius * 8 / 9
            let path = Path { path in
                path.addArc(center: CGPoint(x: 0, y: 0), radius: outerRadius, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 360), clockwise: true)
                path.addArc(center: CGPoint(x: 0, y: 0), radius: innerRadius, startAngle: Angle(degrees: 0), endAngle: Angle(degrees: 360), clockwise: false)
                path.closeSubpath()
            }
            .applying(CGAffineTransform(translationX: rect.midX, y: rect.midY))

            return path
        }
    }

    // 録画ボタンの内側の赤い部分の形
    private struct InnerShape: Shape {
        let buttonRadius: CGFloat   // 録画ボタンの円の半径
        var isRecording: CGFloat = 0  // 録画開始/録画停止のアニメーション (0 <= isRecording <= 1)
        var isHighlight: CGFloat = 0  // 録画ボタンのハイライトのアニメーション (0 <= isHighlight <= 1)

        var animatableData: AnimatablePair<CGFloat, CGFloat> {
            get { AnimatablePair(isRecording, isHighlight) }
            set {
                isRecording = newValue.first
                isHighlight = newValue.second
            }
        }

        func path(in rect: CGRect) -> Path {
            // ベジェで正円を近似するときに使う値
            let circleEdgeConstant: CGFloat = 4 * (sqrt(2) - 1) / 3

            let stopRadius = buttonRadius * 5 / 6             // 録画停止中の円の半径
            let stopEdge   = stopRadius * circleEdgeConstant  // 録画停止中の円の角の丸さ

            let isRecordingRadius = buttonRadius / 3       // 録画中の円の半径
            let isRecordingEdge   = isRecordingRadius * 1.1  // 録画中の円の角の丸さ

            // 録画中/停止中の状態と、ボタンがハイライトされている状態を考慮した円の半径と角の丸さ
            let highlighScale = 1 - (isHighlight * 0.14)
            let radius = (stopRadius + (isRecordingRadius - stopRadius) * isRecording) * highlighScale
            let edge   = (stopEdge   + (isRecordingEdge   - stopEdge  ) * isRecording) * highlighScale

            let path = Path { path in
                path.move(to: CGPoint(x: 0, y: -radius));
                path.addCurve(to: CGPoint(x:  radius, y:  0     ), control1: CGPoint(x:  edge  , y: -radius), control2: CGPoint(x:  radius, y: -edge  ))
                path.addCurve(to: CGPoint(x:  0     , y:  radius), control1: CGPoint(x:  radius, y:  edge  ), control2: CGPoint(x:  edge  , y:  radius))
                path.addCurve(to: CGPoint(x: -radius, y:  0     ), control1: CGPoint(x: -edge  , y:  radius), control2: CGPoint(x: -radius, y:  edge  ))
                path.addCurve(to: CGPoint(x:  0     , y: -radius), control1: CGPoint(x: -radius, y: -edge  ), control2: CGPoint(x: -edge  , y: -radius))
                path.closeSubpath()
            }
            .applying(CGAffineTransform(translationX: rect.midX, y: rect.midY))

            return path
        }
    }

    // ドラッグ開始地点とドラッグ中の点が両方ともボタン内にあるかを判定
    private func dragHitTest(_ value: DragGesture.Value) -> Bool {
        let center = CGPoint(x: buttonRadius, y: buttonRadius)
        return ((value.startLocation - center).length <= buttonRadius) &&
               ((value.location      - center).length <= buttonRadius)
    }
}

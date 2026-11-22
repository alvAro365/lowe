import RealityKit
import SwiftUI

/// Lowes vedskog i 3D: Lowe går rundt i skogen og hugger ved.
/// Skogen og styringen ligger i Forest og ControlsView.
@main
struct LoweApp: App {
    var body: some SwiftUI.Scene {
        WindowGroup {
            ForestView()
                .ignoresSafeArea()
                .statusBarHidden(true)
                .persistentSystemOverlays(.hidden)
        }
    }
}

struct ForestView: UIViewRepresentable {
    func makeCoordinator() -> Forest { Forest() }

    func makeUIView(context: Context) -> ARView {
        let view = ARView(frame: .zero, cameraMode: .nonAR, automaticallyConfigureSession: false)
        context.coordinator.attach(to: view)
        return view
    }

    func updateUIView(_ uiView: ARView, context: Context) {}
}

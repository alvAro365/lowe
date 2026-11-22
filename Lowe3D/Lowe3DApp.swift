import RealityKit
import SwiftUI

/// Et lite 3D-forsøk: Lowe går dit man trykker, og hugger kubben på hoggestabben.
/// Egen app ved siden av 2D-spillet, så det er lett å sammenligne.
@main
struct Lowe3DApp: App {
    var body: some Scene {
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

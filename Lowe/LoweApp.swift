import SpriteKit
import SwiftUI

@main
struct LoweApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
        }
    }
}

struct GameView: View {
    @State private var scene = GameScene.make()

    var body: some View {
        SpriteView(scene: scene, preferredFramesPerSecond: 60)
            .ignoresSafeArea()
            .statusBarHidden(true)
            .persistentSystemOverlays(.hidden)
    }
}

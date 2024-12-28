import SwiftUI
import SpriteKit

var globalScale: CGFloat = 5.0;


#if os(iOS)
import UIKit
typealias Color = UIColor
#elseif os(macOS)
import AppKit
typealias Color = NSColor
#endif

@main
struct CuteCrittersApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        Settings {
            SettingsView()
        }
        #endif
    }
}

struct ContentView: View {
    var body: some View {
        GameView()
            .edgesIgnoringSafeArea(.all)
    }
}

struct GameView: View {
    var body: some View {
        SpriteKitContainer()
            .edgesIgnoringSafeArea(.all)
    }
}

struct SettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
        Form {
            Toggle("Enable Dark Mode", isOn: $isDarkMode)
        }
        .padding()
        .frame(width: 300, height: 150)
    }
}

#if os(iOS)
struct SpriteKitContainer: UIViewRepresentable {
    func makeUIView(context: Context) -> SKView {
           let skView = SKView()
           let scene = CritterGameScene(size: CGSize(width: 300, height: 360))
           scene.scaleMode = .aspectFit
           skView.presentScene(scene)
           return skView
       }

       func updateUIView(_ uiView: SKView, context: Context) {}
}
#endif

#if os(macOS)
struct SpriteKitContainer: NSViewRepresentable {
    func makeNSView(context: Context) -> SKView {
          let skView = SKView()
          let scene = CritterGameScene(size: CGSize(width: 300, height: 360))
          scene.scaleMode = .aspectFit
          skView.presentScene(scene)
          return skView
      }

      func updateNSView(_ nsView: SKView, context: Context) {}
}
#endif

extension SKSpriteNode {
    func alignBottom(to y: CGFloat) {
        let scaledHeight = self.size.height * self.yScale
        self.position.y = y + (scaledHeight / 2)
    }
}





// MARK: - Game Scene
class CritterGameScene: SKScene {
    private var timePanel: SKSpriteNode!
    private var timeLabel: SKLabelNode!
    
    private var background: SKSpriteNode! // Class-level property for the background

    
    
    private var cat: SKSpriteNode!
    private var clouds: [SKSpriteNode] = []
    private var grassBase: SKSpriteNode! // Solid green rectangle
    private var decorativeGrass: [SKSpriteNode] = [] // Grass sprites on top
    private var trees: [SKSpriteNode] = []
    private var mountains: SKSpriteNode!
    
    private var currentCatFrameIndex: Int = 0
    private var isCatIdle: Bool = true
    private var catFacingRight: Bool = true
    
    private var movingRight = true
    private var isMoving = false
    private let movementBoundaryLeft: CGFloat = 50
    private let movementBoundaryRight: CGFloat = 250
    
    private let grassHeight: CGFloat = 40 // Define grass height constant
    
    
    private var lastFrameTime: TimeInterval = 0
    private var frameInterval: TimeInterval = 0.2 // Time between frames
    
    
    private var fpsLabel: SKLabelNode! // FPS counter
        
        private var lastUpdateTime: TimeInterval = 0
        private var frameCount: Int = 0
        private var elapsedTime: TimeInterval = 0
    
    private var thoughtBubble: SKNode!
    private var showThought: Bool = false
    
    
    override func didMove(to view: SKView) {
        setupFPSLabel()
        setupBackground()
        setupGrass()
        setupMountains()
        setupTrees()
        setupCat()
        setupClouds()
        setupThoughtBubble()
        setupLampPost() // Add the lamp post

        setupDarkOverlay()
        
        setupTimePanel() // Ensure this is called before updating the time
        setupLighting()

        startNaturalMovement() // Start the AI behavior loop
        adjustBackgroundForTime() // Initialize the background
        adjustLampLightForTime() // Set initial lamp light state


    }
    
    
    
    private func getCurrentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a" // e.g., 09:43 PM
        return formatter.string(from: Date())
    }
    
    
#if os(iOS)
override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    guard let touch = touches.first else { return }
    let location = touch.location(in: self)
    handleInput(at: location)
}
#endif

#if os(macOS)
override func mouseDown(with event: NSEvent) {
    let location = event.location(in: self)
    handleInput(at: location)
}
#endif
    
    
    private func handleInput(at location: CGPoint) {
        // Check if the tap/click is on the cat
        if cat.contains(location) {
            showThoughtBubble()
        }
        
        if(lampPost.contains(location)){
            toggleLampPost();
        }
    }
    

    
    
    private func setupFPSLabel() {
           fpsLabel = SKLabelNode(fontNamed: "Menlo")
           fpsLabel.fontSize = 16
           fpsLabel.fontColor = .white
           fpsLabel.horizontalAlignmentMode = .left
           fpsLabel.verticalAlignmentMode = .top
           fpsLabel.position = CGPoint(x: 10, y: size.height - 10) // Top-left corner
           fpsLabel.zPosition = 10
           addChild(fpsLabel)
       }
    
    
    private func setupTimePanel() {
        timePanel = SKSpriteNode(imageNamed: "Panel_grey")
        timePanel.setScale(1.5) // Adjust scale to fit your scene
        timePanel.texture?.filteringMode = .nearest
        timePanel.size.width = 100
        timePanel.position = CGPoint(x: timePanel.size.width / 2 + 10, // Offset for padding
                                     y: size.height - timePanel.size.height / 2 - 10) // Offset from the top
        timePanel.zPosition = 5 // Ensure it is above other elements
        addChild(timePanel)

        timeLabel = SKLabelNode(fontNamed: "Menlo")
        timeLabel.fontSize = 12
        timeLabel.fontColor = .white
        timeLabel.position = CGPoint(x: 0, y: 0) // Centered within the panel
        timeLabel.zPosition = 6 // Above the panel
        timeLabel.text = getCurrentTimeString() // Initialize with current time
        timePanel.addChild(timeLabel) // Add it to the panel
    }
    
    private func setupThoughtBubble() {
        // Create bubble container
        thoughtBubble = SKNode()
        thoughtBubble.position = CGPoint(x: 10, y: 4) //since it's appending to cat be 10 px above
        thoughtBubble.zPosition = 10 // Ensure it's above other elements
        thoughtBubble.alpha = 0 // Initially invisible
        
        // Bubble sprite
        let bubbleImage = SKSpriteNode(imageNamed: "ChatBubble_white")
        bubbleImage.setScale(0.5)
        bubbleImage.texture?.filteringMode = .nearest
        bubbleImage.position = .zero
        
        // Heart sprite
        let heartImage = SKSpriteNode(imageNamed: "heart")
        heartImage.setScale(0.4)
        heartImage.position = .zero
        heartImage.texture?.filteringMode = .nearest

        
        // Add sprites to bubble container
        thoughtBubble.addChild(bubbleImage)
        thoughtBubble.addChild(heartImage)
        
        // Attach bubble to cat
        cat.addChild(thoughtBubble)
    }
    
    private func toggleLampPost(){
        // check if lampost is on
        if lampLight.alpha == 0 {
            lampLight.alpha = 1
        } else {
            lampLight.alpha = 0

        }
        
    }
    
    
    
    private func showThoughtBubble() {
        
        if showThought { return } // Avoid overlapping animations
        showThought = true
        
      


        // Show bubble with fade-in effect
        let fadeIn = SKAction.fadeAlpha(to: 1, duration: 0.2)
        thoughtBubble.run(fadeIn)
        
        // Schedule bubble to disappear after 2 seconds
        let wait = SKAction.wait(forDuration: 2.0)
        let fadeOut = SKAction.fadeAlpha(to: 0, duration: 0.2)
        let resetState = SKAction.run { [weak self] in
            self?.showThought = false
        }
        let sequence = SKAction.sequence([wait, fadeOut, resetState])
        thoughtBubble.run(sequence)
    }
    
    private func adjustBackgroundForTime() {
        let hour = Calendar.current.component(.hour, from: Date())
        var skyColors: [CGColor]
        
        print("hour \(hour)")
        
        switch hour {
        case 6...8: // Early morning
            skyColors = [
                Color(red: 1.0, green: 0.6, blue: 0.4, alpha: 1.0).cgColor, // Warm orange
                Color(red: 0.8, green: 0.8, blue: 1.0, alpha: 1.0).cgColor  // Soft blue
            ]
        case 9...17: // Daytime
            skyColors = [
                Color(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0).cgColor, // Bright blue
                Color(red: 0.8, green: 0.9, blue: 1.0, alpha: 1.0).cgColor  // Light blue
            ]
        case 18...20: // Evening
            skyColors = [
                Color(red: 0.8, green: 0.5, blue: 1.0, alpha: 1.0).cgColor, // Purple
                Color(red: 0.2, green: 0.2, blue: 0.5, alpha: 1.0).cgColor  // Dark blue
            ]
        default: // Nighttime
            skyColors = [
                Color(red: 0.1, green: 0.1, blue: 0.2, alpha: 1.0).cgColor, // Deep navy
                Color(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0).cgColor  // Black
            ]
        }

        // Create a new gradient texture
        let gradientTexture = SKTexture.gradientTexture(size: size, colors: skyColors, locations: [0.0, 1.0])
        
        background.texture = gradientTexture

      
    }
    
    
    private var darkOverlay: SKSpriteNode!

    private func setupDarkOverlay() {
        darkOverlay = SKSpriteNode(color: Color.black.withAlphaComponent(0.0), size: size)
        darkOverlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        darkOverlay.zPosition = 10 // Above everything else
        darkOverlay.blendMode = .alpha
        addChild(darkOverlay)
    }

    private func adjustDarknessForTime() {
        let hour = Calendar.current.component(.hour, from: Date())
        var darknessAlpha: CGFloat = 0.0
        
        switch hour {
        case 18...20: // Evening, slight darkness
            darknessAlpha = 0.3
        case 21...23, 0...5: // Nighttime, fully dark
            darknessAlpha = 0.6
        default: // Daytime
            darknessAlpha = 0.0
        }
        
        let fadeAction = SKAction.fadeAlpha(to: darknessAlpha, duration: 1.0)
        darkOverlay.run(fadeAction)
    }
    
    
    private var lightNode: SKLightNode!

    private func setupLighting() {
        lightNode = SKLightNode()
        lightNode.categoryBitMask = 1
        lightNode.falloff = 2.0
        lightNode.ambientColor = .white
        lightNode.lightColor = Color.white
        lightNode.position = CGPoint(x: size.width / 2, y: size.height)
        addChild(lightNode)
    }
    
    
    private func adjustLightingForTime() {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 6...8: // Morning
            lightNode.lightColor = Color(red: 1.0, green: 0.8, blue: 0.6, alpha: 1.0)
            lightNode.ambientColor = Color(red: 0.8, green: 0.8, blue: 1.0, alpha: 1.0)
        case 9...17: // Day
            lightNode.lightColor = Color.white
            lightNode.ambientColor = Color.white
        case 18...20: // Evening
            lightNode.lightColor = Color(red: 0.8, green: 0.5, blue: 1.0, alpha: 1.0)
            lightNode.ambientColor = Color(red: 0.4, green: 0.4, blue: 0.8, alpha: 1.0)
        default: // Night
            lightNode.lightColor = Color(red: 0.2, green: 0.2, blue: 0.4, alpha: 1.0)
            lightNode.ambientColor = Color(red: 0.1, green: 0.1, blue: 0.2, alpha: 1.0)
        }
    }

    override func update(_ currentTime: TimeInterval) {
            super.update(currentTime)
        
    
        adjustDarknessForTime()
        adjustLightingForTime()
  
        
        
        // Update the time and background periodically
           if Int(currentTime) % 1 == 0 { // Every second
               timeLabel.text = getCurrentTimeString()
               adjustBackgroundForTime()
           }

            if lastUpdateTime == 0 {
                lastUpdateTime = currentTime
            }

            // Calculate delta time and increment counters
            let deltaTime = currentTime - lastUpdateTime
            lastUpdateTime = currentTime
            elapsedTime += deltaTime
            frameCount += 1

            // Update FPS every second
            if elapsedTime >= 1.0 {
                let fps = Int(Double(frameCount) / elapsedTime)
                fpsLabel.text = "FPS: \(fps)"
                frameCount = 0
                elapsedTime = 0
            }

            // Update animations
            if deltaTime >= frameInterval {
                if isMoving {
                    updateWalkingAnimation()
                } else {
                    updateIdleAnimation()
                }
            }
        }
    
    private func startNaturalMovement() {
        guard !isMoving else { return } // Avoid overlapping movements
        isMoving = true
        
        // Choose a random target within boundaries
        let targetX = CGFloat.random(in: movementBoundaryLeft...movementBoundaryRight)
        let moveDuration = TimeInterval(abs(cat.position.x - targetX) / 50.0) // Adjust speed (50 points/sec)
        
        // Determine direction and update facing
        if targetX > cat.position.x {
            cat.xScale = globalScale // Face right
        } else {
            cat.xScale = -globalScale // Face left
        }
        
        // Start walking animation
        startWalkingAnimation()
        
        // Move to target position
        let moveAction = SKAction.moveTo(x: targetX, duration: moveDuration)
        cat.run(moveAction) { [weak self] in
            guard let self = self else { return }
            self.isMoving = false
            self.startIdleAnimation() // Rest after reaching position
            
            // Random rest duration before moving again
            let restDuration = TimeInterval.random(in: 2.0...4.0)
            self.run(SKAction.wait(forDuration: restDuration)) {
                self.startNaturalMovement() // Start moving again
            }
        }
    }

    private func startWalkingAnimation() {
        cat.removeAction(forKey: "idle") // Stop idle animation if running
        let walkAction = SKAction.animate(with: catWalkFrames, timePerFrame: 0.2)
        cat.run(SKAction.repeatForever(walkAction), withKey: "walk")
    }

    private func startIdleAnimation() {
        cat.removeAction(forKey: "walk") // Stop walking animation if running
        let idleAction = SKAction.animate(with: catIdleFrames, timePerFrame: 0.5)
        cat.run(SKAction.repeatForever(idleAction), withKey: "idle")
    }
        
        private func updateIdleAnimation() {
            currentCatFrameIndex = (currentCatFrameIndex + 1) % catIdleFrames.count
            cat.texture = catIdleFrames[currentCatFrameIndex]
        }
        
        private func updateWalkingAnimation() {
            currentCatFrameIndex = (currentCatFrameIndex + 1) % catWalkFrames.count
            cat.texture = catWalkFrames[currentCatFrameIndex]
        }
        
    
    private let catIdleFrames: [SKTexture] = {
        let frames = [
            "cat_orange-idle_1",
            "cat_orange-idle_2",
            "cat_orange-idle_3"
        ].map { SKTexture(imageNamed: $0) }
        frames.forEach { $0.filteringMode = .nearest }
        return frames
    }()
    
    private let catWalkFrames: [SKTexture] = {
        let frames = [
            "cat_orange-move_1",
            "cat_orange-move_2",
            "cat_orange-move_3",
            "cat_orange-move_4"
        ].map { SKTexture(imageNamed: $0) }
        frames.forEach { $0.filteringMode = .nearest }
        return frames
    }()
    
    
    
    private var lampPost: SKSpriteNode!
    private var lampLight: SKLightNode!

    private func setupLampPost() {
        // Create the lamp post
        lampPost = SKSpriteNode(imageNamed: "LampPost")
        lampPost.setScale(3.0) // Adjust scale as needed
        lampPost.position = CGPoint(x: size.width / 2, y: grassHeight + lampPost.size.height / 2) // Position on the ground
        lampPost.lightingBitMask = 1
        lampPost.zPosition = 3 // Above grass, below the cat
        lampPost.texture?.filteringMode = .nearest        // Add the light node
        

        addChild(lampPost)
        lampLight = SKLightNode()
        lampLight.categoryBitMask = 1 // Category for light
        lampLight.falloff = 1.2 // How quickly light dims over distance
        lampLight.lightColor = Color.white
        lampLight.ambientColor = Color(white: 0.2, alpha: 1.0) // Low ambient light
        lampLight.position = CGPoint(x: 0, y: 14) // At the top of the lamp post
        lampPost.addChild(lampLight) // Attach the light to the lamp post
    }
    
    private func adjustLampLightForTime() {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 6 || hour > 18 { // Nighttime
            lampLight.isEnabled = true
            lampLight.lightColor = Color.white.withAlphaComponent(0.8) // Bright white light
        } else {
            lampLight.isEnabled = false // Disable light during daytime
        }
    }
    
   
    
    private func setupBackground() {
        let gradientTexture = SKTexture.gradientTexture(
            size: size,
            colors: [Color(red: 52/255.0, green: 107/255.0, blue: 211/255.0, alpha: 1.0).cgColor, Color(red: 143/255.0, green: 211/255.0, blue: 255/255.0, alpha: 1.0).cgColor],
            locations: [0.0, 1.0]
        )
         background = SKSpriteNode(texture: gradientTexture)
        background.position = CGPoint(x: size.width / 2, y: size.height / 2)
        background.zPosition = -2
        addChild(background)
    }
    
    private func setupGrass() {
        // Create the solid grass base rectangle
        grassBase = SKSpriteNode(color: Color(red: 30/255, green: 188/255, blue: 115/255, alpha: 1.0),
                                 size: CGSize(width: size.width, height: grassHeight))
        grassBase.position = CGPoint(x: size.width / 2, y: grassHeight / 2)
        grassBase.zPosition = -1
        grassBase.lightingBitMask = 1

        
       
        addChild(grassBase)
        
        // Add decorative grass sprites on top
        for i in 0..<3 {
            let grassSprite = SKSpriteNode(imageNamed: "Grass_large_1")
            grassSprite.texture?.filteringMode = .nearest
            grassSprite.setScale(4)
            grassSprite.position = CGPoint(x: CGFloat(80 + (i * 100)), y: grassHeight + (grassSprite.size.height / 2))
            grassSprite.zPosition = 2
            grassSprite.lightingBitMask = 1

            decorativeGrass.append(grassSprite)
            addChild(grassSprite)
        }
        
        let smallGrass = [
            "Grass_small_1",
            "Grass_small_2",
            "Grass_small_3",

        ]
        
        // Add decorative grass sprites on top
        for i in 1..<5 {
            print(smallGrass[(i % smallGrass.count)])
            let grassSprite = SKSpriteNode(imageNamed: smallGrass[(i % smallGrass.count)])
            grassSprite.texture?.filteringMode = .nearest
            grassSprite.setScale(4)
            grassSprite.position = CGPoint(x: CGFloat(0 + (i * 100)), y: grassHeight + (grassSprite.size.height / 2))
            grassSprite.zPosition = 2
            grassSprite.lightingBitMask = 1
            decorativeGrass.append(grassSprite)
            addChild(grassSprite)
        }
    }
    
    private func setupMountains() {
        mountains = SKSpriteNode(imageNamed: "Mountain_medium_snowy_2")
        mountains.setScale(2.5)
        mountains.texture?.filteringMode = .nearest
        mountains.position = CGPoint(x: size.width / 2, y: grassHeight + mountains.size.height/2)
        mountains.zPosition = 0
        mountains.lightingBitMask = 1
        addChild(mountains)
    }
    
    private func setupTrees() {
        let treePositions = [
            CGPoint(x: 50, y: 0),
            CGPoint(x: 200, y: 0)
        ]
        
        for position in treePositions {
            let tree = SKSpriteNode(imageNamed: "tree")
            tree.setScale(3)
            tree.texture?.filteringMode = .nearest
            tree.position = position
            tree.zPosition = 1
            tree.position.y = grassHeight + (tree.size.height / 2);
            tree.lightingBitMask = 1

            trees.append(tree)
            addChild(tree)
        }
    }
    
    private func setupCat() {
        cat = SKSpriteNode(texture: catIdleFrames[0])
        cat.setScale(globalScale)
        cat.position = CGPoint(x: size.width / 2, y: grassHeight + (cat.size.height / 2))
        cat.zPosition = 2
        cat.lightingBitMask = 1

        addChild(cat)
        startCatIdleAnimation()
    }
    
    private func startCatIdleAnimation() {
        let idleAction = SKAction.animate(with: catIdleFrames, timePerFrame: 0.5)
        let repeatAction = SKAction.repeatForever(idleAction)
        cat.run(repeatAction, withKey: "idle")
    }
    
    private func setupClouds() {
        for i in 0...1 {
            let cloud = SKSpriteNode(imageNamed: "cloud")
            cloud.texture?.filteringMode = .nearest
            cloud.setScale(3)
            cloud.position = CGPoint(x: -100 - CGFloat(i * 200), y: size.height - CGFloat(50 + i * 30))
            cloud.zPosition = -1

            clouds.append(cloud)
            addChild(cloud)
            
            let moveRight = SKAction.moveBy(x: size.width + 200, y: 0, duration: 50)
            let resetPosition = SKAction.moveBy(x: -(size.width + 200), y: 0, duration: 0)
            let sequence = SKAction.sequence([moveRight, resetPosition])
            cloud.run(SKAction.repeatForever(sequence))
        }
    }
    
 
}

extension SKTexture {
    static func gradientTexture(size: CGSize, colors: [CGColor], locations: [CGFloat]) -> SKTexture {
        #if os(iOS)
        let renderer = UIGraphicsImageRenderer(size: size)
        let image = renderer.image { context in
            let cgContext = context.cgContext
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations)!
            let startPoint = CGPoint(x: 0, y: size.height)
            let endPoint = CGPoint(x: 0, y: 0)
            cgContext.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
        }
        return SKTexture(image: image)

        #elseif os(macOS)
        let image = NSImage(size: size)
        image.lockFocus()
        guard let cgContext = NSGraphicsContext.current?.cgContext else {
            image.unlockFocus()
            return SKTexture()
        }
        let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors as CFArray, locations: locations)!
        let startPoint = CGPoint(x: 0, y: size.height)
        let endPoint = CGPoint(x: 0, y: 0)
        cgContext.drawLinearGradient(gradient, start: startPoint, end: endPoint, options: [])
        image.unlockFocus()
        return SKTexture(image: image)
        #endif
    }
}

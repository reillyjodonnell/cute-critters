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

    // MARK: - Properties
    private var timePanel: SKSpriteNode!
    private var timeLabel: SKLabelNode!
    private var background: SKSpriteNode!
    private var cat: SKSpriteNode!
    private var clouds: [SKSpriteNode] = []
    private var grassBase: SKSpriteNode!
    private var decorativeGrass: [SKSpriteNode] = []
    private var trees: [SKSpriteNode] = []
    private var mountains: SKSpriteNode!
    private var lampPost: SKSpriteNode!
    private var lampLight: SKLightNode!
    private var darkOverlay: SKSpriteNode!
    private var lightNode: SKLightNode!
    private var thoughtBubble: SKNode!
    
    // MARK: - Static Resources
    private static let catIdleFrames: [SKTexture] = {
        let frames = ["cat_orange-idle_1", "cat_orange-idle_2", "cat_orange-idle_3"]
        return frames.map { name in
            let texture = SKTexture(imageNamed: name)
            texture.filteringMode = .nearest
            return texture
        }
    }()
    
    private static let catWalkFrames: [SKTexture] = {
        let frames = ["cat_orange-move_1", "cat_orange-move_2", "cat_orange-move_3", "cat_orange-move_4"]
        return frames.map { name in
            let texture = SKTexture(imageNamed: name)
            texture.filteringMode = .nearest
            return texture
        }
    }()
    
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm a"
        return formatter
    }()
    // MARK: - State Properties
    private var currentCatFrameIndex: Int = 0
    private var isCatIdle: Bool = true
    private var catFacingRight: Bool = true
    private var movingRight = true
    private var isMoving = false
    private var showThought: Bool = false
    private var currentHour: Int = Calendar.current.component(.hour, from: Date()) {
        didSet {
            if currentHour != oldValue {
                updateTimeBasedElements()
            }
        }
    }
    
   

    
    // MARK: - Constants
    private let movementBoundaryLeft: CGFloat = 50
    private let movementBoundaryRight: CGFloat = 250
    private let grassHeight: CGFloat = 40
    private let frameInterval: TimeInterval = 0.2
    
    // MARK: - Time Tracking
    private var lastFrameTime: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private var frameCount: Int = 0
    private var elapsedTime: TimeInterval = 0
    
    // MARK: - Lighting Configuration
    private struct LightConfiguration {
        let lightColor: Color
        let ambientColor: Color
        let darknessAlpha: CGFloat
        let isLampEnabled: Bool
        let lampColor: Color
        let skyColors: [CGColor]
    }
    
    
    override func didMove(to view: SKView) {
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
        setupShopIcon()
        setupShopMenu()
        
        startNaturalMovement() // Start the AI behavior loop
        adjustBackgroundForTime() // Initialize the background
        adjustLampLightForTime() // Set initial lamp light state
        
        
    }
    
    // MARK: - Update Loop
    override func update(_ currentTime: TimeInterval) {
        super.update(currentTime)
        
        
        let newHour = Calendar.current.component(.hour, from: Date())
        if newHour != currentHour {
            currentHour = newHour
        }
        timeLabel.text = getCurrentTimeString()
        
        
        // Animation updates
        if currentTime - lastUpdateTime >= frameInterval {
            lastUpdateTime = currentTime
            if isMoving {
                updateWalkingAnimation()
            } else if !showThought {
                updateIdleAnimation()
            }
        }
    }
    
    // MARK: - Input
    
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
        
        // Check if the tap/click is on the lamp post
        if lampPost.contains(location) {
            toggleLampPost()
        }
        
        if let shopTab = childNode(withName: "shopTab"), shopTab.contains(location) {
            showSidebar()
               return
           }

        
        // Check if the tap/click is on the close button
        if let closeButton = childNode(withName: "//sidebarNode/closeButton"), closeButton.contains(location) {
            hideSidebar()
               return
           }
    }
    private var isSidebarVisible = false

    private func showSidebar() {
        guard let sidebarNode = childNode(withName: "sidebarNode") else { return }
        let slideInAction = SKAction.moveTo(x: 0, duration: 0.3) // Move into view
        slideInAction.timingMode = .easeInEaseOut
        sidebarNode.run(slideInAction)
    }

    private func hideSidebar() {
        guard let sidebarNode = childNode(withName: "sidebarNode") else {
            print("Sidebar node not found")
            return
        }


        // Explicit width and clearing existing actions
        let panelWidth: CGFloat = 160
        sidebarNode.removeAllActions()

        let slideOutAction = SKAction.moveTo(x: -panelWidth, duration: 0.3) // Move out of view
        slideOutAction.timingMode = .easeInEaseOut

        sidebarNode.run(slideOutAction)
    }
    
    private func toggleLampPost(){
        // check if lampost is on
        if lampLight.alpha == 0 {
            lampLight.alpha = 1
        } else {
            lampLight.alpha = 0
            
        }
        
    }
    
    // MARK: - Setup
    private func setupTimePanel() {
        // Setup the time panel
        timePanel = SKSpriteNode(imageNamed: "Panel_grey")
        timePanel.size = CGSize(width: 120, height: 40)
        timePanel.normalTexture?.filteringMode = .nearest
        let topLeftX = timePanel.size.width / 2
        let topLeftY = (scene?.size.height ?? 0) - timePanel.size.height / 2
        timePanel.position = CGPoint(x: topLeftX, y: topLeftY - 20)
        addChild(timePanel)
        
        // Setup the image
        let image = SKSpriteNode(imageNamed: "Clock_1_black")
        let imageWidth = timePanel.size.height * 0.6 // Dynamic width as 60% of panel height
        image.size = CGSize(width: imageWidth, height: imageWidth)
        image.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        image.texture?.filteringMode = .nearest
        
        // Setup the time label
        timeLabel = SKLabelNode(fontNamed: "Tiny5-Regular")
        timeLabel.fontSize = 22
        timeLabel.fontColor = .white
        timeLabel.text = getCurrentTimeString()
        timeLabel.verticalAlignmentMode = .center
        timeLabel.horizontalAlignmentMode = .left
        
        // Calculate total content width
        let totalContentWidth = image.size.width + timeLabel.frame.width
        
        // Calculate space between elements
        // We have 2 elements (image and label) which creates 3 spaces (left edge, between elements, right edge)
        let numberOfSpaces = 3
        let availableWidth = timePanel.size.width
        let spacing = (availableWidth - totalContentWidth) / CGFloat(numberOfSpaces)
        
        // Position image with even spacing from left edge
        image.position = CGPoint(x: -timePanel.size.width/2 + spacing + image.size.width/2, y: 0)
        
        // Position label with even spacing after image
        timeLabel.position = CGPoint(x: image.position.x + image.size.width/2 + spacing, y: 0)
        
        // Add elements to the panel
        timePanel.addChild(image)
        timePanel.addChild(timeLabel)
    }
    
    private func setupShopIcon() {
        
        
        let panel = SKSpriteNode(imageNamed: "Panel_grey")
        panel.size = CGSize(width: 100, height: 40)
        panel.position = CGPoint(x: panel.size.width / 2, y: (panel.size.height / 2) + 10)
        panel.name = "shopTab" // Assign a name for input detection
        panel.zPosition = 100
        addChild(panel)

        // Setup the image on the left side
        let image = SKSpriteNode(imageNamed: "Package")
        image.size = CGSize(width: 20, height: 20)
        image.anchorPoint = CGPoint(x: 0.5, y: 0.5) // Center the image on its position
        image.position = CGPoint(x: -panel.size.width / 2 + image.size.width / 2 + 10, // Offset slightly to the right
                                 y: 0) // Vertically centered
        image.texture?.filteringMode = .nearest
        panel.addChild(image)

        // Setup the label on the right side
        let label = SKLabelNode(fontNamed: "Tiny5-Regular")
        label.fontSize = 22
        label.fontColor = .white
        label.text = "SHOP"
        label.verticalAlignmentMode = .center // Vertically center the text
        label.horizontalAlignmentMode = .left // Align text to the left of its position
        label.position = CGPoint(x: image.position.x + image.size.width / 2 + 10, // Offset to the right of the image
                                 y: 0) // Vertically centered
        panel.addChild(label)
    }
    
    private func setupShopMenu() {
        let panelWidth: CGFloat = 160
        let panelHeight: CGFloat = 260
        let tileSize: CGFloat = 8 // each panel is 8x8px
        let tilesAcross = Int(panelWidth / tileSize)
        let tilesDown = Int(panelHeight / tileSize)

        // Create a parent node for the sidebar
        let sidebarNode = SKNode()
        sidebarNode.name = "sidebarNode"
        sidebarNode.position = CGPoint(x: -panelWidth, y: 0) // Render off-screen to the left
        addChild(sidebarNode) // Add the sidebar node to the scene

        let panelOrigin = CGPoint(x: panelWidth / 2, y: panelHeight / 2)

        for row in 0..<tilesDown {
            for col in 0..<tilesAcross {
                let tileName = return9By9SlicePosition(coordinate: (row: row, col: col), width: tilesDown, height: tilesAcross)
                let tile = SKSpriteNode(imageNamed: tileName)
                tile.size = CGSize(width: tileSize, height: tileSize)
                tile.texture?.filteringMode = .nearest

                // Calculate position for this tile
                let xPos = panelOrigin.x + CGFloat(col) * tileSize - panelWidth / 2
                let yPos = panelOrigin.y - CGFloat(row) * tileSize + panelHeight / 2

                tile.position = CGPoint(x: xPos, y: yPos)
                tile.zPosition = 10
                sidebarNode.addChild(tile) // Add each tile to the sidebar node
            }
        }

        // Add Close Button
        let closeButton = SKSpriteNode(imageNamed: "Close")
        closeButton.size = CGSize(width: 32, height: 32)
        closeButton.texture?.filteringMode = .nearest
        closeButton.position = CGPoint(x: panelWidth - (closeButton.size.width / 2) - 10, y: (panelHeight - (closeButton.size.height / 2) - 10)) // Adjust based on your layout
        closeButton.zPosition = 20
        closeButton.name = "closeButton"
        sidebarNode.addChild(closeButton) // Add close button to the sidebar node
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
    
    private func setupDarkOverlay() {
        darkOverlay = SKSpriteNode(color: Color.black.withAlphaComponent(0.0), size: size)
        darkOverlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        darkOverlay.zPosition = 10 // Above everything else
        darkOverlay.blendMode = .alpha
        addChild(darkOverlay)
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
        // Define a palette of potential dirt colors
        let dirtColors: [Color] = [
            Color(red: 158/255, green: 69/255, blue: 56/255, alpha: 1.0),  // Base dirt color
            Color(red: 140/255, green: 60/255, blue: 48/255, alpha: 1.0),  // Slightly darker
            Color(red: 170/255, green: 80/255, blue: 60/255, alpha: 1.0),  // Slightly lighter
            Color(red: 145/255, green: 65/255, blue: 50/255, alpha: 1.0)   // Another variant
        ]
        
        // Define a palette of grass colors
        let grassColors: [Color] = [
            Color(red: 34/255, green: 144/255, blue: 98/255, alpha: 1.0),  // Base grass color
            Color(red: 30/255, green: 130/255, blue: 90/255, alpha: 1.0),  // Slightly darker
            Color(red: 40/255, green: 150/255, blue: 110/255, alpha: 1.0)  // Slightly lighter
        ]
        
        // Function to randomly pick a color from a palette
        func randomColor(from palette: [Color]) -> Color {
            return palette.randomElement()!
        }
        
        // Generate the grass blocks with randomness
        for i in 0..<Int(size.width / 10) {
            let grassColor = randomColor(from: grassColors) // Randomly select from grassColors
            let grassBlock = SKSpriteNode(color: grassColor, size: CGSize(width: 10, height: grassHeight))
            grassBlock.position = CGPoint(x: CGFloat(i) * 10 + 5, y: grassHeight / 2)
            grassBlock.zPosition = -1
            grassBlock.lightingBitMask = 1
            addChild(grassBlock)
        }
        
        // Generate the dirt blocks with randomness
        for i in 0..<Int(size.width / 10) {
            let dirtColor = randomColor(from: dirtColors) // Randomly select from dirtColors
            let dirtBlock = SKSpriteNode(color: dirtColor, size: CGSize(width: 10, height: 4/5 * grassHeight))
            dirtBlock.position = CGPoint(x: CGFloat(i) * 10 + 5, y: (4/5 * grassHeight) / 2)
            dirtBlock.zPosition = -1
            dirtBlock.lightingBitMask = 1
            addChild(dirtBlock)
        }
        
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
    
    // MARK: - Time Panel
    private func updateTimeAndLighting() {
        timeLabel.text = getCurrentTimeString()
        adjustLightingForTime()
    }
    
    private func getCurrentTimeString() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "hh:mm"
        return formatter.string(from: Date())
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
    
    
    
    // MARK: - Time Management
    private func updateTimeBasedElements() {
        let config = getLightConfiguration(for: currentHour)
        
        // Update all time-based elements in a single pass
        lightNode.lightColor = config.lightColor
        lightNode.ambientColor = config.ambientColor
        darkOverlay.run(SKAction.fadeAlpha(to: config.darknessAlpha, duration: 1.0))
        
        lampLight.isEnabled = config.isLampEnabled
        if lampLight.isEnabled {
            lampLight.lightColor = config.lampColor
        }
        
        background.texture = SKTexture.gradientTexture(
            size: size,
            colors: config.skyColors,
            locations: [0.0, 1.0]
        )
    }
    
    private func getLightConfiguration(for hour: Int) -> LightConfiguration {
        switch hour {
        case 6...8: // Morning
            return LightConfiguration(
                lightColor: Color(red: 1.0, green: 0.8, blue: 0.6, alpha: 1.0),
                ambientColor: Color(red: 0.8, green: 0.8, blue: 1.0, alpha: 1.0),
                darknessAlpha: 0.0,
                isLampEnabled: false,
                lampColor: .clear,
                skyColors: [
                    Color(red: 1.0, green: 0.6, blue: 0.4, alpha: 1.0).cgColor,
                    Color(red: 0.8, green: 0.8, blue: 1.0, alpha: 1.0).cgColor
                ]
            )
            
        case 9...17: // Day
            return LightConfiguration(
                lightColor: .white,
                ambientColor: .white,
                darknessAlpha: 0.0,
                isLampEnabled: false,
                lampColor: .clear,
                skyColors: [
                    Color(red: 0.4, green: 0.7, blue: 1.0, alpha: 1.0).cgColor,
                    Color(red: 0.8, green: 0.9, blue: 1.0, alpha: 1.0).cgColor
                ]
            )
            
        case 18...20: // Evening
            return LightConfiguration(
                lightColor: Color(red: 0.8, green: 0.5, blue: 1.0, alpha: 1.0),
                ambientColor: Color(red: 0.4, green: 0.4, blue: 0.8, alpha: 1.0),
                darknessAlpha: 0.3,
                isLampEnabled: true,
                lampColor: Color.white.withAlphaComponent(0.8),
                skyColors: [
                    Color(red: 0.8, green: 0.5, blue: 1.0, alpha: 1.0).cgColor,
                    Color(red: 0.2, green: 0.2, blue: 0.5, alpha: 1.0).cgColor
                ]
            )
            
        default: // Night
            return LightConfiguration(
                lightColor: Color(red: 0.2, green: 0.2, blue: 0.4, alpha: 1.0),
                ambientColor: Color(red: 0.1, green: 0.1, blue: 0.2, alpha: 1.0),
                darknessAlpha: 0.6,
                isLampEnabled: true,
                lampColor: Color.white.withAlphaComponent(0.8),
                skyColors: [
                    Color(red: 0.1, green: 0.1, blue: 0.2, alpha: 1.0).cgColor,
                    Color(red: 0.0, green: 0.0, blue: 0.0, alpha: 1.0).cgColor
                ]
            )
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
    
    
    private func startCatIdleAnimation() {
        let idleAction = SKAction.animate(with: catIdleFrames, timePerFrame: 0.5)
        let repeatAction = SKAction.repeatForever(idleAction)
        cat.run(repeatAction, withKey: "idle")
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


func return9By9SlicePosition(coordinate: (row: Int, col: Int), width: Int, height: Int) -> String {
    let tileNames = [
        ["Panel_grey_1", "Panel_grey_2", "Panel_grey_3"], // Top row
        ["Panel_grey_4", "Panel_grey_5", "Panel_grey_6"], // Middle row
        ["Panel_grey_7", "Panel_grey_8", "Panel_grey_9"]  // Bottom row
    ]
    
   
    
    let (row, col) = coordinate // Unpack coordinate
    
    
    
   
    // Determine tile name based on the coordinate
    var tileName: String
    
    if row == 0 { // Top row
        if col == 0 {
            tileName = tileNames[0][0] // Top-left
        } else if col == height - 1 {
            tileName = tileNames[0][2] // Top-right
        } else {
            tileName = tileNames[0][1] // Top-center
        }
    } else if row == width - 1 { // Bottom row
        if col == 0 {
            tileName = tileNames[2][0] // Bottom-left
        } else if col == height - 1 {
            tileName = tileNames[2][2] // Bottom-right
        } else {
            tileName = tileNames[2][1] // Bottom-center
        }
    } else { // Middle row
        if col == 0 {
            tileName = tileNames[1][0] // Middle-left
        } else if col == height - 1 {
            tileName = tileNames[1][2] // Middle-right
        } else {
            tileName = tileNames[1][1] // Center
        }
    }
    
    return tileName
}

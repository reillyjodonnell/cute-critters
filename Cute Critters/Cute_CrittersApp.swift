import SwiftUI
import Cocoa
@main


struct CuteCrittersApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    // No main Window group needed if you’re doing a floating panel.
    // You can optionally have other windows or a Settings scene if desired.
    var body: some Scene {
        // Keep your Settings if you want:
        Settings {
            SettingsView() // Add the settings view here

        }
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



extension NSCursor {
    static func customCursor(named imageName: String, hotSpot: NSPoint) -> NSCursor? {
        guard let cursorImage = NSImage(named: imageName) else { return nil }
        return NSCursor(image: cursorImage, hotSpot: hotSpot)
    }
}


class AppDelegate: NSObject, NSApplicationDelegate {
    private var floatingWindowController: NSWindowController?
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set the custom cursor globally
        applyCustomCursor()
        
        NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved, .mouseEntered, .mouseExited]) { _ in
                   self.applyCustomCursor()
               }
        
         func applyCustomCursor() {
               if let customCursor = NSCursor.customCursor(named: "cursor_1", hotSpot: NSPoint(x: 16, y: 16)) {
                   customCursor.set()
               }
           }

        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem?.button {
            // Set the cat sprite as the icon
            button.image = NSImage(named: "cat_orange-idle_1") // Use your sprite name here
            button.image?.size = NSSize(width: 18, height: 18) // Resize for the menu bar
            button.image?.isTemplate = true // Ensure it adapts to light/dark mode

            // Optional: Add a click action
            button.action = #selector(statusBarItemClicked)
            button.target = self
        }

        // Create your floating window as before
        let contentView = FloatingWindowContentView()
        let hostingView = NSHostingView(rootView: contentView)
        hostingView.translatesAutoresizingMaskIntoConstraints = false

        let window = CustomWindow(
            contentRect: NSRect(x: 0, y: 0, width: 300, height: 360),
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = .clear
        window.titleVisibility = .visible
        window.titlebarAppearsTransparent = true
        window.hasShadow = true
        window.isMovableByWindowBackground = true

        // Set the window level and behavior
        window.level = NSWindow.Level(Int(CGWindowLevelForKey(.maximumWindow)) + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        window.contentView = hostingView

        floatingWindowController = NSWindowController(window: window)
        floatingWindowController?.showWindow(nil)

        NSApp.activate(ignoringOtherApps: true)
    }
    

    @objc func statusBarItemClicked() {
        guard let window = floatingWindowController?.window else { return }

        if window.isVisible {
            // Hide the window
            window.orderOut(nil)
        } else {
            // Show the window
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true) // Bring the app to the foreground if needed
        }
    }

    private func applyCustomCursor() {
        if let customCursor = NSCursor.customCursor(named: "cursor_1", hotSpot: NSPoint(x: 16, y: 16)) {
            customCursor.set() // Set the custom cursor globally
        }
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: .whitespacesAndNewlines)
                      .replacingOccurrences(of: "#", with: "")
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        
        let r = Double((rgb >> 16) & 0xFF) / 255.0
        let g = Double((rgb >> 8) & 0xFF) / 255.0
        let b = Double(rgb & 0xFF) / 255.0

        self.init(.sRGB, red: r, green: g, blue: b)
    }
}

struct FloatingWindowContentView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false

    var body: some View {
            ZStack {
                // Main content
                CritterView(isDarkMode: isDarkMode) // Pass the mode state
            }
            .frame(width: 300, height: 360)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isDarkMode ? Color(hex: "#1c1c1e") : Color(hex: "#f8f8f8")) // Dark/light mode background
                    .shadow(color: isDarkMode ? Color(hex: "#111111") : Color(hex: "#e0e0e0"), radius: 6, x: 0, y: 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(10)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Toggle(isOn: $isDarkMode) {
                        Text("Dark Mode")
                    }
                }
            }
        }
}



class CustomWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
}

// MARK: - The VisualEffectBlur View
struct VisualEffectBlur: NSViewRepresentable {
    var material: NSVisualEffectView.Material
    var blendingMode: NSVisualEffectView.BlendingMode
    var state: NSVisualEffectView.State = .active
    
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = state
        view.isEmphasized = true    // Helps ensure it's visible on light/dark backgrounds
        return view
    }
    
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
        nsView.state = state
        nsView.isEmphasized = true
    }
}

struct CritterView: View {
    // MARK: - States
    let isDarkMode: Bool

    @State private var orangeCatPosition: CGFloat = 0
    @State private var targetPosition: CGFloat = 0
    @State private var isIdle: Bool = true
    @State private var showThought: Bool = false
    @State private var currentFrameIndex: Int = 0
    @State private var facingRight: Bool = true
    
    // Clouds
    @State private var cloud1Offset: CGFloat = -300 // Starting position for Cloud 1
    @State private var cloud2Offset: CGFloat = -600 // Starting position for Cloud 2

    // Timers
    @State private var walkTimer: Timer?
    @State private var idleTimer: Timer?

    // MARK: - Sprites
    let orangeCatWalkFrames = [
        "cat_orange-move_1", // walk 1
        "cat_orange-move_2", // jump up
        "cat_orange-move_3", // jump down
        "cat_orange-move_4" // walk 2
    ]
    let orangeCatIdleFrames = [
        "cat_orange-idle_1",
        "cat_orange-idle_2",
        "cat_orange-idle_3"
    ]

    // MARK: - Body
    var body: some View {
        
            
            ZStack {
                LinearGradient(
                                gradient: Gradient(colors: isDarkMode ? [Color.black, Color.gray] : [Color.blue.opacity(0.8), Color.white.opacity(0.5)]),
                                startPoint: .top,
                                endPoint: .bottom
                            )
                
              
                
                // Moving Clouds
                Group {
                    Image("cloud") // Replace with your cloud image asset name
                        .resizable()
                        .interpolation(.none) // Keep pixel art crisp
                        .scaledToFit()
                        .frame(width: 100) // Size of Cloud 1
                        .offset(x: cloud1Offset, y: -120) // Position for Cloud 1
                    
                    Image("cloud") // Replace with your cloud image asset name
                        .interpolation(.none) // Keep pixel art crisp
                        .resizable()
                        .scaledToFit()
                        .frame(width: 140) // Size of Cloud 2
                        .offset(x: cloud2Offset, y: -150) // Position for Cloud 2
                }
                .onAppear {
                    startCloudAnimations()
                }
                
                VStack(spacing: 0) {
                    ZStack(alignment: .bottom) {
                        Image("Mountain_medium_snowy_2")
                        
                            .interpolation(.none) // Keep pixel art crisp
                            .resizable()
                            .scaledToFit()
                        
                            .offset( y: 0) // Adjust position to sit above the grass
                        
                        
                        // Tree
                        Image("tree")
                            .interpolation(.none) // Keep pixel art crisp
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36 * 3, height: 50 * 3) // Tree size
                            .offset(x: -90, y: 0) // Adjust position to sit above the grass
                        
                        Image("Tree_winter_medium_background_2")
                            .interpolation(.none) // Keep pixel art crisp
                            .resizable()
                            .scaledToFit()
                            .frame(width: 36 * 3, height: 50 * 3) // Tree size
                            .offset(x: CGFloat(30.0), y: 0) // Adjust position to sit above the grass
                        
                        Image("Grass_small_1")
                        
                            .interpolation(.none) // Keep pixel art crisp
                            .resizable()
                            .scaledToFit()
                            .frame(width: 6*3, height: 4*3) // Tree size
                            .offset( x: 100, y: 0) // Adjust position to sit above the grass
                        
                        Image("Grass_small_1")
                        
                            .interpolation(.none) // Keep pixel art crisp
                            .resizable()
                            .scaledToFit()
                            .frame(width: 6*3, height: 4*3) // Tree size
                            .offset( x: 40, y: 0) // Adjust position to sit above the grass
                        
                        Image("Flower_purple_small")
                        
                            .interpolation(.none) // Keep pixel art crisp
                            .resizable()
                            .scaledToFit()
                            .frame(width: 6*4, height: 4*4) // Tree size
                            .offset( x: -80, y: 0) // Adjust position to sit above the grass
                        
                        Image("Grass_large_1")
                        
                            .interpolation(.none) // Keep pixel art crisp
                            .resizable()
                            .scaledToFit()
                            .frame(width: 9*4, height: 7*4) // Tree size
                            .offset( x: 70, y: 0) // Adjust position to sit above the grass
                        
                        Image("Grass_large_1")
                        
                            .interpolation(.none) // Keep pixel art crisp
                            .resizable()
                            .scaledToFit()
                            .frame(width: 9*4, height: 7*4) // Tree size
                            .offset( x: -20, y: 0) // Adjust position to sit above the grass
                        
                        
                        
                        // Critter Sprite
                        Image(currentFrameImage)
                            .resizable()
                            .interpolation(.none) // Keep pixel art crisp
                            .scaledToFit()
                            .frame(width: 40, height: 40)
                            .scaleEffect(x: facingRight ? 1 : -1, y: 1)
                            .offset(x: orangeCatPosition, y: 0)
                            .onTapGesture {
                                showThoughtBubble()
                            }
                            .onAppear {
                                beginIdleMode()
                            }
                        
                        ZStack {
                            // Chat bubble image
                            Image("ChatBubble_white")  // Replace with your bubble image name
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 60, height: 60)
                            
                            // Heart image nested inside
                            Image("heart")
                                .interpolation(.none)
                                .resizable()
                                .scaledToFit()
                                .frame(width: 20, height: 20)  // Make heart smaller than bubble
                                // Adjust these offset values to center the heart in the bubble
                                .offset(x: 0, y: 0)
                        }
                        .offset(x: orangeCatPosition + 36, y: -16)  // Position entire bubble above cat
                        .transition(.opacity)
                        .animation(.easeOut, value: showThought)
                        .opacity(showThought ? 1 : 0)
                        
                      
                        
                    }
                    
                    // Grass Floor
                    RoundedRectangle(cornerRadius: 8)
                        .fill(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.green.opacity(0.8), Color.green.opacity(0.4)]),
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: 10 ) // Grass height
                        .shadow(color: .black.opacity(0.2), radius: 5, x: 0, y: 2)
                }
              
            }
            .frame( width:300,height: 360)
        
    }
    
    // MARK: - Cloud Animation
      private func startCloudAnimations() {
          // Cloud 1 Animation
          withAnimation(
              Animation.linear(duration: 200) // Slower speed for Cloud 1
                  .repeatForever(autoreverses: false)
          ) {
              cloud1Offset = 400 // End position for Cloud 1
          }

          // Cloud 2 Animation
          withAnimation(
              Animation.linear(duration: 300) // Even slower speed for Cloud 2
                  .repeatForever(autoreverses: false)
          ) {
              cloud2Offset = 500 // End position for Cloud 2
          }
      }

    // MARK: - Current Frame
    var currentFrameImage: String {
        if isIdle {
            return orangeCatIdleFrames[currentFrameIndex % orangeCatIdleFrames.count]
        } else {
            return orangeCatWalkFrames[currentFrameIndex % orangeCatWalkFrames.count]
        }
    }

    // MARK: - Idle / Walk Logic

    func beginIdleMode() {
        isIdle = true
        stopWalkTimer()

        // Start the idle animation timer
        idleTimer?.invalidate()
        idleTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            currentFrameIndex += 1
        }

        // After some random idle time, pick a new target to walk to
        let randomIdleTime = Double.random(in: 2...5)
        DispatchQueue.main.asyncAfter(deadline: .now() + randomIdleTime) {
            chooseNewTarget()
            beginWalkMode()
        }
    }

    func beginWalkMode() {
        isIdle = false
        stopIdleTimer()

        // Decide facing direction
        facingRight = targetPosition > orangeCatPosition

        // Start the walk animation timer
        walkTimer?.invalidate()
        walkTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { _ in
            currentFrameIndex += 1
            moveToTarget()
        }
    }

    func moveToTarget() {
        let dx = targetPosition - orangeCatPosition
        if abs(dx) < 2 {
            orangeCatPosition = targetPosition
            beginIdleMode()
        } else {
            orangeCatPosition += (dx > 0) ? 2 : -2
        }
    }

    func chooseNewTarget() {
        targetPosition = CGFloat.random(in: -80...80)
    }

    // MARK: - Timer Management
    func stopWalkTimer() {
        walkTimer?.invalidate()
        walkTimer = nil
    }

    func stopIdleTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
    }

    // MARK: - Thought Bubble
    func showThoughtBubble() {
        withAnimation {
            showThought = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                showThought = false
            }
        }
    }
}

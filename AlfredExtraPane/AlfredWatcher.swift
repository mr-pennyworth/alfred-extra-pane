import AXSwift
import Cocoa
import Swindler
import PromiseKit
import CoreFoundation


class AlfredWatcher {
    var swindler: Swindler.State!
    var onDestroy: (() -> Void)!
    var onDownArrow: (() -> Void)!
    var onUpArrow: (() -> Void)!
    
    let UP_ARROW: UInt16 = 126
    let DOWN_ARROW: UInt16 = 125
    
    func start(
        onAlfredWindowDestroy: @escaping () -> Void,
        onDownArrowPressed: @escaping () -> Void,
        onUpArrowPressed: @escaping () -> Void
    ) {
        self.onDestroy = onAlfredWindowDestroy
        self.onDownArrow = onDownArrowPressed
        self.onUpArrow = onUpArrowPressed
        
        guard AXSwift.checkIsProcessTrusted(prompt: true) else {
            NSLog("Not trusted as an AX process; please authorize and re-launch")
            NSApp.terminate(self)
            return
        }

        Swindler.initialize().done { state in
            self.swindler = state
            self.setupEventHandlers()
        }.catch { error in
            NSLog("Fatal error: failed to initialize Swindler: \(error)")
            NSApp.terminate(self)
        }
        
        NSEvent.addGlobalMonitorForEvents(
             matching: [NSEvent.EventTypeMask.keyDown],
             handler: { (event: NSEvent) in
                let mods = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
                let isCtrl = (mods == [.control])
                let keyCode = event.keyCode
                let key = event.charactersIgnoringModifiers
                if (keyCode == self.UP_ARROW || (isCtrl && key == "p")) {
                    self.onUpArrow()
                } else if (keyCode == self.DOWN_ARROW || (isCtrl && key == "n")) {
                    self.onDownArrow()
                }
             }
           )
    }
    
    private func isAlfredWindow(window: Window) -> Bool {
        let bundle = window.application.bundleIdentifier ?? ""
        let title = window.title.value
        return (bundle == "com.runningwithcrayons.Alfred" && title == "Alfred")
    }

    private func setupEventHandlers() {
        swindler.on { (event: WindowDestroyedEvent) in
            if (self.isAlfredWindow(window: event.window)) {
                NSLog("Alfred window destroyed")
                self.onDestroy()
            }
        }
    }

    func alfredFrame() -> CGRect? {
        if (swindler == nil) {
            // when the application isn't already running, and the first call is
            // by invoking the app specific url, swindler might not have been
            // initialized by then. for that special case, we explicitly get
            // alfred frame without relying on swindler.
            let options = CGWindowListOption([.excludeDesktopElements, .optionOnScreenOnly])
            let windowListInfo = CGWindowListCopyWindowInfo(options, CGWindowID(0))
            let wli = windowListInfo as NSArray? as? [[String: AnyObject]]
            if let alfredWindow = wli?.first(where: { windowInfo in
                if let name = windowInfo["kCGWindowOwnerName"] as? String {
                    if (name == "Alfred") {
                        return true
                    } else {
                        return false
                    }
                } else {
                    return false
                }
            }) {
                if let bounds = alfredWindow["kCGWindowBounds"] {
                    let frame = CGRect.init(
                        dictionaryRepresentation: bounds as! CFDictionary
                    )
                    log("Non-Swindler frame: \(String(describing: frame))")
                    return frame
                }
            }

            return nil
        } else {
            let alfredWindow = swindler.knownWindows.first(where: self.isAlfredWindow)!
            let alfred = alfredWindow.frame
            return alfred.value
            // The following is buggy
            // 1. left-shifted alfred's height keeps getting clipped often
            // 2. multiple screens aren't handled properly
            let screenWidth = alfredWindow.screen!.frame.width
            let isAlfredCentered = ((alfred.value.minX + alfred.value.maxX) == screenWidth)
            if (isAlfredCentered) {
                // move alfred 150px left
                let leftShifted = CGRect(
                    x: alfred.value.minX - 150,
                    y: alfred.value.minY,
                    width: alfred.value.width,
                    height: alfred.value.height
                )
                alfred.value = leftShifted
                return leftShifted
            } else {
                return alfred.value
            }
        }
    }
}

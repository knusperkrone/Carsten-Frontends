import UIKit
import Flutter
import GoogleCast

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    let kReceiverAppID = "780E142E"
    let kDebugLoggingEnabled = false
    
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        // Notification
        if #available(iOS 10, *) {
            application.beginReceivingRemoteControlEvents()
        }
        
        // Enable Chromecast support
        let criteria = GCKDiscoveryCriteria(applicationID: kReceiverAppID)
        let options = GCKCastOptions(discoveryCriteria: criteria)
        options.suspendSessionsWhenBackgrounded = false
        GCKCastContext.setSharedInstanceWith(options)
        GCKLogger.sharedInstance().delegate = self // logger
        searchChromecastDevices()
        
        // Get foreground channel
        let controller = window?.rootViewController as! FlutterViewController
        let foregroundMessageChannel = FlutterBasicMessageChannel(name: "interfaceag/cast_context/service_message", binaryMessenger: controller.binaryMessenger, codec: FlutterJSONMessageCodec.sharedInstance())
        
        // Register app plugin
        PlaybackPlugin.register(with: self.registrar(forPlugin: "interface_ag.cast_plugin")!)
        PlaybackPlugin.foregroundBroadcast(channel: foregroundMessageChannel)
        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
    override func applicationDidBecomeActive(_ application: UIApplication) {
        self.searchChromecastDevices()
        PlaybackPlugin.instance?.onForeground()
    }
    
    override func applicationWillResignActive(_ application: UIApplication) {
        GCKCastContext.sharedInstance().discoveryManager.stopDiscovery()
        PlaybackPlugin.instance?.onBackground()
    }
    
    func searchChromecastDevices() {
        let discoveryManager = GCKCastContext.sharedInstance().discoveryManager
        discoveryManager.startDiscovery()
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            GCKCastContext.sharedInstance().discoveryManager.passiveScan = true
            if (discoveryManager.hasDiscoveredDevices) {
                discoveryManager.stopDiscovery()
            } else {
                self.searchChromecastDevices()
            }
        }
    }
}

extension AppDelegate: GCKLoggerDelegate {
    func logMessage(_ message: String, at level: GCKLoggerLevel, fromFunction function: String, location: String) {
        if(kDebugLoggingEnabled) {
            NSLog("\n" + function + " - " + message)
        }
    }
}

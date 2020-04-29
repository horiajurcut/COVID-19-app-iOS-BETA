//
//  RootViewControllerTests.swift
//  SonarTests
//
//  Created by NHSX.
//  Copyright © 2020 NHSX. All rights reserved.
//

import XCTest
@testable import Sonar

class RootViewControllerTests: TestCase {
    
    private var persistence: PersistenceDouble!
    private var authorizationManager: AuthorizationManagerDouble!
    private var remoteNotificationDispatcher: RemoteNotificationDispatcher!
    private var notificationCenter: NotificationCenter!
    private var bluetoothNursery: BluetoothNurseryDouble!
    private var onboardingCoordinator: OnboardingCoordinatorDouble!
    private var rootVC: RootViewController!
    
    override func setUp() {
        super.setUp()
        
        persistence = PersistenceDouble()
        authorizationManager = AuthorizationManagerDouble()
        remoteNotificationDispatcher = makeDispatcher()
        notificationCenter = NotificationCenter()
        bluetoothNursery = BluetoothNurseryDouble()
        onboardingCoordinator = OnboardingCoordinatorDouble()
        
        rootVC = RootViewController()
        rootVC.inject(
            persistence: persistence,
            authorizationManager: authorizationManager,
            remoteNotificationManager: RemoteNotificationManagerDouble(dispatcher: remoteNotificationDispatcher),
            notificationCenter: notificationCenter,
            registrationService: RegistrationServiceDouble(),
            bluetoothNursery: bluetoothNursery,
            onboardingCoordinator: onboardingCoordinator,
            session: SessionDouble(),
            contactEventsUploader: ContactEventsUploaderDouble(),
            linkingIdManager: LinkingIdManagerDouble.make(),
            statusProvider: StatusProvider(persisting: persistence),
            uiQueue: QueueDouble()
        )
    }
    
    func testInitialVC_OnboardingRequired() {
        onboardingCoordinator.isOnboardingRequired = true
        XCTAssertNotNil(rootVC.view)
        
        XCTAssertEqual(rootVC.children.count, 1)
        XCTAssertNotNil(rootVC.children.first as? OnboardingViewController)
    }
    
    func testInitialVC_OnboardingNotRequired() {
        onboardingCoordinator.isOnboardingRequired = false
        XCTAssertNotNil(rootVC.view)
        
        XCTAssertEqual(rootVC.children.count, 1)
        XCTAssertNotNil(rootVC.children.first as? StatusViewController)
    }
    
    func testOnboardingFinished() {
        onboardingCoordinator.isOnboardingRequired = true
        
        XCTAssertNotNil(rootVC.view)
                
        onboardingCoordinator.stateCompletion?(.done)

        XCTAssertEqual(rootVC.children.count, 1)
        XCTAssertNotNil(rootVC.children.first as? StatusViewController)
    }
    
    func testShow() {
        let child = UIViewController()
        XCTAssertNotNil(rootVC.view) // trigger viewDidLoad before we call show
        
        rootVC.show(viewController: child)
        
        XCTAssertEqual(rootVC.children, [child])
    }
    
    func testBecomeActiveShowsPermissionDeniedWhenNoBluetoothPermission() {
        onboardingCoordinator.isOnboardingRequired = false
        persistence.registration = .fake
        authorizationManager.bluetooth = .allowed
        bluetoothNursery.stateObserver = BluetoothStateObserver(initialState: .poweredOn)

        parentViewControllerForTests.viewControllers = [rootVC]

        XCTAssertNil(rootVC.presentedViewController)

        authorizationManager.bluetooth = .denied
        notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        authorizationManager.notificationsCompletion?(.allowed)
        
        XCTAssertNotNil(rootVC.presentedViewController as? BluetoothPermissionDeniedViewController)
    }
    
    func testBecomeActiveShowsPermissionDeniedWhenNoNotificationPermission() {
        onboardingCoordinator.isOnboardingRequired = false
        persistence.registration = .fake
        authorizationManager.bluetooth = .allowed
        bluetoothNursery.stateObserver = BluetoothStateObserver(initialState: .poweredOn)

        parentViewControllerForTests.viewControllers = [rootVC]

        XCTAssertNil(rootVC.presentedViewController)
        
        notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        authorizationManager.notificationsCompletion?(.denied)
        
        XCTAssertNotNil(rootVC.presentedViewController as? NotificationPermissionDeniedViewController)
    }
    
    func testBecomesActiveShowsBluetoothOffWhenBluetoothOff() {
        onboardingCoordinator.isOnboardingRequired = false
        bluetoothNursery.startBluetooth(registration: nil)
        authorizationManager.bluetooth = .allowed
        parentViewControllerForTests.viewControllers = [rootVC]

        XCTAssertNil(rootVC.presentedViewController)

        bluetoothNursery.stateObserver.btleListener(BTLEListenerDouble(), didUpdateState: .poweredOff)
        notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        authorizationManager.notificationsCompletion?(.allowed)

        XCTAssertNotNil(rootVC.presentedViewController as? BluetoothOffViewController)
    }
    
    func testBecomeActiveDoesNotShowPermissionProblemsDuringOnboarding() {
        onboardingCoordinator.isOnboardingRequired = false
        parentViewControllerForTests.viewControllers = [rootVC]
        XCTAssertNotNil(rootVC.view)
        
        authorizationManager.bluetooth = .denied
        notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        authorizationManager.notificationsCompletion?(.allowed)
        
        XCTAssertNil(rootVC.presentedViewController)
    }

    
    func testBecomeActiveDoesNotShowPermissionDeniedWhenAllPermissionsGranted() {
        onboardingCoordinator.isOnboardingRequired = false
        persistence.registration = .fake
        authorizationManager.bluetooth = .allowed
        parentViewControllerForTests.viewControllers = [rootVC]
        
        notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        authorizationManager.notificationsCompletion?(.allowed)
        
        XCTAssertNil(rootVC.presentedViewController)
    }
    
    func testBecomeActiveHidesExistingPermissionDeniedWhenAllPermissionsGranted() {
        onboardingCoordinator.isOnboardingRequired = false
        persistence.registration = .fake
        authorizationManager.bluetooth = .allowed
        bluetoothNursery.startBluetooth(registration: nil)
        
        parentViewControllerForTests.viewControllers = [rootVC]
        
        notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        authorizationManager.notificationsCompletion?(.denied)
        bluetoothNursery.stateObserver.btleListener(BTLEListenerDouble(), didUpdateState: .poweredOn)
        XCTAssertNotNil(rootVC.presentedViewController)
        
        bluetoothNursery.stateObserver.btleListener(BTLEListenerDouble(), didUpdateState: .poweredOn)
        notificationCenter.post(name: UIApplication.didBecomeActiveNotification, object: nil)
        authorizationManager.notificationsCompletion?(.allowed)
        
        let expectation = XCTestExpectation(description: "Presented view controller became nil")
        var done = false
        
        func pollPresentedVC() {
            if rootVC.presentedViewController == nil {
                expectation.fulfill()
            } else if !done {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25, execute: { pollPresentedVC() })
            }
        }
        
        pollPresentedVC()
        wait(for: [expectation], timeout: 2.0)
        done = true
    }
}

fileprivate func makeDispatcher() -> RemoteNotificationDispatcher {
    return RemoteNotificationDispatcher(notificationCenter: NotificationCenter(), userNotificationCenter: UserNotificationCenterDouble())
}
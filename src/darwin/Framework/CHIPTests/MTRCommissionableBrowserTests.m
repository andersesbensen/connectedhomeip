/**
 *
 *    Copyright (c) 2023 Project CHIP Authors
 *
 *    Licensed under the Apache License, Version 2.0 (the "License");
 *    you may not use this file except in compliance with the License.
 *    You may obtain a copy of the License at
 *
 *        http://www.apache.org/licenses/LICENSE-2.0
 *
 *    Unless required by applicable law or agreed to in writing, software
 *    distributed under the License is distributed on an "AS IS" BASIS,
 *    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *    See the License for the specific language governing permissions and
 *    limitations under the License.
 */

#import <Matter/Matter.h>

// system dependencies
#import <XCTest/XCTest.h>

#import "MTRTestKeys.h"
#import "MTRTestStorage.h"

static const uint16_t kLocalPort = 5541;
static const uint16_t kTestVendorId = 0xFFF1u;
static const uint16_t kTestProductId = 0x8001u;
static const uint16_t kTestDiscriminator1 = 1111u;
static const uint16_t kTestDiscriminator2 = 1112u;
static const uint16_t kTestDiscriminator3 = 3840u;
static const uint16_t kDiscoverDeviceTimeoutInSeconds = 10;
static const uint16_t kExpectedDiscoveredDevicesCount = 3;

// Singleton controller we use.
static MTRDeviceController * sController = nil;

@interface DeviceScannerDelegate : NSObject <MTRCommissionableBrowserDelegate>
@property (nonatomic) XCTestExpectation * expectation;
@property (nonatomic) NSNumber * resultsCount;

- (instancetype)initWithExpectation:(XCTestExpectation *)expectation;
- (void)controller:(MTRDeviceController *)controller didFindCommissionableDevice:(MTRCommissionableBrowserResult *)device;
- (void)controller:(MTRDeviceController *)controller didRemoveCommissionableDevice:(MTRCommissionableBrowserResult *)device;
@end

@implementation DeviceScannerDelegate
- (instancetype)initWithExpectation:(XCTestExpectation *)expectation
{
    if (!(self = [super init])) {
        return nil;
    }

    _resultsCount = 0;
    _expectation = expectation;
    return self;
}

- (void)controller:(MTRDeviceController *)controller didFindCommissionableDevice:(MTRCommissionableBrowserResult *)device
{
    _resultsCount = @(_resultsCount.unsignedLongValue + 1);
    if ([_resultsCount isEqual:@(kExpectedDiscoveredDevicesCount)]) {
        [self.expectation fulfill];
    }

    XCTAssertLessThanOrEqual(_resultsCount.unsignedLongValue, kExpectedDiscoveredDevicesCount);

    __auto_type instanceName = device.instanceName;
    __auto_type vendorId = device.vendorID;
    __auto_type productId = device.productID;
    __auto_type discriminator = device.discriminator;
    __auto_type commissioningMode = device.commissioningMode;

    XCTAssertEqual(instanceName.length, 16); // The  instance name is random, so just ensure the len is right.
    XCTAssertEqualObjects(vendorId, @(kTestVendorId));
    XCTAssertEqualObjects(productId, @(kTestProductId));
    XCTAssertTrue([discriminator isEqual:@(kTestDiscriminator1)] || [discriminator isEqual:@(kTestDiscriminator2)] ||
        [discriminator isEqual:@(kTestDiscriminator3)]);
    XCTAssertEqual(commissioningMode, YES);

    NSLog(@"Found Device (%@) with discriminator: %@ (vendor: %@, product: %@)", instanceName, discriminator, vendorId, productId);
}

- (void)controller:(MTRDeviceController *)controller didRemoveCommissionableDevice:(MTRCommissionableBrowserResult *)device
{
    __auto_type instanceName = device.instanceName;
    __auto_type vendorId = device.vendorID;
    __auto_type productId = device.productID;
    __auto_type discriminator = device.discriminator;

    NSLog(
        @"Removed Device (%@) with discriminator: %@ (vendor: %@, product: %@)", instanceName, discriminator, vendorId, productId);
}
@end

@interface MTRCommissionableBrowserTests : XCTestCase
@end

static BOOL sStackInitRan = NO;
static BOOL sNeedsStackShutdown = YES;

@implementation MTRCommissionableBrowserTests

+ (void)tearDown
{
    // Global teardown, runs once
    if (sNeedsStackShutdown) {
        [self shutdownStack];
    }
}

- (void)setUp
{
    // Per-test setup, runs before each test.
    [super setUp];
    [self setContinueAfterFailure:NO];

    if (sStackInitRan == NO) {
        [self initStack];
    }
}

- (void)tearDown
{
    // Per-test teardown, runs after each test.
    [super tearDown];
}

- (void)initStack
{
    sStackInitRan = YES;

    __auto_type * factory = [MTRDeviceControllerFactory sharedInstance];
    XCTAssertNotNil(factory);

    __auto_type * storage = [[MTRTestStorage alloc] init];
    __auto_type * factoryParams = [[MTRDeviceControllerFactoryParams alloc] initWithStorage:storage];
    factoryParams.port = @(kLocalPort);

    BOOL ok = [factory startControllerFactory:factoryParams error:nil];
    XCTAssertTrue(ok);

    __auto_type * testKeys = [[MTRTestKeys alloc] init];
    XCTAssertNotNil(testKeys);

    __auto_type * params = [[MTRDeviceControllerStartupParams alloc] initWithIPK:testKeys.ipk fabricID:@(1) nocSigner:testKeys];
    params.vendorID = @(kTestVendorId);

    MTRDeviceController * controller = [factory createControllerOnNewFabric:params error:nil];
    XCTAssertNotNil(controller);

    sController = controller;
}

+ (void)shutdownStack
{
    sNeedsStackShutdown = NO;

    MTRDeviceController * controller = sController;
    XCTAssertNotNil(controller);

    [controller shutdown];
    XCTAssertFalse([controller isRunning]);

    [[MTRDeviceControllerFactory sharedInstance] stopControllerFactory];
}

- (void)test001_StartBrowseAndStopBrowse
{
    __auto_type delegate = [[DeviceScannerDelegate alloc] init];
    dispatch_queue_t dispatchQueue = dispatch_queue_create("com.chip.discover", DISPATCH_QUEUE_SERIAL);

    // Start browsing
    XCTAssertTrue([sController startBrowseForCommissionables:delegate queue:dispatchQueue]);

    // Stop browsing
    XCTAssertTrue([sController stopBrowseForCommissionables]);
}

- (void)test002_StartBrowseAndStopBrowseMultipleTimes
{
    __auto_type delegate = [[DeviceScannerDelegate alloc] init];
    dispatch_queue_t dispatchQueue = dispatch_queue_create("com.chip.discover", DISPATCH_QUEUE_SERIAL);

    // Start browsing
    XCTAssertTrue([sController startBrowseForCommissionables:delegate queue:dispatchQueue]);

    // Stop browsing
    XCTAssertTrue([sController stopBrowseForCommissionables]);

    // Start browsing a second time
    XCTAssertTrue([sController startBrowseForCommissionables:delegate queue:dispatchQueue]);

    // Stop browsing a second time
    XCTAssertTrue([sController stopBrowseForCommissionables]);
}

- (void)test003_StopBrowseWhileNotBrowsing
{
    // Stop browsing while there is no browse ongoing
    XCTAssertFalse([sController stopBrowseForCommissionables]);
}

- (void)test004_StartBrowseWhileBrowsing
{
    __auto_type delegate = [[DeviceScannerDelegate alloc] init];
    dispatch_queue_t dispatchQueue = dispatch_queue_create("com.chip.discover", DISPATCH_QUEUE_SERIAL);

    // Start browsing
    XCTAssertTrue([sController startBrowseForCommissionables:delegate queue:dispatchQueue]);

    // Start browsing a second time while a browse is ongoing
    XCTAssertFalse([sController startBrowseForCommissionables:delegate queue:dispatchQueue]);

    // Properly stop browsing
    XCTAssertTrue([sController stopBrowseForCommissionables]);
}

- (void)test005_StartBrowseGetCommissionableOverMdns
{
    __auto_type expectation = [self expectationWithDescription:@"Commissionable devices Found"];
    __auto_type delegate = [[DeviceScannerDelegate alloc] initWithExpectation:expectation];
    dispatch_queue_t dispatchQueue = dispatch_queue_create("com.chip.discover", DISPATCH_QUEUE_SERIAL);

    // Start browsing
    XCTAssertTrue([sController startBrowseForCommissionables:delegate queue:dispatchQueue]);

    [self waitForExpectations:@[ expectation ] timeout:kDiscoverDeviceTimeoutInSeconds];

    // Properly stop browsing
    XCTAssertTrue([sController stopBrowseForCommissionables]);
}

- (void)test999_TearDown
{
    [[self class] shutdownStack];
}

@end

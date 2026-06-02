
#import "RNReactNativePing.h"
#import "GBPing.h"
#import "LHNetwork.h"
#import "LHDefinition.h"

@interface RNReactNativePing ()
@property (nonatomic,strong) dispatch_queue_t queue;
@end

@implementation RNReactNativePing


RCT_EXPORT_MODULE()
- (dispatch_queue_t)methodQueue
{
    if (!_queue) {
        _queue = dispatch_queue_create("com.pomato.React.RNReactNativePing", DISPATCH_QUEUE_SERIAL);
    }
    return _queue;
}

RCT_EXPORT_METHOD(
                  start:(NSString *)ipAddress
                  option:(NSDictionary *)option
                  resolver:(RCTPromiseResolveBlock)resolve
                  rejecter:(RCTPromiseRejectBlock)reject
                  ) {
    __block GBPing * ping = [[GBPing alloc] init];
    __block BOOL callbackCalled = NO;

    void (^finishResolve)(NSNumber *) = ^(NSNumber *result) {
        if (callbackCalled) {
            return;
        }
        callbackCalled = YES;
        [ping stop];
        ping = nil;
        resolve(result);
    };

    void (^finishReject)(NSError *) = ^(NSError *error) {
        if (callbackCalled) {
            return;
        }
        callbackCalled = YES;
        [ping stop];
        ping = nil;
        reject(@(error.code).stringValue,error.domain,error);
    };

    ping.timeout = 1.0;
    ping.payloadSize = 56;
    ping.pingPeriod = 0.9;
    ping.host = ipAddress;
    NSNumber *nsTimeout = option[@"timeout"];
    unsigned long long timeout = 1000.0;
    if (nsTimeout) {
        timeout = nsTimeout.unsignedLongLongValue;
        ping.timeout = timeout;
    }
    
    NSNumber *nsPayloadSize = option[@"payloadSize"];
    if (nsPayloadSize) {
        unsigned long long payloadSize = nsPayloadSize.unsignedLongLongValue;
        ping.payloadSize = payloadSize;
    }

    [ping setupWithBlock:^(BOOL success, NSError *_Nullable err) {
        if (!success) {
            finishReject(err);
            return;
        }
        [ping startPingingWithBlock:^(GBPingSummary *summary) {
            if (!ping) {
                return;
            }
            finishResolve(@(@(summary.rtt * 1000).intValue));
        } fail:^(NSError *_Nonnull error) {
            if (!ping) {
                return;
            }
            finishReject(error);
        }];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_MSEC)), _queue, ^{
            if (!ping) {
                return;
            }
            DEFINE_NSError(timeoutError,PingUtil_Message_Timeout)
            finishReject(timeoutError);
        });
    }];
}
RCT_REMAP_METHOD(
                 getTrafficStats,
                 resolver:(RCTPromiseResolveBlock)resolve
                 rejecter:(RCTPromiseRejectBlock)reject
                 ) {
    // Prevent multiple calls from causing data confusion
    LHNetwork *instance = [[LHNetwork alloc]init];
    
    [instance checkNetworkflow];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), _queue, ^{
        [instance checkNetworkflow];
        
        NSString *receivedNetworkSpeed = instance.receivedNetworkSpeed;
        NSString *receivedNetworkTotal = instance.receivedNetworkTotal;
        NSString *sendNetworkSpeed = instance.sendNetworkSpeed;
        NSString *sendNetworkTotal = instance.sendNetworkTotal;
        resolve(@{
                  @"receivedNetworkSpeed": receivedNetworkSpeed,
                  @"receivedNetworkTotal": receivedNetworkTotal,
                  @"sendNetworkSpeed": sendNetworkSpeed,
                  @"sendNetworkTotal": sendNetworkTotal
                  });
    });
}
@end

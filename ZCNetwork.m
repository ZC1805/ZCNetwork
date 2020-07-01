//
//  ZCNetwork.m
//  PalmPartner
//
//  Created by zjy on 2020/1/17.
//  Copyright © 2020 Ttranssnet. All rights reserved.
//

#import "ZCNetwork.h"
#import <objc/runtime.h>
#import <AFNetworking.h>

ZCNetworkKey const ZCNetworkAutoTip = @"static_custom_auto_tip";
ZCNetworkKey const ZCNetworkCustomKey = @"static_custom_single_key";


#pragma mark - ~ NSURLSessionTask ~
@interface NSURLSessionTask (JFNetwork)

@property (nonatomic, copy) NSString *showWaitTip;

@property (nonatomic, copy) NSString *showFailTip;

@property (nonatomic, copy) NSString *showSucsTip;

@end

@implementation NSURLSessionTask (JFNetwork)

- (void)setShowWaitTip:(NSString *)showWaitTip {
    objc_setAssociatedObject(self, @selector(showWaitTip), showWaitTip, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)showWaitTip {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setShowFailTip:(NSString *)showFailTip {
    objc_setAssociatedObject(self, @selector(showFailTip), showFailTip, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)showFailTip {
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setShowSucsTip:(NSString *)showSucsTip {
    objc_setAssociatedObject(self, @selector(showSucsTip), showSucsTip, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

- (NSString *)showSucsTip {
    return objc_getAssociatedObject(self, _cmd);
}

@end


#pragma mark - ~ ZCNetworkError ~
@interface ZCNetworkError ()

@end

@implementation ZCNetworkError

- (instancetype)initWithErrorType:(ZCEnumNetworkError)errorType errorCode:(NSString *)errorCode errorPrompt:(NSString *)errorPrompt {
    if (self = [super init]) {
        _errorType = errorType;
        _errorCode = ZCStrNonnil(errorCode);
        _errorPrompt = ZCStrNonnil(errorPrompt);
    }
    return self;
}

+ (instancetype)networkErrorWithNoNetwork {
    NSString *prompt = @"Unable to connect to the network, please check the network connection.";
    return [[ZCNetworkError alloc] initWithErrorType:ZCEnumNetworkErrorNoNetwork errorCode:ZCStrFormat(@"%ld", (long)NSURLErrorNotConnectedToInternet) errorPrompt:prompt];
}

+ (instancetype)networkErrorWithAppUpdate {
    NSString *prompt = @"There was a minor problem with the server, please try again later.";
    return [[ZCNetworkError alloc] initWithErrorType:ZCEnumNetworkErrorAppUpdate errorCode:ZCStrFormat(@"%ld", (long)-5503) errorPrompt:prompt];
}

+ (instancetype)networkErrorWithError:(NSError *)error {
    if (error.code == NSURLErrorTimedOut) { //请求超时
        NSString *prompt = @"The request timed out, please check the network connection.";
        return [[ZCNetworkError alloc] initWithErrorType:ZCEnumNetworkErrorTimeOut errorCode:ZCStrFormat(@"%ld", (long)error.code) errorPrompt:prompt];
    } else if (error.code == NSURLErrorNotConnectedToInternet) { //无网络连接
        NSString *prompt = @"Unable to connect to the network, please check the network connection.";
        return [[ZCNetworkError alloc] initWithErrorType:ZCEnumNetworkErrorNoNetwork errorCode:ZCStrFormat(@"%ld", (long)error.code) errorPrompt:prompt];
    } else if (error.code == NSURLErrorCancelled) { //请求取消
        NSString *prompt = @"Invalid URL address, please try again later.";
        return [[ZCNetworkError alloc] initWithErrorType:ZCEnumNetworkErrorCanceled errorCode:ZCStrFormat(@"%ld", (long)error.code) errorPrompt:prompt];
    } else if ((error.code >= 500 && error.code <= 599) || (error.code == NSURLErrorBadServerResponse)) { //服务端问题
        NSString *prompt = @"There was a minor problem with the server, please try again later.";
        return [[ZCNetworkError alloc] initWithErrorType:ZCEnumNetworkErrorAbnormal errorCode:ZCStrFormat(@"%ld", (long)error.code) errorPrompt:prompt];
    } else if (error) { //请求异常
        NSString *prompt = @"Request data failed, please try again later.";
        return [[ZCNetworkError alloc] initWithErrorType:ZCEnumNetworkErrorAbnormal errorCode:ZCStrFormat(@"%ld", (long)error.code) errorPrompt:prompt];
    } else { //数据异常
        NSString *prompt = @"Data exception, please try again later.";
        return [[ZCNetworkError alloc] initWithErrorType:ZCEnumNetworkErrorAbnormal errorCode:ZCStrFormat(@"%ld", (long)-5500) errorPrompt:prompt];
    }
}

+ (instancetype)networkErrorWithErrorCode:(NSString *)errorCode errorPrompt:(NSString *)errorPrompt {
    if (!errorCode.length) errorCode = ZCStrFormat(@"%ld", (long)-5501); //数据错误
    if (!errorPrompt.length) errorCode = @"Data error, please try again later.";
    return [[ZCNetworkError alloc] initWithErrorType:ZCEnumNetworkErrorPrompt errorCode:errorCode errorPrompt:errorPrompt];
}

@end


#pragma mark - ~ ZCNetwork ~
@interface ZCNetwork ()

//请求信息
@property (nonatomic, assign) BOOL isBreakContact;

@property (nonatomic, assign) BOOL isShowNetworkTips;

@property (nonatomic, copy) NSString *networkDesc;

@property (nonatomic, copy) NSString *networkType;

@property (nonatomic, strong) NSArray *basicHeaderKeys;

@property (nonatomic, strong, readonly) TYRSAHandler *rasHandler;

@property (nonatomic, strong, readonly) NSCharacterSet *signAllowCharacters;

@property (nonatomic, copy, readonly) NSString *basicUrlStr; /**< 请求地址的base路径 */

@property (nonatomic, assign, readonly) ZCEnumRunEnvironment runEnvironment; /**< 当前的运行环境 */

//提示信息
@property (nonatomic, copy) NSString *saveWaitTip;

@property (nonatomic, copy) NSString *saveFailTip;

@property (nonatomic, copy) NSString *saveSucsTip;

@property (nonatomic, assign) int waitAnimationCount;

@property (nonatomic, strong) NSMutableArray <NSURLSessionTask *>*allActiveTasks;

//版本信息
@property (nonatomic, assign) int versionCheckState;

@property (nonatomic, strong) NSDictionary *versionInfo;

@property (nonatomic, strong) NSDictionary *hisVersionInfo;

@property (nonatomic, assign) NSInteger downloadVersionCount;

@end

@implementation ZCNetwork

@synthesize basicUrlStr = _basicUrlStr;

+ (void)start {
    [ZCNetwork sharedNetwork];
}

+ (instancetype)sharedNetwork {
    static ZCNetwork *instance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[ZCNetwork alloc] init];
    });
    return instance;
}

- (instancetype)init {
    if (self = [super init]) {
        self.isBreakContact = NO;
        self.networkType = @"WIFI";
        self.networkDesc = @"Currently under WIFI network";
        self.isShowNetworkTips = NO;
        self.versionCheckState = 0;
        self.waitAnimationCount = 0;
        self.saveWaitTip = ZCNetworkAutoTip;
        self.saveFailTip = ZCNetworkAutoTip;
        self.saveSucsTip = ZCNetworkAutoTip;
        self.allActiveTasks = [NSMutableArray array];
        _rasHandler = [[TYRSAHandler alloc] init];
        _runEnvironment = ZCEnumRunEnvironmentTest;
        _signAllowCharacters = [[NSCharacterSet characterSetWithCharactersInString:@"?!@#$^&%*+,:;='\"`<>()[]{}/\\| "] invertedSet];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onCountryChanged:) name:@"noti_select_country" object:nil];
        [_rasHandler importkeyString:self.rsaPrivateKey];
        [self startReachabilityStatus];
        [self downloadVersionInfo];
    }
    return self;
}

- (void)startReachabilityStatus {
    [[AFNetworkReachabilityManager sharedManager] setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
        switch (status) {
            case AFNetworkReachabilityStatusUnknown:{
                self.isBreakContact = NO;
                self.networkType = @"";
                self.networkDesc = @"Unknown Network";
            } break;
            case AFNetworkReachabilityStatusNotReachable:{
                self.isBreakContact = YES;
                self.networkType = @"";
                self.networkDesc = @"Unable to connect to the network";
                [self onNetworkTips];
            } break;
            case AFNetworkReachabilityStatusReachableViaWWAN:{
                self.isBreakContact = NO;
                self.networkType = @"2G/3G/4G";
                self.networkDesc = @"Currently using 2G/3G/4G network";
            } break;
            default:{
                self.isBreakContact = NO;
                self.networkType = @"WIFI";
                self.networkDesc = @"Currently under WIFI network";
            }
        }
    }];
    [[AFNetworkReachabilityManager sharedManager] startMonitoring];
}

#pragma mark - core1
- (NSString *)basicUrlStr {
    if (!_basicUrlStr) {
        switch (self.runEnvironment) {
            case ZCEnumRunEnvironmentProduct:{
                _basicUrlStr = @"https://*******/";
            } break;
            case ZCEnumRunEnvironmentGrayscale:{
                _basicUrlStr = @"https://*******/";
            } break;
            case ZCEnumRunEnvironmentTest:{
                _basicUrlStr = @"https://*******/";
            } break;
            case ZCEnumRunEnvironmentDevelopment:{
                _basicUrlStr = @"https://*******/";
            } break;
        }
    }
    return _basicUrlStr;
}

- (NSString *)rsaPrivateKey {
    return @"MII......";
}

- (BOOL)isIgnoreToken:(NSString *)cmd parm:(NSDictionary *)parm {
    if ([cmd isEqualToString:@"*******"] || [cmd isEqualToString:@"*******"]) {
        return YES;
    }
    if ([cmd isEqualToString:@"*******"]) {
        return YES;
    }
    return NO;
}

- (AFSecurityPolicy *)httpsPolicy {
    NSString *cerPath = [[NSBundle mainBundle] pathForResource:@"*******" ofType:@"cer"];
    NSData *cerData = [NSData dataWithContentsOfFile:cerPath];
    NSString *palmpayCerPath = [[NSBundle mainBundle] pathForResource:@"*******" ofType:@"cer"];
    NSData *palmpayCerData = [NSData dataWithContentsOfFile:palmpayCerPath];
    NSString *httpsCerPath = [[NSBundle mainBundle] pathForResource:@"*******" ofType:@"cer"];
    NSData *httpsCerData = [NSData dataWithContentsOfFile:httpsCerPath];
    AFSecurityPolicy *securityPolicy = [AFSecurityPolicy policyWithPinningMode:AFSSLPinningModeCertificate]; //使用证书验证模式
    securityPolicy.allowInvalidCertificates = NO; //是否允许无效证书(也就是自建的证书)，默认为NO
    securityPolicy.validatesDomainName = YES; //是否需要验证域名，默认为YES，如置为NO，建议自己添加对应域名的校验逻辑
    securityPolicy.pinnedCertificates = [NSSet setWithObjects:cerData, palmpayCerData, httpsCerData, nil];
    return securityPolicy;
}

- (NSString *)rsaSign:(NSString *)deviceId with:(NSString *)deviceType with:(NSString *)clientVer with:(NSString *)timestamp with:(NSString *)idToken {
    NSString *str = ZCStrFormat(@"%@%@%@%@%@", ZCStrNonnil(deviceId), ZCStrNonnil(deviceType), ZCStrNonnil(clientVer), ZCStrNonnil(timestamp), ZCStrNonnil(idToken));
    NSString *md5sign = [self.rasHandler signMD5String:str];
    return [md5sign stringByAddingPercentEncodingWithAllowedCharacters:self.signAllowCharacters];
}

#pragma mark - core2
- (AFHTTPSessionManager *)sharedSession {
    static AFHTTPSessionManager *session = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        session = [[AFHTTPSessionManager alloc] initWithBaseURL:[NSURL URLWithString:self.basicUrlStr]];
        session.requestSerializer = [AFJSONRequestSerializer serializer];
        session.responseSerializer = [AFJSONResponseSerializer serializer];
        session.requestSerializer.cachePolicy = NSURLRequestReloadIgnoringLocalCacheData;
        NSSet *types = [NSSet setWithObjects:@"application/json", @"text/json", @"text/plain", @"text/html", nil];
        [session.responseSerializer setAcceptableContentTypes:types];
        [session.requestSerializer setTimeoutInterval:30];
        if (self.runEnvironment == ZCEnumRunEnvironmentProduct) [session setSecurityPolicy:self.httpsPolicy];
        self.basicHeaderKeys = [session.requestSerializer.HTTPRequestHeaders.allKeys copy];
    });
    return session;
}

- (void)request:(NSString *)cmd parm:(NSDictionary *)parm post:(BOOL)post block:(void(^)(ZCNetworkError * _Nullable, NSDictionary * _Nonnull))block {
    //检查更新网络
    if (!cmd.length) {NSAssert(0, @"ZC: request cmd is nil"); return;}
    [self logRequestCmdStr:cmd parmDic:parm];
    if (self.isBreakContact) {
        NSDictionary *dataDic = [NSDictionary dictionary];
        ZCNetworkError *netError = [ZCNetworkError networkErrorWithNoNetwork];
        [self logResponseCmdStr:cmd errorObject:nil dataDic:nil netError:netError];
        if (block) {block(netError, dataDic); block = nil;}
        [self showBasicFail:netError.errorPrompt]; return;
    }
    if (self.checkVersionInfo) {
        NSDictionary *dataDic = [NSDictionary dictionary];
        ZCNetworkError *netError = [ZCNetworkError networkErrorWithAppUpdate];
        [self logResponseCmdStr:cmd errorObject:nil dataDic:nil netError:netError];
        if (block) {block(netError, dataDic); block = nil;}
        [self showBasicFail:netError.errorPrompt]; return;
    }

    //头和签名设置
    NSString *deviceType = @"IOS";
    NSString *timestamp = NSDate.date.timestamp;
    NSString *idToken = [[TYGlobalData getInstance] getToken];
    NSString *deviceId = [[TYGlobalData getInstance] getDeviceid];
    NSString *clientVer = ZCStrFormat(@"%@&%@", UIApplication.appVersion, UIApplication.appBuildVersion);
    if ([self isIgnoreToken:cmd parm:parm]) idToken = @"";
    NSArray *otherKeys = [self.sharedSession.requestSerializer.HTTPRequestHeaders.allKeys restExceptObjects:self.basicHeaderKeys];
    [otherKeys enumerateObjectsUsingBlock:^(NSString * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [self.sharedSession.requestSerializer setValue:nil forHTTPHeaderField:obj];
    }];
    NSString *rsaSign = [self rsaSign:deviceId with:deviceType with:clientVer with:timestamp with:idToken];
    [self.sharedSession.requestSerializer setValue:deviceType forHTTPHeaderField:@"*******"];
    [self.sharedSession.requestSerializer setValue:clientVer forHTTPHeaderField:@"*******"];
    [self.sharedSession.requestSerializer setValue:timestamp forHTTPHeaderField:@"*******"];
    [self.sharedSession.requestSerializer setValue:deviceId forHTTPHeaderField:@"*******"];
    [self.sharedSession.requestSerializer setValue:rsaSign forHTTPHeaderField:@"*******"];
    [self.sharedSession.requestSerializer setValue:idToken forHTTPHeaderField:@"*******"];
    if (!post || !parm) {
        [self.sharedSession.requestSerializer setValue:rsaSign forHTTPHeaderField:@"*******"];
    } else {
        NSString *rsaSignParm = [self rsaSign:[self jsonObjectToJsonStr:parm] with:nil with:nil with:nil with:nil];
        [self.sharedSession.requestSerializer setValue:rsaSignParm forHTTPHeaderField:@"*******"];
    }
    
    //开始任务请求
    NSURLSessionTask *task = nil;
    if (post) {
        task = [self.sharedSession POST:cmd parameters:parm progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable dataObject) {
            [self handle:cmd object:dataObject error:nil task:task block:block];
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            [self handle:cmd object:nil error:error task:task block:block];
        }];
    } else {
        task = [self.sharedSession GET:cmd parameters:parm progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable dataObject) {
            [self handle:cmd object:dataObject error:nil task:task block:block];
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            [self handle:cmd object:nil error:error task:task block:block];
        }];
    }
    [self injectTask:task];
}

- (void)handle:(NSString *)cmd object:(id)dataObject error:(NSError *)error task:(NSURLSessionTask *)task block:(void (^)(ZCNetworkError * _Nullable, NSDictionary * _Nonnull))block {
    NSDictionary *dataDic = dataObject; ZCNetworkError *netError = nil;
    if (error) { //请求失败
        dataDic = [NSDictionary dictionary];
        netError = [ZCNetworkError networkErrorWithError:error];
        [self logResponseCmdStr:cmd errorObject:error dataDic:nil netError:netError];
    } else if (!dataDic || ![dataDic isKindOfClass:NSDictionary.class]) { //响应数据错误
        dataDic = [NSDictionary dictionary];
        netError = [ZCNetworkError networkErrorWithError:nil];
        [self logResponseCmdStr:cmd errorObject:dataObject dataDic:nil netError:netError];
    } else { //请求成功
        NSString *errorCode = [dataDic stringValueForKey:@"respCode"];
        if ([errorCode isEqualToString:@"00000000"]) { //返回成功
            id dataContent = [dataDic objectForKey:@"data"];
            if (dataContent && [dataContent isKindOfClass:NSDictionary.class]) { //data值为字典
                dataDic = dataContent;
                [self logResponseCmdStr:cmd errorObject:nil dataDic:dataDic netError:netError];
            } else if (dataContent && ([dataContent isKindOfClass:NSString.class] || [dataContent isKindOfClass:NSNumber.class] || [dataContent isKindOfClass:NSArray.class])) {
                dataDic = @{ZCNetworkCustomKey : dataContent}; //data值为非字典
                [self logResponseCmdStr:cmd errorObject:nil dataDic:dataDic netError:netError];
            } else { //data值为空
                dataDic = [NSDictionary dictionary];
                netError = [ZCNetworkError networkErrorWithError:nil];
                [self logResponseCmdStr:cmd errorObject:dataObject dataDic:nil netError:netError];
            }
        } else { //返回错误
            NSString *errorPrompt = [dataDic stringValueForKey:@"respMsg"];
            if ([errorCode isEqualToString:@"*******"]) { //token过期
                [self onClearSaveData:nil];
            } else if ([errorCode isEqualToString:@"*******"]) { //被挤下线
                [self onClearSaveData:errorPrompt];
            } else if ([errorCode isEqualToString:@"*******"]) { //活动过期
                [self onClearSaveData:errorPrompt];
            }
            dataDic = [NSDictionary dictionary];
            netError = [ZCNetworkError networkErrorWithErrorCode:errorCode errorPrompt:errorPrompt];
            [self logResponseCmdStr:cmd errorObject:dataObject dataDic:nil netError:netError];
        }
    }
    if (block) {block(netError, dataDic); block = nil;}
    [self removeTask:task failTip:netError.errorPrompt];
}

- (void)logRequestCmdStr:(NSString *)cmdStr parmDic:(NSDictionary *)parmDic {
    if (self.runEnvironment == ZCEnumRunEnvironmentProduct) return;
    NSString *parmStr = nil;
    if (parmDic) parmStr = parmDic.jsonFormatString;
    NSLog(@"~~~~~~ request -> cmd:%@%@ -> parm:%@ \n", self.basicUrlStr, cmdStr, parmStr);
}

- (void)logResponseCmdStr:(NSString *)cmdStr errorObject:(id)errorObject dataDic:(NSDictionary *)dataDic netError:(ZCNetworkError *)netError {
    if (self.runEnvironment == ZCEnumRunEnvironmentProduct) return;
    BOOL isFailure = netError != nil;
    NSString *dcscPrompt = netError.errorPrompt;
    if (dataDic) dcscPrompt = dataDic.jsonFormatString;
    if (errorObject) dcscPrompt = errorObject;
    if (errorObject && [errorObject isKindOfClass:NSData.class]) dcscPrompt = ((NSData *)errorObject).utf8String;
    if (errorObject && [errorObject isKindOfClass:NSDictionary.class]) dcscPrompt = ((NSDictionary *)errorObject).jsonFormatString;
    NSLog(@"****** receive -> cmd:%@%@ -> %@ data:%@ \n", self.basicUrlStr, cmdStr, (isFailure ? @"failure" : @"success"), dcscPrompt);
}

#pragma mark - TaskTip
- (void)showBasicFail:(NSString *)failTip {
    if (failTip && [self.saveFailTip isEqualToString:ZCNetworkAutoTip]) {
        self.waitAnimationCount = 0;
        main_imp(^{[self.window showTip:failTip];});
    } else if (failTip && self.saveFailTip) {
        self.waitAnimationCount = 0;
        main_imp(^{[self.window showTip:self.saveFailTip];});
    }
    self.saveWaitTip = ZCNetworkAutoTip;
    self.saveFailTip = ZCNetworkAutoTip;
    self.saveSucsTip = ZCNetworkAutoTip;
}

- (void)injectTask:(NSURLSessionTask *)task {
    if (!task) {
        self.waitAnimationCount = 0;
        main_imp(^{[self.window hideWait];}); return;
    }
    [self.allActiveTasks addObjectIfNoExist:task];
    task.showWaitTip = self.saveWaitTip;
    task.showFailTip = self.saveFailTip;
    task.showSucsTip = self.saveSucsTip;
    if ([task.showWaitTip isEqualToString:ZCNetworkAutoTip]) {
        self.waitAnimationCount ++;
        main_imp(^{[self.window showAdditionalWait:nil];});
    } else if (task.showWaitTip) {
        self.waitAnimationCount ++;
        main_imp(^{[self.window showAdditionalWait:task.showWaitTip];});
    }
    self.saveWaitTip = ZCNetworkAutoTip;
    self.saveFailTip = ZCNetworkAutoTip;
    self.saveSucsTip = ZCNetworkAutoTip;
}

- (void)removeTask:(NSURLSessionTask *)task failTip:(NSString *)failTip {
    if (!task) {
        self.waitAnimationCount = 0;
        main_imp(^{[self.window hideWait];}); return;
    }
    [self.allActiveTasks removeObjectIfExist:task];
    if (task.showWaitTip) {
        self.waitAnimationCount --;
        if (self.waitAnimationCount <= 0) {
            main_imp(^{[self.window hideWait];});
        }
    }
    if (failTip && [task.showFailTip isEqualToString:ZCNetworkAutoTip]) { //显示自动的失败提示语
        self.waitAnimationCount = 0;
        main_imp(^{[self.window showTip:failTip];});
    } else if (failTip && task.showFailTip) { //显示手动的失败提示语
        self.waitAnimationCount = 0;
        main_imp(^{[self.window showTip:task.showFailTip];});
    } else if (!failTip && task.showSucsTip && ![task.showSucsTip isEqualToString:ZCNetworkAutoTip]) { //显示手动的成功提示语
        self.waitAnimationCount = 0;
        main_imp(^{[self.window showTip:task.showSucsTip];});
    }
}

#pragma mark - ClassApi1
+ (void)cancelAllTask {
    @synchronized (ZCNetwork.sharedNetwork) {
        [ZCNetwork.sharedNetwork.allActiveTasks enumerateObjectsUsingBlock:^(NSURLSessionTask * _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            [task cancel];
        }];
    }
}

+ (void)cancelTaskWithUrl:(NSString *)url {
    @synchronized (ZCNetwork.sharedNetwork) {
        [ZCNetwork.sharedNetwork.allActiveTasks enumerateObjectsUsingBlock:^(NSURLSessionTask * _Nonnull task, NSUInteger idx, BOOL * _Nonnull stop) {
            if (url.length && [task.currentRequest.URL.absoluteString hasSuffix:url]) {[task cancel]; *stop = YES;}
        }];
    }
}

+ (void)setNextRequestWaitTip:(NSString *)waitTip failTip:(NSString *)failTip sucsTip:(NSString *)sucsTip {
    @synchronized (ZCNetwork.sharedNetwork) {
        ZCNetwork.sharedNetwork.saveWaitTip = waitTip;
        ZCNetwork.sharedNetwork.saveFailTip = failTip;
        ZCNetwork.sharedNetwork.saveSucsTip = sucsTip;
    }
}

+ (void)get:(NSString *)cmdUrl parm:(NSDictionary *)parm block:(void (^)(ZCNetworkError * _Nullable, NSDictionary * _Nonnull))block {
    [ZCNetwork.sharedNetwork request:cmdUrl parm:parm post:NO block:block];
}

+ (void)post:(NSString *)cmdUrl parm:(NSDictionary *)parm block:(void (^)(ZCNetworkError * _Nullable, NSDictionary * _Nonnull))block {
    [ZCNetwork.sharedNetwork request:cmdUrl parm:parm post:YES block:block];
}

+ (NSString *)sign:(NSString *)str1 with:(NSString *)str2 with:(NSString *)str3 with:(NSString *)str4 with:(NSString *)str5; {
    return [ZCNetwork.sharedNetwork rsaSign:str1 with:str2 with:str3 with:str4 with:str5];
}

#pragma mark - ClassApi2
+ (ZCEnumRunEnvironment)runEnvironment {
    return ZCNetwork.sharedNetwork.runEnvironment;
}

#pragma mark - Private
- (NSString *)jsonObjectToJsonStr:(id)parm {
    if (!parm) return nil;
    if ([NSJSONSerialization isValidJSONObject:parm]) {
        NSError *error; NSString *json = nil;
        NSData *data = [NSJSONSerialization dataWithJSONObject:parm options:kNilOptions error:&error];
        if (!error && data) json = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        return json;
    }
    return nil;
}

- (void)onNetworkTips {
    if (self.isShowNetworkTips) return;
    self.isShowNetworkTips = YES;
    [ZCSystemHandler alertChoice:@"Attention" message:@"Not network service" ctor:^NSString * _Nullable(BOOL isCancel, BOOL * _Nonnull destructive) {
        return isCancel ? @"I know" : nil;
    } action:^(BOOL isCancel) {self.isShowNetworkTips = NO;}];
}

- (void)onClearSaveData:(NSString *)message {
    
}

- (void)showLoginWithAlertWithMessage:(NSString *)message {
   if (![[TYGlobalData getInstance] getToken].length) return;
   [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"isFirstShowVoucherskmnopqrs"];
   [[NSUserDefaults standardUserDefaults] removeObjectForKey:LoGInPP_TOKEN];
   [[NSUserDefaults standardUserDefaults] removeObjectForKey:LoGInPP_MeMberID];
   [[TYGlobalData getInstance] setPPtoken];
   [[TYGlobalData getInstance] setMemberID:@""];
   [[TYGlobalData getInstance] setLogout];
   UIViewController *currentVc = [ZCGlobal currentController];
   [currentVc showINKAlertWithTitle:@"Attention" andMsg:message cancleTitle:@"Confirm" handler:^{
       [[ZCMainViewController sharedVC] showLoginBox];
   }];
}

- (void)pushLogin {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"isFirstShowVoucherskmnopqrs"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:LoGInPP_TOKEN];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:LoGInPP_MeMberID];
    [[TYGlobalData getInstance] setPPtoken];
    [[TYGlobalData getInstance] setMemberID:@""];
    [[TYGlobalData getInstance] setLogout];
    [[ZCMainViewController sharedVC] showLoginBox];
}

- (void)clearSaveUserData {
    //[[JFManager sharedManager] logoutUser]; //清除数据，登出
    [[NSNotificationCenter defaultCenter] postNotificationName:@"notif_exit_login" object:nil];
}

#pragma mark - Action
- (void)onCountryChanged:(NSNotification *)noti {
    self.versionCheckState = 0;
    #warning - 用户数据需要登出账号 & 所有保存键前面需要加环境名 & 删除所有的NSLog & 重写用户数据类 & 退出登录取消当前所有请求
}

#pragma mark - Get & Set
- (UIWindow *)window {
    return [UIApplication sharedApplication].delegate.window;
}


#pragma mark - 版本检查
- (void)downloadVersionInfo {
    if ((self.downloadVersionCount % 2) || (self.downloadVersionCount > 20)) return;
    self.downloadVersionCount ++; //请求失败十次
    NSString *savePath = [[UIApplication.documentsPath stringByAppendingPathComponent:@"partner_version_info"] stringByAppendingPathExtension:@"json"];
    savePath = [savePath stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    if ([[NSFileManager defaultManager] fileExistsAtPath:savePath]) {
        NSDictionary *his = nil; NSData *data = [NSData dataWithContentsOfFile:savePath];
        [[NSFileManager defaultManager] removeItemAtPath:savePath error:nil];
        if (data) his = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
        if (his && [his isKindOfClass:NSDictionary.class] && !self.hisVersionInfo) {
            NSInteger time = (NSInteger)[[NSUserDefaults standardUserDefaults] integerForKey:@"partner_version_load_time"];
            if (time + 43200 > NSDate.date.timeIntervalSince1970) self.hisVersionInfo = his.copy; //最多加载半天前的历史数据
        }
    }
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    NSString *downloadUrl = @"*******";
    if (![AppEveronment isEqualToString:@"ProductionEnvironment"]) downloadUrl = @"*******";
    downloadUrl = [downloadUrl stringByAddingPercentEncodingWithAllowedCharacters:NSCharacterSet.URLQueryAllowedCharacterSet];
    NSURLRequest *requestUrl = [NSURLRequest requestWithURL:[NSURL URLWithString:downloadUrl]];
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSURLSessionDownloadTask *downloadTask = [manager downloadTaskWithRequest:requestUrl progress:nil destination:^NSURL *(NSURL *targetPath, NSURLResponse *response) {
            return [NSURL fileURLWithPath:savePath];
        } completionHandler:^(NSURLResponse *response, NSURL *filePath, NSError *error) {
            NSDictionary *dic = nil; NSData *data = [NSData dataWithContentsOfURL:filePath];
            if (data) dic = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:nil];
            if (dic && [dic isKindOfClass:NSDictionary.class]) self.versionInfo = dic.copy;
            self.downloadVersionCount ++;
            if (self.versionInfo.count) {
                [[NSUserDefaults standardUserDefaults] setInteger:(NSInteger)NSDate.date.timeIntervalSince1970 forKey:@"partner_version_load_time"];
                [[NSUserDefaults standardUserDefaults] synchronize];
                [self checkVersionInfo];
            }
        }]; [downloadTask resume];
    });
}

- (BOOL)checkVersionInfo { //返回是否检查不通过
    if (self.versionCheckState == 1) return YES;
    if (self.versionCheckState == 2 || self.versionCheckState == 3) return NO;
    if (!self.versionInfo.count) {
        [self downloadVersionInfo];
        if (!self.hisVersionInfo.count) return YES;
    }
    if (self.versionInfo.count) {
        NSDictionary *dic = [[self.versionInfo dictionaryValueForKey:@"partner"] dictionaryValueForKey:@"NG"];
        NSInteger currentCode = UIApplication.appBuildVersion.integerValue;
        NSInteger newestCode = [dic longValueForKey:@"versioncode"];
        NSInteger minCode = [dic longValueForKey:@"minversioncode"];
        NSString *name = [dic stringValueForKey:@"versionname"];
        NSString *desc = [dic stringValueForKey:@"releasenote"];
        if (currentCode < minCode) {
            [self showUpdateRemind:newestCode name:name desc:desc compulsory:YES];
            self.versionCheckState = 1; return YES; //强制更新
        } else if (currentCode < newestCode) {
            [self showUpdateRemind:newestCode name:name desc:desc compulsory:NO];
            self.versionCheckState = 2; return NO; //更新提示
        } else {
            self.versionCheckState = 3; return NO; //无更新
        }
    } else {
        NSDictionary *dic = [[self.hisVersionInfo dictionaryValueForKey:@"partner"] dictionaryValueForKey:@"NG"];
        NSInteger currentCode = UIApplication.appBuildVersion.integerValue;
        NSInteger minCode = [dic longValueForKey:@"minversioncode"];
        if (currentCode < minCode) return YES;
    }
    return NO;
}

- (void)showUpdateRemind:(NSInteger)newestCode name:(NSString *)name desc:(NSString *)desc compulsory:(BOOL)compulsory {
    NSInteger cacheCode = [[NSUserDefaults standardUserDefaults] integerForKey:@"partner_remind_version"];
    if (compulsory || (!compulsory && cacheCode != newestCode)) {
        TYNewVersionView *views = [TYNewVersionView createName:name desc:desc compulsory:compulsory];
        views.selectBlock = ^(BOOL isComfirm) {
            if (isComfirm) {
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"*******"]];
            } else {
                [[TYGlobalData getInstance] dissMissCustomerWindow];
            }
            if (!compulsory) {
                [[NSUserDefaults standardUserDefaults] setInteger:newestCode forKey:@"partner_remind_version"];
                [[NSUserDefaults standardUserDefaults] synchronize];
            }
        };
        [[TYGlobalData getInstance].customerWindow addSubview:views];
    }
}

@end

//
//  ZCNetwork.h
//  PalmPartner
//
//  Created by zjy on 2020/1/17.
//  Copyright © 2020 Ttranssnet. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NSString * ZCNetworkKey;

extern ZCNetworkKey const ZCNetworkAutoTip;
extern ZCNetworkKey const ZCNetworkCustomKey;

typedef NS_ENUM(NSUInteger, ZCEnumRunEnvironment) { //运行环境
    ZCEnumRunEnvironmentProduct     = 0, //生产环境
    ZCEnumRunEnvironmentGrayscale   = 1, //灰度环境
    ZCEnumRunEnvironmentTest        = 2, //测试环境
    ZCEnumRunEnvironmentDevelopment = 3, //开发环境
};

typedef NS_ENUM(NSUInteger, ZCEnumNetworkError) { //失败类型
    ZCEnumNetworkErrorPrompt    = 1, //返回错误
    ZCEnumNetworkErrorTimeOut   = 2, //请求超时
    ZCEnumNetworkErrorAbnormal  = 3, //请求异常
    ZCEnumNetworkErrorNoNetwork = 4, //无网络
    ZCEnumNetworkErrorCanceled  = 5, //被取消
    ZCEnumNetworkErrorAppUpdate = 6, //需更新
};


@interface ZCNetworkError : NSObject //网络请求错误类

@property (nonatomic, copy, readonly) NSString *errorCode; /**< 错误码 */

@property (nonatomic, copy, readonly) NSString *errorPrompt; /**< 错误提示 */

@property (nonatomic, assign, readonly) ZCEnumNetworkError errorType; /**< 错误类型 */

@end


@interface ZCNetwork : NSObject //通用网络请求类

@property (class, nonatomic, readonly) ZCEnumRunEnvironment runEnvironment; /**< 当前运行环境 */

/** 程序启动时调用 */
+ (void)start;

/** 取消当前的单个请求 & 顺序遍历到的第一个 */
+ (void)cancelTaskWithUrl:(NSString *)url;

/** 按参数设置返回已经包装好的ras签名 */
+ (NSString *)sign:(nullable NSString *)str1 with:(nullable NSString *)str2 with:(nullable NSString *)str3 with:(nullable NSString *)str4 with:(nullable NSString *)str5;

/** 下个请求提示设置，不实现默认只展示加载动画和自定义错误提示，waitTip请求中提示(设置nil不显示)，failTip请求错误提示(设置nil不显示)，sucsTip请求成功提示(设置nil或auto都不显示) */
+ (void)setNextRequestWaitTip:(nullable NSString *)waitTip failTip:(nullable NSString *)failTip sucsTip:(nullable NSString *)sucsTip;

/** GET请求，必定回调block，当netError为nil即表示请求成功(即respCode为@"00000000"且data对应的value有值)，dataDic为最终请求data字段对应的value字典对象(若value为非字典将会自动拼接成一个键值对组成字典) */
+ (void)get:(NSString *)cmdUrl parm:(nullable NSDictionary *)parm block:(void(^)(ZCNetworkError * _Nullable netError, NSDictionary * _Nonnull dataDic))block;

/** POST请求，必定回调block，当netError为nil即表示请求成功(即respCode为@"00000000"且data对应的value有值)，dataDic为最终请求data字段对应的value字典对象(若value为非字典将会自动拼接成一个键值对组成字典) */
+ (void)post:(NSString *)cmdUrl parm:(nullable NSDictionary *)parm block:(void(^)(ZCNetworkError * _Nullable netError, NSDictionary * _Nonnull dataDic))block;

@end

NS_ASSUME_NONNULL_END

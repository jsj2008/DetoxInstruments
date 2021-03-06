//
//  DTXRemoteProfilingBasics.h
//  DTXProfiler
//
//  Created by Leo Natan (Wix) on 23/07/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

@class NSEntityDescription;

typedef NS_ENUM(NSUInteger, DTXRemoteProfilingCommandType) {
	DTXRemoteProfilingCommandTypePing,
	DTXRemoteProfilingCommandTypeGetDeviceInfo,
	DTXRemoteProfilingCommandTypeStartProfilingWithConfiguration,
	DTXRemoteProfilingCommandTypeProfilingStoryEvent,
	DTXRemoteProfilingCommandTypeStopProfiling,
};

@class DTXRecording, DTXSampleGroup, DTXPerformanceSample, DTXAdvancedPerformanceSample;
@class DTXThreadInfo, DTXReactNativePeroformanceSample, DTXNetworkSample, DTXLogSample, DTXTag;

@protocol DTXProfilerStoryListener <NSObject>

- (void)createRecording:(DTXRecording*)recording;
- (void)updateRecording:(DTXRecording*)recording stopRecording:(BOOL)stopRecording;
- (void)pushSampleGroup:(DTXSampleGroup*)sampleGroup isRootGroup:(BOOL)root;
- (void)popSampleGroup:(DTXSampleGroup*)sampleGroup;
- (void)createdOrUpdatedThreadInfo:(DTXThreadInfo*)threadInfo;
- (void)addPerformanceSample:(__kindof DTXPerformanceSample*)perfrmanceSample;
- (void)addRNPerformanceSample:(DTXReactNativePeroformanceSample *)rnPerfrmanceSample;
- (void)startRequestWithNetworkSample:(DTXNetworkSample*)networkSample;
- (void)finishWithResponseForNetworkSample:(DTXNetworkSample*)networkSample;
- (void)addLogSample:(DTXLogSample*)logSample;
- (void)addTag:(DTXTag*)tag;

@end

@protocol DTXProfilerStoryDecoder <NSObject>

- (void)willDecodeStoryEvent;
- (void)didDecodeStoryEvent;

- (void)createRecording:(NSDictionary*)recording entityDescription:(NSEntityDescription*)entityDescription;
- (void)updateRecording:(NSDictionary*)recording stopRecording:(NSNumber*)stopRecording entityDescription:(NSEntityDescription*)entityDescription;
- (void)pushSampleGroup:(NSDictionary*)sampleGroup isRootGroup:(NSNumber*)root entityDescription:(NSEntityDescription*)entityDescription;
- (void)popSampleGroup:(NSDictionary*)sampleGroup entityDescription:(NSEntityDescription*)entityDescription;
- (void)createdOrUpdatedThreadInfo:(NSDictionary*)threadInfo entityDescription:(NSEntityDescription*)entityDescription;
- (void)addPerformanceSample:(NSDictionary*)perfrmanceSample entityDescription:(NSEntityDescription*)entityDescription;
- (void)addRNPerformanceSample:(NSDictionary *)rnPerfrmanceSample entityDescription:(NSEntityDescription*)entityDescription;
- (void)startRequestWithNetworkSample:(NSDictionary*)networkSample entityDescription:(NSEntityDescription*)entityDescription;
- (void)finishWithResponseForNetworkSample:(NSDictionary*)networkSample entityDescription:(NSEntityDescription*)entityDescription;
- (void)addLogSample:(NSDictionary*)logSample entityDescription:(NSEntityDescription*)entityDescription;
- (void)addTag:(NSDictionary*)tag entityDescription:(NSEntityDescription*)entityDescription;

@end

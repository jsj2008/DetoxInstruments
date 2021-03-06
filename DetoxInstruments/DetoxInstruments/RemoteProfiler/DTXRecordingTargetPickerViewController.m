//
//  DTXRecordingTargetPickerViewController.m
//  DetoxInstruments
//
//  Created by Leo Natan (Wix) on 20/07/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import "DTXRecordingTargetPickerViewController.h"
#import "DTXRemoteProfilingTarget-Private.h"
#import "DTXRemoteProfilingTargetCellView.h"
#import "DTXRemoteProfilingBasics.h"
#import "DTXProfilingConfiguration.h"

@interface DTXRecordingTargetPickerViewController () <NSOutlineViewDataSource, NSOutlineViewDelegate, NSNetServiceBrowserDelegate, NSNetServiceDelegate, DTXRemoteProfilingTargetDelegate>
{
	IBOutlet NSOutlineView* _outlineView;
	IBOutlet NSButton* _selectButton;
	
	NSNetServiceBrowser* _browser;
	NSMutableArray<DTXRemoteProfilingTarget*>* _targets;
	NSMapTable<NSNetService*, DTXRemoteProfilingTarget*>* _serviceToTargetMapping;
	NSMapTable<DTXRemoteProfilingTarget*, NSNetService*>* _targetToServiceMapping;
	
	dispatch_queue_t _workQueue;
}

@end

@implementation DTXRecordingTargetPickerViewController

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	self.view.wantsLayer = YES;
	self.view.canDrawSubviewsIntoLayer = YES;
	
	_targets = [NSMutableArray new];
	_serviceToTargetMapping = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsStrongMemory];
	_targetToServiceMapping = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsStrongMemory];
	
	dispatch_queue_attr_t qosAttribute = dispatch_queue_attr_make_with_qos_class(DISPATCH_QUEUE_SERIAL, QOS_CLASS_USER_INTERACTIVE, 0);
	_workQueue = dispatch_queue_create("com.wix.DTXRemoteProfiler", qosAttribute);
	
	_browser = [NSNetServiceBrowser new];
	_browser.delegate = self;
	
	[_browser searchForServicesOfType:@"_detoxprofiling._tcp" inDomain:@""];
}

- (IBAction)selectRecording:(id)sender
{
	[self.delegate recordingTargetPicker:self didSelectRemoteProfilingTarget:_targets[_outlineView.selectedRow] profilingConfiguration:[DTXProfilingConfiguration defaultProfilingConfiguration]];
}

- (IBAction)cancel:(id)sender
{
	[self.delegate recordingTargetPickerDidCancel:self];
}

- (void)_addTarget:(DTXRemoteProfilingTarget*)target forService:(NSNetService*)service
{
	[_serviceToTargetMapping setObject:target forKey:service];
	[_targetToServiceMapping setObject:service forKey:target];
	[_targets addObject:target];
	
	[_outlineView insertItemsAtIndexes:[NSIndexSet indexSetWithIndex:_targets.count - 1] inParent:nil withAnimation:NSTableViewAnimationEffectFade];
}

- (void)_removeTargetForService:(NSNetService*)service
{
	DTXRemoteProfilingTarget* target = [_serviceToTargetMapping objectForKey:service];
	if(target == nil)
	{
		return;
	}
	
	NSInteger index = [_targets indexOfObject:target];
	
	if(index == NSNotFound)
	{
		return;
	}
	
	[_targets removeObjectAtIndex:index];
	[_serviceToTargetMapping removeObjectForKey:service];
	[_targetToServiceMapping removeObjectForKey:target];
	
	[_outlineView removeItemsAtIndexes:[NSIndexSet indexSetWithIndex:index] inParent:nil withAnimation:NSTableViewAnimationEffectFade];
}

- (void)_updateTarget:(DTXRemoteProfilingTarget*)target
{
//	[_outlineView reloadData];
	[_outlineView reloadItem:target];
}

#pragma mark NSNetServiceBrowserDelegate

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didFindService:(NSNetService *)service moreComing:(BOOL)moreComing
{
	service.delegate = self;
	
	DTXRemoteProfilingTarget* target = [DTXRemoteProfilingTarget new];
	[self _addTarget:target forService:service];
	
	[service resolveWithTimeout:10];
}

- (void)netServiceBrowser:(NSNetServiceBrowser *)browser didRemoveService:(NSNetService *)service moreComing:(BOOL)moreComing
{
	DTXRemoteProfilingTarget* target = [_serviceToTargetMapping objectForKey:service];
	if(target.state < 1)
	{
		[self _removeTargetForService:service];
	}
}

#pragma mark NSOutlineViewDataSource

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(nullable id)item
{
	if(item != nil)
	{
		return 0;
	}
	
	return _targets.count;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(nullable id)item
{
	return _targets[index];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return NO;
}

#pragma mark NSOutlineViewDelegate

- (nullable NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(nullable NSTableColumn *)tableColumn item:(id)item
{
	DTXRemoteProfilingTarget* target = item;
	
	DTXRemoteProfilingTargetCellView* cellView = [outlineView makeViewWithIdentifier:@"DTXRemoteProfilingTargetCellView" owner:nil];
	cellView.progressIndicator.usesThreadedAnimation = YES;
	
	switch(target.state)
	{
		case DTXRemoteProfilingTargetStateDiscovered:
		case DTXRemoteProfilingTargetStateResolved:
			cellView.title1Field.stringValue = @"";
			cellView.title2Field.stringValue = target.state == DTXRemoteProfilingTargetStateDiscovered ? NSLocalizedString(@"Resolving...", @"") : NSLocalizedString(@"Loading...", @"");
			cellView.title3Field.stringValue = @"";
			cellView.deviceImageView.hidden = YES;
			[cellView.progressIndicator startAnimation:nil];
			cellView.progressIndicator.hidden = NO;
			break;
		case DTXRemoteProfilingTargetStateDeviceInfoLoaded:
			cellView.title1Field.stringValue = target.deviceName;
			cellView.title2Field.stringValue = target.appName;
			cellView.title3Field.stringValue = target.deviceOS;
			cellView.deviceImageView.hidden = NO;
			[cellView.progressIndicator stopAnimation:nil];
			cellView.progressIndicator.hidden = YES;
			break;
		default:
			break;
	}
	
	return cellView;
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	_selectButton.enabled = _outlineView.selectedRowIndexes.count > 0;
}

#pragma mark NSNetServiceDelegate

- (void)netServiceDidResolveAddress:(NSNetService *)sender
{
	DTXRemoteProfilingTarget* target = [_serviceToTargetMapping objectForKey:sender];
	target.delegate = self;
	
	[target _connectWithHostName:sender.hostName port:sender.port workQueue:_workQueue];
	
	[target loadDeviceInfo];
	
	[self _updateTarget:target];
}

- (void)netService:(NSNetService *)sender didNotResolve:(NSDictionary<NSString *, NSNumber *> *)errorDict
{
	[self _removeTargetForService:sender];
}

#pragma mark DTXRemoteProfilingTargetDelegate

- (void)connectionDidCloseForProfilingTarget:(DTXRemoteProfilingTarget*)target
{
	dispatch_async(dispatch_get_main_queue(), ^ {
		[self _removeTargetForService:[_targetToServiceMapping objectForKey:target]];
	});
}

- (void)profilingTargetDidLoadDeviceInfo:(DTXRemoteProfilingTarget *)target
{
	dispatch_async(dispatch_get_main_queue(), ^{
		[self _updateTarget:target];
	});
}

@end

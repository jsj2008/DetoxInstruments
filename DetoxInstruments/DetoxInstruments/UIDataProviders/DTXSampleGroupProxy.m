//
//  DTXSampleGroupProxy.m
//  DetoxInstruments
//
//  Created by Leo Natan (Wix) on 12/06/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import "DTXSampleGroupProxy.h"
#import "DTXSampleGroup+UIExtensions.h"

@interface DTXSampleGroupProxy () <NSFetchedResultsControllerDelegate>

@end

@implementation DTXSampleGroupProxy
{
	NSFetchedResultsController* _frc;
	__weak NSOutlineView* _outlineView;
	NSArray<NSNumber*>* _sampleTypes;
	BOOL _isRoot;
	
	BOOL _updatesExperiencedErrors;
	
	NSMapTable<DTXSampleGroup*, DTXSampleGroupProxy*>* _groupToProxyMapping;
	NSMutableArray* _updates;
	NSMutableArray* _inserts;
}

- (id)_objForObj:(id)sample sampleTypes:(NSArray<NSNumber*>*)sampleTypes outlineView:(NSOutlineView*)outlineView
{
	if([sample isKindOfClass:[DTXSampleGroup class]])
	{
		DTXSampleGroup* sampleGroup = (id)sample;
		
		DTXSampleGroupProxy* groupProxy = [_groupToProxyMapping objectForKey:sampleGroup];
		
		if(groupProxy == nil)
		{
			groupProxy = [[DTXSampleGroupProxy alloc] initWithSampleGroup:sampleGroup sampleTypes:sampleTypes isRoot:NO outlineView:outlineView];
			groupProxy.name = sampleGroup.name;
			groupProxy.timestamp = sampleGroup.timestamp;
			groupProxy.closeTimestamp = sampleGroup.closeTimestamp;
			[_groupToProxyMapping setObject:groupProxy forKey:sampleGroup];
		}
		
		return groupProxy;
	}
	else
	{
		return sample;
	}
}

- (instancetype)initWithSampleGroup:(DTXSampleGroup*)sampleGroup sampleTypes:(NSArray<NSNumber*>*)sampleTypes outlineView:(NSOutlineView*)outlineView
{
	return [self initWithSampleGroup:sampleGroup sampleTypes:sampleTypes isRoot:YES outlineView:outlineView];
}

- (instancetype)initWithSampleGroup:(DTXSampleGroup*)sampleGroup sampleTypes:(NSArray<NSNumber*>*)sampleTypes isRoot:(BOOL)isRoot outlineView:(NSOutlineView*)outlineView;
{
	self = [super init];
	if(self)
	{
		_groupToProxyMapping = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsStrongMemory];
		_outlineView = outlineView;
		_sampleTypes = sampleTypes;
		_isRoot = isRoot;
		
		_frc = [[NSFetchedResultsController alloc] initWithFetchRequest:[sampleGroup fetchRequestForSamplesWithTypes:sampleTypes includingGroups:YES] managedObjectContext:sampleGroup.managedObjectContext sectionNameKeyPath:nil cacheName:nil];
		_frc.delegate = self;
		[_frc performFetch:NULL];
	}
	return self;
}

- (void)controllerWillChangeContent:(NSFetchedResultsController *)controller
{
	_updates = [NSMutableArray new];
	_inserts = [NSMutableArray new];
	
	_updatesExperiencedErrors = YES;
	
	[_outlineView beginUpdates];
}

- (void)controller:(NSFetchedResultsController *)controller didChangeObject:(id)anObject atIndexPath:(NSIndexPath *)indexPath forChangeType:(NSFetchedResultsChangeType)type newIndexPath:(NSIndexPath *)newIndexPath
{
	if(type == NSFetchedResultsChangeUpdate && [anObject isKindOfClass:[DTXSampleGroup class]] == NO)
	{
		[_updates addObject:@{@"anObject": anObject, @"indexPath": indexPath}];
	}
	
	if(type == NSFetchedResultsChangeInsert)
	{
		[_inserts addObject:@{@"anObject": anObject, @"indexPath": newIndexPath}];
	}
}

- (void)controllerDidChangeContent:(NSFetchedResultsController *)controller
{
	NSMutableArray* toExpand = [NSMutableArray new];
	
	@try
	{
		[_inserts sortUsingDescriptors:@[[NSSortDescriptor sortDescriptorWithKey:@"indexPath" ascending:YES]]];
		
		[_inserts enumerateObjectsUsingBlock:^(NSDictionary* _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
			id anObject = obj[@"anObject"];
			NSIndexPath* newIndexPath = obj[@"indexPath"];
			
			[_outlineView insertItemsAtIndexes:[NSIndexSet indexSetWithIndex:newIndexPath.item] inParent:_isRoot ? nil : self withAnimation:NSTableViewAnimationEffectNone];
			
			if([anObject isKindOfClass:[DTXSampleGroup class]])
			{
				[toExpand addObject:anObject];
			}
		}];
		
		[_updates enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
			NSIndexPath* indexPath = obj[@"indexPath"];
			
			[_outlineView reloadItem:[self sampleAtIndex:indexPath.item]];
		}];
		
		[_outlineView endUpdates];
		
		[_outlineView expandItem:nil expandChildren:YES];
	}
	@catch(NSException* e)
	{
		_updatesExperiencedErrors = YES;
	}
	
	if(_updatesExperiencedErrors)
	{
		[_outlineView reloadItem:_isRoot ? nil : self reloadChildren:YES];
	}
}

- (NSUInteger)samplesCount
{
	return _frc.fetchedObjects.count;
}

- (id)sampleAtIndex:(NSUInteger)index
{
	if(index >= _frc.fetchedObjects.count)
	{
		return nil;
	}
	
	id obj = [_frc objectAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]];
	
	return [self _objForObj:obj sampleTypes:_sampleTypes outlineView:_outlineView];
}

@end

@implementation DTXGroupInspectorDataProvider

- (DTXInspectorContentTableDataSource*)inspectorTableDataSource
{
	DTXSampleGroupProxy* proxy = (id)self.sample;
	
	DTXInspectorContentTableDataSource* rv = [DTXInspectorContentTableDataSource new];
	
	DTXInspectorContent* request = [DTXInspectorContent new];
	request.title = NSLocalizedString(@"Group", @"");
	
	NSMutableArray<DTXInspectorContentRow*>* content = [NSMutableArray new];
	
	[content addObject:[DTXInspectorContentRow contentRowWithTitle:NSLocalizedString(@"Name", @"") description:proxy.name]];
	
	NSTimeInterval ti = [proxy.timestamp timeIntervalSinceReferenceDate] - [self.document.recording.startTimestamp timeIntervalSinceReferenceDate];
	
	[content addObject:[DTXInspectorContentRow contentRowWithTitle:NSLocalizedString(@"Start", @"") description:[[NSFormatter dtx_secondsFormatter] stringForObjectValue:@(ti)]]];
	
	ti = [proxy.closeTimestamp ?: self.document.recording.endTimestamp timeIntervalSinceReferenceDate] - [self.document.recording.startTimestamp timeIntervalSinceReferenceDate];
	
	[content addObject:[DTXInspectorContentRow contentRowWithTitle:NSLocalizedString(@"End", @"") description:[[NSFormatter dtx_secondsFormatter] stringForObjectValue:@(ti)]]];
	
	request.content = content;
	
	rv.contentArray = @[request];
	
	return rv;
}

@end

//
//  DTXManagedPlotControllerGroup.m
//  DetoxInstruments
//
//  Created by Leo Natan (Wix) on 02/06/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import "DTXManagedPlotControllerGroup.h"
#import "DTXTimelineIndicatorView.h"
#import "DTXTableRowView.h"
#import "DTXPlotTypeCellView.h"
#import "DTXPlotHostingTableCellView.h"

@interface DTXManagedPlotControllerGroup () <DTXPlotControllerDelegate, NSOutlineViewDelegate, NSOutlineViewDataSource>
{
	NSMutableArray<id<DTXPlotController>>* _managedPlotControllers;
	NSMapTable<id<DTXPlotController>, NSMutableArray<id<DTXPlotController>>*>* _childrenMap;
	
	BOOL _ignoringPlotRangeNotifications;
	DTXTimelineIndicatorView* _timelineView;
	CPTPlotRange* _savedPlotRange;
	CPTPlotRange* _savedGlobalPlotRange;
	
	id<DTXPlotController> _currentlySelectedPlotController;
}

@property (nonatomic, strong) NSOutlineView* hostingOutlineView;
@property (nonatomic, copy, readonly) NSArray<id<DTXPlotController>>* plotControllers;
@property (nonatomic, copy, readonly) id<DTXPlotController> headerPlotController;

@end

@implementation DTXManagedPlotControllerGroup

- (instancetype)initWithHostingOutlineView:(NSOutlineView*)outlineView
{
	self = [super init];
	
	if(self)
	{
		_managedPlotControllers = [NSMutableArray new];
		_childrenMap = [NSMapTable mapTableWithKeyOptions:NSPointerFunctionsStrongMemory valueOptions:NSPointerFunctionsStrongMemory];
		
		_hostingOutlineView = outlineView;
		_hostingOutlineView.indentationPerLevel = 0;
		_hostingOutlineView.indentationMarkerFollowsCell = NO;
		_hostingOutlineView.dataSource = self;
		_hostingOutlineView.delegate = self;
		
		_timelineView = [DTXTimelineIndicatorView new];
		_timelineView.translatesAutoresizingMaskIntoConstraints = NO;

		NSTrackingArea* tracker = [[NSTrackingArea alloc] initWithRect:_timelineView.bounds options:NSTrackingActiveAlways | NSTrackingInVisibleRect | NSTrackingMouseEnteredAndExited | NSTrackingMouseMoved owner:self userInfo:nil];
		[_timelineView addTrackingArea:tracker];

		[_hostingOutlineView.superview.superview.superview addSubview:_timelineView positioned:NSWindowAbove relativeTo:_hostingOutlineView.superview.superview];

		[NSLayoutConstraint activateConstraints:@[[_hostingOutlineView.topAnchor constraintEqualToAnchor:_timelineView.topAnchor],
												  [_hostingOutlineView.leadingAnchor constraintEqualToAnchor:_timelineView.leadingAnchor],
												  [_hostingOutlineView.trailingAnchor constraintEqualToAnchor:_timelineView.trailingAnchor],
												  [_hostingOutlineView.bottomAnchor constraintEqualToAnchor:_timelineView.bottomAnchor]]];
	}
	
	return self;
}

- (NSArray<id<DTXPlotController>> *)plotControllers
{
	return _managedPlotControllers;
}

- (void)addHeaderPlotController:(id<DTXPlotController>)headerPlotController
{
	_headerPlotController = headerPlotController;
	_headerPlotController.delegate = self;
	
	if(_savedGlobalPlotRange)
	{
		[headerPlotController setGlobalPlotRange:_savedGlobalPlotRange enforceOnLocalPlotRange:YES];
	}
	else if(_savedPlotRange)
	{
		[headerPlotController setPlotRange:_savedPlotRange];
	}
}

- (void)addPlotController:(id<DTXPlotController>)plotController
{
	[self insertPlotController:plotController afterPlotController:_managedPlotControllers.lastObject];
}

- (void)removePlotController:(id<DTXPlotController>)plotController
{
	plotController.delegate = nil;
	[_managedPlotControllers removeObject:plotController];
}

- (void)insertPlotController:(id<DTXPlotController>)plotController afterPlotController:(id<DTXPlotController>)afterPlotController
{
	[self _insertPlotController:plotController afterPlotController:afterPlotController parentPlotController:nil inCollection:_managedPlotControllers];
}

- (void)_insertPlotController:(id<DTXPlotController>)plotController afterPlotController:(id<DTXPlotController>)afterPlotController parentPlotController:(id<DTXPlotController>)parentPlotController inCollection:(NSMutableArray<id<DTXPlotController>>*)collection
{
	NSInteger idx;
	
	if(afterPlotController == nil)
	{
		//This will make sure we insert at index 0.
		idx = -1;
	}
	else
	{
		idx = [collection indexOfObject:afterPlotController];
	}
	
	if(idx == NSNotFound)
	{
		return;
	}
	
	[collection insertObject:plotController atIndex:idx + 1];
	plotController.delegate = self;
	if(_savedGlobalPlotRange)
	{
		[plotController setGlobalPlotRange:_savedGlobalPlotRange enforceOnLocalPlotRange:YES];
	}
	else if(_savedPlotRange)
	{
		[plotController setPlotRange:_savedPlotRange];
	}
	
	[self _noteOutlineViewOfInsertedAtIndex:idx + 1 forItem:parentPlotController];
	
	if(idx == 0 && parentPlotController == nil && _hostingOutlineView.selectedRowIndexes.count == 0)
	{
		[_hostingOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:0] byExtendingSelection:NO];
	}
}

- (void)_noteOutlineViewOfInsertedAtIndex:(NSUInteger)index forItem:(id<DTXPlotController>)item
{
	[_hostingOutlineView beginUpdates];
	[_hostingOutlineView insertItemsAtIndexes:[NSIndexSet indexSetWithIndex:index] inParent:item withAnimation:NSTableViewAnimationEffectNone];
	[_hostingOutlineView endUpdates];
}

- (void)_noteOutlineViewOfRemovedAtIndex:(NSUInteger)index forItem:(id<DTXPlotController>)item
{
	[_hostingOutlineView beginUpdates];
	[_hostingOutlineView removeItemsAtIndexes:[NSIndexSet indexSetWithIndex:index] inParent:item withAnimation:NSTableViewAnimationEffectNone];
	[_hostingOutlineView endUpdates];
}

- (NSMutableArray<id<DTXPlotController>>*)_childrenArrayForPlotController:(id<DTXPlotController>)plotController create:(BOOL)create
{
	NSMutableArray* rv = [_childrenMap objectForKey:plotController];
	
	if(create == YES && rv == nil)
	{
		rv = [NSMutableArray new];
		[_childrenMap setObject:rv forKey:plotController];
	}
	
	return rv;
}

- (void)addChildPlotController:(id<DTXPlotController>)childPlotController toPlotController:(id<DTXPlotController>)plotController
{
	NSMutableArray* children = [self _childrenArrayForPlotController:plotController create:YES];
	[self _insertPlotController:childPlotController afterPlotController:children.lastObject parentPlotController:plotController inCollection:children];
}

- (void)insertChildPlotController:(id<DTXPlotController>)childPlotController afterChildPlotController:(id<DTXPlotController>)afterPlotController ofPlotController:(id<DTXPlotController>)plotController
{
	NSMutableArray* children = [self _childrenArrayForPlotController:plotController create:YES];
	[self _insertPlotController:childPlotController afterPlotController:afterPlotController parentPlotController:plotController inCollection:children];
}

- (void)removeChildPlotController:(id<DTXPlotController>)childPlotController ofPlotController:(id<DTXPlotController>)plotController
{
	NSMutableArray* children = [self _childrenArrayForPlotController:plotController create:YES];
	childPlotController.delegate = nil;
	[_managedPlotControllers removeObject:childPlotController];
}

- (void)mouseEntered:(NSEvent *)event
{
	[self mouseMoved:event];
}

- (void)mouseExited:(NSEvent *)event
{
	_timelineView.displaysIndicator = NO;
}

- (void)mouseMoved:(NSEvent *)event
{
	CGPoint pointInView = [_hostingOutlineView convertPoint:[event locationInWindow] fromView:nil];
	
	_timelineView.displaysIndicator = pointInView.x >= 210;
	_timelineView.indicatorOffset = pointInView.x;
}

- (void)setStartTimestamp:(NSDate*)startTimestamp endTimestamp:(NSDate*)endTimestamp;
{
	_savedGlobalPlotRange = [CPTPlotRange plotRangeWithLocation:@0 length:@(endTimestamp.timeIntervalSinceReferenceDate - startTimestamp.timeIntervalSinceReferenceDate)];
	
	BOOL shouldEnforce = _savedPlotRange == nil || fabs(_savedPlotRange.length.doubleValue - _savedGlobalPlotRange.length.doubleValue) < 1;
	
	_ignoringPlotRangeNotifications = YES;
	[_headerPlotController setGlobalPlotRange:_savedGlobalPlotRange enforceOnLocalPlotRange:shouldEnforce];
	[_managedPlotControllers enumerateObjectsUsingBlock:^(id<DTXPlotController>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
		[obj setGlobalPlotRange:_savedGlobalPlotRange enforceOnLocalPlotRange:shouldEnforce];
	}];
	if(shouldEnforce)
	{
		_savedPlotRange = nil;
	}
	_ignoringPlotRangeNotifications = NO;
}

- (void)zoomIn
{
	//Zooming in or out one plot controller will propagate to others using the plotController:didChangeToPlotRange: delegate method.
	[_managedPlotControllers.firstObject zoomIn];
}

- (void)zoomOut
{
	//Zooming in or out one plot controller will propagate to others using the plotController:didChangeToPlotRange: delegate method.
	[_managedPlotControllers.firstObject zoomOut];
}

- (void)plotControllerUserDidClickInPlotBounds:(id<DTXPlotController>)pc
{
	[_hostingOutlineView selectRowIndexes:[NSIndexSet indexSetWithIndex:[_hostingOutlineView childIndexForItem:pc]] byExtendingSelection:NO];
	[_hostingOutlineView.window makeFirstResponder:_hostingOutlineView];
}

- (void)requiredHeightChangedForPlotController:(id<DTXPlotController>)pc
{
	[_hostingOutlineView noteHeightOfRowsWithIndexesChanged:[NSIndexSet indexSetWithIndex:[_hostingOutlineView childIndexForItem:pc]]];
}

#pragma mark DTXPlotControllerDelegate

static BOOL __uglyHackTODOFixThisShit()
{
	//TODO: Fix
	return [[[NSThread callStackSymbols] description] containsString:@"CPTAnimation"];
}

- (void)plotController:(id<DTXPlotController>)pc didChangeToPlotRange:(CPTPlotRange *)plotRange
{
	if(_ignoringPlotRangeNotifications || __uglyHackTODOFixThisShit())
	{
		return;
	}
	
	_ignoringPlotRangeNotifications = YES;
	_savedPlotRange = plotRange;
	
	if(pc != _headerPlotController)
	{
		[_headerPlotController setPlotRange:plotRange];
	}
	
	[_managedPlotControllers enumerateObjectsUsingBlock:^(id<DTXPlotController>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
		if(obj == pc)
		{
			return;
		}
		
		[obj setPlotRange:plotRange];
	}];
	
	_ignoringPlotRangeNotifications = NO;
}

#pragma mark NSOutlineView Data Source & Delegate

- (NSInteger)outlineView:(NSOutlineView *)outlineView numberOfChildrenOfItem:(id)item
{
	if(item == nil)
	{
		return _managedPlotControllers.count;
	}
	
	return [[self _childrenArrayForPlotController:item create:NO] count];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView isItemExpandable:(id)item
{
	return [[self _childrenArrayForPlotController:item create:NO] count] > 0;
}

- (id)outlineView:(NSOutlineView *)outlineView child:(NSInteger)index ofItem:(id)item
{
	if(item == nil)
	{
		return _managedPlotControllers[index];
	}
	
	id<DTXPlotController> plotController = item;
	return [[self _childrenArrayForPlotController:plotController create:NO] objectAtIndex:index];
}

- (NSTableRowView *)outlineView:(NSOutlineView *)outlineView rowViewForItem:(id)item
{
	return [DTXTableRowView new];
}

- (NSView *)outlineView:(NSOutlineView *)outlineView viewForTableColumn:(NSTableColumn *)tableColumn item:(id)item
{
	id<DTXPlotController> controller = item;
	
	if([tableColumn.identifier isEqualToString:@"DTXTitleColumnt"])
	{
		DTXPlotTypeCellView* cell = [outlineView makeViewWithIdentifier:@"InfoTableViewCell" owner:nil];
		cell.textField.font = controller.titleFont;
		cell.textField.stringValue = controller.displayName;
		cell.textField.toolTip = controller.displayName;
		cell.textField.allowsDefaultTighteningForTruncation = YES;
		cell.imageView.image = controller.displayIcon;
		
		return cell;
	}
	else if([tableColumn.identifier isEqualToString:@"DTXGraphColumn"])
	{
		DTXPlotHostingTableCellView* cell = [outlineView makeViewWithIdentifier:@"PlotHostingTableViewCell" owner:nil];
		cell.plotController = controller;
		return cell;
	}
	
	return nil;
}

- (CGFloat)outlineView:(NSOutlineView *)outlineView heightOfRowByItem:(id)item
{
	return [item requiredHeight];
}

- (BOOL)outlineView:(NSOutlineView *)outlineView shouldSelectItem:(id)item
{
	return [item canReceiveFocus];
}

- (void)outlineViewSelectionDidChange:(NSNotification *)notification
{
	[_currentlySelectedPlotController removeHighlight];
	
	id<DTXPlotController> plotController = [_hostingOutlineView itemAtRow:_hostingOutlineView.selectedRow];
	_currentlySelectedPlotController = plotController;

	[self.delegate managedPlotControllerGroup:self didSelectPlotController:plotController];
}

@end

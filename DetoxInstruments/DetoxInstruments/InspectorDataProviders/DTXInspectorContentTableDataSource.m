//
//  DTXContentAwareTableDataSource.m
//  DetoxInstruments
//
//  Created by Leo Natan (Wix) on 14/06/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import "DTXInspectorContentTableDataSource.h"
#import "DTXTextViewCellView.h"
#import "DTXViewCellView.h"
#import "DTXStackTraceCellView.h"
@import QuartzCore;

@implementation DTXInspectorContentRow

@synthesize description=_description;

+ (instancetype)contentRowWithTitle:(NSString *)title description:(NSString *)description
{
	return [self contentRowWithTitle:title description:description color:NSColor.blackColor];
}

+ (instancetype)contentRowWithTitle:(NSString*)title description:(NSString*)description color:(NSColor*)color
{
	DTXInspectorContentRow* rv = [DTXInspectorContentRow new];
	rv.title = title;
	rv.description = description;
	rv.color = color;
	
	return rv;
}

+ (instancetype)contentRowWithNewLine
{
	return [self contentRowWithTitle:@"\n" description:@"\n"];
}

- (BOOL)isNewLine
{
	return [self.title isEqualToString:@"\n"] && [self.description isEqualToString:@"\n"];
}

@end

@implementation DTXInspectorContent @end

@interface DTXInspectorContentTableDataSource () <NSTableViewDataSource, NSTableViewDelegate>
{
	NSMutableArray<NSMutableAttributedString*>* _attributedStrings;
}

@end

@implementation DTXInspectorContentTableDataSource

- (void)setManagedTableView:(NSTableView *)managedTableView
{
	//Cleanup
	_managedTableView.dataSource = nil;
	_managedTableView.delegate = nil;
	[_managedTableView reloadData];
	
	_managedTableView = managedTableView;
	
#if __MAC_OS_X_VERSION_MAX_ALLOWED > __MAC_10_12_4
	if (@available(macOS 10.13, *))
	{
		_managedTableView.usesAutomaticRowHeights = YES;
	}
#endif
	
	_managedTableView.dataSource = self;
	_managedTableView.delegate = self;
	[_managedTableView reloadData];
}

- (void)setContentArray:(NSArray<DTXInspectorContent *> *)contentArray
{
	_contentArray = [contentArray copy];
	[self _prepareAttributedStrings];
	[_managedTableView reloadData];
}

- (void)_prepareAttributedStrings
{
	_attributedStrings = [NSMutableArray new];
	[_contentArray enumerateObjectsUsingBlock:^(DTXInspectorContent * _Nonnull content, NSUInteger idx, BOOL * _Nonnull stop) {
		NSMutableAttributedString* mas = [NSMutableAttributedString new];
		[content.content enumerateObjectsUsingBlock:^(DTXInspectorContentRow * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
			if(obj.isNewLine)
			{
				[mas appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:10 weight:NSFontWeightRegular]}]];
				return;
			}
			
			if(obj.description == nil)
			{
				return;
			}
			
			if(obj.title)
			{
				[mas appendAttributedString:[[NSAttributedString alloc] initWithString:obj.title attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:10 weight:NSFontWeightSemibold]}]];
				[mas appendAttributedString:[[NSAttributedString alloc] initWithString:@": " attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:10 weight:NSFontWeightSemibold]}]];
			}
			
			[mas appendAttributedString:[[NSAttributedString alloc] initWithString:obj.description attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:10 weight:NSFontWeightRegular], NSForegroundColorAttributeName: obj.color}]];
			
			if(idx < content.content.count - 1)
			{
				[mas appendAttributedString:[[NSAttributedString alloc] initWithString:@"\n" attributes:@{NSFontAttributeName: [NSFont systemFontOfSize:10 weight:NSFontWeightRegular]}]];
			}
		}];
		[_attributedStrings addObject:mas];
	}];
}

- (NSInteger)numberOfRowsInTableView:(NSTableView *)tableView
{
	return _attributedStrings.count;
}

- (nullable NSView *)tableView:(NSTableView *)tableView viewForTableColumn:(nullable NSTableColumn *)tableColumn row:(NSInteger)row
{
	DTXInspectorContent* content = _contentArray[row];
	
	__kindof NSTableCellView* cell = [tableView makeViewWithIdentifier:content.stackFrames ? @"DTXStackTraceCellView" : content.customView ? @"DTXViewCellView" : content.image ? @"DTXImageViewCellView" : @"DTXTextViewCellView" owner:nil];
	
	NSView* targetForWindowWideCopy = cell.imageView;
	
	if(content.stackFrames != nil)
	{
		[cell setStackFrames:content.stackFrames];
		targetForWindowWideCopy = [cell stackTraceTableView];
	}
	
	if(content.customView == nil && content.image == nil && content.stackFrames == nil)
	{
		[cell contentTextField].attributedStringValue = _attributedStrings[row];
		[cell contentTextField].allowsEditingTextAttributes = YES;
		[cell contentTextField].selectable = YES;
		targetForWindowWideCopy = [cell contentTextField];
	}
	
	cell.textField.stringValue = content.title ?: @"Title";
	cell.imageView.image = content.image;
	
	if(content.customView)
	{
		[content.customView removeFromSuperview];
		
		DTXViewCellView* viewCell = (id)cell;
		[viewCell.contentView addSubview:content.customView];
		[NSLayoutConstraint activateConstraints:@[[viewCell.contentView.topAnchor constraintEqualToAnchor:content.customView.topAnchor],
												  [viewCell.contentView.bottomAnchor constraintEqualToAnchor:content.customView.bottomAnchor],
												  [viewCell.contentView.centerXAnchor constraintEqualToAnchor:content.customView.centerXAnchor],
												  [viewCell.contentView.centerYAnchor constraintEqualToAnchor:content.customView.centerYAnchor]]];
		
		targetForWindowWideCopy = viewCell.contentView;
	}
	
	if(content.setupForWindowWideCopy)
	{
		[tableView.window.windowController setTargetForCopy:targetForWindowWideCopy];
	}
	
	return cell;
}

- (CGFloat)_displayHeightForString:(NSAttributedString*)string width:(CGFloat)width
{
	return [string boundingRectWithSize:NSMakeSize(width, 0) options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading].size.height;
}

- (CGFloat)tableView:(NSTableView *)tableView heightOfRow:(NSInteger)row
{
	DTXInspectorContent* content = _contentArray[row];
	
	CGFloat top = 3 + 14 + 10;
	CGFloat bottom = 3 + 10;
	CGFloat leading = 15;
	CGFloat trailing = 3;
	
	if(content.stackFrames)
	{
		return top + DTXStackTraceCellView.heightForStackFrame * content.stackFrames.count + bottom;
	}
	
	if(content.customView)
	{
		CGFloat h = top + content.customView.fittingSize.height + bottom;
		
		return h;
	}
	
	if(content.image)
	{
		CGFloat availableWidth = tableView.bounds.size.width - leading - trailing;
		CGFloat scale = 1.0;
		if(availableWidth < content.image.size.width)
		{
			scale = availableWidth / content.image.size.width;
		}
		
		return top + MAX(content.image.size.height, 80) * scale + bottom;
	}
	
	return top + [self _displayHeightForString:_attributedStrings[row] width:tableView.bounds.size.width - leading - trailing] + bottom;
}

@end

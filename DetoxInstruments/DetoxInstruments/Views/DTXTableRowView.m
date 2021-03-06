//
//  DTXTableRowView.m
//  DetoxInstruments
//
//  Created by Leo Natan (Wix) on 11/06/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import "DTXTableRowView.h"

@implementation DTXTableRowView
{
	NSView* _backgroundView;
}

- (instancetype)init
{
	self = [super init];
	
	if(self)
	{
		self.wantsLayer = YES;
	}
	
	return self;
}

- (void)setSelected:(BOOL)selected
{
	[super setSelected:selected];
}

- (void)drawSelectionInRect:(NSRect)dirtyRect {
	[super drawSelectionInRect:dirtyRect];
//	if (self.selectionHighlightStyle != NSTableViewSelectionHighlightStyleNone) {
//		NSRect selectionRect = NSInsetRect(self.bounds, 2.5, 2.5);
//		[[NSColor colorWithCalibratedWhite:.65 alpha:1.0] setStroke];
//		[[NSColor colorWithCalibratedWhite:.82 alpha:1.0] setFill];
//		NSBezierPath *selectionPath = [NSBezierPath bezierPathWithRoundedRect:selectionRect xRadius:6 yRadius:6];
//		[selectionPath fill];
//		[selectionPath stroke];
//	}
}

- (void)layout
{
	[super layout];
	
	if(self.isGroupRowStyle)
	{
		[self.subviews enumerateObjectsUsingBlock:^(__kindof NSView * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
			if([obj isKindOfClass:[NSButton class]])
			{
				obj.frame = (CGRect){6, obj.frame.origin.y, obj.frame.size};
			}
			else
			{
				obj.frame = (CGRect){24, obj.frame.origin.y, obj.frame.size};
			}
		}];
	}
}


@end

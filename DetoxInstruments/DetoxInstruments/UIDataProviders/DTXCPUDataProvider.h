//
//  DTXCPUDataProvider.h
//  DetoxInstruments
//
//  Created by Leo Natan (Wix) on 12/06/2017.
//  Copyright © 2017 Wix. All rights reserved.
//

#import "DTXUIDataProvider.h"

@interface DTXCPUDataProvider : DTXUIDataProvider

- (NSString*)titleOfCPUHeader;
- (BOOL)showsHeaviestThreadColumn;

@end

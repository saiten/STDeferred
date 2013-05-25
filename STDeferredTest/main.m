//
//  main.m
//  STDeferredTest
//
//  Created by saiten on 12/08/25.
//  Copyright (c) 2012年 saiten. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <GHUnitIOS/GHUnit.h>

@interface MyUIApp : UIApplication
@end

@implementation MyUIApp

- (id)init
{
    self = [super init];
    if (self && getenv("GHUNIT_CLI") && [[[UIDevice currentDevice] systemVersion] doubleValue] >= 5.0) {
        
        __block BOOL done = NO;
        NSOperationQueue * queue = [[NSOperationQueue alloc ] init];
        [queue addOperationWithBlock:^{
            [GHTestRunner run];
            done = YES;
        }];
        
        while( !done ) {
            [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow:5]];
        }
    }
    
    return self;
}

@end

int main(int argc, char *argv[])
{
  @autoreleasepool {
      return UIApplicationMain(argc, argv, @"MyUIApp", @"GHUnitIOSAppDelegate");
  }
}

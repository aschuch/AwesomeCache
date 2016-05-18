//
//  NSKeyedUnarchiverWrapper.m
//  Example
//
//  Created by Javier Soto on 5/17/16.
//  Copyright © 2016 Alexander Schuch. All rights reserved.
//

#import "NSKeyedUnarchiverWrapper.h"

NSObject * __nullable _awesomeCache_unarchiveObjectSafely(NSString *path) {
    @try {
        return [NSKeyedUnarchiver unarchiveObjectWithFile:path];
    }
    @catch (NSException *exception) {
        NSLog(@"Caught exception while unarchiving file at path %@: %@", path, exception);
        return nil;
    }
}

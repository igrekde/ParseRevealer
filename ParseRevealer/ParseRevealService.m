//
//  ParseRevealService.m
//  ParseRevealer
//
//  Created by Egor Tolstoy on 06.01.15.
//  Copyright (c) 2015 Egor Tolstoy. All rights reserved.
//

#import "ParseRevealService.h"

#import <ParseOSX/ParseOSX.h>

typedef void (^ParsePermissionCheckBlock)(ParseACLPermission permission, NSError *error);
typedef void (^ParseFirstObjectBlock)(PFObject *firstObject, NSError *error);

@implementation ParseRevealService

#pragma mark - Public Methods

- (void)checkParseForApplicationId:(NSString *)applicationId
                         clientKey:(NSString *)clientKey
                   completionBlock:(ParseAccountCheckBlock)completion
{
    [Parse setApplicationId:applicationId clientKey:clientKey];
    
    PFQuery *query = [PFUser query];
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        completion(error);
    }];
}

- (void)getAclForCustomClass:(NSString *)customClassName
             completionBlock:(ParseCustomClassACLBlock)completion
{
    NSMutableDictionary *aclDictionary = [@{} mutableCopy];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    dispatch_group_t group = dispatch_group_create();
    
    dispatch_group_enter(group);
    [self checkGetPermissionForCustomClass:customClassName completionBlock:^(ParseACLPermission permission, NSError *error) {
        [aclDictionary setObject:@(permission) forKey:@"GET"];
        dispatch_group_leave(group);
    }];
    
    dispatch_group_enter(group);
    [self checkFindPermissionForCustomClass:customClassName completionBlock:^(ParseACLPermission permission, NSError *error) {
        [aclDictionary setObject:@(permission) forKey:@"FIND"];
        dispatch_group_leave(group);
    }];

    dispatch_group_enter(group);
    [self checkUpdatePermissionForCustomClass:customClassName completionBlock:^(ParseACLPermission permission, NSError *error) {
        [aclDictionary setObject:@(permission) forKey:@"UPDATE"];
        dispatch_group_leave(group);
    }];
    
    dispatch_group_notify(group, queue,^{
        NSLog(@"group begin");
        completion(aclDictionary, nil);
        NSLog(@"group end");
    });
}

#pragma mark - Private Methods

- (void)checkGetPermissionForCustomClass:(NSString *)customClassName completionBlock:(ParsePermissionCheckBlock)completion {
    [self firstObjectInQueryForCustomClassName:customClassName completionBlock:^(PFObject *firstObject, NSError *error) {
        if (!firstObject) {
            completion(ParseACLPermissionUnknown, nil);
        }
        
        if (firstObject && !error) {
            NSString *firstObjectId = firstObject.objectId;
            
            PFObject *testObject = [PFQuery getObjectOfClass:customClassName
                                                    objectId:firstObjectId
                                                       error:&error];
            if (testObject && !error) {
                completion(ParseACLPermissionTrue, nil);
            } else if (error.code == 119) {
                completion(ParseACLPermissionFalse, error);
            } else {
                completion(ParseACLPermissionUnknown, nil);
            }
        } else {
            completion(ParseACLPermissionUnknown, nil);
        }
    }];
}

- (void)checkFindPermissionForCustomClass:(NSString *)customClassName completionBlock:(ParsePermissionCheckBlock)completion {
    [self firstObjectInQueryForCustomClassName:customClassName completionBlock:^(PFObject *firstObject, NSError *error) {
        if (!error) {
            completion(ParseACLPermissionTrue, nil);
        } else if (error.code == 119) {
            completion(ParseACLPermissionFalse, error);
        } else {
            completion(ParseACLPermissionUnknown, nil);
        }
    }];
}

- (void)checkUpdatePermissionForCustomClass:(NSString *)customClassName completionBlock:(ParsePermissionCheckBlock)completion {
    [self firstObjectInQueryForCustomClassName:customClassName completionBlock:^(PFObject *firstObject, NSError *error) {
        if (!firstObject) {
            completion(ParseACLPermissionUnknown, nil);
        }
        
        NSArray *allKeys = [firstObject allKeys];
        NSString *firstKey = [allKeys firstObject];
        [firstObject setValue:@"" forKey:firstKey];
        
        [firstObject saveInBackgroundWithBlock:^(BOOL succeeded, NSError *error) {
            if (succeeded || error.code == 111) {
                completion(ParseACLPermissionTrue, nil);
            } else if (error.code == 119) {
                completion(ParseACLPermissionFalse, error);
            } else {
                completion(ParseACLPermissionUnknown, nil);
            }
        }];
    }];
}

- (BOOL)checkCreatePermissionForCustomClass:(NSString *)customClassName {
    return NO;
}

- (BOOL)checkDeletePermissionForCustomClass:(NSString *)customClassName {
    return NO;
}

- (BOOL)checkAddFieldsPermissionForCustomClass:(NSString *)customClassName {
    return NO;
}

- (void)firstObjectInQueryForCustomClassName:(NSString *)customClassName completionBlock:(ParseFirstObjectBlock)completion {
    PFQuery *query = [PFQuery queryWithClassName:customClassName];
    
    [query findObjectsInBackgroundWithBlock:^(NSArray *objects, NSError *error) {
        if (objects && !error) {
            PFObject *firstObject = [objects firstObject];
            
            completion(firstObject, nil);
        } else {
            completion(nil, error);
        }
    }];
}

@end

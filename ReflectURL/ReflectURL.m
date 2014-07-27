//
//  ReflectURL.m
//  ReflectURL
//
//  Created by inket on 27/07/2014.
//  Copyright (c) 2014 inket. All rights reserved.
//

#import "ReflectURL.h"
#import <objc/runtime.h>
#import <AppKit/AppKit.h>

@interface UnifiedField : NSObject
- (NSURL*)reflectedURL;
- (void)setReflectedURL:(NSURL*)newURL;
- (NSString*)_urlStringWithOnlyHostNameVisible:(NSString*)truncated expandedURLString:(NSString*)expanded;
- (void)setShowingSecurityUI:(BOOL)ok;
- (BOOL)_lockButtonIsVisible;
- (BOOL)_isEditing;
@end

@interface BrowserWindowControllerMac : NSObject
- (UnifiedField*)unifiedField;
@end

@interface BrowserWindow : NSObject
- (BrowserWindowControllerMac*)windowController;
@end

@implementation NSObject (ReflectURL)

- (void)new_setReflectedURL:(NSURL*)newURL {
    [self new_setReflectedURL:newURL];
    
    // It seems Safari calculates the constraints (mainly width) of the address bar text
    // from the ivar "_reflectedURLStringWhenNotEditing", so we make sure it's up to date.
    [self setValue:[newURL absoluteString] forKey:@"_reflectedURLStringWhenNotEditing"];
}


- (NSString*)new_urlStringWithOnlyHostNameVisible:(NSString*)truncated expandedURLString:(NSString*)expanded {
    // We give it the expanded version instead of the truncated one! :)
    return [self new_urlStringWithOnlyHostNameVisible:expanded expandedURLString:expanded];
}

- (void)new_setShowingSecurityUI:(BOOL)defaultValue {
    // Getting rid of the certificate title: Hide if it exists, else default implementation
    BOOL shouldHideSecurityUI = ([self valueForKey:@"_evCertificateTitle"] != nil);
    [self new_setShowingSecurityUI:shouldHideSecurityUI ? NO : defaultValue];
}

- (BOOL)new_lockButtonIsVisible {
    BOOL defaultResult = [self new_lockButtonIsVisible];
    BOOL shouldShowSecurityUI = ([self valueForKey:@"_evCertificateTitle"] != nil);
    BOOL isEditingURL = [(UnifiedField*)self _isEditing];
    
    return !isEditingURL && (defaultResult || shouldShowSecurityUI);
}

@end

@implementation ReflectURL

+ (instancetype)sharedInstance {
    static ReflectURL* plugin = nil;
    
    if (plugin == nil)
        plugin = [[ReflectURL alloc] init];
    
    return plugin;
}

+ (void)load {
    [[ReflectURL sharedInstance] loadPlugin];
    NSLog(@"ReflectURL loaded.");
}

- (void)loadPlugin {
    BOOL safari8OrLater = NSClassFromString(@"ScrollableTabBarView") != nil;
    
    if (!safari8OrLater)
    {
        NSLog(@"ReflectURL only works on Safari 8 or later.");
        return;
    }
    else
    {
        Class class = NSClassFromString(@"UnifiedField");
        
        Method new = class_getInstanceMethod(class, @selector(new_setReflectedURL:));
        Method old = class_getInstanceMethod(class, @selector(setReflectedURL:));
        method_exchangeImplementations(new, old);

        new = class_getInstanceMethod(class, @selector(new_urlStringWithOnlyHostNameVisible:expandedURLString:));
        old = class_getInstanceMethod(class, @selector(_urlStringWithOnlyHostNameVisible:expandedURLString:));
        method_exchangeImplementations(new, old);
        
        new = class_getInstanceMethod(class, @selector(new_setShowingSecurityUI:));
        old = class_getInstanceMethod(class, @selector(setShowingSecurityUI:));
        method_exchangeImplementations(new, old);
        
        new = class_getInstanceMethod(class, @selector(new_lockButtonIsVisible));
        old = class_getInstanceMethod(class, @selector(_lockButtonIsVisible));
        method_exchangeImplementations(new, old);
    }

    // Refresh the displayed URL in the address bar at startup.
    @try {
        for (NSWindow* window in [[NSClassFromString(@"NSApplication") sharedApplication] windows])
        {
            if ([window isKindOfClass:NSClassFromString(@"BrowserWindow")])
            {
                BrowserWindowControllerMac* windowController = [(BrowserWindow*)window windowController];
                UnifiedField* unifiedField = [windowController unifiedField];
                
                NSURL* reflectedURL = [unifiedField reflectedURL];
                [unifiedField setReflectedURL:[NSURL URLWithString:@""]];
                [unifiedField setReflectedURL:reflectedURL];
            }
        }
    }
    @catch (NSException* exception) {
        NSLog(@"Caught ReflectURL exception: %@", exception);
    }
}

@end
/*
 * webkit_haskell.m — Objective-C implementation of the webkit-haskell C API
 *
 * Creates a macOS Cocoa application with a WKWebView, exposes a
 * JavaScript bridge (window.webkit_haskell.invoke), and provides a
 * clean C API for Haskell to call via FFI.
 */

#import <Cocoa/Cocoa.h>
#import <WebKit/WebKit.h>
#include <stdlib.h>
#include <string.h>
#include "webkit_haskell.h"

/* ── Internal App Structure ──────────────────────────────────── */

typedef struct {
    NSWindow*             window;
    WKWebView*            webview;
    WKUserContentController* content_controller;
    wkhsk_bridge_callback_t bridge_callback;
    void*                 bridge_userdata;
    NSString*             pending_html;
    NSString*             pending_url;
    NSString*             pending_file;
    int                   width;
    int                   height;
    NSString*             title;
    BOOL                  running;
} wkhsk_app_internal;

/* ── Bridge Message Handler ──────────────────────────────────── */

@interface WKHSKBridgeHandler : NSObject <WKScriptMessageHandler>
@property (assign) wkhsk_app_internal* app;
@end

@implementation WKHSKBridgeHandler

- (void)userContentController:(WKUserContentController *)controller
      didReceiveScriptMessage:(WKScriptMessage *)message {
    if (![message.name isEqualToString:@"wkhsk_bridge"]) return;
    if (!self.app->bridge_callback) return;

    NSDictionary *body = message.body;
    if (![body isKindOfClass:[NSDictionary class]]) return;

    NSString *command = body[@"command"];
    NSString *payload = body[@"payload"];
    NSString *callbackId = body[@"callbackId"];

    if (!command) return;
    if (!payload) payload = @"{}";
    if (!callbackId) callbackId = @"0";

    const char *cmd_c = [command UTF8String];
    const char *payload_c = [payload UTF8String];

    const char *result = self.app->bridge_callback(cmd_c, payload_c,
                                                     self.app->bridge_userdata);

    /* Send the result back to JS */
    NSString *resultStr = result ? [NSString stringWithUTF8String:result]
                                : @"null";
    /* Free the malloc'd result from the callback */
    if (result) free((void*)result);

    NSString *js = [NSString stringWithFormat:
        @"window.webkit_haskell._resolveCallback('%@', %@);",
        callbackId, resultStr];

    dispatch_async(dispatch_get_main_queue(), ^{
        [self.app->webview evaluateJavaScript:js completionHandler:nil];
    });
}

@end

/* ── Navigation Delegate ─────────────────────────────────────── */

@interface WKHSKNavigationDelegate : NSObject <WKNavigationDelegate>
@end

@implementation WKHSKNavigationDelegate

- (void)webView:(WKWebView *)webView
    didFinishNavigation:(WKNavigation *)navigation {
    /* Page loaded successfully */
}

- (void)webView:(WKWebView *)webView
    didFailNavigation:(WKNavigation *)navigation
            withError:(NSError *)error {
    NSLog(@"webkit-haskell: navigation failed: %@", error.localizedDescription);
}

@end

/* ── App Delegate ────────────────────────────────────────────── */

@interface WKHSKAppDelegate : NSObject <NSApplicationDelegate>
@property (assign) wkhsk_app_internal* app;
@end

@implementation WKHSKAppDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification {
    [self.app->window makeKeyAndOrderFront:nil];
    [NSApp activateIgnoringOtherApps:YES];

    /* Load any pending content */
    if (self.app->pending_html) {
        [self.app->webview loadHTMLString:self.app->pending_html
                                  baseURL:nil];
        self.app->pending_html = nil;
    } else if (self.app->pending_url) {
        NSURL *url = [NSURL URLWithString:self.app->pending_url];
        NSURLRequest *req = [NSURLRequest requestWithURL:url];
        [self.app->webview loadRequest:req];
        self.app->pending_url = nil;
    } else if (self.app->pending_file) {
        NSURL *fileURL = [NSURL fileURLWithPath:self.app->pending_file];
        [self.app->webview loadFileURL:fileURL
               allowingReadAccessToURL:[fileURL URLByDeletingLastPathComponent]];
        self.app->pending_file = nil;
    }
}

- (BOOL)applicationShouldTerminateAfterLastWindowClosed:(NSApplication *)sender {
    return YES;
}

@end

/* ── C API Implementation ────────────────────────────────────── */

/* Bridge JS injected into every page */
static NSString* bridge_js_source(void) {
    return @"\
window.webkit_haskell = {\n\
    _callbackId: 0,\n\
    _callbacks: {},\n\
    invoke: function(command, payload) {\n\
        return new Promise(function(resolve, reject) {\n\
            var id = String(++window.webkit_haskell._callbackId);\n\
            window.webkit_haskell._callbacks[id] = { resolve: resolve, reject: reject };\n\
            var msg = {\n\
                command: command,\n\
                payload: JSON.stringify(payload || {}),\n\
                callbackId: id\n\
            };\n\
            window.webkit.messageHandlers.wkhsk_bridge.postMessage(msg);\n\
        });\n\
    },\n\
    _resolveCallback: function(id, result) {\n\
        var cb = window.webkit_haskell._callbacks[id];\n\
        if (cb) {\n\
            cb.resolve(result);\n\
            delete window.webkit_haskell._callbacks[id];\n\
        }\n\
    }\n\
};\n";
}

wkhsk_app_t wkhsk_create(const char* title, int width, int height) {
    wkhsk_app_internal *app = calloc(1, sizeof(wkhsk_app_internal));
    if (!app) return NULL;

    app->width = width;
    app->height = height;
    app->title = title ? [NSString stringWithUTF8String:title]
                       : @"webkit-haskell";

    /* Set up the user content controller with bridge script */
    app->content_controller = [[WKUserContentController alloc] init];

    WKUserScript *bridgeScript = [[WKUserScript alloc]
        initWithSource:bridge_js_source()
         injectionTime:WKUserScriptInjectionTimeAtDocumentStart
      forMainFrameOnly:YES];
    [app->content_controller addUserScript:bridgeScript];

    /* Register the message handler */
    WKHSKBridgeHandler *handler = [[WKHSKBridgeHandler alloc] init];
    handler.app = app;
    [app->content_controller addScriptMessageHandler:handler
                                                name:@"wkhsk_bridge"];

    /* WebView configuration */
    WKWebViewConfiguration *config = [[WKWebViewConfiguration alloc] init];
    config.userContentController = app->content_controller;

    /* Allow developer extras (Web Inspector) in debug builds */
#ifdef DEBUG
    [config.preferences setValue:@YES forKey:@"developerExtrasEnabled"];
#endif

    /* Create the WebView */
    NSRect frame = NSMakeRect(0, 0, width, height);
    app->webview = [[WKWebView alloc] initWithFrame:frame
                                       configuration:config];
    app->webview.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;

    /* Navigation delegate */
    WKHSKNavigationDelegate *navDelegate = [[WKHSKNavigationDelegate alloc] init];
    app->webview.navigationDelegate = navDelegate;

    /* Create the window */
    NSUInteger styleMask = NSWindowStyleMaskTitled
                         | NSWindowStyleMaskClosable
                         | NSWindowStyleMaskMiniaturizable
                         | NSWindowStyleMaskResizable;

    app->window = [[NSWindow alloc]
        initWithContentRect:frame
                  styleMask:styleMask
                    backing:NSBackingStoreBuffered
                      defer:NO];
    [app->window setTitle:app->title];
    [app->window center];
    [app->window setContentView:app->webview];

    return (wkhsk_app_t)app;
}

void wkhsk_run(wkhsk_app_t handle) {
    if (!handle) return;
    wkhsk_app_internal *app = (wkhsk_app_internal*)handle;

    @autoreleasepool {
        NSApplication *nsApp = [NSApplication sharedApplication];
        [nsApp setActivationPolicy:NSApplicationActivationPolicyRegular];

        /* Create a basic menu bar */
        NSMenu *menuBar = [[NSMenu alloc] init];
        NSMenuItem *appMenuItem = [[NSMenuItem alloc] init];
        [menuBar addItem:appMenuItem];

        NSMenu *appMenu = [[NSMenu alloc] init];
        NSMenuItem *quitItem = [[NSMenuItem alloc]
            initWithTitle:[NSString stringWithFormat:@"Quit %@", app->title]
                   action:@selector(terminate:)
            keyEquivalent:@"q"];
        [appMenu addItem:quitItem];
        [appMenuItem setSubmenu:appMenu];
        [nsApp setMainMenu:menuBar];

        /* Set the app delegate */
        WKHSKAppDelegate *delegate = [[WKHSKAppDelegate alloc] init];
        delegate.app = app;
        [nsApp setDelegate:delegate];

        app->running = YES;
        [nsApp run];
        app->running = NO;
    }
}

void wkhsk_quit(wkhsk_app_t handle) {
    if (!handle) return;
    dispatch_async(dispatch_get_main_queue(), ^{
        [NSApp terminate:nil];
    });
}

void wkhsk_destroy(wkhsk_app_t handle) {
    if (!handle) return;
    wkhsk_app_internal *app = (wkhsk_app_internal*)handle;
    /* ARC handles Objective-C object cleanup */
    free(app);
}

void wkhsk_load_html(wkhsk_app_t handle, const char* html) {
    if (!handle || !html) return;
    wkhsk_app_internal *app = (wkhsk_app_internal*)handle;
    NSString *htmlStr = [NSString stringWithUTF8String:html];

    if (app->running) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [app->webview loadHTMLString:htmlStr baseURL:nil];
        });
    } else {
        app->pending_html = htmlStr;
    }
}

void wkhsk_load_url(wkhsk_app_t handle, const char* url) {
    if (!handle || !url) return;
    wkhsk_app_internal *app = (wkhsk_app_internal*)handle;
    NSString *urlStr = [NSString stringWithUTF8String:url];

    if (app->running) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSURL *nsUrl = [NSURL URLWithString:urlStr];
            NSURLRequest *req = [NSURLRequest requestWithURL:nsUrl];
            [app->webview loadRequest:req];
        });
    } else {
        app->pending_url = urlStr;
    }
}

void wkhsk_load_file(wkhsk_app_t handle, const char* path) {
    if (!handle || !path) return;
    wkhsk_app_internal *app = (wkhsk_app_internal*)handle;
    NSString *pathStr = [NSString stringWithUTF8String:path];

    /* Resolve relative paths */
    if (![pathStr isAbsolutePath]) {
        NSString *cwd = [[NSFileManager defaultManager] currentDirectoryPath];
        pathStr = [cwd stringByAppendingPathComponent:pathStr];
    }

    if (app->running) {
        dispatch_async(dispatch_get_main_queue(), ^{
            NSURL *fileURL = [NSURL fileURLWithPath:pathStr];
            [app->webview loadFileURL:fileURL
                  allowingReadAccessToURL:[fileURL URLByDeletingLastPathComponent]];
        });
    } else {
        app->pending_file = pathStr;
    }
}

void wkhsk_eval_js(wkhsk_app_t handle, const char* js) {
    if (!handle || !js) return;
    wkhsk_app_internal *app = (wkhsk_app_internal*)handle;
    NSString *jsStr = [NSString stringWithUTF8String:js];

    dispatch_async(dispatch_get_main_queue(), ^{
        [app->webview evaluateJavaScript:jsStr completionHandler:nil];
    });
}

void wkhsk_set_bridge_callback(wkhsk_app_t handle,
                               wkhsk_bridge_callback_t callback,
                               void* userdata) {
    if (!handle) return;
    wkhsk_app_internal *app = (wkhsk_app_internal*)handle;
    app->bridge_callback = callback;
    app->bridge_userdata = userdata;
}

void wkhsk_set_title(wkhsk_app_t handle, const char* title) {
    if (!handle || !title) return;
    wkhsk_app_internal *app = (wkhsk_app_internal*)handle;
    NSString *titleStr = [NSString stringWithUTF8String:title];

    dispatch_async(dispatch_get_main_queue(), ^{
        [app->window setTitle:titleStr];
    });
}

void wkhsk_set_size(wkhsk_app_t handle, int width, int height) {
    if (!handle) return;
    wkhsk_app_internal *app = (wkhsk_app_internal*)handle;

    dispatch_async(dispatch_get_main_queue(), ^{
        NSRect frame = [app->window frame];
        NSRect newFrame = NSMakeRect(frame.origin.x, frame.origin.y,
                                     width, height);
        [app->window setFrame:newFrame display:YES animate:YES];
    });
}

void wkhsk_set_resizable(wkhsk_app_t handle, int resizable) {
    if (!handle) return;
    wkhsk_app_internal *app = (wkhsk_app_internal*)handle;

    dispatch_async(dispatch_get_main_queue(), ^{
        NSUInteger mask = [app->window styleMask];
        if (resizable) {
            mask |= NSWindowStyleMaskResizable;
        } else {
            mask &= ~NSWindowStyleMaskResizable;
        }
        [app->window setStyleMask:mask];
    });
}

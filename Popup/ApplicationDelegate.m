#import "ApplicationDelegate.h"
#import "BLAuthentication.h"

@implementation ApplicationDelegate

@synthesize panelController = _panelController;
@synthesize menubarController = _menubarController;

#pragma mark -

- (void)dealloc
{
    [_panelController removeObserver:self forKeyPath:@"hasActivePanel"];
}

#pragma mark -

void *kContextActivePanel = &kContextActivePanel;

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (context == kContextActivePanel) {
        self.menubarController.hasActiveIcon = self.panelController.hasActivePanel;
    }
    else {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
    }
}

#pragma mark - NSApplicationDelegate

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    // Install icon into the menu bar
    self.menubarController = [[MenubarController alloc] init];
}

- (NSApplicationTerminateReply)applicationShouldTerminate:(NSApplication *)sender
{
    // Explicitly remove the icon from the menu bar
    self.menubarController = nil;
    return NSTerminateNow;
}

#pragma mark - Actions

- (NSString *)executeCommand:(NSString *)command arguments:(NSArray *)arguments
{
    NSTask *task;
    task = [[NSTask alloc] init];
    [task setLaunchPath: command];
    
    if (arguments) {
        [task setArguments: arguments];
    }
    
    NSPipe *pipe;
    pipe = [NSPipe pipe];
    [task setStandardOutput: pipe];
    
    NSFileHandle *file;
    file = [pipe fileHandleForReading];
    
    [task launch];
    
    NSData *data;
    data = [file readDataToEndOfFile];
    
    return [[NSString alloc] initWithData: data encoding: NSUTF8StringEncoding];
}

- (IBAction)togglePanel:(id)sender
{
    if (![[BLAuthentication sharedInstance] isAuthenticated:@"/usr/sbin/networksetup"]) {
        BOOL fetchedAuth = [[BLAuthentication sharedInstance] authenticate:@"/usr/sbin/networksetup"];
        if (!fetchedAuth) {
            return;
        }
    }
    
    static BOOL on = NO;
    on = !on;
    
    NSString *result = [self executeCommand:@"/usr/sbin/networksetup" arguments:@[@"-listallnetworkservices"]];
    NSArray *interfaces = [result componentsSeparatedByString:@"\n"];
    for (NSString *interface in interfaces) {
        result = [self executeCommand:@"/usr/sbin/networksetup" arguments:@[@"-getinfo", interface]];
        if ([result rangeOfString:@"\nIP address: "].location == NSNotFound) {
            continue;
        }
        result = [self executeCommand:@"/usr/sbin/networksetup" arguments:@[@"-getsocksfirewallproxy", interface]];
        if ([result rangeOfString:@"Port: "].location != NSNotFound && [result rangeOfString:@"Port: 0"].location == NSNotFound) { // socks has configured
            [[BLAuthentication sharedInstance] executeCommandSynced:@"/usr/sbin/networksetup" withArgs:@[@"-setsocksfirewallproxystate", interface, on ? @"on" : @"off"]];
        } else {
            result = [self executeCommand:@"/usr/sbin/networksetup" arguments:@[@"-getwebproxy", interface]];
            if ([result rangeOfString:@"Port: "].location != NSNotFound && [result rangeOfString:@"Port: 0"].location == NSNotFound) { // http has configured
                [[BLAuthentication sharedInstance] executeCommandSynced:@"/usr/sbin/networksetup" withArgs:@[@"-setwebproxystate", interface, on ? @"on" : @"off"]];
            }
        }
    }
    self.menubarController.statusItemView.image = [NSImage imageNamed:(on ? @"StatusHighlighted" : @"Status")];
    
    return;
    
    
    self.menubarController.hasActiveIcon = !self.menubarController.hasActiveIcon;
    self.panelController.hasActivePanel = self.menubarController.hasActiveIcon;
}

#pragma mark - Public accessors

- (PanelController *)panelController
{
    if (_panelController == nil) {
        _panelController = [[PanelController alloc] initWithDelegate:self];
        [_panelController addObserver:self forKeyPath:@"hasActivePanel" options:0 context:kContextActivePanel];
    }
    return _panelController;
}

#pragma mark - PanelControllerDelegate

- (StatusItemView *)statusItemViewForPanelController:(PanelController *)controller
{
    return self.menubarController.statusItemView;
}

@end

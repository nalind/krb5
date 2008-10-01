//
//  IPCClient.m
//  Kerberos5
//
//  Created by Justin Anderson on 9/28/08.
//  Copyright 2008 MIT. All rights reserved.
//

#import "IPCClient.h"
#import "SelectIdentityController.h"
#import "AuthenticationController.h"
#import "KerberosAgentListener.h"

enum krb_agent_client_state {
    ipc_client_state_idle,
    ipc_client_state_init,
    ipc_client_state_enter,
    ipc_client_state_select,
    ipc_client_state_auth_prompt,
    ipc_client_state_change_password,
    ipc_client_state_handle_error,
    ipc_client_state_fini,
};

@interface IPCClient ()

@property (readwrite, retain) SelectIdentityController *selectController;
@property (readwrite, retain) AuthenticationController *authController;

@end


@implementation IPCClient

@synthesize port;
@synthesize name;
@synthesize path;
@synthesize state;
@synthesize currentInfo;
@synthesize selectController;
@synthesize authController;

- (BOOL) isEqual: (IPCClient *) otherClient
{
    return (self.port == otherClient.port);
}

- (NSUInteger) hash
{
    return self.port;
}

- (id) init
{
    self = [super init];
    if (self != nil) {
        self.state = ipc_client_state_init;
        self.selectController = [[[SelectIdentityController alloc] init] autorelease];
        self.authController = [[[AuthenticationController alloc] init] autorelease];
        self.selectController.associatedClient = self;
        self.authController.associatedClient = self;
    }
    return self;
}

- (void) cleanup
{
    [self.selectController close];
    [self.authController close];
}

- (void) didCancel
{
    kim_error err = KIM_USER_CANCELED_ERR;
    if (self.state == ipc_client_state_select) {
        [KerberosAgentListener didSelectIdentity:self.currentInfo error:err];
    }
    else if (self.state == ipc_client_state_enter) {
        [KerberosAgentListener didEnterIdentity:self.currentInfo error:err];
    }
    else if (self.state == ipc_client_state_select) {
        [KerberosAgentListener didSelectIdentity:self.currentInfo error:err];
    }
    else if (self.state == ipc_client_state_auth_prompt) {
        [KerberosAgentListener didPromptForAuth:self.currentInfo error:err];
    }
    else if (self.state == ipc_client_state_change_password) {
        [KerberosAgentListener didChangePassword:self.currentInfo error:err];
    }
    [self.selectController close];
    [self.authController close];
    self.state = ipc_client_state_idle;
}

- (kim_error) selectIdentity: (NSDictionary *) info
{
    self.currentInfo = [[info mutableCopy] autorelease];
    self.state = ipc_client_state_select;

    [self.selectController showWindow:nil];
    
    return 0;
}

- (void) didSelectIdentity: (NSString *) identityString
{
    [self.currentInfo setObject:identityString forKey:@"identity_string"];
    
    [KerberosAgentListener didSelectIdentity:self.currentInfo error:0];
    
    // clean up state
    self.currentInfo = nil;
    self.state = ipc_client_state_idle;
}

- (kim_error) enterIdentity: (NSDictionary *) info
{
    self.currentInfo = [[info mutableCopy] autorelease];
    self.state = ipc_client_state_enter;

    [self.authController setContent:self.currentInfo];
    [self.authController showEnterIdentity];
    
    return 0;
}

- (void) didEnterIdentity: (NSString *) identityString options: (NSDictionary *) options
{
    [self.currentInfo setObject:identityString forKey:@"identity_string"];
    [self.currentInfo setObject:options forKey:@"options"];
    [KerberosAgentListener didEnterIdentity:self.currentInfo error:0];
}

- (kim_error) promptForAuth: (NSDictionary *) info
{
    self.currentInfo = [[info mutableCopy] autorelease];
    self.state = ipc_client_state_auth_prompt;
    
    [self.authController setContent:self.currentInfo];
    [self.authController showAuthPrompt];
    
    return 0;
}

- (void) didPromptForAuth: (NSString *) responseString saveResponse: (NSNumber *) saveResponse
{
    [self.currentInfo setObject:responseString forKey:@"prompt_response"];
    [self.currentInfo setObject:saveResponse forKey:@"save_response"];
    [KerberosAgentListener didPromptForAuth:self.currentInfo error:0];
}

- (kim_error) changePassword: (NSDictionary *) info
{
    self.currentInfo = [[info mutableCopy] autorelease];
    self.state = ipc_client_state_change_password;
    
    [self.authController setContent:self.currentInfo];
    [self.authController showChangePassword];
    
    return 0;
}

- (void) didChangePassword: (NSString *) oldPassword 
               newPassword: (NSString *) newPassword 
            verifyPassword: (NSString *) verifyPassword
{
    [self.currentInfo setObject:oldPassword forKey:@"old_password"];
    [self.currentInfo setObject:newPassword forKey:@"new_password"];
    [self.currentInfo setObject:verifyPassword forKey:@"verify_password"];
    [KerberosAgentListener didChangePassword:self.currentInfo error:0];
}


- (kim_error) handleError: (NSDictionary *) info
{
    self.currentInfo = [[info mutableCopy] autorelease];
    self.state = ipc_client_state_handle_error;
    
    [self.authController setContent:self.currentInfo];
    [self.authController showError];
    
    return 0;
}

- (void) didHandleError
{
    [KerberosAgentListener didHandleError:self.currentInfo error:0];
}

@end
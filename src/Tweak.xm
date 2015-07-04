#ifndef MSHake // In case something went wrong with theos :/
#include <substrate.h>
#endif

#import <Foundation/Foundation.h>

typedef CFTypeRef VPNConfigurationRef;
CFArrayRef (*original_VPNConfigurationCopyAll)(CFStringRef vpnType);
CFDictionaryRef (*original_VPNConfigurationCopyVendorData)(VPNConfigurationRef conf);
CFDictionaryRef (*original_VPNConfigurationCopy)(VPNConfigurationRef conf); 
SEL sel_appName;

CFArrayRef proxy_VPNConfigurationCopyAll(CFStringRef vpnType) {
#ifdef DEBUG
	NSLog(@"Hello from VPNConfigurationCopyAll");
#endif

	CFArrayRef configurations = original_VPNConfigurationCopyAll(vpnType);
#ifdef DEBUG
	CFStringRef description = CFCopyDescription(configurations);
	NSLog(@"Array %@", description);
	CFRelease(description);
#endif

	CFMutableArrayRef n = CFArrayCreateMutable(NULL, 0, &kCFTypeArrayCallBacks);
	
	for (int i = 0; i < CFArrayGetCount(configurations); i++) {
		VPNConfigurationRef cfg = (VPNConfigurationRef)CFArrayGetValueAtIndex(configurations, i);

#ifdef DEBUG
		NSLog(@"Item %@: %@", CFCopyTypeIDDescription(CFGetTypeID(cfg)), CFCopyDescription(cfg));
		@try {
			NSLog(@"Vendor data: %@", original_VPNConfigurationCopyVendorData(cfg));
			NSLog(@"Configuration data: %@", original_VPNConfigurationCopy(cfg));
#endif

			// This is horrible, but I found no better ways
			id cfg_id = *(id *)((intptr_t)cfg + sizeof(intptr_t)*20);
			if ([cfg_id respondsToSelector:sel_appName] && [[cfg_id performSelector:sel_appName] isEqualToString:@"OpenVPN"]) {
				CFArrayAppendValue(n, cfg);
			}
	
#ifdef DEBUG
		@catch(NSException * e) {
			NSLog(@"Exception: %@", e);
		}
#endif
	}
	
	CFRelease(configurations);
	
#ifdef DEBUG
	NSLog(@"Done with VPNConfigurationCopyAll");
#endif

	return n;
}

MSInitialize {
#ifdef DEBUG
	NSLog(@"Hello from CorrectOpenVPN");
#endif

	void *local_VPNConfigurationCopyAll = dlsym(RTLD_DEFAULT, "VPNConfigurationCopyAll");
#ifdef DEBUG
	original_VPNConfigurationCopyVendorData = (CFDictionaryRef (*)(VPNConfigurationRef))dlsym(RTLD_DEFAULT, "VPNConfigurationCopyVendorData");
	original_VPNConfigurationCopy = (CFDictionaryRef (*)(VPNConfigurationRef))dlsym(RTLD_DEFAULT, "VPNConfigurationCopy");
#endif
	
	if (local_VPNConfigurationCopyAll 
#ifdef DEBUG
		&& original_VPNConfigurationCopyVendorData && original_VPNConfigurationCopy
#endif
	) {
		// No other appear to work (application, applicationIdentifier, externalIdentifier)
		sel_appName = sel_registerName("applicationName");
	
		MSHookFunction(local_VPNConfigurationCopyAll, 
						(void *)proxy_VPNConfigurationCopyAll, 
						(void **)&original_VPNConfigurationCopyAll
		);
	} else {
		NSLog(@"Failed to get VPNConfigurationCopyAll pointer or something else");
	}

#ifdef DEBUG
	NSLog(@"Done with CorrectOpenVPN");
#endif
}
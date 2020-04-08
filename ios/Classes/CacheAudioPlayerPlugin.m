#import "CacheAudioPlayerPlugin.h"
#if __has_include(<cache_audio_player/cache_audio_player-Swift.h>)
#import <cache_audio_player/cache_audio_player-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "cache_audio_player-Swift.h"
#endif

@implementation CacheAudioPlayerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftCacheAudioPlayerPlugin registerWithRegistrar:registrar];
}
@end

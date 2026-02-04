//
//  WiiMMenuBar-Bridging-Header.h
//  WiiMMenuBar
//
//  Bridging header for MediaRemote framework (private Apple framework)
//

#ifndef WiiMMenuBar_Bridging_Header_h
#define WiiMMenuBar_Bridging_Header_h

#import <Foundation/Foundation.h>

// MediaRemote framework types
typedef NS_ENUM(NSInteger, MRCommand) {
    MRCommandPlay = 0,
    MRCommandPause = 1,
    MRCommandTogglePlayPause = 2,
    MRCommandStop = 3,
    MRCommandNextTrack = 4,
    MRCommandPreviousTrack = 5,
    MRCommandAdvanceShuffleMode = 6,
    MRCommandAdvanceRepeatMode = 7,
    MRCommandBeginFastForward = 8,
    MRCommandEndFastForward = 9,
    MRCommandBeginRewind = 10,
    MRCommandEndRewind = 11,
    MRCommandLikeTrack = 12,
    MRCommandDislikeTrack = 13,
    MRCommandBookmarkTrack = 14,
    MRCommandSeekToPlaybackPosition = 45
};

// Now Playing Info dictionary keys
extern NSString *kMRMediaRemoteNowPlayingInfoTitle;
extern NSString *kMRMediaRemoteNowPlayingInfoArtist;
extern NSString *kMRMediaRemoteNowPlayingInfoAlbum;
extern NSString *kMRMediaRemoteNowPlayingInfoArtworkData;
extern NSString *kMRMediaRemoteNowPlayingInfoDuration;
extern NSString *kMRMediaRemoteNowPlayingInfoElapsedTime;
extern NSString *kMRMediaRemoteNowPlayingInfoPlaybackRate;
extern NSString *kMRMediaRemoteNowPlayingInfoTimestamp;

// Now Playing Application info
extern NSString *kMRMediaRemoteNowPlayingApplicationDisplayNameUserInfoKey;
extern NSString *kMRMediaRemoteNowPlayingApplicationBundleIdentifierUserInfoKey;
extern NSString *kMRMediaRemoteNowPlayingApplicationIsPlayingUserInfoKey;

// Notification names
extern NSString *kMRMediaRemoteNowPlayingInfoDidChangeNotification;
extern NSString *kMRMediaRemoteNowPlayingApplicationDidChangeNotification;
extern NSString *kMRMediaRemoteNowPlayingApplicationIsPlayingDidChangeNotification;

// MediaRemote functions

/// Register for now playing notifications
void MRMediaRemoteRegisterForNowPlayingNotifications(dispatch_queue_t queue);

/// Unregister from now playing notifications
void MRMediaRemoteUnregisterForNowPlayingNotifications(void);

/// Get now playing info
typedef void (^MRMediaRemoteGetNowPlayingInfoCompletion)(NSDictionary *info);
void MRMediaRemoteGetNowPlayingInfo(dispatch_queue_t queue, MRMediaRemoteGetNowPlayingInfoCompletion completion);

/// Get now playing application PID
typedef void (^MRMediaRemoteGetNowPlayingApplicationPIDCompletion)(int pid);
void MRMediaRemoteGetNowPlayingApplicationPID(dispatch_queue_t queue, MRMediaRemoteGetNowPlayingApplicationPIDCompletion completion);

/// Get now playing application is playing
typedef void (^MRMediaRemoteGetNowPlayingApplicationIsPlayingCompletion)(BOOL isPlaying);
void MRMediaRemoteGetNowPlayingApplicationIsPlaying(dispatch_queue_t queue, MRMediaRemoteGetNowPlayingApplicationIsPlayingCompletion completion);

/// Send command to media remote
typedef void (^MRMediaRemoteSendCommandCompletion)(BOOL success);
BOOL MRMediaRemoteSendCommand(MRCommand command, NSDictionary * _Nullable options);

#endif /* WiiMMenuBar_Bridging_Header_h */

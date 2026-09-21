#import <Foundation/Foundation.h>
#import <SceneKit/SceneKit.h>
#import <GLTFKit2/GLTFKit2.h>
int main(int argc, const char *argv[]) { @autoreleasepool {
 if(argc!=3)return 2;
 NSError *error=nil;
 GLTFAsset *asset=[GLTFAsset assetWithURL:[NSURL fileURLWithPath:@(argv[1])] options:@{} error:&error];
 if(!asset){ NSLog(@"%@",error);return 1; }
 GLTFSCNSceneSource *source=[[GLTFSCNSceneSource alloc] initWithAsset:asset];
 SCNScene *scene=source.defaultScene;
 GLTFSCNAnimation *wave=nil;
 for(GLTFSCNAnimation *a in source.animations)if([a.name isEqualToString:@"Wave_One_Hand"])wave=a;
 if(!scene||!wave)return 3;
 CAAnimationGroup *all=(CAAnimationGroup *)[CAAnimation animationWithSCNAnimation:wave.animationPlayer.animation];
 NSMutableDictionary<NSString *,NSMutableArray *> *tracks=[NSMutableDictionary dictionary];
 for(CAKeyframeAnimation *channel in all.animations){
  NSString *path=channel.keyPath;
  NSRange dot=[path rangeOfString:@"." options:NSBackwardsSearch];
  if(![path hasPrefix:@"/"] || dot.location==NSNotFound)return 5;
  NSString *name=[path substringWithRange:NSMakeRange(1,dot.location-1)];
  channel.keyPath=[path substringFromIndex:dot.location+1];
  if(!tracks[name])tracks[name]=[NSMutableArray array];
  [tracks[name] addObject:channel];
 }
 for(NSString *name in tracks){
  SCNNode *node=[scene.rootNode childNodeWithName:name recursively:YES];
  if(!node)return 6;
  // Preserve a valid standing pose even when Reduce Motion pauses before frame one.
  for(CAKeyframeAnimation *track in tracks[name]) {
   if(track.values.count) [node setValue:track.values.firstObject forKeyPath:track.keyPath];
  }
  CAAnimationGroup *group=[CAAnimationGroup animation];
  group.animations=tracks[name];group.duration=all.duration;group.repeatCount=FLT_MAX;
  SCNAnimation *animation=[SCNAnimation animationWithCAAnimation:group];
  animation.usesSceneTimeBase=NO;
  SCNAnimationPlayer *player=[SCNAnimationPlayer animationPlayerWithAnimation:animation];
  [node addAnimationPlayer:player forKey:@"wave"];
  [player play];
 }
 BOOL ok=[scene writeToURL:[NSURL fileURLWithPath:@(argv[2])] options:nil delegate:nil progressHandler:nil];
 NSLog(@"export=%d duration=%f",ok,wave.animationPlayer.animation.duration);
 return ok?0:4;
}}

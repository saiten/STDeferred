# STDeferred

簡単なDeferredオブジェクトの実装

## Usage

```objectivec
STDeferredBlock block1 = ^{
  STDeferred *deferred = [STDeferred deferred];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.0f * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
    [deferred resolve:@"first"];
  });
  return deferred;
};

STDeferredBlock block2 = ^{
  STDeferred *deferred = [STDeferred deferred];
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2.0f * NSEC_PER_SEC), dispatch_get_main_queue(), ^(void){
    [deferred resolve:@"second"];
  });
  return deferred;
};

[[STDeferred when:block1, block2, nil] then:^(id ret) {
  NSLog(@"%@", [ret objectAtIndex:0]); // "first"
  NSLog(@"%@", [ret objectAtIndex:1]); // "second"
}];
```

[![Build Status](https://travis-ci.org/saiten/STDeferred.png?branch=master)](https://travis-ci.org/saiten/STDeferred)

# STDeferred 0.1.0

Objective-C simple implementation of deferred object

## Installation

### Cocoapods

1. Add `pod 'STDeferred'` to your Podfile
2. Run `pod install`

### Manual

Add files `STDeferred/STDeferred.h`, `STDeferred/STDeferred.m` to your Project

## Requirements

- iOS5 and later
- ARC

## Usage

```objectivec
[STDeferred deferred].resolve([NSURLRequest requestWithURL:[NSURL URLWithString:@"http://example.com/data.json"]])
.next(^id(id request) {
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if(error) {
        @throw [NSException exceptionWithName:@"Request Error" reason:@"Request Error" userInfo:nil];
    }
    return data;
})
.next(^id(id responseData) {
    NSError *error = nil;
    id json = [NSJSONSerialization JSONObjectWithData:responseData options:NSJSONReadingAllowFragments error:&error];
    if(error) {
        @throw [NSException exceptionWithName:@"Parse Error" reason:@"Parse Error" userInfo:nil];
    }
    return json;
})
.then(^(id json) {
    NSLog(@"name = %@", [json objectForKey:@"name"]);
})
.fail(^(id exception) {
    NSLog(@"error = %@", [exception reason]);
});
```

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

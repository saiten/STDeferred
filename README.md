# STDeferred 0.1.0 [![Build Status](https://travis-ci.org/saiten/STDeferred.png?branch=master)](https://travis-ci.org/saiten/STDeferred)

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

### basic

```objectivec
- (STDeferred*)asynchronousRequest
{
  STDeferred *deferred = [STDeferred deferred];

  dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://example.com/data.json"]];
    NSURLResponse *response = nil;
    NSError *error = nil;
    NSData *data = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
    if(error) {
      [deferred reject:error];
    } else {
      [deferred resolve:data];
    }
  });  

return deferred;
}

[self asynchronousRequest]
.then(^(NSData *data) {
  NSLog(@"response string = %@", [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding]);
})
.fail(^(NSError *error) {
  NSLog(@"error = %@", error.description);
})
.always(^(id ret) {
  NSLog(@"Always execute this block.");
});
```

### when

```objectivec
- (STDeferred*)func1
{
  STDeferred *deferred = [STDeferred deferred];
  [STDeferred timeout:1.0f].then(^(id ret) {
    [deferred resolve:@"first"];
  });
  return deferred;  
}

- (STDeferred*)func2
{
  STDeferred *deferred = [STDeferred deferred];
  [STDeferred timeout:2.0f].then(^(id ret) {
    [deferred resolve:@"second"];
  });
  return deferred;  
}

[[STDeferred when:[self func1], [self func2], nil] then:^(id ret) {
  NSLog(@"%@", [ret objectAtIndex:0]); // "first"
  NSLog(@"%@", [ret objectAtIndex:1]); // "second"
}];
```

### pipe

```objectivec
- (STDeferred*)func1
{
  STDeferred *deferred = [STDeferred deferred];
  [STDeferred timeout:1.0f].then(^(id ret) {
    [deferred resolve:@"first"];
  });
  return deferred;  
}

- (STDeferred*)func2
{
  STDeferred *deferred = [STDeferred deferred];
  [STDeferred timeout:2.0f].then(^(id ret) {
    [deferred resolve:@"second"];
  });
  return deferred;  
}

STDeferred *deferred = [self func1].pipe(^id(id ret) {
  NSLog(ret) // @"first"
  return [self func2];
}, nil);

deferred.then(^(id ret) {
  NSLog(ret) // @"second"
});
```

### next

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

### timeout

```objectivec
NSTimeInterval interval = 5.0f;
[STDeferred timeout:interval].then(^(id ret) {
  NSLog(@"This block is executed 5 seconds later.")
});
```

### cancel



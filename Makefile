test:
	xcodebuild \
		-sdk iphonesimulator \
		-workspace STDeferred.xcworkspace \
		-scheme STDeferredTest \
		-configuration Debug \
		clean build \
	GHUNIT_CLI=1 \
	ONLY_ACTIVE_ARCH=NO \

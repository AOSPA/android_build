# Selects a Java compiler.
#
# Outputs:
#   ANDROID_JAVA_TOOLCHAIN -- Directory that contains javac and other java tools
#

ANDROID_COMPILE_WITH_JACK := false

ifdef TARGET_BUILD_APPS
  ifndef TURBINE_ENABLED
    TURBINE_ENABLED := false
  endif
endif

ANDROID_JAVA_TOOLCHAIN := $(ANDROID_JAVA_HOME)/bin

# TODO(ccross): remove this, it is needed for now because it is used by
# config.mk before makevars from soong are loaded
JAVA := $(ANDROID_JAVA_TOOLCHAIN)/java -XX:OnError="cat hs_err_pid%p.log" \
  -XX:CICompilerCount=2 \
  -XX:+UseG1GC \
  -XX:+ParallelRefProcEnabled \
  -XX:MaxGCPauseMillis=500 \
  -XX:+UnlockExperimentalVMOptions \
  -XX:+AlwaysPreTouch \
  -XX:+DisableExplicitGC \
  -XX:G1NewSizePercent=35 \
  -XX:G1MaxNewSizePercent=45 \
  -XX:G1HeapRegionSize=16M \
  -XX:G1ReservePercent=10 \
  -XX:G1HeapWastePercent=4 \
  -XX:G1MixedGCCountTarget=4 \
  -XX:InitiatingHeapOccupancyPercent=15 \
  -XX:G1MixedGCLiveThresholdPercent=90 \
  -XX:G1RSetUpdatingPauseTimePercent=5 \
  -XX:SurvivorRatio=32 \
  -XX:+PerfDisableSharedMem \
  -XX:MaxTenuringThreshold=1

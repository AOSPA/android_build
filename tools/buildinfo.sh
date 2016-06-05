#!/bin/bash
function prop {
  if [ -n "$1" ] ; then
    if [ -n "$2" ] ; then
      echo "$1=$2"
    else
      echo "# $1 missing"
    fi
  fi
}

PROP_TARGET=$1
if [ -z "$PROP_TARGET" ] ; then
  echo "# properties list generation failed; properties target missing."
  exit 1
fi

case "$PROP_TARGET" in
default)
  echo "# begin standard boot properties"
  prop ro.bootimage.build.date "`date`"
  prop ro.bootimage.build.date.utc "`date +%s`"
  prop ro.bootimage.build.fingerprint "$BUILD_FINGERPRINT"
  echo "# end standard boot properties"
  ;;
system)
  echo "# begin standard system properties"

  prop ro.board.platform "$TARGET_BOARD_PLATFORM"

  prop ro.build.characteristics "$TARGET_AAPT_CHARACTERISTICS"
  prop ro.build.date "`date`"
  prop ro.build.date.utc "`date +%s`"
  prop ro.build.flavor "$TARGET_BUILD_FLAVOR"
  prop ro.build.host "`hostname`"
  prop ro.build.id "$BUILD_ID"
  prop ro.build.display.id "$BUILD_DISPLAY_ID"
  if [ -n "$TARGET_DEVICE" ] ; then
    echo "# ro.build.product is obsolete; use ro.product.device instead."
    prop ro.build.product "$TARGET_DEVICE"
  fi
  prop ro.build.tags "$BUILD_VERSION_TAGS"
  prop ro.build.type "$TARGET_BUILD_TYPE"
  prop ro.build.user "$USER"
  prop ro.build.version.all_codenames "$PLATFORM_VERSION_ALL_CODENAMES"
  prop ro.build.version.base_os "$PLATFORM_BASE_OS"
  prop ro.build.version.codename "$PLATFORM_VERSION_CODENAME"
  prop ro.build.version.incremental "$BUILD_NUMBER"
  prop ro.build.version.preview_sdk "$PLATFORM_PREVIEW_SDK_VERSION"
  prop ro.build.version.release "$PLATFORM_VERSION"
  prop ro.build.version.security_patch "$PLATFORM_SECURITY_PATCH"
  prop ro.build.version.sdk "$PLATFORM_SDK_VERSION"

  if [ -n "$BUILD_THUMBPRINT" ] ; then
    echo "# do not parse the description, fingerprint or thumbprint."
  else
    echo "# do not parse the description or fingerprint."
  fi
  prop ro.build.description "$PRIVATE_BUILD_DESC"
  prop ro.build.fingerprint "$BUILD_FINGERPRINT"
  if [ -n "$BUILD_THUMBPRINT" ] ; then
    prop ro.build.thumbprint "$BUILD_THUMBPRINT"
  fi

  prop ro.product.board "$TARGET_BOOTLOADER_BOARD_NAME"
  prop ro.product.brand "$PRODUCT_BRAND"
  if [ -n "$TARGET_CPU_ABI" ] ; then
    echo "# ro.product.cpu.abi is obsolete; use ro.product.cpu.abilist instead."
    prop ro.product.cpu.abi "$TARGET_CPU_ABI"
  fi
  if [ -n "$TARGET_CPU_ABI2" ] ; then
    echo "# ro.product.cpu.abi2 is obsolete; use ro.product.cpu.abilist instead."
    prop ro.product.cpu.abi2 "$TARGET_CPU_ABI2"
  fi
  prop ro.product.cpu.abilist "$TARGET_CPU_ABI_LIST"
  prop ro.product.cpu.abilist32 "$TARGET_CPU_ABI_LIST_32_BIT"
  prop ro.product.cpu.abilist64 "$TARGET_CPU_ABI_LIST_64_BIT"
  prop ro.product.device "$TARGET_DEVICE"
  if [ -n "$PRODUCT_DEFAULT_LOCALE" ] ; then
    prop ro.product.locale "$PRODUCT_DEFAULT_LOCALE"
  fi
  prop ro.product.manufacturer "$PRODUCT_MANUFACTURER"
  prop ro.product.model "$PRODUCT_MODEL"
  prop ro.product.name "$PRODUCT_NAME"

  prop ro.wifi.channels "$PRODUCT_DEFAULT_WIFI_CHANNELS"

  echo "# end standard system properties"
  ;;
vendor)
  echo "# begin standard vendor properties"
  prop ro.vendor.build.date "`date`"
  prop ro.vendor.build.date.utc "`date +%s`"
  prop ro.vendor.build.fingerprint "$BUILD_FINGERPRINT"
  echo "# end standard vendor properties"
  ;;
*)
  echo "# properties list generation failed; properties target unrecognized ($PROP_TARGET)."
  exit 1
  ;;
esac

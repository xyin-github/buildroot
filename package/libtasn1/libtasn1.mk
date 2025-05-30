################################################################################
#
# libtasn1
#
################################################################################

LIBTASN1_VERSION = 4.20.0
LIBTASN1_SITE = $(BR2_GNU_MIRROR)/libtasn1
LIBTASN1_DEPENDENCIES = host-bison host-pkgconf
LIBTASN1_LICENSE = GPL-3.0+ (tests, tools), LGPL-2.1+ (library)
LIBTASN1_LICENSE_FILES = README.md COPYING COPYING.LESSERv2
LIBTASN1_CPE_ID_VENDOR = gnu
LIBTASN1_INSTALL_STAGING = YES

# 'missing' fallback logic botched so disable it completely
LIBTASN1_CONF_ENV = MAKEINFO="true"

LIBTASN1_CONF_OPTS = CFLAGS="$(TARGET_CFLAGS) -std=gnu99"

LIBTASN1_PROGS = asn1Coding asn1Decoding asn1Parser

# We only need the library
define LIBTASN1_REMOVE_PROGS
	$(RM) $(addprefix $(TARGET_DIR)/usr/bin/,$(LIBTASN1_PROGS))
endef
LIBTASN1_POST_INSTALL_TARGET_HOOKS += LIBTASN1_REMOVE_PROGS

$(eval $(autotools-package))
$(eval $(host-autotools-package))

################################################################################
#
# libgpg-error
#
################################################################################

LIBGPG_ERROR_VERSION = 1.51
LIBGPG_ERROR_SITE = https://www.gnupg.org/ftp/gcrypt/libgpg-error
LIBGPG_ERROR_SOURCE = libgpg-error-$(LIBGPG_ERROR_VERSION).tar.bz2
LIBGPG_ERROR_LICENSE = GPL-2.0+, LGPL-2.1+
LIBGPG_ERROR_LICENSE_FILES = COPYING COPYING.LIB
LIBGPG_ERROR_CPE_ID_VENDOR = gnupg
LIBGPG_ERROR_INSTALL_STAGING = YES
LIBGPG_ERROR_CONFIG_SCRIPTS = gpg-error-config
LIBGPG_ERROR_DEPENDENCIES = $(TARGET_NLS_DEPENDENCIES)
LIBGPG_ERROR_CONF_OPTS = \
	cross_compiling=yes \
	--host=$(BR2_PACKAGE_LIBGPG_ERROR_SYSCFG) \
	--enable-install-gpg-error-config \
	--disable-tests \
	--disable-languages

ifeq ($(BR2_TOOLCHAIN_HAS_THREADS),y)
LIBGPG_ERROR_CONF_OPTS += --enable-threads
else
LIBGPG_ERROR_CONF_OPTS += --disable-threads
endif

HOST_LIBGPG_ERROR_CONF_OPTS = \
	--enable-threads \
	--enable-install-gpg-error-config \
	--disable-tests

$(eval $(autotools-package))
$(eval $(host-autotools-package))

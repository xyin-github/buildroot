################################################################################
# Golang package infrastructure
#
# This file implements an infrastructure that eases development of package .mk
# files for Go packages. It should be used for all packages that are written in
# go.
#
# See the Buildroot documentation for details on the usage of this
# infrastructure
#
#
# In terms of implementation, this golang infrastructure requires the .mk file
# to only specify metadata information about the package: name, version,
# download URL, etc.
#
# We still allow the package .mk file to override what the different steps are
# doing, if needed. For example, if <PKG>_BUILD_CMDS is already defined, it is
# used as the list of commands to perform to build the package, instead of the
# default golang behavior. The package can also define some post operation
# hooks.
#
################################################################################

GO_BIN = $(HOST_DIR)/bin/go

################################################################################
# inner-golang-package -- defines how the configuration, compilation and
# installation of a Go package should be done, implements a few hooks to tune
# the build process for Go specificities and calls the generic package
# infrastructure to generate the necessary make targets
#
#  argument 1 is the lowercase package name
#  argument 2 is the uppercase package name, including a HOST_ prefix for host
#             packages
#  argument 3 is the uppercase package name, without the HOST_ prefix for host
#             packages
#  argument 4 is the type (target or host)
#
################################################################################

define inner-golang-package

$(2)_BUILD_OPTS += \
	-ldflags "$$($(2)_LDFLAGS)" \
	-modcacherw \
	-tags "$$($(2)_TAGS)" \
	-trimpath \
	-p $$(PARALLEL_JOBS) \
	-buildvcs=false

# Target packages need the Go compiler on the host at download time (for
# vendoring), and at build and install time.
$(2)_DOWNLOAD_DEPENDENCIES += host-go
$(2)_DEPENDENCIES += host-go

$(2)_BUILD_TARGETS ?= .

# If the build target is just ".", then we assume the binary to be
# produced is named after the package. If however, a build target has
# been specified, we assume that the binaries to be produced are named
# after each build target building them (below in <pkg>_BUILD_CMDS).
ifeq ($$($(2)_BUILD_TARGETS),.)
$(2)_BIN_NAME ?= $$($(2)_RAWNAME)
endif

$(2)_INSTALL_BINS ?= $$($(2)_RAWNAME)

# Source files in Go usually use an import path resolved around
# domain/vendor/software. We infer domain/vendor/software from the upstream URL
# of the project.
$(2)_SRC_DOMAIN = $$(call domain,$$($(2)_SITE))
$(2)_SRC_VENDOR = $$(word 1,$$(subst /, ,$$(call notdomain,$$($(2)_SITE))))
$(2)_SRC_SOFTWARE = $$(word 2,$$(subst /, ,$$(call notdomain,$$($(2)_SITE))))

# $(2)_GOMOD is the root Go module path for the project, inferred if not set.
# If the go.mod file does not exist, one is written with this root path.
$(2)_GOMOD ?= $$($(2)_SRC_DOMAIN)/$$($(2)_SRC_VENDOR)/$$($(2)_SRC_SOFTWARE)

# Generate a go.mod file if it doesn't exist. Note: Go is configured
# to use the "vendor" dir and not make network calls.
define $(2)_GEN_GOMOD
	if [ ! -f $$(@D)/$$($(2)_SUBDIR)/go.mod ]; then \
		printf "module $$($(2)_GOMOD)\n" > $$(@D)/$$($(2)_SUBDIR)/go.mod; \
	fi
endef
$(2)_POST_PATCH_HOOKS += $(2)_GEN_GOMOD

$(2)_DOWNLOAD_POST_PROCESS = go
$(2)_DL_ENV += \
	$$(HOST_GO_COMMON_ENV) \
	GOPROXY=direct \
	$$($(2)_GO_ENV)

# If building in a sub directory, do the vendoring in there
ifneq ($$($(2)_SUBDIR),)
$(2)_DOWNLOAD_POST_PROCESS_OPTS += -s$$($(2)_SUBDIR)
endif

# Because we append vendored info, we can't rely on the values being empty
# once we eventually get into the generic-package infra. So, we duplicate
# the heuristics here
ifndef $(2)_LICENSE
  ifdef $(3)_LICENSE
    $(2)_LICENSE = $$($(3)_LICENSE)
  endif
endif

# Due to vendoring, it is pretty likely that not all licenses are
# listed in <pkg>_LICENSE. If the license is unset, it is "unknown"
# so adding unknowns to some unknown is still some other unknown,
# so don't append the blurb in that case.
ifneq ($$($(2)_LICENSE),)
$(2)_LICENSE += , vendored dependencies licenses probably not listed
endif

# Build step. Only define it if not already defined by the package .mk
# file.
ifndef $(2)_BUILD_CMDS
ifeq ($(4),target)

ifeq ($(BR2_STATIC_LIBS),y)
$(2)_EXTLDFLAGS += -static
$(2)_TAGS += osusergo netgo
endif

ifeq ($(BR2_aarch64),y)
# Go forces use of the Gold linker on aarch64 due to a bug in BFD that
# is fixed in Binutils >= 2.41 (that includes all versions provided by
# Buildroot). Forcing Gold will break with toolchains that don't
# provide it (like the Buildroot toolchains), so override the flag and
# use BFD.
# See: https://github.com/golang/go/issues/22040
$(2)_EXTLDFLAGS += -fuse-ld=bfd
endif

ifneq ($$($(2)_EXTLDFLAGS),)
$(2)_LDFLAGS += -extldflags '$$($(2)_EXTLDFLAGS)'
endif

# Build package for target
define $(2)_BUILD_CMDS
	$$(foreach d,$$($(2)_BUILD_TARGETS),\
		cd $$(@D)/$$($(2)_SUBDIR); \
		$$(HOST_GO_TARGET_ENV) \
			$$($(2)_GO_ENV) \
			$$(GO_BIN) build -v $$($(2)_BUILD_OPTS) \
			-o $$(@D)/bin/$$(or $$($(2)_BIN_NAME),$$(notdir $$(d))) \
			$$($(2)_GOMOD)/$$(d)
	)
endef
else
# Build package for host
define $(2)_BUILD_CMDS
	$$(foreach d,$$($(2)_BUILD_TARGETS),\
		cd $$(@D)/$$($(2)_SUBDIR); \
		$$(HOST_GO_HOST_ENV) \
			$$($(2)_GO_ENV) \
			$$(GO_BIN) build -v $$($(2)_BUILD_OPTS) \
			-o $$(@D)/bin/$$(or $$($(2)_BIN_NAME),$$(notdir $$(d))) \
			$$($(2)_GOMOD)/$$(d)
	)
endef
endif
endif

# Target installation step. Only define it if not already defined by the
# package .mk file.
ifndef $(2)_INSTALL_TARGET_CMDS
define $(2)_INSTALL_TARGET_CMDS
	$$(foreach d,$$($(2)_INSTALL_BINS),\
		$$(INSTALL) -D -m 0755 $$(@D)/bin/$$(d) $$(TARGET_DIR)/usr/bin/$$(d)
	)
endef
endif

# Host installation step
ifndef $(2)_INSTALL_CMDS
define $(2)_INSTALL_CMDS
	$$(foreach d,$$($(2)_INSTALL_BINS),\
		$$(INSTALL) -D -m 0755 $$(@D)/bin/$$(d) $$(HOST_DIR)/bin/$$(d)
	)
endef
endif

# Call the generic package infrastructure to generate the necessary make
# targets
$(call inner-generic-package,$(1),$(2),$(3),$(4))

endef # inner-golang-package

################################################################################
# golang-package -- the target generator macro for Go packages
################################################################################

golang-package = $(call inner-golang-package,$(pkgname),$(call UPPERCASE,$(pkgname)),$(call UPPERCASE,$(pkgname)),target)
host-golang-package = $(call inner-golang-package,host-$(pkgname),$(call UPPERCASE,host-$(pkgname)),$(call UPPERCASE,$(pkgname)),host)

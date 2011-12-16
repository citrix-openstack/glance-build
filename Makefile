USE_BRANDING := yes
IMPORT_BRANDING := yes
ifdef B_BASE
include $(B_BASE)/common.mk
include $(B_BASE)/rpmbuild.mk
else
COMPONENT := glance
include ../../mk/easy-config.mk
endif

REPO := $(call hg_loc,glance)
VPX_REPO := $(call hg_loc,os-vpx)


LP_GLANCE_BRANCH ?= lp:glance


GLANCE_UPSTREAM := $(shell test -d /repos/glance && \
			   readlink -f /repos/glance || \
			   readlink -f $(REPO)/upstream)


GLANCE_VERSION := $(shell sh -c "(cat $(GLANCE_UPSTREAM)/glance/version.py; \
                                echo 'print canonical_version_string()') | \
                               python")
GLANCE_FULLNAME := openstack-glance-$(GLANCE_VERSION)-$(BUILD_NUMBER)
GLANCE_SPEC := $(MY_OBJ_DIR)/openstack-glance.spec
GLANCE_RPM_TMP_DIR := $(MY_OBJ_DIR)/RPM_BUILD_DIRECTORY/tmp/openstack-glance
GLANCE_RPM_TMP := $(MY_OBJ_DIR)/RPMS/noarch/$(GLANCE_FULLNAME).noarch.rpm
GLANCE_TARBALL := $(MY_OBJ_DIR)/SOURCES/$(GLANCE_FULLNAME).tar.gz
GLANCE_RPM := $(MY_OUTPUT_DIR)/RPMS/noarch/$(GLANCE_FULLNAME).noarch.rpm
GLANCE_SRPM := $(MY_OUTPUT_DIR)/SRPMS/$(GLANCE_FULLNAME).src.rpm

EPEL_RPM_DIR := $(CARBON_DISTFILES)/epel5
EPEL_YUM_DIR := $(MY_OBJ_DIR)/epel5

EPEL_REPOMD_XML := $(EPEL_YUM_DIR)/repodata/repomd.xml
REPOMD_XML := $(MY_OUTPUT_DIR)/repodata/repomd.xml

DEB_GLANCE_VERSION := $(shell head -1 $(REPO)/upstream/debian/changelog | \
                          sed -ne 's,^.*(\(.*\)).*$$,\1,p')
GLANCE_DEB := $(MY_OUTPUT_DIR)/glance_$(DEB_GLANCE_VERSION)_all.deb
PYTHON_GLANCE_DEB := $(MY_OUTPUT_DIR)/python-glance_$(DEB_GLANCE_VERSION)_all.deb
PYTHON_GLANCE_DOC_DEB := $(MY_OUTPUT_DIR)/python-glance-doc_$(DEB_GLANCE_VERSION)_all.deb

DEBS := $(GLANCE_DEB) $(PYTHON_GLANCE_DEB) $(PYTHON_GLANCE_DOC_DEB)
RPMS := $(GLANCE_RPM) $(GLANCE_SRPM)
OUTPUT := $(RPMS) $(REPOMD_XML)

.PHONY: build
build: $(OUTPUT)

.PHONY: debs
debs: $(DEBS)

$(PYTHON_GLANCE_DEB): $(GLANCE_DEB)
$(PYTHON_GLANCE_DOC_DEB): $(GLANCE_DEB)
$(GLANCE_DEB): $(shell find $(REPO)/upstream -type f)
	@if ls $(REPO)/*.deb >/dev/null 2>&1; \
	then \
	  echo "Refusing to run with .debs in $(REPO)." >&2; \
	  exit 1; \
	fi
	cd $(REPO)/upstream; \
	  DEB_BUILD_OPTIONS=nocheck dpkg-buildpackage -us -uc -d -b
	mv $(REPO)/*.deb $(@D)
	rm $(REPO)/*.changes
	# The log files end up newer than the .debs, so we never reach a
	# fixed point given this rule's dependency unless we remove them.
	rm $(REPO)/upstream/debian/*.debhelper.log

$(GLANCE_SRPM): $(GLANCE_RPM)
$(GLANCE_RPM): $(GLANCE_SPEC) $(GLANCE_TARBALL) $(EPEL_REPOMD_XML) \
	     $(shell find $(REPO)/openstack-glance -type f) \
	     $(REPO)/build-glance.sh
	cp -f $(REPO)/openstack-glance/* $(MY_OBJ_DIR)/SOURCES
	sh $(REPO)/build-glance.sh $@ $< $(MY_OBJ_DIR)/SOURCES

$(MY_OBJ_DIR)/%.spec: $(REPO)/openstack-glance/%.spec.in
	mkdir -p $(dir $@)
	$(call brand,$^) >$@
	sed -e 's,@GLANCE_VERSION@,$(GLANCE_VERSION),g' -i $@

$(GLANCE_TARBALL): $(shell find $(GLANCE_UPSTREAM) -type f)
	rm -rf $@ $(MY_OBJ_DIR)/openstack-glance-$(GLANCE_VERSION)
	mkdir -p $(@D)
	cp -a $(GLANCE_UPSTREAM) $(MY_OBJ_DIR)/openstack-glance-$(GLANCE_VERSION)
	tar -C $(MY_OBJ_DIR) -czf $@ openstack-glance-$(GLANCE_VERSION)

$(REPOMD_XML): $(RPMS)
	createrepo $(MY_OUTPUT_DIR)

$(EPEL_REPOMD_XML): $(wildcard $(EPEL_RPM_DIR)/%)
	$(call mkdir_clean,$(EPEL_YUM_DIR))
	cp -s $(EPEL_RPM_DIR)/* $(EPEL_YUM_DIR)
	createrepo $(EPEL_YUM_DIR)

.PHONY: rebase
rebase:
	@sh $(VPX_REPO)/rebase.sh $(LP_GLANCE_BRANCH) $(REPO)/upstream

.PHONY: doc-html
doc-html:
	$(MAKE) -C $(GLANCE_UPSTREAM)/doc

.PHONY: doc-pdf
doc-pdf:
	$(MAKE) -C $(GLANCE_UPSTREAM)/doc latex
	$(MAKE) -C $(GLANCE_UPSTREAM)/build/latex all-pdf

.PHONY: doc-clean
doc-clean:
	$(MAKE) -C $(GLANCE_UPSTREAM)/doc clean

.PHONY: clean
clean:
	rm -f $(OUTPUT)
	rm -rf $(MY_OBJ_DIR)/*

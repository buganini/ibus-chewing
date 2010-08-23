# - RPM generation, maintaining (remove old rpm) and verification (rpmlint).
#
# To use: INCLUDE(RPM)
# Included: SourceTarball
#
#===================================================================
# Variables:
# RPM_DIST_TAG: Current distribution tag such as el5, fc10.
#         Default: Distribution tag from rpm --showrc
#
# RPM_BUILD_TOPDIR: Directory of  the rpm topdir.
#         Default: ${CMAKE_BINARY_DIR}
# RPM_BUILD_SPECS: Directory of  spec files.
#         Default: ${RPM_BUILD_TOPDIR}/SPECS
# RPM_BUILD_SOURCES: Directory of source (tar.gz or zip) files.
#         Default: ${RPM_BUILD_TOPDIR}/SOURCES
# RPM_BUILD_SRPMS: Directory of source rpm files.
#         Default: ${RPM_BUILD_TOPDIR}/SRPMS
# RPM_BUILD_RPMS: Directory of generated rpm files.
#         Default: ${RPM_BUILD_TOPDIR}/RPMS
# RPM_BUILD_BUILD:  Directory for RPM build.
#         Default: ${RPM_BUILD_TOPDIR}/BUILD
# RPM_BUILD_BUILDROOT:  Directory for RPM build.
#         Default: ${RPM_BUILD_TOPDIR}/BUILDROOT
#
# RPM_SOURCE_FILES: Source and patch file for RPM build.
#         Default: ${RPM_BUILD_SOURCES}/${PROJECT_NAME}-${PRJ_VER}-Source
#                   with suffix of either tar.gz, tar.bz2, tgz, tbz, zip
# SRPM_FILE: Generated srpm file.
#         Default: ${RPM_BUILD_SRPMS}/${PROJECT_NAME}-${PRJ_VER_FULL}.${RPM_DIST_TAG}.src.rpm
# RPM_IS_NO_ARCH: Set it if this rpm is noarch, it also
#         hide rpm_mock_i386 and rpm_mock_x86_64 for noarch package
#
# MOCK_RPM_DIST_TAG: Prefix of mock configure file, such as "fedora-11", "fedora-rawhide", "epel-5"/
#         Default: Convert from RPM_DIST_TAG
#
#===================================================================
# Macros:
# GENERATE_SPEC(spec_in)
#     spec_in: Spec input file
#
# Generate a RPM spec file using an input file, spec_in
#===================================================================
# Targets:
# srpm: Build srpm (rpmbuild -bs).
#     Depends on pack_src.
#
# rpm: Build rpm and srpm (rpmbuild -ba)
#     Depends on pack_src.
#
# rpmlint: Run rpmlint to generated rpms.
#
# rpm_mock_i386: Use mock to build i386/i586 rpms.
#     Depends on srpm.
#
# rpm_mock_x86_64: Use mock to build x86_64 rpms.
#     Depends on srpm.
#
# rpm_remove_old: Remove old rpms.
#
# pkg_remove_old: Remove old source tarballs and rpms.
#     Depends on rpm_remove_old
#

IF(NOT DEFINED _PACK_RPM_CMAKE_)
    SET (_PACK_RPM_CMAKE_ "DEFINED")

    INCLUDE(PackSource)
    SET (SPEC_FILE_WARNING "This file is generated, please modified the .spec.in file instead!")

    IF(NOT DEFINED RPM_DIST_TAG)
	EXECUTE_PROCESS(COMMAND rpm --showrc
	    COMMAND grep -E "dist[[:space:]]*\\."
	    COMMAND sed -e "s/^.*dist\\s*\\.//"
	    COMMAND tr \\n \\t
	    COMMAND sed  -e s/\\t//
	    OUTPUT_VARIABLE RPM_DIST_TAG)
    ENDIF(NOT DEFINED RPM_DIST_TAG)

    IF(NOT DEFINED RPM_BUILD_TOPDIR)
	SET(RPM_BUILD_TOPDIR ${CMAKE_BINARY_DIR})
    ENDIF(NOT DEFINED RPM_BUILD_TOPDIR)

    IF(NOT DEFINED RPM_BUILD_SPECS)
	SET(RPM_BUILD_SPECS "${RPM_BUILD_TOPDIR}/SPECS")
    ENDIF(NOT DEFINED RPM_BUILD_SPECS)

    IF(NOT DEFINED RPM_BUILD_SOURCES)
	SET(RPM_BUILD_SOURCES "${RPM_BUILD_TOPDIR}/SOURCES")
    ENDIF(NOT DEFINED RPM_BUILD_SOURCES)

    IF(NOT DEFINED RPM_BUILD_SRPMS)
	SET(RPM_BUILD_SRPMS "${RPM_BUILD_TOPDIR}/SRPMS")
    ENDIF(NOT DEFINED RPM_BUILD_SRPMS)

    IF(NOT DEFINED RPM_BUILD_RPMS)
	SET(RPM_BUILD_RPMS "${RPM_BUILD_TOPDIR}/RPMS")
    ENDIF(NOT DEFINED RPM_BUILD_RPMS)

    IF(NOT DEFINED RPM_BUILD_BUILD)
	SET(RPM_BUILD_BUILD "${RPM_BUILD_TOPDIR}/BUILD")
    ENDIF(NOT DEFINED RPM_BUILD_BUILD)

    IF(NOT DEFINED RPM_BUILD_BUILDROOT)
	SET(RPM_BUILD_BUILDROOT "${RPM_BUILD_TOPDIR}/BUILDROOT")
    ENDIF(NOT DEFINED RPM_BUILD_BUILDROOT)

    MACRO(PACK_RPM spec_in [generator])
	FIND_PROGRAM(RPMBUILD NAMES "rpmbuild-md5" "rpmbuild")
	IF(${RPMBUILD} STREQUAL "RPMBUILD-NOTFOUND")
	    MESSAGE(FATAL_ERROR "rpmbuild-md5 and rpmbuild are not found in PATH!")
	ENDIF(${RPMBUILD} STREQUAL "RPMBUILD-NOTFOUND")

	# Add RPM build directories in ignore file list.
	GET_FILENAME_COMPONENT(_rpm_build_sources_basename ${RPM_BUILD_SOURCES} NAME)
	GET_FILENAME_COMPONENT(_rpm_build_srpms_basename ${RPM_BUILD_SRPMS} NAME)
	GET_FILENAME_COMPONENT(_rpm_build_rpms_basename ${RPM_BUILD_RPMS} NAME)
	GET_FILENAME_COMPONENT(_rpm_build_build_basename ${RPM_BUILD_BUILD} NAME)
	GET_FILENAME_COMPONENT(_rpm_build_buildroot_basename ${RPM_BUILD_BUILDROOT} NAME)
	SET(RPM_IGNORE_FILES "\\\\.rpm$"
	    "/${rpm_build_sources_basename}/" "/${rpm_build_srpms_basename}/" "/${rpm_build_rpms_basename}/"
	    "/${rpm_build_build_basename}/" "/${rpm_build_buildroot_basename}/" "debug.*s.list")
	INCLUDE(PackSource)
	SET(PACK_SOURCE_IGNORE_FILES ${PACK_SOURCE_IGNORE_FILE} ${RPM_IGNORE_FILES})

	# Pack source and generate spec
	PACK_SOURCE(${RPM_BUILD_SOURCES} ${ARGV2})
	GET_FILENAME_COMPONENT(_source_tarball ${PACK_SOURCE_FILE_NAME} NAME)
	CONFIGURE_FILE(${spec_in} ${RPM_BUILD_SPECS}/${PROJECT_NAME}.spec)
	SET_SOURCE_FILES_PROPERTIES(${RPM_BUILD_SPECS}/${PROJECT_NAME}.spec
	    PROPERTIES GENERATED TRUE
	    )

	#-------------------------------------------------------------------
	# RPM build targets

	ADD_CUSTOM_COMMAND(OUTPUT ${RPM_BUILD_SRPMS}
	    COMMAND ${CMAKE_COMMAND} -E make_directory ${RPM_BUILD_SRPMS}
	    )

	ADD_CUSTOM_COMMAND(OUTPUT ${RPM_BUILD_RPMS}
	    COMMAND ${CMAKE_COMMAND} -E make_directory ${RPM_BUILD_RPMS}
	    )

	ADD_CUSTOM_COMMAND(OUTPUT ${RPM_BUILD_BUILD}
	    COMMAND ${CMAKE_COMMAND} -E make_directory ${RPM_BUILD_BUILD}
	    )

	ADD_CUSTOM_COMMAND(OUTPUT ${RPM_BUILD_BUILDROOT}
	    COMMAND ${CMAKE_COMMAND} -E make_directory ${RPM_BUILD_BUILDROOT}
	    )

	ADD_CUSTOM_TARGET(srpm
	    COMMAND ${RPMBUILD} -bs ${RPM_BUILD_SPECS}/${PROJECT_NAME}.spec
	    --define '_sourcedir ${RPM_BUILD_SOURCES}'
	    --define '_builddir ${RPM_BUILD_BUILD}'
	    --define '_srcrpmdir ${RPM_BUILD_SRPMS}'
	    --define '_rpmdir ${RPM_BUILD_RPMS}'
	    --define '_specdir ${RPM_BUILD_SPECS}'
	    DEPENDS ${RPM_BUILD_SPECS}/${PROJECT_NAME}.spec ${PACK_SOURCE_FILE_NAME}
	      ${RPM_BUILD_SRPMS} ${RPM_BUILD_BUILD}
	    )

	ADD_CUSTOM_TARGET(rpm
	    COMMAND ${CMAKE_COMMAND} -E make_directory ${RPM_BUILD_SRPMS}
	    COMMAND ${RPMBUILD} -ba --buildroot ${RPM_BUILD_BUILDROOT} ${RPM_BUILD_SPECS}/${PROJECT_NAME}.spec
	    --define '_sourcedir ${RPM_BUILD_SOURCES}'
	    --define '_builddir ${RPM_BUILD_BUILD}'
	    --define '_srcrpmdir ${RPM_BUILD_SRPMS}'
	    --define '_rpmdir ${RPM_BUILD_RPMS}'
	    --define '_specdir ${RPM_BUILD_SPECS}'
	    DEPENDS ${RPM_BUILD_SPECS}/${PROJECT_NAME}.spec ${PACK_SOURCE_FILE_NAME}
	    ${RPM_BUILD_SRPMS} ${RPM_BUILD_RPMS} ${RPM_BUILD_BUILD} ${RPM_BUILD_BUILDROOT}
	    )

    ENDMACRO(PACK_RPM spec_in)

IF(NOT DEFINED RPM_SOURCE_FILES)
    SET(RPM_SOURCE_FILES ${SOURCE_TARBALL_OUTPUT})
    #MESSAGE("RPM_SOURCE_FILES=${RPM_SOURCE_FILES}")
ENDIF(NOT DEFINED RPM_SOURCE_FILES)

IF(NOT DEFINED SRPM_FILE)
    SET (SRPM_FILE ${RPM_BUILD_SRPMS}/${PROJECT_NAME}-${PRJ_VER_FULL}.${RPM_DIST_TAG}.src.rpm)
ENDIF(NOT DEFINED SRPM_FILE)

IF(NOT DEFINED MOCK_RPM_DIST_TAG)
    STRING(REGEX MATCH "^fc([1-9][0-9]*)"  _fedora_mock_dist "${RPM_DIST_TAG}")
    STRING(REGEX MATCH "^el([1-9][0-9]*)"  _el_mock_dist "${RPM_DIST_TAG}")

    IF (_fedora_mock_dist)
        STRING(REGEX REPLACE "^fc([1-9][0-9]*)" "fedora-\\1" MOCK_RPM_DIST_TAG "${RPM_DIST_TAG}")
    ELSEIF (_el_mock_dist)
        STRING(REGEX REPLACE "^el([1-9][0-9]*)" "epel-\\1" MOCK_RPM_DIST_TAG "${RPM_DIST_TAG}")
    ELSE (_fedora_mock_dist)
	SET(MOCK_RPM_DIST_TAG "fedora-devel")
    ENDIF(_fedora_mock_dist)
    #MESSAGE ("MOCK_RPM_DIST_TAG=${MOCK_RPM_DIST_TAG}")
ENDIF(NOT DEFINED MOCK_RPM_DIST_TAG)

IF(NOT RPM_IS_NOARCH)
    ADD_CUSTOM_TARGET(rpm_mock_i386
	COMMAND ${CMAKE_COMMAND} -E make_directory RPMS/i386
	COMMAND mock -r  "${MOCK_RPM_DIST_TAG}-i386" --resultdir="${RPM_BUILD_RPMS}/i386" ${SRPM_FILE}
	)

    ADD_CUSTOM_TARGET(rpm_mock_x86_64
	COMMAND ${CMAKE_COMMAND} -E make_directory RPMS/x86_64
	COMMAND mock -r  "${MOCK_RPM_DIST_TAG}-x86_64" --resultdir="${RPM_BUILD_RPMS}/x86_64" ${SRPM_FILE}
	)

    ADD_DEPENDENCIES(rpm_mock_i386 srpm)
    ADD_DEPENDENCIES(rpm_mock_x86_64 srpm)
ENDIF(NOT RPM_IS_NOARCH)

ADD_CUSTOM_TARGET(rpmlint find .
    -name '${PROJECT_NAME}*-${PRJ_VER_FULL}.*.rpm'
    -print -exec rpmlint '{}' '\\;'
    )


ADD_CUSTOM_TARGET(rpm_remove_old
    COMMAND find .
    -name '${PROJECT_NAME}*.rpm' ! -name '${PROJECT_NAME}*-${PRJ_VER_FULL}.*.rpm'
    -print -delete
    COMMENT "Removing the old rpms.."
    )


ADD_DEPENDENCIES(pkg_remove_old rpm_remove_old)
ENDIF(NOT DEFINED _PACK_RPM_CMAKE_)

#!/usr/bin/env bash
#
# Script to generate UFS test files
# Requires BSD with dd, mdconfig, bsdlabel and newfs

EXIT_SUCCESS=0;
EXIT_FAILURE=1;

# Checks the availability of a binary and exits if not available.
#
# Arguments:
#   a string containing the name of the binary
#
assert_availability_binary()
{
	local BINARY=$1;

	which ${BINARY} > /dev/null 2>&1;
	if test $? -ne ${EXIT_SUCCESS};
	then
		echo "Missing binary: ${BINARY}";
		echo "";

		exit ${EXIT_FAILURE};
	fi
}

# Creates test file entries.
#
# Arguments:
#   a string containing the mount point of the image file
#
create_test_file_entries()
{
	MOUNT_POINT=$1;

	# Create an empty file
	touch ${MOUNT_POINT}/emptyfile

	# Create a directory
	mkdir ${MOUNT_POINT}/testdir1

	# Create a file that can be stored as inline data
	echo "My file" > ${MOUNT_POINT}/testdir1/testfile1

	# Create a file that cannot be stored as inline data
	cp LICENSE ${MOUNT_POINT}/testdir1/TestFile2

	# Create a hard link to a file
	ln ${MOUNT_POINT}/testdir1/testfile1 ${MOUNT_POINT}/file_hardlink1

	# Create a symbolic link to a file
	ln -s ${MOUNT_POINT}/testdir1/testfile1 ${MOUNT_POINT}/file_symboliclink1

	# Create a hard link to a directory
	# ln: hard link not allowed for directory

	# Create a symbolic link to a directory
	ln -s ${MOUNT_POINT}/testdir1 ${MOUNT_POINT}/directory_symboliclink1

	# Create a file with an UTF-8 NFC encoded filename
	touch `printf "${MOUNT_POINT}/nfc_t\xc3\xa9stfil\xc3\xa8"`

	# Create a file with an UTF-8 NFD encoded filename
	touch `printf "${MOUNT_POINT}/nfd_te\xcc\x81stfile\xcc\x80"`

	# Create a file with an UTF-8 NFD encoded filename
	touch `printf "${MOUNT_POINT}/nfd_\xc2\xbe"`

	# Create a file with an UTF-8 NFKD encoded filename
	touch `printf "${MOUNT_POINT}/nfkd_3\xe2\x81\x844"`
}

# Creates a test image file.
#
# Arguments:
#   a string containing the path of the image file
#   an integer containing the size of the image file
#   an integer containing the sector size
#   an array containing the arguments for newfs
#
create_test_image_file()
{
	IMAGE_FILE=$1;
	IMAGE_SIZE=$2;
	SECTOR_SIZE=$3;
	shift 3;
	local ARGUMENTS=("$@");

	dd if=/dev/zero of=${IMAGE_FILE} bs=${SECTOR_SIZE} count=$(( ${IMAGE_SIZE} / ${SECTOR_SIZE} )) 2> /dev/null;

	mdconfig -a -t vnode -f ${IMAGE_FILE} -u 9;

	bsdlabel -w -B md9 auto;

	echo "newfs ${ARGUMENTS[@]} md9a";
	newfs ${ARGUMENTS[@]} md9a;
}

# Creates a test image file with file entries.
#
# Arguments:
#   a string containing the path of the image file
#   an integer containing the size of the image file
#   an integer containing the sector size
#   an array containing the arguments for newfs
#
create_test_image_file_with_file_entries()
{
	IMAGE_FILE=$1;
	IMAGE_SIZE=$2;
	SECTOR_SIZE=$3;
	shift 3;
	local ARGUMENTS=("$@");

	create_test_image_file ${IMAGE_FILE} ${IMAGE_SIZE} ${SECTOR_SIZE} ${ARGUMENTS[@]};

	mount /dev/md9a ${MOUNT_POINT};

	create_test_file_entries ${MOUNT_POINT};

	umount ${MOUNT_POINT};

	mdconfig -d -u 9;
}

assert_availability_binary bsdlabel;
assert_availability_binary dd;
assert_availability_binary mdconfig;
assert_availability_binary newfs;

SPECIMENS_PATH="specimens/newfs";

if test -d ${SPECIMENS_PATH};
then
	echo "Specimens directory: ${SPECIMENS_PATH} already exists.";

	exit ${EXIT_FAILURE};
fi

mkdir -p ${SPECIMENS_PATH};

set -e;

MOUNT_POINT="/mnt/ufs";

mkdir -p ${MOUNT_POINT};

IMAGE_SIZE=$(( 4 * 1024 * 1024 ));
SECTOR_SIZE=512;

# Create an UFS 1 file system
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/ufs1.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-L ufs_test" "-O 1";

# Create an UFS 2 file system
create_test_image_file_with_file_entries "${SPECIMENS_PATH}/ufs2.raw" ${IMAGE_SIZE} ${SECTOR_SIZE} "-L ufs_test" "-O 2";

# TODO: test image with journaling -J
# TODO: test image with different block sizes -b 4096 - 32768
# TODO: test image with different number of blocks per cylinder -c
# TODO: test image with different maximum extent size -m
# TODO: test image with different fragment size -f

exit ${EXIT_SUCCESS};


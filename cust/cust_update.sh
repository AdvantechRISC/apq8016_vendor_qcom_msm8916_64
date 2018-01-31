#!/system/bin/sh

# =========================================================================================================================================================== #
# Default environment
# =========================================================================================================================================================== #
CUST_ROOT_DIR="/cust"

# default update device : USB
CUST_RESOURCE_DEV="USB"

CUST_LOCAL_INFO_DIR="${CUST_ROOT_DIR}/info"
CUST_LOCAL_INFO_PROJECT="$(cat ${CUST_LOCAL_INFO_DIR}/name)"

CUST_UPDATE_TARGET_DIR="/cust/usr"
CUST_UPDATE_TARGET_PACKAGE="${CUST_UPDATE_TARGET_DIR}/cust_update.zip"

CUST_UPDATE_RESULT="0"

CUST_TAG="[CUST-UPDT]"

# =========================================================================================================================================================== #
# Dynamic environment
# =========================================================================================================================================================== #
CUST_LOCAL_INFO_ITEMS=""

CUST_UPDATE_SOURCE_DIR=""
CUST_UPDATE_SOURCE_PACKAGE=""

CUST_UPDATE_INFO_DIR=""
CUST_UPDATE_INFO_VERSION=""
CUST_UPDATE_PROJECT_DIR=""

CUST_UPDATE_INFO_ITEMS=""

CUST_UPDATE_SOURCE_PACKAGE=""

CUST_UPDATE_LOG=""

# =========================================================================================================================================================== #
# Device & Flag
# =========================================================================================================================================================== #
KERNEL_CONSOLE="/dev/kmsg"

EXTRACT_PACKAGE=0
EXTRACT_RESULT=0

# =========================================================================================================================================================== #
# Function
# =========================================================================================================================================================== #
WORK_DIR_PUSH=""
WORK_DIR_POP=""

function pushd ()
{
	WORK_DIR_PUSH=$1
	WORK_DIR_POP=$(pwd)
	
	echo "${CUST_TAG} <pushd> : from $WORK_DIR_POP to $WORK_DIR_PUSH" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
	
	cd $WORK_DIR_PUSH
}

function popd ()
{
	echo "${CUST_TAG} <popd> : from $WORK_DIR_PUSH to $WORK_DIR_POP" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
	
	cd $WORK_DIR_POP
}

function exit_svc ()
{
	value=$1
	
	setprop sys.cust.update.lock 0
	
	echo "${CUST_TAG} <exit_svc> : exit with value $value" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
	
	if [ "$value" == "0" ]; then
		if [ "$CUST_UPDATE_RESULT" == "1" ]; then
			reboot
		fi
	fi
	
	svc power stayon false
	
	exit $value
}

# =========================================================================================================================================================== #
# Core
# =========================================================================================================================================================== #
echo "\n${CUST_TAG} cust update service start" | tee ${KERNEL_CONSOLE}

if [ "x$1" != "x" ]; then
	CUST_RESOURCE_DEV=$1
	
	case ${CUST_RESOURCE_DEV} in
	"SYS")
		CUST_TAG="[CUST-UPDT][SYS]"
		CUST_UPDATE_SOURCE_DIR="/system"
		CUST_UPDATE_LOG="${CUST_UPDATE_TARGET_DIR}/log_sys.txt"
		;;
	"USB")
		CUST_TAG="[CUST-UPDT][USB]"
		CUST_UPDATE_SOURCE_DIR="/mnt/media_rw/$(getprop sys.cust.storage)"
		CUST_UPDATE_LOG="${CUST_UPDATE_TARGET_DIR}/log_usb.txt"
		;;
	"MMC")
		CUST_TAG="[CUST-UPDT][MMC]"
		CUST_UPDATE_SOURCE_DIR="/mnt/media_rw/extsd/cust"
		CUST_UPDATE_LOG="${CUST_UPDATE_TARGET_DIR}/log_mmc.txt"
		;;
	"*")
		# default resource device : USB
		echo "${CUST_TAG} unknown resource, use ${CUST_RESOURCE_DEV}" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
		CUST_TAG="[CUST-UPDT][USB]"
		CUST_UPDATE_SOURCE_DIR="/mnt/media_rw/$(getprop sys.cust.storage)"
		CUST_UPDATE_LOG="${CUST_UPDATE_TARGET_DIR}/log_usb.txt"
		;;
	esac
else
	echo "${CUST_TAG} default resource : ${CUST_RESOURCE_DEV}" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
	CUST_TAG="[CUST-UPDT][USB]"
	CUST_UPDATE_SOURCE_DIR="/mnt/media_rw/$(getprop sys.cust.storage)"
	CUST_UPDATE_LOG="${CUST_UPDATE_TARGET_DIR}/log_usb.txt"
fi

# =========================================================================================================================================================== #

# delete the old log file
rm -rf "${CUST_UPDATE_LOG}"

# =========================================================================================================================================================== #
# simulate the mutex lock function
while [ "$(getprop sys.cust.update.lock)" == "1" ]; do
	echo "${CUST_TAG} waiting for other update service" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
	sleep 5
done

setprop sys.cust.update.lock 1

svc power stayon true

echo "${CUST_TAG} update customization data from ${CUST_RESOURCE_DEV}" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}

# debug mutex
#if [ "${CUST_RESOURCE_DEV}" == "SYS" ]; then
#	echo "${CUST_TAG} ${CUST_RESOURCE_DEV} working emulation time" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
#	sleep 50
#fi
# =========================================================================================================================================================== #
# device dependent environment setup
CUST_LOCAL_INFO_VERSION="$(cat ${CUST_LOCAL_INFO_DIR}/version)"

CUST_UPDATE_SOURCE_PACKAGE="${CUST_UPDATE_SOURCE_DIR}/cust/cust_update.zip"
CUST_PROJECT_LIST=$(busybox unzip -l ${CUST_UPDATE_SOURCE_PACKAGE} | busybox awk '{print $4}' | sed -e '/^Name/d' -e '/^\-/d' -e '/^$/d' -e '/^.*\/..*/d' | cut -d / -f 1)

# =========================================================================================================================================================== #
# clear the previous resource
rm -rf "${CUST_UPDATE_TARGET_DIR}/${CUST_LOCAL_INFO_PROJECT}" && \
rm -rf "${CUST_UPDATE_TARGET_PACKAGE}"

# =========================================================================================================================================================== #
# download resource
for target in ${CUST_PROJECT_LIST[@]}; do
	if [ "$target" == "${CUST_LOCAL_INFO_PROJECT}" ]; then

		cp ${CUST_UPDATE_SOURCE_PACKAGE} ${CUST_UPDATE_TARGET_PACKAGE} && \
		busybox diff -q ${CUST_UPDATE_SOURCE_PACKAGE} ${CUST_UPDATE_TARGET_PACKAGE}
		
		if [ "$?" == "0" ]; then
			echo "${CUST_TAG} cust package download complete" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
		else
			echo "${CUST_TAG} cust package download failed"   | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
			exit_svc 1
		fi
		
		CUST_UPDATE_PROJECT_DIR="${CUST_UPDATE_TARGET_DIR}/${target}"
		CUST_UPDATE_INFO_DIR="${CUST_UPDATE_PROJECT_DIR}/info"
		CUST_UPDATE_INFO_VERSION=$(busybox unzip -p ${CUST_UPDATE_SOURCE_PACKAGE} "${target}/info/version")
		
		EXTRACT_PACKAGE=$(busybox awk -v x=${CUST_LOCAL_INFO_VERSION} -v y=${CUST_UPDATE_INFO_VERSION} 'BEGIN{print x<y?1:0 }')
		
		echo "${CUST_TAG} update version : $CUST_UPDATE_INFO_VERSION"  | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
		echo "${CUST_TAG} local version  : $CUST_LOCAL_INFO_VERSION"   | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
	fi
done

if [ "$EXTRACT_PACKAGE" == "1" ]; then

	# extract the matched project only
	busybox unzip ${CUST_UPDATE_TARGET_PACKAGE} "${CUST_LOCAL_INFO_PROJECT}/*" -d "${CUST_UPDATE_TARGET_DIR}"
	
	if [ "$?" == "0" ]; then
		echo "${CUST_TAG} extract package complete" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
	else
		echo "${CUST_TAG} extract package failed"   | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
		exit_svc 1
	fi	
	
	total_items=$(sed -n '1p' ${CUST_UPDATE_INFO_DIR}/items | cut -d : -f 2)

	pushd ${CUST_UPDATE_PROJECT_DIR}
		checked_items=$(busybox md5sum -c md5 | grep "OK" | wc -l)
	
		if [ "$?" != "0" ]; then
			echo "${CUST_TAG} md5sum update items failed"  | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
			exit_svc 1
		fi
		
		echo "${CUST_TAG} checked:$checked_items total:$(expr $total_items - 1)" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
		
		# exclude the md5 file itself
		if [ "$checked_items" == "$(expr ${total_items} - 1)" ]; then
			echo "${CUST_TAG} all update items are checked"       | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
			EXTRACT_RESULT=1
		else
			echo "${CUST_TAG} checked item numbers are incorrect" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
			exit_svc 1
		fi
	popd

	# update package
	if [ "$EXTRACT_RESULT" == "1" ]; then

		# cut out the "./" 
		CUST_LOCAL_INFO_ITEMS=$(sed '/^total items/d' ${CUST_LOCAL_INFO_DIR}/items | cut -d / -f 2-)
		CUST_UPDATE_INFO_ITEMS=$(sed '/^total items/d' ${CUST_UPDATE_INFO_DIR}/items | cut -d / -f 2-)
		
		# delete the items that don't exist in the update package
		for item in ${CUST_LOCAL_INFO_ITEMS[@]}; do
			cust_local_item="${CUST_ROOT_DIR}/$item"
			cust_update_item="${CUST_UPDATE_TARGET_DIR}/${CUST_LOCAL_INFO_PROJECT}/$item"
			
			if [ ! -f $cust_update_item ]; then
				echo "${CUST_TAG} delete local file $cust_local_item" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
				rm $cust_local_item
			fi
			
		done
		
		# add new items or replace the both exist items
		for item in ${CUST_UPDATE_INFO_ITEMS[@]}; do
			cust_local_item="${CUST_ROOT_DIR}/$item"
			cust_update_item="${CUST_UPDATE_TARGET_DIR}/${CUST_LOCAL_INFO_PROJECT}/$item"
			
			# leave version to the last step
			if [ "$item" == "info/version" ]; then
				continue
			fi
			
			echo "${CUST_TAG} update file $cust_local_item" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
			cp -f $cust_update_item $cust_local_item
		done
	fi
	
	# reset the properties
	while read cmdline; do	
		property=$(echo $cmdline | cut -d '|' -f 1)
		value=$(echo $cmdline | cut -d '|' -f 2)

		while true
		do
			if [ "$value" == "eInvalid" ]; then
				echo "${CUST_TAG} [DEFAULT] : $property []" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
				setprop $property ""
			else
				echo "${CUST_TAG} [DEFAULT] : $property [$value]" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
				setprop $property $value
			fi
			
			if [ "$?" != "0" ]; then
				echo "${CUST_TAG} setprop $property failed"  | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
				continue
			fi
			
			# verify the property
			if  [ "$value" != "eInvalid" ] && [ "$(getprop $property)" != "$value" ]; then
				echo "${CUST_TAG} verify the property $property:$value failed"  | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
				continue
			else
				break
			fi		
		done
	done < "${CUST_LOCAL_INFO_DIR}/default.prop"
	
	# parse the commandline
	while read cmdline; do
		action=$(echo $cmdline | cut -d '|' -f 1)
		num=$(echo $cmdline | busybox awk -F"|" '{print NF}')
	
		case $action in
			"S")
				property=$(echo $cmdline | cut -d '|' -f 2)
				value=$(echo $cmdline | cut -d '|' -f 3)

				while true
				do
					if [ "$value" == "eInvalid" ]; then
						echo "${CUST_TAG} <cmd> : $property []" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
						setprop $property ""
					else
						echo "${CUST_TAG} <cmd> : $property [$value]" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
						setprop $property $value
					fi
				
					if [ "$?" != "0" ]; then
						echo "${CUST_TAG} setprop $property failed"  | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
						continue
					fi
				
					# verify the property
					if  [ "$value" != "eInvalid" ] && [ "$(getprop $property)" != "$value" ]; then
						echo "${CUST_TAG} verify the property $property:$value failed"  | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
						continue
					else
						break
					fi		
				done			
				;;
			"D")
				file=$(echo $cmdline | cut -d '|' -f 2)
				
				echo "${CUST_TAG} <cmd> rm -f $file" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
				rm -rf $file
				
				if [ "$?" != "0" ]; then
					echo "${CUST_TAG} delete file: $file failed"  | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
					exit_svc 1
				fi
				
				# verify if the file exist
				if [ -f $file ]; then
					echo "${CUST_TAG} verify the deleted file: $file failed"  | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
					exit_svc 1				
				fi			
				;;
			"C")
				cmd=$(echo $cmdline | cut -d '|' -f 2 | sed 's/"//g')
				
				echo "${CUST_TAG} <cmd> $cmd" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
				$cmd
				
				# for specfic use, don't exit anyway
				if [ "$?" != "0" ]; then
					echo "${CUST_TAG} excute command $cmd failed"  | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
				fi
				;;			
			"*")
				echo "${CUST_TAG} unknown action: $action" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
				;;
		esac
	done < "${CUST_LOCAL_INFO_DIR}/cmds"
	
	# update the cust version in the final step
	cust_local_version_path="${CUST_ROOT_DIR}/info/version"
	cust_update_version_path="${CUST_UPDATE_TARGET_DIR}/${CUST_LOCAL_INFO_PROJECT}/info/version"
	
	echo "${CUST_TAG} update cust version from `cat $cust_local_version_path` to `cat $cust_update_version_path`" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
	
	cp -f "$cust_update_version_path" "$cust_local_version_path"
	
	if [ "$?" != "0" ]; then
		echo "${CUST_TAG} update cust version failed"  | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
		exit_svc 1
	fi

	# verify the updated files
	pushd ${CUST_ROOT_DIR}
		total_items=$(sed -n '1p' ./info/items | cut -d : -f 2)
		checked_items=$(busybox md5sum -c md5 | grep "OK" | wc -l)

		if [ "$?" != "0" ]; then
			echo "${CUST_TAG} verify items failed"  | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
			exit_svc 1
		fi
		
		if [ "$checked_items" == "$(expr $total_items - 1)" ]; then
			echo "${CUST_TAG} all items are verified"               | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
			CUST_UPDATE_RESULT=1
		else
			echo "${CUST_TAG} verified item numbers are incorrect"  | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
			exit_svc 1
		fi
	popd	
	
fi

exit_svc 0

# =========================================================================================================================================================== #


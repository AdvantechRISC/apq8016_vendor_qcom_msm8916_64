#!/system/bin/sh

# =========================================================================================================================================================== #
# Default environment
# =========================================================================================================================================================== #
CUST_ROOT_DIR="/cust"

CUST_UPDATE_TARGET_DIR="/cust/usr"
CUST_UPDATE_LOG="${CUST_UPDATE_TARGET_DIR}/log.txt"

CUST_UPDATE_SOURCE_DIR="/system/cust"
CUST_UPDATE_SOURCE_PACKAGE="${CUST_UPDATE_SOURCE_DIR}/cust_update.zip"

CUST_LOCAL_INFO_DIR="/cust/info"

CUST_FACTORY_RESET_PROP="persist.sys.cust.freset"

CUST_TAG="[CUST-INIT]"

# =========================================================================================================================================================== #
# Device & Flag
# =========================================================================================================================================================== #
KERNEL_CONSOLE="/dev/kmsg"

# =========================================================================================================================================================== #
# Function
# =========================================================================================================================================================== #
function exit_svc ()
{
	value=$1
	
	echo "${CUST_TAG} <exit_svc> : exit with value $value" | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}

	if [ "$value" == "0" ] && [ "$CLEAN_BOOT" != "false" ]; then
		setprop $CUST_FACTORY_RESET_PROP false

		if [ "$?" != "0" ]; then
			echo "${CUST_TAG} setprop $CUST_FACTORY_RESET_PROP failed"  | tee ${KERNEL_CONSOLE} | tee -a ${CUST_UPDATE_LOG}
			exit 1
		else
			reboot
		fi
	fi
	
	svc power stayon false
	
	exit $value
}

# =========================================================================================================================================================== #
# Core
# =========================================================================================================================================================== #
echo "${CUST_TAG} sysinit service start" | tee ${KERNEL_CONSOLE} | tee ${CUST_UPDATE_LOG}

CLEAN_BOOT=$(getprop $CUST_FACTORY_RESET_PROP)

if [ "$CLEAN_BOOT" != "false" ]; then
	# keep system stayon awake
	svc power stayon true
	
	# parse the command file
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
fi

if [ -f ${CUST_UPDATE_SOURCE_PACKAGE} ]; then
	/system/bin/sh /system/etc/cust_update.sh "SYS"
fi

echo "${CUST_TAG} sysinit service end" | tee ${KERNEL_CONSOLE} | tee ${CUST_UPDATE_LOG}

exit_svc 0
# =========================================================================================================================================================== #

## close the STDERR output
# exec 2<&-

## or...

## redirect STDERR to the warning_log.in file
# d_logs='./logs'
# exec 2> ${d_logs}/warning_log.in

#################
# local variables
#################

# auto leveling values
al_base_midrange=.5
al_colormode='rgb' # default color mode
al_gamma_sigma=0
al_midrange=.5 # default gamma
al_show_midrange=0

# file variables
bname=''
fileBar=''
fname=''
xname=''
ofname=''
alreadyExists=' already exists. Skipping process.'

# colorspace
fileColorspace=''



# contrast-stretch values
blackSigma=2
whiteSigma=1

# denoise default values
# [filter size, noise sigma, unsharpen sigma]
dn_filter=1
dn_noise=8
# dn_usharp='0x6+0.5+0'
dn_usharp='0.25x0.25+8+0.065'

# label values
al_label='fw-autolevel'
cs_label='contrast-stretch'
eq_label='equalizing'
gr_label='gaussian-redist'
nr_label='normalize'
ur_label='uniform-redist'

# path variables
d_colorCorrected='02-colorCorrected'
d_master='master'
d_noiseReduced='01-noiseReduced'
d_leanJPG='03-leanJPG'
d_retouched='02-retouched'
d_resized='00-resized'
filesToProcess='*.tif'

# resize values
rs_size=1920 # size (width) of the image.
rs_dpi=300 # density of the image

# logging functions

logTimes() {
	echo "** Times..."
	times
	echo ""
}

########################
# file naming functions
########################

# strip the path from each file name row as it comes as 
# "./master/example.tif"
getBaseName() {
	bname="$(basename -- ${1})"
	echo "°°° ${FUNCNAME[0]}(${1}) - bname = '${bname}'"
}

getExtName() {
	xname="${1##*.}"
	echo "°°° ${FUNCNAME[0]}(${1}) - xname = '${xname}'"
}

getFileName() {
	fname="${1%%.*}"
	echo "°°° ${FUNCNAME[0]}(${1}) - fname = '${fname}'"
}

setOutFileName() {
	# $1 fileNameLabel 
	# $2 callingFunctionName
	# $3 directory
	# $4 file extension (if changing)
	if [ -z ${1} ]; then
		fileBar=''
	else
		fileBar='_'
	fi
	# echo "[ $2 ] -> fileNameLabel='${1}', \
	# fileBar='${fileBar}'"

	if [ ! -z ${4} ]; then
		xname=${4}
	fi 
	ofname="${3}/${fname}${fileBar}${1}.${xname}"

	# if the file exists, don't process
	if test -f ${ofname}; then
		echo "[ $2 ] -> '${ofname}${alreadyExists}"
		return 1
	else # if it doesn't, process
		echo "[ $2 ] -> '${ofname}'"
		return 0
	fi
}

#############################
# image processing functions
#############################

autoLevelImg() {
	al_gamma_sigma=${1}
	al_midrange=$(awk "BEGIN {print $al_gamma_sigma+$al_base_midrange; exit}")
	al_show_midrange=$(awk "BEGIN {print $al_midrange*10; exit}")
	# decide which colorspace we will be using
	getColorspace ${3}
	if [[ "${fileColorspace}" == "Gray" ]]; then
		al_colormode='gray'
		# al_midrange=${al_gray_midrange}+${1}
		echo "  -- fileColorspace=${fileColorspace}, al_colormode={$al_colormode}"
	else
		al_colormode='rgb'
		#al_midrange=${al_rgb_midrange}+${1}
		echo "  -- fileColorspace=${fileColorspace}, al_colormode={$al_colormode}"
	fi
	
	setOutFileName "${al_label}(${al_colormode}-g[${al_show_midrange}])" \
		${FUNCNAME[0]} ${d_colorCorrected}
	# [-c colormode] [-m midrange] infile outfile 
	if [ $? -eq 0 ]; then
		autolevel -c ${al_colormode} -m ${al_midrange} ${2} ${ofname}
	fi
}

#TODO
contrastStretch() {
	
	# 
	# 
	setOutFileName ${cs_label} ${FUNCNAME[0]} ${d_colorCorrected}
	if [ $? -eq 0 ]; then
		convert ${1} -channel RGB -contrast-stretch \
			${blackSigma}%x${whiteSigma}% ${ofname}
	fi
}

copyImage() {
	setOutFileName "" ${FUNCNAME[0]} ${2}
	if [ $? -eq 0 ]; then
		cp ${1} ${ofname}
	fi
}

deNoiseImg() {
	# denoise [-m method] [-f filter] [-s subsection] [-n nstd] 
	#   [-u unsharp] [-g gain] infile outfile
	setOutFileName "denoise[f${1}-n${2}-u${3}]" \
					${FUNCNAME[0]} ${d_noiseReduced}
	if [ $? -eq 0 ]; then
		denoise -f ${1} -n ${2} -u ${3} ${4} ${ofname}
	fi
}

equalizeImg() {
	setOutFileName "equalize" ${FUNCNAME[0]}
	# [-c colormode] [-m midrange] infile outfile 
	convert $1 -equalize ${ofname}
}

getColorspace() {
	fileColorspace=`identify -format "%[colorspace]\n" ${1} 2>/dev/null`
}

normalizeImg() {
	setOutFileName ${nr_label} ${FUNCNAME[0]} ${d_colorCorrected}
	# convert infile -channel all -normalize outfile
	if [ $? -eq 0 ]; then
		convert $1 -channel all -normalize ${ofname}
	fi
}

redistImg() {
	setOutFileName ${3} ${FUNCNAME[0]}
	# [-s shape] mid, low, high infile outfile
	# redist -s ${1} 60,60,60 ${2} ${ofname}
	redist -s ${1} ${2} ${ofname}
}

# -resize <pixels> -density <dots per inch> infile outfile
resizeImage() {
	setOutFileName "rsz" ${FUNCNAME[0]} ${d_resized}
	if [ $? -eq 0 ]; then
		convert -resize ${1} -density ${2} ${3} ${ofname}
	fi
}

exportLeanJPG() {
	setOutFileName "a_lean[q${2}]" ${FUNCNAME[0]} \
		${d_leanJPG} "jpg"
	if [ $? -eq 0 ]; then		
		convert ${1} -sampling-factor 4:2:0 -quality ${2} \
			-interlace JPEG ${ofname}
	fi
}

###################
# processing steps
###################

step00_Resize() {
	# loop over all base files
	for f in ${d_master}/${filesToProcess}
	do	
		# get the list of files to work with
		getBaseName $f
		getFileName $bname
		getExtName $bname
		
#		copyImage ${f} ${d_resized}
		resizeImage ${rs_size} ${rs_dpi} $f

		logTimes
	done
}

step01a_Denoise() {
	# loop over all resized files
	for f in ${1}/${filesToProcess}
	do	
		# get the list of files to work with
		getBaseName $f
		getFileName $bname
		getExtName $bname
		
		# filterSize noiseSigma unsharpSigma inputFile
		deNoiseImg $dn_filter $dn_noise $dn_usharp $f

		logTimes
	done
}

# step02* is related to color correction

step02_AutoLevelImg() {
	# loop over all resized files
	for f in ${d_resized}/${filesToProcess}
	do	
		# get the list of files to work with
		getBaseName $f
		getFileName $bname
		getExtName $bname
		
		# autoLevelImg modifyGammaB infile
		autoLevelImg -.2 ${f}
		autoLevelImg -.1 ${f}
		autoLevelImg 0 ${f}
		autoLevelImg .1 ${f}
		autoLevelImg .2 ${f}
		

		logTimes
	done
}

step02a_NormalizeImage() {
	# loop over all resized files
	for f in ${d_resized}/${filesToProcess}
	do	
		# get the list of files to work with
		getBaseName $f
		getFileName $bname
		getExtName $bname
		
		# inputFile
		normalizeImg ${f}

		logTimes
	done
}

step02b_ContrastStretchImage() {
	# loop over all resized files
	for f in ${d_resized}/${filesToProcess}
	do	
		# get the list of files to work with
		getBaseName $f
		getFileName $bname
		getExtName $bname
		
		# inputFile
		contrastStretch ${f}

		logTimes
	done
}

step03a_exportLeanJPG() {
	# loop over all base files
	for f in ${1}/${filesToProcess}
	do	
		# get the list of files to work with
		getBaseName $f
		getFileName $bname
		getExtName $bname
		
		exportLeanJPG $f 80
		# exportLeanJPG $f 85
		# exportLeanJPG $f 90

		logTimes
	done
}

step10_CopyFolder() {
	# loop over all base files
	for f in ${1}/${filesToProcess}
	do	
		# get the list of files to work with
		getBaseName $f
		getFileName $bname
		getExtName $bname
		
		copyImage $f ${2}

		logTimes
	done
}

main() {
	step00_Resize
	#step01a_Denoise ${d_resized} #not needed. this resize does it all
	step02_AutoLevelImg
	step02a_NormalizeImage
	step02b_ContrastStretchImage
	
	
	
	step10_CopyFolder ${d_resized} ${d_colorCorrected}

	step03a_exportLeanJPG ${d_colorCorrected}
}

main
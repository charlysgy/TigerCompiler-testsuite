#!/bin/sh

print_usage() {
	printf "Unrecognized option $arg\n"
	printf "usage: ./testsuite.sh [options]\n"
	printf "options:\n\t%-15s%s\n" "-out" "Save the output of the testsuite in the file out.tmp"
	printf "\t%-15s%s\n" "-err" "Save the error output of the testsuite in the file err.tmp"
	printf "\t%-15s%s\n" "-dir=<directory>" "Choose the directory to test (can't be set with -file)"
	printf "\t%-15s%s\n" "-file=<file>" "Choose the file to test (can't be set with -dir)"
	printf "\t%-15s%s\n\n\n" "--help" "Print this helper"
	exit 1
}

# Arguments are: 1 - path to file to test, 2 - exepcted return code
run_test() {

    FILE="$1"
    EXPECTED="$2"

    start_time=$(date +%s%N)

    # Redirecting errors to a temp file so they don't interfere when comparing outputs
    "$EXEC_PATH" --parse "$FILE" >> out.tmp 2>> err.tmp
    RETURN_CODE=$?

    end_time=$(date +%s%N)
    elapsed_time=$(( (end_time - start_time) / 1000000 ))

    if [ "$RETURN_CODE" -eq "$EXPECTED" ]; then
        printf "%-50s %-20s $GREEN%s$DEFAULT\n" "$FILE" " => $EXPECTED" " PASSED";
        PASSED=$((PASSED + 1))
    else
        printf "%-50s %-20s $RED%s$DEFAULT\n" "$FILE" " => $RETURN_CODE but expected: $EXPECTED" "FAILED";
        FAILED=$((FAILED + 1))
    fi
}


run_test_tc2() {
    FILE="$1"
    EXPECTED="$2"

    start_time=$(date +%s%N)

    # Test if the program works well for the first iteration
    "$EXEC_PATH" -A "$FILE" > "$FILE_out1.tmp" 2>> err.tmp
    RETURN_CODE_1="$?"

    # Retest the program by giving the output of the first execution as the input
    # of the second
    "$EXEC_PATH" -A "$FILE" | "$EXEC_PATH" -A - > "%FILE_out2.tmp" 2>> err.tmp
    RETURN_CODE_2="$?"

    end_time=$(date +%s%N)
    elapsed_time=$(( (end_time - start_time) / 1000000 ))

    if [ diff -q "$FILE_out1.tmp" "$FILE_out2.tmp" >> err.tmp && [ $RETURN_CODE_1 -eq $RETURN_CODE_2 ]]
    then
        rm "$FILE_out1.tmp"
        rm "$FILE_out2.tmp"
        if [ $TIME ]
        then
            printf "%-50s %-20s $GREEN%s$DEFAULT %s\n" "${1}" " => ${2}" " PASSED TC2" " in ${elapsed_time}s";
        else
            printf "%-50s %-20s $GREEN%s$DEFAULT\n" "${1}" " => ${2}" " PASSED TC2";
            PASSED=$((PASSED + 1))
        fi
    else
        printf "%-50s %-20s $RED%s$DEFAULT\n" "${1}" " => ${RETURN_CODE_1} but expected: ${2}" "FAILED TC2";
        FAILED=$((FAILED + 1))

    fi
}

# Reset de terminal to have the best view of tests
clear

########### INITIALIZE ALL VARIABLES FROM GIVEN ARGUMENTS #####################

SAVEOUTPUT=false
SAVEERROR=false

DIRECTORY=false
dir=""

FILE=false
file=""

TIME=false

for arg in $@
do
	if [ "$arg" = "-out" ]
		then
			SAVEOUTPUT=true;
			continue
	fi
	if [ "$arg" = "-time" ]
		then
			TIME=true;
			continue
	fi
	if [ "$arg" = "-err" ]
		then
			SAVEERROR=true;
			continue
	fi
	if [ "$(echo $arg | cut -d '=' -f 1)" = "-dir" ]
		then
			if [ $FILE = true ]
				then print_usage
			fi
			DIRECTORY=true;
			dir=$(echo $arg | cut -d '=' -f 2);
			continue
	fi
	if [ "$(echo $arg | cut -d '=' -f 1)" = "-file" ]
		then
			if [ $DIRECTORY = true ]
				then print_usage
			fi
			FILE=true
			file=$(echo $arg | cut -d '=' -f 2)
			continue
	fi
	print_usage
done

###################### USEFUL VARIABLES FOR THE PROGRAM #######################

PASSED=0
FAILED=0

RED="\e[31m"
GREEN="\e[32m"
YELLOW="\e[33m"
CYAN="\033[1;36m"
DEFAULT="\033[0m"
BOLD="\033[1;97m"

EXEC_PATH="../src/tc"

######################### BEGINNNING OF THE TESTSUITE ##########################

printf "${BOLD}BEGINNING OF THE TESTSUITE${DEFAULT}\n\n\n"

# If the DIRECTORY var has been set to true, only one directory is tested
if [ $DIRECTORY = true ]
then
	if [ $dir = "./pretty_print" ]
		then
        for file in $(find $dir -name "tests.txt")
        do
            while IFS= read -r LINE
            do
                TEST=$(echo "$LINE" | cut -d '#' -f 1);
                EXP=$(echo "$LINE" | cut -d '#' -f 2);
                run_test_tc2 "$dir/$TEST" $EXP;
            done < "$file"
        done
        continue
	else
        while IFS= read -r LINE
       	do
        	TEST="$(echo "$LINE" | cut -d '#' -f 1)";
		    EXP=$(echo "$LINE" | cut -d '#' -f 2);
    		run_test "$dir/$TEST" $EXP;
    	done < "$dir/tests.txt"
    fi
# If the FILE variable has been set to true, only file is tested
elif [ $FILE = true ]
	then
		run_test "$file" 0

# Else, all file from all directory are tested
else
	for dir in $(find . -type d)
	do
		if [ $dir = "." ]
			then continue
		fi
		if [ $dir = "./pretty_print" ]
			then
            for file in $(find $dir -name "tests.txt")
            do
                while IFS= read -r LINE
                do
                    TEST=$(echo "$LINE" | cut -d '#' -f 1);
                    EXP=$(echo "$LINE" | cut -d '#' -f 2);
                    run_test_tc2 "$dir/$TEST" $EXP;
                done < "$file"
            done
            continue
		fi
		echo "================================================================================"
		for file in $(find $dir -name "tests.txt")
		do
			while IFS= read -r LINE
			do
				TEST=$(echo "$LINE" | cut -d '#' -f 1);
				EXP=$(echo "$LINE" | cut -d '#' -f 2);
				run_test "$dir/$TEST" $EXP;
			done < "$file"
		done
	done
	echo "================================================================================"
fi

#################### STATS MOMENT FOR NERDS ####################################

NB_TESTS=$((PASSED + FAILED))
PERCENTAGE=$(( 100 * PASSED / NB_TESTS ))
# Display test summary
printf "\n\nTest Summary: $GREEN Passed $PASSED tests $DEFAULT, $RED Failed $FAILED tests$DEFAULT\n"
printf "Recap: ${GREEN}${PERCENTAGE}%%$DEFAULT of success\n\n"

if [ ${SAVEERROR} = false ]
	then rm -f err.tmp
fi

if [ ${SAVEOUTPUT} = false ]
	then rm -r out.tmp
fi

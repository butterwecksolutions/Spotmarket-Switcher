#!/bin/bash

VERSION="2.4.18-DEV"

set -e

if [ -z "$LANG" ]; then
    export LANG="C"
fi

# Note: This script is only for hourly-based tariff data, please create your own fork for higher resolutions like 15 minute intervals.

#######################################
###    Begin of the functions...    ###
#######################################

if [[ ${BASH_VERSINFO[0]} -le 4 ]]; then
    valid_config_version=9 # Please increase this value by 1 when changing the configuration variables
else
    declare -A valid_vars=(
    	["config_version"]="9" # Please increase this value by 1 if variables are added or deleted in the valid_vars array
        ["use_fritz_dect_sockets"]="0|1"
        ["fbox"]="^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"
        ["user"]="string"
        ["passwd"]="string"
        ["sockets"]='^\(\"[^"]+\"( \"[^"]+\")*\)$'
        ["use_shelly_wlan_sockets"]="0|1"
        ["shelly_ips"]="^\(\".*\"\)$"
        ["shellyuser"]="string"
        ["shellypasswd"]="string"
        ["use_charger"]="0|1|2|3|4"
        ["limit_inverter_power_after_enabling"]="^(-1|[0-9]{2,5})$"
        ["energy_loss_percent"]="[0-9]+(\.[0-9]+)?"
        ["battery_lifecycle_costs_cent_per_kwh"]="[0-9]+(\.[0-9]+)?"
        ["economic_check"]="0|1|2"
        ["start_price"]="-?[0-9]+(\.[0-9]+)?"
        ["feedin_price"]="[0-9]+(\.[0-9]+)?"
        ["energy_fee"]="[0-9]+(\.[0-9]+)?"
        ["abort_price"]="[0-9]+(\.[0-9]+)?"
        ["use_start_stop_logic"]="0|1"
        ["switchablesockets_at_start_stop"]="0|1"
        ["charge_at_solar_breakeven_logic"]="0|1"
        ["switchablesockets_at_solar_breakeven_logic"]="0|1"
        ["TZ"]="string"
        ["select_pricing_api"]="1|2|3"
        ["include_second_day"]="0|1"
        ["use_solarweather_api_to_abort"]="0|1"
        ["abort_solar_yield_today"]="[0-9]+(\.[0-9]+)?"
        ["abort_solar_yield_tomorrow"]="[0-9]+(\.[0-9]+)?"
        ["abort_suntime"]="[0-9]+"
        ["latitude"]="[-]?[0-9]+(\.[0-9]+)?"
        ["longitude"]="[-]?[0-9]+(\.[0-9]+)?"
        ["visualcrossing_api_key"]="string"
        ["awattar"]="de|at"
        ["in_Domain"]="string"
        ["out_Domain"]="string"
        ["entsoe_eu_api_security_token"]="string"
        ["price_unit"]="energy|total|tax"
        ["tibber_api_key"]="string"
        ["venus_os_mqtt_ip"]="^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$"
        ["venus_os_mqtt_port"]="^[0-9]*$"
        ["mqtt_broker_host_publish"]="string"
        ["mqtt_broker_host_subscribe"]="string"
        ["mqtt_broker_port_publish"]="^[0-9]*$"
        ["mqtt_broker_port_subscribe"]="^[0-9]*$"
        ["mqtt_broker_topic_publish"]="string"
        ["mqtt_broker_topic_subscribe"]="string"
        ["reenable_inverting_at_fullbatt"]="0|1"
        ["reenable_inverting_at_soc"]="^([1-9][0-9]?|100)$"
        ["sonnen_API_KEY"]="string"
        ["sonnen_API_URL"]="string"
        ["sonnen_minimum_SoC"]="^([0-9][0-9]?|100)$"
		)

    declare -A config_values
fi

parse_and_validate_config() {
    if [[ ${BASH_VERSINFO[0]} -le 4 ]]; then
        # Für Bash-Version <= 4, überprüfe nur config_version=1
	log_message >&2 "W: Due to the older Bash version, the configuration validation is skipped."
        local file="$1"
        local version_valid=false
        while IFS='=' read -r key value; do
            key=$(echo "$key" | cut -d'#' -f1 | tr -d ' ')
            value=$(echo "$value" | awk -F'#' '{gsub(/^ *"|"$|^ *| *$/, "", $1); print $1}')
            if [[ "$key" == "config_version" && "$value" == "$valid_config_version" ]]; then
                version_valid=true
                break
            fi
        done <"$file"
        
        if [[ "$version_valid" == false ]]; then
            log_message >&2 "E: Error: config_version=$valid_config_version is missing or the configuration is invalid."
            return 1
        fi
        return 0
    else    
        local file="$1"
        local errors=""
        rotating_spinner &   # Start the spinner in the background
        local spinner_pid=$! # Get the PID of the spinner
        local version_valid=false
        local version_value=0

        # Step 1: Parse
        while IFS='=' read -r key value; do
            # Treat everything after a "#" as a comment and remove it
            key=$(echo "$key" | cut -d'#' -f1 | tr -d ' ')
            value=$(echo "$value" | awk -F'#' '{gsub(/^ *"|"$|^ *| *$/, "", $1); print $1}')

            # Only process rows with key-value pairs
            [[ "$key" == "" || "$value" == "" ]] && continue

            # Set the value in the associative array
            config_values["$key"]="$value"
	
            if [[ "$key" == "config_version" ]]; then
                version_valid=true
                version_value="$value"
	        fi
        done <"$file"

        # Step 2: Validation
        for var_name in "${!valid_vars[@]}"; do
            local validation_pattern=${valid_vars[$var_name]}

            # Check whether the variable was set at all
            if [[ -z ${config_values[$var_name]+x} ]]; then
                errors+="E: $var_name is not set.\n"
                continue
            fi

            if [[ "$validation_pattern" == "string" ]]; then
                continue
            elif [[ "$validation_pattern" == "array" && "${config_values[$var_name]}" == "" ]]; then
                continue
            elif [[ "$validation_pattern" == "ip" && ! "${config_values[$var_name]}" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                errors+="E: $var_name has an invalid IP address format: ${config_values[$var_name]}.\n"
                continue
            fi

            if ! [[ "${config_values[$var_name]}" =~ ^($validation_pattern)$ ]]; then
                errors+="E: $var_name has an invalid value: ${config_values[$var_name]}.\n"
            fi
        done

        if [[ "$version_valid" == true && "$version_value" -lt 1 ]]; then
            errors+="W: The config.txt version is less than 1. You are using an outdated unsupported configuration file. Please re-download and reconfigurate. \n"
        fi

        kill $spinner_pid &>/dev/null

        if [[ -n "$errors" ]]; then
            echo -e "$errors"
            return 1
        else
            echo "Config validation passed."
			
            return 0
        fi
    fi
}

rotating_spinner() {
    local delay=0.1
    local spinstr="|/-\\"
    while true; do
        local temp=${spinstr#?}
        printf " [%c]  Loading..." "$spinstr"
        spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\r"
    done
}

download_awattar_prices() {
    local url="$1"
    local file="$2"
    local output_file="$3"
    local sleep_time="$4"

    if [ -z "$DEBUG" ]; then
        log_message >&2 "I: Please be patient. First we wait $sleep_time seconds in case the system clock is not syncronized and not to overload the API." false
        sleep "$sleep_time"
    fi
    if ! curl "$url" >"$file"; then
        log_message >&2 "E: Download of aWATTar prices from '$url' to '$file' failed."
		rm "$file"
        exit_with_cleanup 1
    fi

    if ! test -f "$file"; then
        log_message >&2 "E: Could not get aWATTar prices from '$url' to feed file '$file'."
        exit_with_cleanup 1
    fi

    if [ -n "$DEBUG" ]; then
        log_message "D: Download of file '$file' from URL '$url' successful."
    fi
    echo >>"$file"
	
if [ "$price_unit" = "energy" ]; then
    awk '/data_price_hour_rel_.*_amount: / {print substr($0, index($0, ":") + 2)}' "$file" > "$output_file"
elif [ "$price_unit" = "total" ]; then
    awk -v vat_rate="$vat_rate" -v energy_fee="$energy_fee" '/data_price_hour_rel_.*_amount: / {
        amount = substr($0, index($0, ":") + 2)
        total = amount * (1 + vat_rate) + energy_fee
        print total
    }' "$file" > "$output_file"
elif [ "$price_unit" = "tax" ]; then
    awk -v vat_rate="$vat_rate" -v energy_fee="$energy_fee" '/data_price_hour_rel_.*_amount: / {
        amount = substr($0, index($0, ":") + 2)
        tax = (amount * vat_rate) + energy_fee
        print tax
    }' "$file" > "$output_file"
else
    log_message >&2 "E: Invalid value at awattar_prices. Check config.txt"
fi

    sort -g "$output_file" >"${output_file%.*}_sorted.${output_file##*.}"
    timestamp=$(TZ=$TZ date +%d)
    echo "date_now_day: $timestamp" >>"$output_file"
    echo "date_now_day: $timestamp" >>"${output_file%.*}_sorted.${output_file##*.}"

    if [ -f "$file2" ] && [ "$(wc -l <"$file1")" = "$(wc -l <"$file2")" ]; then
        rm -f "$file2"
        log_message >&2 "I: File '$file2' has no tomorrow data, we have to try it again until the new prices are online." false
    fi
}

get_tibber_api() {
    curl --location --request POST $link6 \
        --header 'Content-Type: application/json' \
        --header "Authorization: Bearer $tibber_api_key" \
        --data-raw '{"query":"{viewer{homes{currentSubscription{priceInfo{current{total energy tax startsAt}today{total energy tax startsAt}tomorrow{total energy tax startsAt}}}}}}"}' |
        awk '{
        gsub(/"current":/, "\n&");
        gsub(/"today":/, "\n&");
        gsub(/"tomorrow":/, "\n&");
        gsub(/"total":/, "\n&");
        print
    }'
}

download_tibber_prices() {
    local url="$1"
    local file="$2"
    local sleep_time="$3"

    if [ -z "$DEBUG" ]; then
        log_message >&2 "I: Please be patient. First we wait $sleep_time seconds in case the system clock is not syncronized and not to overload the API." false
        sleep "$sleep_time"
    else
        log_message "D: No delay of download of Tibber data since DEBUG variable set."
    fi
    if ! get_tibber_api | tr -d '{}[]' >"$file"; then
        log_message >&2 "E: Download of Tibber prices from '$url' to '$file' failed."
        exit_with_cleanup 1
    fi

    sed -n '/"today":/,/"tomorrow":/p' "$file" | sed '$d' | sed '/"today":/d' >"$file15"
    sort -t, -k1.9n $file15 >"$file16"
    sed -n '/"tomorrow":/,$p' "$file" | sed '/"tomorrow":/d' >"$file17"
    sort -t, -k1.9n $file17 >"$file18"
    if [ "$include_second_day" = 0 ]; then
        cp "$file16" "$file12"
    else
    sed -n '4,$p' "$file14" | grep '"total"' | sort -t':' -k2 -n > "$file12"
    fi

    timestamp=$(TZ=$TZ date +%d)
    echo "date_now_day: $timestamp" >>"$file15"
    echo "date_now_day: $timestamp" >>"$file17"

    if [ ! -s "$file16" ]; then
        log_message >&2 "E: Tibber prices cannot be extracted to '$file16', please check your internet connection and Tibber API Key. Waiting 120 seconds and fallback to aWATTar API."
        use_tibber=0
		rm "$file"
		sleep 120
		select_pricing_api="1"
		use_awattar_api
		use_awattar_tomorrow_api
		if [ -f "$file2" ] && [ "$(wc -l <"$file2")" -gt 10 ]; then
        loop_hours=48
		fi
	fi
}

download_entsoe_prices() {
    local url="$1"
    local file="$2"
    local output_file="$3"
    local sleep_time="$4"

    if [ -z "$DEBUG" ]; then
        log_message >&2 "I: Please be patient. First we wait $sleep_time seconds in case the system clock is not syncronized and not to overload the API."
        sleep "$sleep_time"
    else
        log_message "D: No delay of download of entsoe data since DEBUG variable set."
    fi

    if ! curl "$url" >"$file"; then
        log_message >&2 "E: Retrieval of entsoe data from '$url' into file '$file' failed."
        exit_with_cleanup 1
    fi

    if ! test -f "$file"; then
        log_message >&2 "E: Could not find file '$file' with entsoe price data. Curl itself reported success."
        exit_with_cleanup 1
    fi

    if [ -n "$DEBUG" ]; then log_message "D: Entsoe file '$file' with price data downloaded"; fi

    if [ ! -s "$file" ]; then
        log_message >&2 "E: Entsoe file '$file' is empty, please check your entsoe API Key."
        exit_with_cleanup 1
    fi

    if [ -n "$DEBUG" ]; then log_message "D: No delay of download of entsoe data since DEBUG variable set." "D: Entsoe file '$file' with price data downloaded"; fi

awk '
BEGIN {
    capture_period = 0
    valid_period = 0
    in_reason = 0
    prices = ""
    error_code = ""
    error_message = ""
    last_price = ""
    current_position = 1
    max_positions = 24
    for (i = 1; i <= max_positions; i++) {
        positions[i] = ""
    }
}

/<Period>/ {
    capture_period = 1
}

/<\/Period>/ {
    capture_period = 0
    valid_period = 0
}

capture_period && /<resolution>PT60M<\/resolution>/ {
    valid_period = 1
}

valid_period && /<position>/ {
    gsub("<position>", "", $0)
    gsub("</position>", "", $0)
    gsub(/^[\t ]+|[\t ]+$/, "", $0)
    current_position = $0
}

valid_period && /<price.amount>/ {
    gsub("<price.amount>", "", $0)
    gsub("</price.amount>", "", $0)
    gsub(/^[\t ]+|[\t ]+$/, "", $0)
    last_price = $0
    positions[current_position] = last_price
}

/<Reason>/ {
    in_reason = 1
    error_message = ""
}

in_reason && /<code>/ {
    gsub(/<code>|<\/code>/, "")
    gsub(/^[\t ]+|[\t ]+$/, "", $0)
    error_code = $0
}

in_reason && /<text>/ {
    gsub(/<text>|<\/text>/, "")
    gsub(/^[\t ]+|[\t ]+$/, "", $0)
    error_message = $0
}

/<\/Reason>/ {
    in_reason = 0
}

END {
    for (i = 1; i <= max_positions; i++) {
        if (positions[i] == "") {
            positions[i] = (i == 1 ? last_price : positions[i-1])
        }
        if (positions[i] != "") {
            prices = prices positions[i] ORS
        }
    }

    if (error_code == 999) {
        print "E: Entsoe data retrieval error found in the XML data:", error_message
    } else if (prices != "") {
        printf "%s", prices > "'"$output_file"'"
    } else {
        print "E: No prices found in the XML data."
    }
}
' "$file"

if [ -f "$output_file" ]; then
    sort -g "$output_file" > "${output_file%.*}_sorted.${output_file##*.}"
    line_count=$(grep -v "^date_now_day" "$file11" | wc -l)
    if [ "$line_count" -lt 24 ]; then
        log_message >&2 "E:  Warning. $file11 has only price data for $line_count hours. Maybe API error. Please check XML data if hours are missing."
        log_message >&2 "E: Fallback to aWATTar API."
        select_pricing_api="1"
        use_awattar_api
    fi
    timestamp=$(TZ=$TZ date +%d)
    echo "date_now_day: $timestamp" >> "$output_file"

    # Check if the file for tomorrow contains prices for the next day
    if [ "$include_second_day" = 1 ] && grep -q "PT60M" "$file" && [ "$(wc -l <"$output_file")" -gt 3 ]; then
        cat $file10 > $file8
        if [ -f "$file13" ]; then
            cat "$file13" >> "$file8"
        fi
        sed -i '25d;50d' "$file8"
        sort -g "$file8" > "$file19"
        timestamp=$(TZ=$TZ date +%d)
        echo "date_now_day: $timestamp" >> "$file8"

        if [ -f "$file9" ]; then
            line_count2=$(grep -v "^date_now_day" "$file9" | wc -l) # ignores day marker
            if [ "$line_count2" -lt 24 ]; then
                log_message >&2 "E:  Warning. $file9 has only price data for $line_count2 hours. Maybe API error. Please check XML data if hours are missing."
            fi
        fi
    else
        cp $file11 $file19  # If there's no second day, copy the sorted price file.
    fi
fi



}

download_solarenergy() {
    if ((use_solarweather_api_to_abort == 1)); then
        delay=$((RANDOM % 15 + 1))
        if [ -z "$DEBUG" ]; then
            log_message >&2 "I: Please be patient. A delay of $delay seconds will help avoid overloading the Solarweather-API." false
            sleep "$delay"
        else
            log_message "D: No delay of download of solarenergy data since DEBUG variable set."
        fi

        if ! curl "$link3" -o "$file3"; then
            log_message >&2 "E: Download of solarenergy data from '$link3' failed. Old data will be used if downloaded already."
        elif ! test -f "$file3"; then
            log_message >&2 "E: Could not get solarenergy data, missing file '$file3'. Solarenergy will be ignored."
        fi

		if [ -f "$file3" ]; then
			if grep -q "API" "$file3"; then
			log_message >&2 "E: Error, there is a problem with the Solarweather-API."
			cat "$file3"
			echo
			rm "$file3"
		fi
	fi


        if [ -n "$DEBUG" ]; then
            log_message "D: File3 $file3 downloaded"
        fi
        if ! test -f "$file3"; then
            log_message >&2 "E: Could not find downloaded file '$file3' with solarenergy data. Solarenergy will be ignored."
        fi
        if [ -n "$DEBUG" ]; then
            log_message "D: Solarenergy data downloaded to file '$file3'."
        fi
    fi
}

get_current_awattar_day() { current_awattar_day=$(sed -n 3p $file1 | grep -Eo '[0-9]+'); }
get_current_awattar_day2() { current_awattar_day2=$(sed -n 3p $file2 | grep -Eo '[0-9]+'); }

use_awattar_api() {
    # Test if Awattar today data exists
    if test -f "$file1"; then
        # Test if data is current
        get_current_awattar_day
        if [ "$current_awattar_day" = "$(TZ=$TZ date +%-d)" ]; then
            log_message >&2 "I: aWATTar today-data is up to date." false
        else
            log_message >&2 "I: aWATTar today-data is outdated, fetching new data." false
            rm -f $file1 $file6 $file7
            download_awattar_prices "$link1" "$file1" "$file6" $((RANDOM % 21 + 10))
        fi
    else # Data file1 does not exist
        log_message >&2 "I: Fetching today-data data from aWATTar." false
        download_awattar_prices "$link1" "$file1" "$file6" $((RANDOM % 21 + 10))
    fi
	}
	
use_awattar_tomorrow_api() {
        # Test if Awattar tomorrow data exists
        if test -f "$file2"; then
            # Test if data is current
            get_current_awattar_day2
            if [ "$current_awattar_day2" = "$(TZ=$TZ date +%-d)" ]; then
                log_message >&2 "I: aWATTar tomorrow-data is up to date." false
            else
                log_message >&2 "I: aWATTar tomorrow-data is outdated, fetching new data." false
                rm -f $file3
                download_awattar_prices "$link2" "$file2" "$file6" $((RANDOM % 21 + 10))
            fi
        else # Data file2 does not exist
            log_message >&2 "I: aWATTar tomorrow-data does not exist, fetching data." false
            download_awattar_prices "$link2" "$file2" "$file6" $((RANDOM % 21 + 10))
        fi
		}
	

get_awattar_prices() {
    current_price=$(sed -n "$((now_linenumber))p" "$file6")
    for i in $(seq 1 $loop_hours); do
        eval "P$i=$(sed -n "${i}p" "$file7")"
    done
    highest_price=$(grep -E '^[0-9]+\.[0-9]+$' "$file7" | tail -n1)
    average_price=$(grep -E '^[0-9]+\.[0-9]+$' "$file7" | awk '{sum+=$1; count++} END {if (count > 0) print sum/count}')
}

use_tibber_api() {
    # Test if Tibber today data exists
    if test -f "$file14"; then
        # Test if data is current
        get_current_tibber_day
        if [ "$current_tibber_day" = "$(TZ=$TZ date +%d)" ]; then
            log_message >&2 "I: Tibber today-data is up to date." false
        else
            log_message >&2 "I: Tibber today-data is outdated, fetching new data." false
            rm -f "$file12" "$file14" "$file15" "$file16"
            download_tibber_prices "$link6" "$file14" $((RANDOM % 21 + 10))
        fi
    else # Tibber data does not exist
        log_message >&2 "I: Fetching today-data data from Tibber." false
        download_tibber_prices "$link6" "$file14" $((RANDOM % 21 + 10))
    fi
	}
	
use_tibber_tomorrow_api() {
        if [ ! -s "$file18" ]; then
            rm -f "$file17" "$file18"
            log_message >&2 "I: File '$file18' has no tomorrow data, we have to try it again until the new prices are online." false
            rm -f "$file12" "$file14" "$file15" "$file16" "$file17" "$file18"
            download_tibber_prices "$link6" "$file14" $((RANDOM % 21 + 10))
            sort -t, -k1.9n $file17 >>"$file12"
        fi
	}

get_tibber_prices() {
    current_price=$(sed -n "${now_linenumber}s/.*\"${price_unit}\":\([^,]*\),.*/\1/p" "$file15")
    for i in $(seq 1 $loop_hours); do
        eval "P$i=$(sed -n "${i}s/.*\"${price_unit}\":\([^,]*\),.*/\1/p" "$file12")"
    done
    highest_price=$(sed -n "s/.*\"${price_unit}\":\([^,]*\),.*/\1/p" "$file12" | awk 'BEGIN {max = 0} {if ($1 > max) max = $1} END {print max}')
    average_price=$(sed -n "s/.*\"${price_unit}\":\([^,]*\),.*/\1/p" "$file12" | awk '{sum += $1} END {print sum/NR}')
}

get_current_entsoe_day() { current_entsoe_day=$(sed -n 25p "$file10" | grep -Eo '[0-9]+'); }

get_current_tibber_day() { current_tibber_day=$(sed -n 25p "$file15" | grep -Eo '[0-9]+'); }

use_entsoe_api() {
    # Test if Entsoe today data exists
    if test -f "$file10"; then
        # Test if data is current
        get_current_entsoe_day
        if [ "$current_entsoe_day" = "$(TZ=$TZ date +%d)" ]; then
            log_message >&2 "I: Entsoe today-data is up to date." false
        else
            log_message >&2 "I: Entsoe today-data is outdated, fetching new data." false
            rm -f "$file4" "$file5" "$file8" "$file9" "$file10" "$file11" "$file13" "$file19"
            download_entsoe_prices "$link4" "$file4" "$file10" $((RANDOM % 21 + 10))
        fi
    else # Entsoe data does not exist
        log_message >&2 "I: Fetching today-data data from Entsoe." false
        download_entsoe_prices "$link4" "$file4" "$file10" $((RANDOM % 21 + 10))
    fi
	}
	
use_entsoe_tomorrow_api() {
        # Test if Entsoe tomorrow data exists
        if [ ! -s "$file9" ]; then
            log_message >&2 "I: File '$file9' has no tomorrow data, we have to try it again until the new prices are online." false
            rm -f "$file5" "$file9" "$file13"
            download_entsoe_prices "$link5" "$file5" "$file13" $((RANDOM % 21 + 10))
        fi
		}

get_entsoe_prices() {
    current_price=$(sed -n "${now_linenumber}p" "$file10")
    
    for i in $(seq 1 $loop_hours); do
        eval P$i=$(tail -n +1 "$file19" | sed -n "${i}p")
    done

    highest_price=$(tail -n +1 "$file19" | awk 'BEGIN {max = 0} $1 > max {max = $1} END {print max}')
    average_price=$(tail -n +1 "$file19" | awk 'NF > 0 && $1 ~ /^[0-9]*(\.[0-9]*)?$/ {sum += $1; count++} END {if (count > 0) print sum / count}')
}


convert_vars_to_integer() {
    local potency="$1"
    shift
    for var in "$@"; do
        local integer_var="${var}_integer"
        printf -v "$integer_var" '%s' "$(euroToMillicent "${!var}" "$potency")"
        local value="${!integer_var}" # Speichern Sie den Wert in einer temporären Variable
        if [ -n "$DEBUG" ]; then
            log_message "D: Variable: $var | Original: ${!var} | Integer: $value | Len: ${#value}"
        fi
    done
}

get_awattar_prices_integer() {
    local price_vars=""
    for i in $(seq 1 $loop_hours); do
        price_vars+="P$i "
    done
    price_vars+="average_price highest_price current_price start_price feedin_price energy_fee abort_price battery_lifecycle_costs_cent_per_kwh"
    convert_vars_to_integer 15 $price_vars
}

get_tibber_prices_integer() {
    local price_vars=""
    for i in $(seq 1 $loop_hours); do
        price_vars+="P$i "
    done
    price_vars+="average_price highest_price current_price"
    convert_vars_to_integer 17 $price_vars

    convert_vars_to_integer 15 start_price feedin_price energy_fee abort_price battery_lifecycle_costs_cent_per_kwh
}

get_prices_integer_entsoe() {
    local price_vars=""
    for i in $(seq 1 $loop_hours); do
        price_vars+="P$i "
    done
    price_vars+="average_price highest_price current_price"
    convert_vars_to_integer 14 $price_vars

    convert_vars_to_integer 15 start_price feedin_price energy_fee abort_price battery_lifecycle_costs_cent_per_kwh
}

get_temp_today() {
    if [ ! -s "$file3" ]; then return; fi
    temp_today=$(sed '2!d' "$file3" | cut -d',' -f1)
}

get_temp_tomorrow() {
    if [ ! -s "$file3" ]; then return; fi
    temp_tomorrow=$(sed '3!d' "$file3" | cut -d',' -f1)
}

get_snow_today() {
    if [ ! -s "$file3" ]; then return; fi
    snow_today=$(sed '2!d' "$file3" | cut -d',' -f2)
}

get_snow_tomorrow() {
    if [ ! -s "$file3" ]; then return; fi
    snow_tomorrow=$(sed '3!d' "$file3" | cut -d',' -f2)
}

get_solarenergy_today() {
    if [ ! -s "$file3" ]; then return; fi
    solarenergy_today=$(sed '2!d' "$file3" | cut -d',' -f4)
    solarenergy_today_integer=$(euroToMillicent "${solarenergy_today}" 15)
    abort_solar_yield_today_integer=$(euroToMillicent "${abort_solar_yield_today}" 15)
}

get_solarenergy_tomorrow() {
    if [ ! -s "$file3" ]; then return; fi
    solarenergy_tomorrow=$(sed '3!d' "$file3" | cut -d',' -f4)
    solarenergy_tomorrow_integer=$(euroToMillicent "$solarenergy_tomorrow" 15)
    abort_solar_yield_tomorrow_integer=$(euroToMillicent "${abort_solar_yield_tomorrow}" 15)
}

get_cloudcover_today() {
    if [ ! -s "$file3" ]; then return; fi
    cloudcover_today=$(sed '2!d' "$file3" | cut -d',' -f4)
}

get_cloudcover_tomorrow() {
    if [ ! -s "$file3" ]; then return; fi
    cloudcover_tomorrow=$(sed '3!d' "$file3" | cut -d',' -f4)
}

get_sunrise_today() {
    if [ ! -s "$file3" ]; then return; fi
    sunrise_today=$(sed '2!d' "$file3" | cut -d',' -f5 | cut -d 'T' -f2 | awk -F: '{ print $1 ":" $2 }')
}

get_sunset_today() {
    if [ ! -s "$file3" ]; then return; fi
    sunset_today=$(sed '2!d' "$file3" | cut -d',' -f6 | cut -d 'T' -f2 | awk -F: '{ print $1 ":" $2 }')
}

get_suntime_today() {
    if [ ! -s "$file3" ]; then return; fi
    get_sunrise_today
    get_sunset_today
    suntime_today=$((($(TZ=$TZ date -d "1970-01-01 $sunset_today" +%s) - $(TZ=$TZ date -d "1970-01-01 $sunrise_today" +%s)) / 60))
}

# Function to evaluate conditions
evaluate_conditions() {
    local -n conditions=$1
    local -n descriptions=$2
    local -n execute_flag=$3
    local -n condition_met_description=$4

    for i in "${!conditions[@]}"; do
        if (( ${conditions[$i]} )); then
            execute_flag=1
            condition_met_description="${descriptions[$i]}"

            if [[ $DEBUG -eq 1 ]]; then
                log_message "D: Condition met: ${condition_met_description}"
            fi

            # Exit the loop if a condition is met
            return
        fi
    done

    # If no condition is met
    execute_flag=0
    condition_met_description=""
}

# Function to check economical
is_charging_economical() {
    local reference_price="$1"
    local total_cost="$2"

    local is_economical=1
    [[ $reference_price -ge $total_cost ]] && is_economical=0

    if [ -n "$DEBUG" ]; then
        log_message "D: is_charging_economical [ $is_economical - $([ "$is_economical" -eq 1 ] && echo "false" || echo "true") ]."
        reference_price_euro=$(millicentToEuro $reference_price)
        total_cost_euro=$(millicentToEuro "$total_cost")
        is_economical_str=$([ "$is_economical" -eq 1 ] && echo "false" || echo "true")
        log_message "D: if [ reference_price $reference_price_euro > total_cost $total_cost_euro ] result is $is_economical_str."
    fi

    return $is_economical
}

# Function to calculate dynamic SOC based on the expected solarenergy
get_target_soc() {
    local megajoule=$1
    local result=""
    
    IFS=' ' read -ra first_line <<< "${config_matrix_target_soc_weather[0]}"
    if awk -v megajoule="$megajoule" -v lower="${first_line[0]}" 'BEGIN {exit !(megajoule < lower)}'; then
        echo "${first_line[1]}"
        return
    fi

    for ((i = 0; i < ${#config_matrix_target_soc_weather[@]} - 1; i++)); do
        IFS=' ' read -ra line <<< "${config_matrix_target_soc_weather[$i]}"
        next_line="${config_matrix_target_soc_weather[$((i + 1))]}"
        IFS=' ' read -ra next_line <<< "$next_line"
        
        if awk -v megajoule="$megajoule" -v lower="${line[0]}" -v upper="${next_line[0]}" \
            'BEGIN {exit !(megajoule >= lower && megajoule < upper)}'; then
            result=$(awk -v megajoule="$megajoule" -v lower="${line[0]}" \
                -v upper="${next_line[0]}" -v lower_soc="${line[1]}" -v upper_soc="${next_line[1]}" \
                'BEGIN {printf "%.0f", lower_soc + (megajoule - lower) * (upper_soc - lower_soc) / (upper - lower)}')
            echo "$result"
            return
        fi
    done

    IFS=' ' read -ra last_line <<< "${config_matrix_target_soc_weather[-1]}"
    if awk -v megajoule="$megajoule" -v upper="${last_line[0]}" 'BEGIN {exit !(megajoule >= upper)}'; then
        echo "${last_line[1]}"
        return
    fi

    echo "No target SoC found."
}



# Function to manage charging
manage_charging() {
    local action=$1
    local reason=$2

    if [[ $action == "on" ]]; then
	
		log_message >&2 "I: Starting charging."
        charger_command_charge >/dev/null
		charging=1
        log_message >&2 "I: Charging is ON. $reason"
    else
		log_message >&2 "I: Stopping charging."
		charging=0
        charger_command_stop_charging >/dev/null
        log_message >&2 "I: Charging is OFF. $reason"
    fi
}

# Function to manage discharging
manage_discharging() {
    local action=$1
    local reason=$2

    if [[ $action == "on" ]]; then
		log_message >&2 "I: Enabling inverter."
        charger_enable_inverter >/dev/null
		inverting=1
        log_message >&2 "I: Discharging is ON. Battery SOC is at $SOC_percent%."
    else
		log_message "I: Disabling inverter."
        charger_disable_inverter >/dev/null
		inverting=0
        log_message >&2 "I: Discharging is OFF. Battery SOC is at $SOC_percent%."
    fi
}

# Function to manage fritz sockets and log a message
manage_fritz_sockets() {
    if [ -n "$DEBUG" ]; then
    log_message "D: Managing Fritz sockets - Action: $action, execute_switchablesockets_on: $execute_switchablesockets_on"
	fi
    local action=$1

    [ "$action" != "off" ] && action=$([ "$execute_switchablesockets_on" == "1" ] && echo "on" || echo "off")

    if fritz_login; then
        log_message >&2 "I: Turning $action Fritz sockets."
        for socket in "${sockets[@]}"; do
            [ "$socket" != "0" ] && manage_fritz_socket "$action" "$socket"
        done
    else
        log_message >&2 "E: Fritz login failed."
    fi
}

manage_fritz_socket() {
    local action=$1
    local socket=$2

if [ "$1" != "off" ] && [ "$economic" == "expensive" ] && { [ "$use_charger" != "0" ]; }; then
    log_message >&2 "I: Disabling inverter while switching."
    charger_disable_inverter >/dev/null
fi
    local url="http://$fbox/webservices/homeautoswitch.lua?sid=$sid&ain=$socket&switchcmd=setswitch$action"
    curl -s "$url" >/dev/null || log_message >&2 "E: Could not call URL '$url' to switch $action said switch - ignored."
}

fritz_login() {
    # Get session ID (SID)
    sid=""
    challenge=$(curl -s "http://$fbox/login_sid.lua" | grep -o "<Challenge>[a-z0-9]\{8\}" | cut -d'>' -f 2)
    if [ -z "$challenge" ]; then
        log_message >&2 "E: Could not retrieve challenge from login_sid.lua."
        return 1
    fi

    hash=$(echo -n "$challenge-$passwd" | sed -e 's,.,&\n,g' | tr '\n' '\0' | md5sum | grep -o "[0-9a-z]\{32\}")
    sid=$(curl -s "http://$fbox/login_sid.lua" -d "response=$challenge-$hash" -d "username=$user" |
        grep -o "<SID>[a-z0-9]\{16\}" | cut -d'>' -f 2)

    if [ "$sid" = "0000000000000000" ]; then
        log_message >&2 "E: Login to Fritz!Box failed."
        return 1
    fi

    if [ -n "$DEBUG" ]; then
        log_message "D: Login to Fritz!Box successful."
    fi
    return 0
}

# Function to manage shelly and log a message
manage_shelly_sockets() {
    local action=$1

    [ "$action" != "off" ] && action=$([ "$execute_switchablesockets_on" == "1" ] && echo "on" || echo "off")

    log_message >&2 "I: Turning $action Shelly sockets."
    for ip in "${shelly_ips[@]}"; do
        [ "$ip" != "0" ] && manage_shelly_socket "$action" "$ip"
    done
}

manage_shelly_socket() {
    local action=$1
    local ip=$2
	if [ "$1" != "off" ] && [ "$economic" == "expensive" ] && { [ "$use_charger" != "0" ]; }; then
        log_message >&2 "I: Disabling inverter while switching."
        charger_disable_inverter >/dev/null
    fi
    curl -s -u "$shellyuser:$shellypasswd" "http://$ip/relay/0?turn=$action" -o /dev/null || log_message >&2 "E: Could not execute switch-$action of Shelly socket with IP $ip - ignored."
}

millicentToEuro() {
    local millicents="$1"

    local EURO_FACTOR=100000000000000000
    local DECIMAL_FACTOR=10000000000000

    local euro_main_part=$((millicents / EURO_FACTOR))
    local euro_decimal_part=$(((millicents % EURO_FACTOR) / DECIMAL_FACTOR))

    printf "%d.%04d\n" $euro_main_part $euro_decimal_part
}

euroToMillicent() {
    euro="$1"
    potency="$2"

    if [ -z "$potency" ]; then
        potency=14
    fi

    # Replace each comma with a period, fixme if this is wrong
    euro="${euro//,/.}"

    v=$(awk -v euro="$euro" -v potency="$potency" 'BEGIN {printf "%.0f", euro * (10 ^ potency)}')

    if [ -z "$v" ]; then
        log_message >&2 "E: Could not translate '$euro' to an integer."
        log_message >&2 "E: Called from ${FUNCNAME[1]} at line ${BASH_LINENO[0]}"
        return 1
    fi
    echo "$v"
    return 0
}

log_message() {
    local msg="$1"
    local prefix
    prefix=$(echo "$msg" | head -n 1 | cut -d' ' -f1)

    local color="\033[1m"
    local writeToLog=true

    case "$prefix" in
    "E:") color="\033[1;31m" ;;
    "D:")
        color="\033[1;34m"
        writeToLog=false
        ;;
    "W:") color="\033[1;33m" ;;
    "I:") color="\033[1;32m" ;;
    esac

    writeToLog="${2:-$writeToLog}" # Override default if second parameter is provided

    printf "${color}%b\033[0m\n" "$msg"

    if [ "$writeToLog" == "true" ]; then
        echo -e "$msg" | sed 's/\x1b\[[0-9;]*m//g' >>"$LOG_FILE"
    fi
}

exit_with_cleanup() {
    log_message >&2 "I: Cleanup and exit with error $1"
	if ((use_charger != 0)); then
    manage_charging "off" "Turn off charging."
	fi
	if ((execute_discharging == 0 && (use_charger != 0))); then
         manage_discharging "on" "Spotmarket-Switcher is disabling itself. Maybe there is no internet connection."
    fi
    manage_fritz_sockets "off"
    manage_shelly_sockets "off"
    exit $1
}

checkAndClean() {
    scriptFile1="$DIR/$CONFIG"
    scriptFile2="$DIR/controller.sh"
    currentTime=$(date +%s)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        lastModified1=$(stat -f "%m" "$scriptFile1")
        lastModified2=$(stat -f "%m" "$scriptFile2")
    else
        lastModified1=$(stat -c %Y "$scriptFile1")
        lastModified2=$(stat -c %Y "$scriptFile2")
    fi
    difference1=$(( (currentTime - lastModified1) / 60 ))
    difference2=$(( (currentTime - lastModified2) / 60 ))
    if [ $difference1 -lt 60 ] || [ $difference2 -lt 60 ]; then
        log_message >&2 "I: Config or Controller was changed within the last 60 minutes. Cleaning /tmp directory."
        rm -f /tmp/tibber*.*
        rm -f /tmp/awattar*.*
		rm -f /tmp/entsoe*.*
		rm -f $file3
    fi
}

fetch_prices() {
    if [ "$select_pricing_api" -eq 1 ]; then
        Unit="Cent/kWh $price_unit price"
        get_awattar_prices
        get_awattar_prices_integer
    elif [ "$select_pricing_api" -eq 2 ]; then
        Unit="EUR/MWh net"
        get_entsoe_prices
        get_prices_integer_entsoe
    elif [ "$select_pricing_api" -eq 3 ]; then
        Unit="EUR/kWh $price_unit price"
        get_tibber_prices
        get_tibber_prices_integer
    fi
}

####################################
###    Begin of the script...    ###
####################################

# Path to the current script directory
DIR="$(dirname "$0")"

if [ -z "$LOG_FILE" ]; then
    LOG_FILE="/tmp/spotmarket-switcher.log"
fi
if [ -z "$LOG_MAX_SIZE" ]; then
    LOG_MAX_SIZE=1024 # 1 MB
fi
if [ -z "$LOG_FILES_TO_KEEP" ]; then
    LOG_FILES_TO_KEEP=2
fi

if [ -z "$CONFIG" ]; then
    CONFIG="config.txt"
fi

if [ -f "$DIR/$CONFIG" ]; then
    source "$DIR/$CONFIG"

num_tools_missing=0
SOC_percent=-1 # Set to negative -1 first (maybe no charger is activated).
tools="awk curl cat sed sort head tail"

# Victron DBUS Charger

if [ "$use_charger" == "1" ]; then
    tools="$tools dbus"
charger_command_charge() {
	log_message >&2 "I: Executing dbus -y com.victronenergy.settings /Settings/CGwacs/BatteryLife/Schedule/Charge/0/Day SetValue -- 7"
    dbus -y com.victronenergy.settings /Settings/CGwacs/BatteryLife/Schedule/Charge/0/Day SetValue -- 7
}

charger_command_stop_charging() {
	log_message >&2 "I: Executing dbus -y com.victronenergy.settings /Settings/CGwacs/BatteryLife/Schedule/Charge/0/Day SetValue -- -7"
    dbus -y com.victronenergy.settings /Settings/CGwacs/BatteryLife/Schedule/Charge/0/Day SetValue -- -7
}

charger_command_set_SOC_target() {
	log_message >&2 "I: Executing dbus -y com.victronenergy.settings /Settings/CGwacs/BatteryLife/Schedule/Charge/0/Soc SetValue -- "$target_soc""
    dbus -y com.victronenergy.settings /Settings/CGwacs/BatteryLife/Schedule/Charge/0/Soc SetValue -- "$target_soc"
}

charger_disable_inverter() {
	log_message >&2 "I: Executing dbus -y com.victronenergy.settings /Settings/CGwacs/MaxDischargePower SetValue -- 0"
    dbus -y com.victronenergy.settings /Settings/CGwacs/MaxDischargePower SetValue -- 0
}

charger_enable_inverter() {
	log_message >&2 "I: Executing dbus -y com.victronenergy.settings /Settings/CGwacs/MaxDischargePower SetValue -- "$limit_inverter_power_after_enabling""
    dbus -y com.victronenergy.settings /Settings/CGwacs/MaxDischargePower SetValue -- "$limit_inverter_power_after_enabling"
}

	SOC_percent="$(dbus-send --system --print-reply --dest=com.victronenergy.system /Dc/Battery/Soc com.victronenergy.BusItem.GetValue | grep variant | awk '{print int($3)}' | tr -d '[:space:]')"
	if ! [[ "$SOC_percent" =~ ^[0-9]+$ ]]; then
    log_message >&2 "E: SOC cannot be read properly. Value is not an integer."
    exit 1
	elif (( $SOC_percent < 0 || $SOC_percent > 100 )); then
    log_message >&2 "E: SOC value out of range: $SOC_percent. Valid range is 0-100."
    exit 1
	fi

fi

# Victron MQTT Charger
if [ "$use_charger" == "2" ]; then

serial_number=$(mosquitto_sub -h "$venus_os_mqtt_ip" -p "$venus_os_mqtt_port" -t "${MQTT_TOPIC_PREFIX}N/#" -C 1 | grep -o '"value":"[^,]*' | sed 's/"value"://' | cut -d '}' -f 1 | tr -d '"')

if [[ -z "$serial_number" ]]; then
  log_message >&2 "E: Victron MQTT system not found. Exit."
  exit 1
fi

MQTT_TOPIC_SUB=N/$serial_number/system/0/Dc/Battery/Soc
MQTT_TOPIC_PUB=R/$serial_number/keepalive
MQTT_TOPIC_SUB_CHARGE=W/$serial_number/settings/0/Settings/CGwacs/BatteryLife/Schedule/Charge/0/Day
MQTT_TOPIC_SUB_STOP_CHARGE=W/$serial_number/settings/0/Settings/CGwacs/BatteryLife/Schedule/Charge/0/Day
MQTT_TOPIC_SUB_SET_SOC=W/$serial_number/settings/0/Settings/CGwacs/BatteryLife/Schedule/Charge/0/Soc
MQTT_TOPIC_SUB_DISABLE_INV=W/$serial_number/settings/0/Settings/CGwacs/MaxDischargePower
MQTT_TOPIC_SUB_ENABLE_INV=W/$serial_number/settings/0/Settings/CGwacs/MaxDischargePower

keepalive_pid=""
send_keepalive_for_charger2() {
    while [ "$use_charger" == "2" ]; do
    mosquitto_pub -t "$MQTT_TOPIC_PUB" -m "" -h "$venus_os_mqtt_ip" -p "$venus_os_mqtt_port"
    sleep 5
    done
}
    send_keepalive_for_charger2 &
    keepalive_pid=$!

SOC_percent=$(mosquitto_sub -h $venus_os_mqtt_ip -p $venus_os_mqtt_port -t $MQTT_TOPIC_SUB -C 1 | grep -o '"value":[^,]*' | sed 's/"value"://' | cut -d '.' -f 1)
charger_command_charge() {
	log_message >&2 "I: Executing mosquitto_pub -t "$MQTT_TOPIC_SUB_STOP_CHARGE" -h "$venus_os_mqtt_ip" -p $venus_os_mqtt_port -m "{\"value\":7}""
    mosquitto_pub -t "$MQTT_TOPIC_SUB_STOP_CHARGE" -h "$venus_os_mqtt_ip" -p $venus_os_mqtt_port -m "{\"value\":7}"
}

charger_command_stop_charging() {
	log_message >&2 "I: Executing mosquitto_pub -t "$MQTT_TOPIC_SUB_STOP_CHARGE" -h "$venus_os_mqtt_ip" -p $venus_os_mqtt_port -m "{\"value\":-7}""
    mosquitto_pub -t "$MQTT_TOPIC_SUB_STOP_CHARGE" -h "$venus_os_mqtt_ip" -p $venus_os_mqtt_port -m "{\"value\":-7}"
}

charger_command_set_SOC_target() {
	log_message >&2 "I: Executing mosquitto_pub -t $MQTT_TOPIC_SUB_SET_SOC -h $venus_os_mqtt_ip -p $venus_os_mqtt_port -m \"{\"value\":$target_soc}\""
    mosquitto_pub -t $MQTT_TOPIC_SUB_SET_SOC -h $venus_os_mqtt_ip -p $venus_os_mqtt_port -m "{\"value\":$target_soc}"
}

charger_disable_inverter() {
	log_message >&2 "I: Executing mosquitto_pub -t "$MQTT_TOPIC_SUB_DISABLE_INV" -h "$venus_os_mqtt_ip" -p "$venus_os_mqtt_port" -m "{\"value\":0}""
    mosquitto_pub -t "$MQTT_TOPIC_SUB_DISABLE_INV" -h "$venus_os_mqtt_ip" -p "$venus_os_mqtt_port" -m "{\"value\":0}"
}

charger_enable_inverter() {
	log_message >&2 "I: Executing mosquitto_pub -t "$MQTT_TOPIC_SUB_ENABLE_INV" -h "$venus_os_mqtt_ip" -p "$venus_os_mqtt_port" -m "{\"value\":$limit_inverter_power_after_enabling}""
    mosquitto_pub -t "$MQTT_TOPIC_SUB_ENABLE_INV" -h "$venus_os_mqtt_ip" -p "$venus_os_mqtt_port" -m "{\"value\":$limit_inverter_power_after_enabling}"
}

fi


# other MQTT Charger
if [ "$use_charger" == "3" ]; then

# Check for required MQTT commands
if ! command -v mosquitto_pub &> /dev/null || ! command -v mosquitto_sub &> /dev/null; then
    log_message >&2 "E: Error. mosquitto_pub or mosquitto_sub command not found. Please install mosquitto-clients."
    exit 1
fi

# Validate MQTT ports
if ! [[ "$mqtt_broker_port_publish" =~ ^[1-9][0-9]{0,4}$ && "$mqtt_broker_port_publish" -le 65535 ]]; then
    log_message >&2 "E: Error. Invalid mqtt_broker_port_publish: $mqtt_broker_port_publish. Port must be between 1 and 65535."
    exit 1
fi
if ! [[ "$mqtt_broker_port_subscribe" =~ ^[1-9][0-9]{0,4}$ && "$mqtt_broker_port_subscribe" -le 65535 ]]; then
    log_message >&2 "E: Error. Invalid mqtt_broker_port_subscribe: $mqtt_broker_port_subscribe. Port must be between 1 and 65535."
    exit 1
fi

num_tools_missing=0
SOC_percent=-1 # Set to negative -1 first (maybe no charger is activated).
tools="$tools mosquitto_sub mosquitto_pub"

charger_command_charge() {
	log_message >&2 "I: Executing mosquitto_pub -h "$mqtt_broker_host_publish" -p "$mqtt_broker_port_publish" -t "$mqtt_broker_topic_publish/charger_command" -m true"
    mosquitto_pub -h "$mqtt_broker_host_publish" -p "$mqtt_broker_port_publish" -t "$mqtt_broker_topic_publish/charger_command" -m true
}

charger_command_stop_charging() {
	log_message >&2 "I: Executing mosquitto_pub -h "$mqtt_broker_host_publish" -p "$mqtt_broker_port_publish" -t "$mqtt_broker_topic_publish/charger_command" -m false"
    mosquitto_pub -h "$mqtt_broker_host_publish" -p "$mqtt_broker_port_publish" -t "$mqtt_broker_topic_publish/charger_command" -m false
}

charger_command_set_SOC_target() {
	log_message >&2 "I: Executing mosquitto_pub -h "$mqtt_broker_host_publish" -p "$mqtt_broker_port_publish" -t "$mqtt_broker_topic_publish/charger_command_set_SOC_target" -m "$target_soc""
    mosquitto_pub -h "$mqtt_broker_host_publish" -p "$mqtt_broker_port_publish" -t "$mqtt_broker_topic_publish/charger_command_set_SOC_target" -m "$target_soc"
}

charger_disable_inverter() {
	log_message >&2 "I: Executing mosquitto_pub -h "$mqtt_broker_host_publish" -p "$mqtt_broker_port_publish" -t "$mqtt_broker_topic_publish/charger_inverter" -m false"
    mosquitto_pub -h "$mqtt_broker_host_publish" -p "$mqtt_broker_port_publish" -t "$mqtt_broker_topic_publish/charger_inverter" -m false
}

charger_enable_inverter() {
	log_message >&2 "I: Executing mosquitto_pub -h "$mqtt_broker_host_publish" -p "$mqtt_broker_port_publish" -t "$mqtt_broker_topic_publish/charger_inverter" -m true"
    mosquitto_pub -h "$mqtt_broker_host_publish" -p "$mqtt_broker_port_publish" -t "$mqtt_broker_topic_publish/charger_inverter" -m true
}


if [ -z "$mqtt_broker_host_subscribe" ] || [ -z "$mqtt_broker_port_subscribe" ] || [ -z "$mqtt_broker_topic_subscribe" ]; then
    log_message >&2 "E: Error. MQTT subscribe variables are not fully configured."
    exit 1
fi
SOC_file=$(mktemp)
mosquitto_sub -h "$mqtt_broker_host_subscribe" -p "$mqtt_broker_port_subscribe" -t "$mqtt_broker_topic_subscribe" -C 1 > "$SOC_file" &
MOSQUITTO_PID=$!
timeout=5
counter=0

while kill -0 "$MOSQUITTO_PID" 2>/dev/null; do
    sleep 1
    counter=$((counter + 1))
    if [ "$counter" -ge "$timeout" ]; then
        kill "$MOSQUITTO_PID"
        log_message >&2 "E: Failed to retrieve SOC_percent from MQTT. Timeout executing mosquitto_sub -h $mqtt_broker_host_subscribe -p $mqtt_broker_port_subscribe -t $mqtt_broker_topic_subscribe -C 1"
        rm "$SOC_file"
        exit 1
    fi
done

SOC_percent=$(cat "$SOC_file")
rm "$SOC_file"

if [ -z "$SOC_percent" ]; then
    log_message >&2 "E: Error. Failed to retrieve SOC_percent from MQTT."
    exit 1
fi

	if ! [[ "$SOC_percent" =~ ^[0-9]+$ ]]; then
    log_message >&2 "D: SOC cannot be read properly. Value is not an integer and will be convert."
    SOC_percent=${SOC_percent%.*}
	elif (( $SOC_percent < 0 || $SOC_percent > 100 )); then
    log_message >&2 "E: SOC value out of range: $SOC_percent. Valid range is 0-100."
    exit 1
	fi

fi

# sonnenBatterie

if [ "$use_charger" == "4" ]; then

    SOC_percent=$(curl --max-time 5 --header "Auth-Token: $sonnen_API_KEY" "$sonnen_API_URL/latestdata" | awk -F'[,{}:]' '{for(i=1;i<=NF;i++) if ($i ~ /"USOC"/) print $(i+1)}')

    if [ -z "$SOC_percent" ]; then
        log_message >&2 "E: Timeout while trying to read RSOC from the charger."
        exit 1
    fi

    charger_command_charge() {
        log_message >&2 "I: Executing curl -X PUT -d EM_USOC=$target_soc --header \"Auth-Token: $sonnen_API_KEY\" $sonnen_API_URL/configurations"
        curl -X PUT -d "EM_USOC=$target_soc" --header "Auth-Token: $sonnen_API_KEY" "$sonnen_API_URL/configurations"
    }

    charger_command_stop_charging() {
        log_message >&2 "I: Executing curl -X PUT -d EM_USOC=$sonnen_minimum_SoC --header \"Auth-Token: $sonnen_API_KEY\" $sonnen_API_URL/configurations"
        curl -X PUT -d "EM_USOC=$sonnen_minimum_SoC" --header "Auth-Token: $sonnen_API_KEY" "$sonnen_API_URL/configurations"
    }

    charger_command_set_SOC_target() {
        echo "Nothing to do at sonnen charger." >/dev/null
    }

    charger_disable_inverter() {
        if ((charging == 0)); then
            log_message >&2 "I: Executing curl -X PUT -d EM_USOC=$SOC_percent --header \"Auth-Token: $sonnen_API_KEY\" $sonnen_API_URL/configurations"
            curl -X PUT -d "EM_USOC=$SOC_percent" --header "Auth-Token: $sonnen_API_KEY" "$sonnen_API_URL/configurations"
        fi
    }

    charger_enable_inverter() {
        if ((charging == 0)); then
            log_message >&2 "I: Executing curl -X PUT -d EM_USOC=$sonnen_minimum_SoC --header \"Auth-Token: $sonnen_API_KEY\" $sonnen_API_URL/configurations"
            curl -X PUT -d "EM_USOC=$sonnen_minimum_SoC" --header "Auth-Token: $sonnen_API_KEY" "$sonnen_API_URL/configurations"
        fi
    }
fi

for tool in $tools; do
    if ! which "$tool" >/dev/null; then
        log_message >&2 "E: Please ensure the tool '$tool' is found."
        num_tools_missing=$((num_tools_missing + 1))
    fi
done

if [ $num_tools_missing -gt 0 ]; then
    log_message >&2 "E: $num_tools_missing tools are missing."
    exit 127
fi

unset num_tools_missing

else
    log_message >&2 "E: The file $DIR/$CONFIG was not found! Configure the existing sample.config.txt file and then save it as config.txt in the same directory." false
    exit 127
fi

if [ -f "$DIR/license.txt" ]; then
    # Include the license file
    source "$DIR/license.txt"
else
    log_message >&2 "E: The file $DIR/license.txt was not found! Please read the license.txt file and save it together with the config.txt in the same directory. Thank you." false
    exit 127
fi

if [ -z "$UNAME" ]; then
    UNAME=$(uname)
fi
if [ "Darwin" = "$UNAME" ]; then
    log_message >&2 "W: MacOS has a different implementation of 'date' - use conda if hunting a bug on a mac".
fi

# further API parameters (no need to edit)
dateInSeconds=$(LC_ALL=C TZ=$TZ date +"%s")
if [ "Darwin" = "$UNAME" ]; then
    yesterday=$(LC_ALL=C TZ=$TZ date -j -f "%s" $((dateInSeconds - 86400)) +%d)2300
    yestermonth=$(LC_ALL=C TZ=$TZ date -j -f "%s" $((dateInSeconds - 86400)) +%m)
    yesteryear=$(LC_ALL=C TZ=$TZ date -j -f "%s" $((dateInSeconds - 86400)) +%Y)
    today=$(LC_ALL=C TZ=$TZ date -j -f "%s" $((dateInSeconds)) +%d)2300
    today2=$(LC_ALL=C TZ=$TZ date -j -f "%s" $((dateInSeconds)) +%d)
    todaymonth=$(LC_ALL=C TZ=$TZ date -j -f "%s" $((dateInSeconds)) +%m)
    todayyear=$(LC_ALL=C TZ=$TZ date -j -f "%s" $((dateInSeconds)) +%Y)
    tomorrow=$(LC_ALL=C TZ=$TZ date -j -f "%s" $((dateInSeconds + 86400)) +%d)2300
    tomorrow2=$(LC_ALL=C TZ=$TZ date -j -f "%s" $((dateInSeconds + 86400)) +%d)
    tomorrowmonth=$(LC_ALL=C TZ=$TZ date -j -f "%s" $((dateInSeconds + 86400)) +%m)
    tomorrowyear=$(LC_ALL=C TZ=$TZ date -j -f "%s" $((dateInSeconds + 86400)) +%Y)
    getnow=$(LC_ALL=C TZ=$TZ date -j -f "%s" $((dateInSeconds)) +%k)
else
    yesterday=$(LC_ALL=C TZ=$TZ date -d @$((dateInSeconds - 86400)) +%d)2300
    yestermonth=$(LC_ALL=C TZ=$TZ date -d @$((dateInSeconds - 86400)) +%m)
    yesteryear=$(LC_ALL=C TZ=$TZ date -d @$((dateInSeconds - 86400)) +%Y)
    today=$(LC_ALL=C TZ=$TZ date -d @$((dateInSeconds)) +%d)2300
    today2=$(LC_ALL=C TZ=$TZ date -d @$((dateInSeconds)) +%d)
    todaymonth=$(LC_ALL=C TZ=$TZ date -d @$((dateInSeconds)) +%m)
    todayyear=$(LC_ALL=C TZ=$TZ date -d @$((dateInSeconds)) +%Y)
    tomorrow=$(LC_ALL=C TZ=$TZ date -d @$((dateInSeconds + 86400)) +%d)2300
    tomorrow2=$(LC_ALL=C TZ=$TZ date -d @$((dateInSeconds + 86400)) +%d)
    tomorrowmonth=$(LC_ALL=C TZ=$TZ date -d @$((dateInSeconds + 86400)) +%m)
    tomorrowyear=$(LC_ALL=C TZ=$TZ date -d @$((dateInSeconds + 86400)) +%Y)
    getnow=$(LC_ALL=C TZ=$TZ date -d @$((dateInSeconds)) +%k)
fi

now_linenumber=$((getnow + 1))
link1="https://api.awattar.$awattar/v1/marketdata/current.yaml"
link2="http://api.awattar.$awattar/v1/marketdata/current.yaml?tomorrow=include"
link3="https://weather.visualcrossing.com/VisualCrossingWebServices/rest/services/timeline/$latitude%2C%20$longitude/$todayyear-$todaymonth-$today2/$tomorrowyear-$tomorrowmonth-$tomorrow2?unitGroup=metric&elements=snowdepth%2Ctemp%2Csolarenergy%2Ccloudcover%2Csunrise%2Csunset&include=days&key=$visualcrossing_api_key&contentType=csv"
link4="https://web-api.tp.entsoe.eu/api?securityToken=$entsoe_eu_api_security_token&documentType=A44&in_Domain=$in_Domain&out_Domain=$out_Domain&periodStart=$yesteryear$yestermonth$yesterday&periodEnd=$todayyear$todaymonth$today"
link5="https://web-api.tp.entsoe.eu/api?securityToken=$entsoe_eu_api_security_token&documentType=A44&in_Domain=$in_Domain&out_Domain=$out_Domain&periodStart=$todayyear$todaymonth$today&periodEnd=$tomorrowyear$tomorrowmonth$tomorrow"
link6="https://api.tibber.com/v1-beta/gql"
file1=/tmp/awattar_today_prices.yaml
file2=/tmp/awattar_tomorrow_prices.yaml
file3=/tmp/expected_solarenergy.csv
file4=/tmp/entsoe_today_prices.xml
file5=/tmp/entsoe_tomorrow_prices.xml
file6=/tmp/awattar_prices.txt
file7=/tmp/awattar_prices_sorted.txt
file8=/tmp/entsoe_prices.txt
file9=/tmp/entsoe_tomorrow_prices_sorted.txt
file10=/tmp/entsoe_today_prices.txt
file11=/tmp/entsoe_today_prices_sorted.txt
file12=/tmp/tibber_prices_sorted.txt
file13=/tmp/entsoe_tomorrow_prices.txt
file14=/tmp/tibber_prices.txt
file15=/tmp/tibber_today_prices.txt
file16=/tmp/tibber_today_prices_sorted.txt
file17=/tmp/tibber_tomorrow_prices.txt
file18=/tmp/tibber_tomorrow_prices_sorted.txt
file19=/tmp/entsoe_prices_sorted.txt

########## Start ##########

echo >>"$LOG_FILE"

log_message >&2 "I: Bash Version: $(bash --version | head -n 1)"
log_message >&2 "I: Spotmarket-Switcher - Version $VERSION"

parse_and_validate_config "$DIR/$CONFIG"

checkAndClean

if ((select_pricing_api == 1)); then
	use_awattar_api

elif ((select_pricing_api == 2)); then
	use_entsoe_api

elif ((select_pricing_api == 3)); then
	use_tibber=1
	use_tibber_api
    
    if [ "$use_tibber" -eq 0 ]; then
    select_pricing_api="1"
    use_awattar_api
    fi
	
fi

if ((include_second_day == 1)); then

    if ((select_pricing_api == 1)); then

use_awattar_tomorrow_api

    elif ((select_pricing_api == 2)); then

use_entsoe_tomorrow_api

    elif ((select_pricing_api == 3)); then

use_tibber_tomorrow_api

fi

fi # Include second day

loop_hours=24
if [ "$include_second_day" = 1 ]; then
    if [ "$select_pricing_api" = 1 ] && [ -f "$file2" ] && [ "$(wc -l <"$file2")" -gt 10 ]; then
        loop_hours=48
    elif [ "$select_pricing_api" = 2 ] && [ -f "$file13" ] && [ "$(wc -l <"$file13")" -gt 10 ]; then
        loop_hours=48
    elif [ "$select_pricing_api" = 3 ] && [ -f "$file17" ] && [ "$(wc -l <"$file17")" -gt 10 ]; then
        loop_hours=48
    fi

fi

fetch_prices

if ((use_solarweather_api_to_abort == 1)); then
    download_solarenergy
	get_temp_today
	get_temp_tomorrow
	get_snow_today
	get_snow_tomorrow
    get_solarenergy_today
    get_solarenergy_tomorrow
    get_cloudcover_today
    get_cloudcover_tomorrow
    get_sunrise_today
    get_sunset_today
    get_suntime_today
fi

log_message >&2 "I: Please verify correct system time and timezone:\n   $(TZ=$TZ date)"
log_message >&2 "I: Current price is $current_price $Unit."
log_message >&2 "I: The average price will be $average_price $Unit."
log_message >&2 "I: Highest price will be $highest_price $Unit."
price_table=""
for i in $(seq 1 $loop_hours); do
    eval price=\$P$i
    price_table+="$i:$price "

    if [ $((i % 12)) -eq 0 ]; then
        price_table+="\n                  "
    fi
done
log_message >&2 "I: Sorted prices: $price_table"
if [ "$include_second_day" -eq 1 ]; then
    price_count=$(echo "$price_table" | grep -oE '[0-9]+:[0-9]+\.[0-9]+' | wc -l)
    if [ "$price_count" -le 25 ]; then
        current_hour=$(TZ=$TZ date +%H)
        if [ "$current_hour" -ge 13 ]; then
            log_message >&2 "I: time is > 13:00 and price data delayed. $price_count prices available. Trying to check other APIs too (5 retries with 5 minutes pause)..."
retry_count=0
max_retries=5
while [ "$current_hour" -ge 13 ]; do
    for api in "awattar-API" "entsoe-API" "tibber-API"; do
        log_message >&2 "E: Trying $api for prices."
        price_table=""
        case "$api" in
            "awattar-API")
                select_pricing_api="1"
                use_awattar_api
                use_awattar_tomorrow_api
                ;;
            "entsoe-API")
                select_pricing_api="2"
                rm -f "$file4" "$file5" "$file8" "$file9" "$file10" "$file11" "$file13" "$file19"                
                use_entsoe_api
                ;;
            "tibber-API")
                select_pricing_api="3"
                use_tibber_api
                use_tibber_tomorrow_api
                ;;
        esac
        fetch_prices
        price_table=""
        for i in $(seq 1 $loop_hours); do
            eval price=\$P$i
            price_table+="$i:$price "

            if [ $((i % 12)) -eq 0 ]; then
                price_table+="\n                  "
            fi
        done

        price_count=$(echo "$price_table" | grep -oE '[0-9]+:[0-9]+\.[0-9]+' | wc -l)
        log_message >&2 "I: $api returned $price_count prices."
        
        if [ -n "$price_table" ]; then
            log_message >&2 "I: $api sorted prices: $price_table"
        else
            log_message >&2 "E: $api did not return valid prices."
        fi

        if [ "$price_count" -gt 24 ]; then
            break 2
        fi
    done

    retry_count=$((retry_count + 1))
    if [ "$retry_count" -ge "$max_retries" ]; then
        log_message >&2 "E: All retries exhausted. Exiting..."
        break 2
    fi

    log_message >&2 "I: Prices still delayed. Waiting 5 minutes..."
    sleep 300
    current_hour=$(date +%H)
done
        fi
    fi
fi

if [ "$loop_hours" = 24 ]; then

    # Separate arrays for each column
    config_matrix24_charge=()
    config_matrix24_discharge=()
    config_matrix24_switchablesockets=()

    # Populate separate arrays
    for ((i=0; i<25; i++)); do
        row=(${config_matrix24_price[$i]})
        config_matrix24_charge+=("${row[0]}")
        config_matrix24_discharge+=("${row[1]}")
        config_matrix24_switchablesockets+=("${row[2]}")
    done

    # Use the separate arrays
    for ((i=1; i<=24; i++)); do
        hour=$i
        charge_value="${config_matrix24_charge[$i]}"
        discharge_value="${config_matrix24_discharge[$i]}"
        switchable_sockets_value="${config_matrix24_switchablesockets[$i]}"
        hour_var_name="${hour//[^a-zA-Z0-9]/_}"

        charge_var_name="charge_at_${hour_var_name}"
        discharge_var_name="discharge_at_${hour_var_name}"
        switchable_sockets_var_name="switchablesockets_at_${hour_var_name}"

        declare "$charge_var_name=$charge_value"
        declare "$switchable_sockets_var_name=$switchable_sockets_value"

    if [ $SOC_percent -ge $discharge_value ]; then
        declare "$discharge_var_name=1"
		if [ -n "$DEBUG" ]; then
        log_message "D: $discharge_var_name=1"
		fi
    else
        declare "$discharge_var_name=0"
		if [ -n "$DEBUG" ]; then
        log_message "D: $discharge_var_name=0"
		fi
    fi
		if [ -n "$DEBUG" ]; then
        log_message "D: $charge_var_name=$charge_value"
        log_message "D: $switchable_sockets_var_name=$switchable_sockets_value"
		fi
    done
	
charge_table=""
discharge_table=""
switchable_sockets_table=""
for ((i=1; i<=$loop_hours; i++)); do
    hour=$i
    charge_value="${config_matrix24_charge[i]}"
    discharge_value="${config_matrix24_discharge[i]}"
    switchable_sockets_value="${config_matrix24_switchablesockets[i]}"
    hour_var_name="${hour//[^a-zA-Z0-9]/_}"

    charge_var_name="${hour_var_name}"
    discharge_var_name="${hour_var_name}"
    switchable_sockets_var_name="${hour_var_name}"

    if [ "$charge_value" -eq 1 ]; then
        charge_table+="$charge_var_name "
    fi

    if [ "$SOC_percent" -ge "$discharge_value" ]; then
        discharge_table+="$discharge_var_name "
    fi

    if [ "$switchable_sockets_value" -eq 1 ]; then
        switchable_sockets_table+="$switchable_sockets_var_name "
    fi

done
	
fi
	
if [ "$loop_hours" = 48 ]; then
	    # Separate arrays for each column
    config_matrix48_charge=()
    config_matrix48_discharge=()
    config_matrix48_switchablesockets=()

    # Populate separate arrays
    for ((i=0; i<49; i++)); do
        row=(${config_matrix48_price[$i]})
        config_matrix48_charge+=("${row[0]}")
        config_matrix48_discharge+=("${row[1]}")
        config_matrix48_switchablesockets+=("${row[2]}")
    done

    # Use the separate arrays
    for ((i=1; i<=48; i++)); do
        hour=$i
        charge_value="${config_matrix48_charge[$i]}"
        discharge_value="${config_matrix48_discharge[$i]}"
        switchable_sockets_value="${config_matrix48_switchablesockets[$i]}"
        hour_var_name="${hour//[^a-zA-Z0-9]/_}"

        charge_var_name="charge_at_${hour_var_name}"
        discharge_var_name="discharge_at_${hour_var_name}"
        switchable_sockets_var_name="switchablesockets_at_${hour_var_name}"

        declare "$charge_var_name=$charge_value"
        declare "$switchable_sockets_var_name=$switchable_sockets_value"

    if [ "$SOC_percent" -ge "$discharge_value" ]; then
        declare "$discharge_var_name=1"
		if [ -n "$DEBUG" ]; then
        log_message "D: $discharge_var_name=1"
		fi
    else
        declare "$discharge_var_name=0"
		if [ -n "$DEBUG" ]; then
        log_message "D: $discharge_var_name=0"
		fi
    fi
	    if [ -n "$DEBUG" ]; then
        log_message "D: $charge_var_name=$charge_value"
        log_message "D: $switchable_sockets_var_name=$switchable_sockets_value"
		fi
    done

charge_table=""
discharge_table=""
switchable_sockets_table=""
for ((i=1; i<=$loop_hours; i++)); do
    hour=$i
    charge_value="${config_matrix48_charge[i]}"
    discharge_value="${config_matrix48_discharge[i]}"
    switchable_sockets_value="${config_matrix48_switchablesockets[i]}"
    hour_var_name="${hour//[^a-zA-Z0-9]/_}"

    charge_var_name="${hour_var_name}"
    discharge_var_name="${hour_var_name}"
    switchable_sockets_var_name="${hour_var_name}"

    if [ "$charge_value" -eq 1 ]; then
        charge_table+="$charge_var_name "
    fi

    if [ "$SOC_percent" -ge "$discharge_value" ]; then
        discharge_table+="$discharge_var_name "
    fi

    if [ "$switchable_sockets_value" -eq 1 ]; then
        switchable_sockets_table+="$switchable_sockets_var_name "
    fi

done

fi

	if (( $SOC_percent != -1 )); then
		log_message >&2 "I: Charge at prices: $charge_table"
		log_message >&2 "I: Dynamic ESS discharge (depending SOC) at prices: $discharge_table"
	fi

	if (( use_shelly_wlan_sockets + use_fritz_dect_sockets > 0 )); then
		log_message >&2 "I: Switchable sockets at prices: $switchable_sockets_table"
	fi


if ((use_solarweather_api_to_abort == 1)); then
    if [ -f "$file3" ] && [ -s "$file3" ]; then
        log_message >&2 "I: Sunrise today will be $sunrise_today and sunset will be $sunset_today. Suntime will be $suntime_today minutes."
        log_message >&2 "I: Solarenergy today will be $solarenergy_today megajoule per sqaremeter with $cloudcover_today percent clouds. The temperature is "$temp_today"°C with "$snow_today"cm snowdepth."
        log_message >&2 "I: Solarenergy tomorrow will be $solarenergy_tomorrow megajoule per squaremeter with $cloudcover_tomorrow percent clouds. The temperature will be "$temp_tomorrow"°C with "$snow_tomorrow"cm snowdepth."
		
		if awk -v temp="$temp_today" -v snow="$snow_today" 'BEGIN { exit !(temp < 0 && snow > 1) }'; then
		target_soc=$(get_target_soc 0)
		log_message >&2 "I: There is snow on the solar panels (snowdepth > 1cm) at negative degrees. Target SOC will be set to $target_soc% (max value of the matrix)."
		charger_command_set_SOC_target >/dev/null
		else
		if (($SOC_percent != -1)); then
			target_soc=$(get_target_soc "$solarenergy_today")
			log_message >&2 "I: At $solarenergy_today megajoule there will be a dynamic SOC charge-target of $target_soc% calculated. The rest is reserved for solar."
			charger_command_set_SOC_target >/dev/null
    
		fi
fi

    else
        log_message >&2 "E: No solar data. Please check your internet connection and API Key or wait if it is a temporary error."
		    if (($SOC_percent != -1)); then	
            target_soc=$(get_target_soc "$solarenergy_today")
            log_message >&2 "E: A SOC charge-target of $target_soc% will be used without valid solarweather-data."
	        charger_command_set_SOC_target >/dev/null
        fi
    fi
else
    log_message "D: skip Solarweather. not activated"
fi

charging_condition_met=""
discharging_condition_met=""
switchablesockets_condition_met=""
execute_charging=0
execute_discharging=0
execute_switchablesockets_on=0

# Function to evaluate and execute charging, discharging, and socket conditions
evaluate_conditions() {
    local conditions=("${!1}")
    local descriptions=("${!2}")
    local execute_ref_name="$3"
    local condition_met_ref_name="$4"
    local condition_met=0

    for index in "${!conditions[@]}"; do
        if ((conditions[index])) && [[ $condition_met -eq 0 ]]; then
            eval $execute_ref_name=1
			eval "$condition_met_ref_name='${descriptions[index]}'"
            condition_met=1
            [[ $DEBUG -ne 1 ]] && break
        fi
    done
}

# Add general conditions for charging
charging_conditions+=(
    $((use_start_stop_logic == 1 && start_price_integer > current_price_integer))
    $((charge_at_solar_breakeven_logic == 1 && feedin_price_integer > current_price_integer + energy_fee_integer))
)
charging_descriptions+=(
    "use_start_stop_logic ($use_start_stop_logic) == 1 && start_price_integer ($start_price_integer) > current_price_integer ($current_price_integer)"
    "charge_at_solar_breakeven_logic ($charge_at_solar_breakeven_logic) == 1 && feedin_price_integer ($feedin_price_integer) > current_price_integer ($current_price_integer) + energy_fee_integer ($energy_fee_integer)"
)

# Dynamically add conditions for P1 to P48 for charging, discharging, and switchable sockets
for ((i=1; i<=$loop_hours; i++)); do
    hour=$i
    charge_value="${config_matrix_charge[i]}"
    discharge_value="${config_matrix_discharge[i]}"
    switchable_sockets_value="${config_matrix_switchablesockets[i]}"
    hour_var_name="${hour//[^a-zA-Z0-9]/_}"

    charge_var_name="charge_at_${hour_var_name}"
    discharge_var_name="discharge_at_${hour_var_name}"
    switchable_sockets_var_name="switchablesockets_at_${hour_var_name}"
    price_var="P${i}_integer"

    if [[ -n "${!charge_var_name}" && "${!charge_var_name}" == 1 && "${!price_var}" == "$current_price_integer" ]]; then
        charging_conditions+=("1")
        charging_descriptions+=("\"$charge_var_name (${!charge_var_name}) == 1 && $price_var (${!price_var}) == current_price_integer ($current_price_integer)\"")
    else
        charging_conditions+=("0")
    fi

    if [[ -n "${!discharge_var_name}" && "${!discharge_var_name}" == 1 && "${!price_var}" == "$current_price_integer" ]]; then
        discharging_conditions+=("1")
        discharging_descriptions+=("\"$discharge_var_name (${!discharge_var_name}) == 1 && $price_var (${!price_var}) == current_price_integer ($current_price_integer)\"")
    else
        discharging_conditions+=("0")
    fi

    if [[ -n "${!switchable_sockets_var_name}" && "${!switchable_sockets_var_name}" == 1 && "${!price_var}" == "$current_price_integer" ]]; then
        switchablesockets_conditions+=("1")
        switchablesockets_conditions_descriptions+=("\"$switchable_sockets_var_name (${!switchable_sockets_var_name}) == 1 && $price_var (${!price_var}) == current_price_integer ($current_price_integer)\"")
    else
        switchablesockets_conditions+=("0")
    fi
done

if [ -n "$DEBUG" ]; then
log_message "D: Before evaluating charging conditions - execute_charging: $execute_charging"
log_message "D: Before evaluating discharging conditions - execute_discharging: $execute_discharging"
log_message "D: Before evaluating switchable sockets conditions - execute_switchablesockets_on: $execute_switchablesockets_on"
fi
evaluate_conditions charging_conditions[@] charging_descriptions[@] "execute_charging" "charging_condition_met"
evaluate_conditions discharging_conditions[@] discharging_descriptions[@] "execute_discharging" "discharging_condition_met"
evaluate_conditions switchablesockets_conditions[@] switchablesockets_conditions_descriptions[@] "execute_switchablesockets_on" "switchablesockets_condition_met"

if [ -n "$DEBUG" ]; then
log_message "D: After evaluating charging conditions - execute_charging: $execute_charging "
log_message "D: After evaluating discharging conditions - execute_discharging: $execute_discharging "
log_message "D: After evaluating switchable sockets conditions - execute_switchablesockets_on: $execute_switchablesockets_on "
fi

if ((use_solarweather_api_to_abort == 1)); then
    
    if [ ! -s "$file3" ]; then 
        log_message >&2 "E: File '$file3' does not exist or is empty."
        return
    fi

    if ((abort_solar_yield_today_integer <= solarenergy_today_integer)) && ((abort_solar_yield_tomorrow_integer <= solarenergy_tomorrow_integer)); then
        log_message >&2 "I: There is enough solarenergy today and tomorrow. ESS can be used normal and no need to switch or charge. Spotmarket-Switcher will be disabled."
        execute_charging=0
        execute_discharging=1
        execute_switchablesockets_on=0
    else
        log_message >&2 "I: Not enough solarenergy today or tomorrow. Spotmarket-Switcher will manage discharging (ESS), charging and switching."
    fi

    if ((abort_suntime <= suntime_today)); then
        log_message >&2 "I: There are enough sun minutes today. Spotmarket-Switcher will be disabled."
        execute_charging=0
        execute_discharging=1
        execute_switchablesockets_on=0
    fi

fi

echo $link3

if ((reenable_inverting_at_fullbatt == 1)); then
if (( $SOC_percent >= reenable_inverting_at_soc )); then
    log_message >&2 "I: The battery is getting full. Re-enabling inverter. This is important on a DC-AC system to enable grid-feedin."
    execute_discharging=1
    fi
fi

if ((abort_price_integer <= current_price_integer)); then
    log_message >&2 "I: Current price ($(millicentToEuro "$current_price_integer")€) is too high. Spotmarket-Switcher will be disabled if higher than ($(millicentToEuro "$abort_price_integer")€)."
    execute_charging=0
    execute_discharging=1
    execute_switchablesockets_on=0
fi

# If any charging condition is met, start charging
percent_of_current_price_integer=$(awk "BEGIN {printf \"%.0f\", $current_price_integer*$energy_loss_percent/100}")
total_cost_integer=$((current_price_integer + percent_of_current_price_integer + battery_lifecycle_costs_cent_per_kwh_integer))

# If any charging condition is met, start charging
if ((execute_charging == 1 && use_charger != 0)); then
    economic=""
    # Evaluate if charging is economical
    percent_of_current_price_integer=$(awk "BEGIN {printf \"%.0f\", $current_price_integer*$energy_loss_percent/100}")
    total_cost_integer=$((current_price_integer + percent_of_current_price_integer + battery_lifecycle_costs_cent_per_kwh_integer))

    if [ "$economic_check" -eq 0 ]; then
        manage_charging "on" "Economical check was not activated. Total charging costs: $(millicentToEuro "$total_cost_integer")€"
    elif [ "$economic_check" -eq 1 ] && is_charging_economical $highest_price_integer $total_cost_integer; then
        manage_charging "on" "Charging based on highest price ($(millicentToEuro "$highest_price_integer") €) comparison makes sense. Total charging costs: $(millicentToEuro "$total_cost_integer")€"
    elif [ "$economic_check" -eq 2 ] && is_charging_economical $average_price_integer $total_cost_integer; then
        manage_charging "on" "Charging based on average price ($(millicentToEuro "$average_price_integer") €) comparison makes sense. Total charging costs: $(millicentToEuro "$total_cost_integer")€"
    else
        reason_msg="Considering charging losses and costs, charging is too expensive."
        economic="expensive"
        manage_charging "off" "$reason_msg Total charging costs: $(millicentToEuro "$total_cost_integer")€"
    fi
elif ((execute_charging != 1 && use_charger != 0)); then
    manage_charging "off" "Charging was not executed. Total charging costs: $(millicentToEuro "$total_cost_integer")€"
else
    log_message "D: Skip charger. Not activated. "
fi

if ((execute_discharging == 1 && use_charger != 0)); then
         manage_discharging "on" "$reason_msg Total charging costs: $(millicentToEuro "$total_cost_integer")€"
fi
if ((execute_discharging == 0 && use_charger != 0)); then
         manage_discharging "off" "$reason_msg Total charging costs: $(millicentToEuro "$total_cost_integer")€"
fi

# Execute Fritz DECT on command
if ((use_fritz_dect_sockets == 1)); then
    manage_fritz_sockets
else
    log_message "D: skip Fritz DECT. not activated"
fi

if ((use_shelly_wlan_sockets == 1)); then
    manage_shelly_sockets
else
    log_message "D: skip Shelly Api. not activated"
fi
cleanup() {
    if [ -n "$keepalive_pid" ]; then
        kill "$keepalive_pid" 2>/dev/null
        wait "$keepalive_pid" 2>/dev/null
    fi
}
echo >>"$LOG_FILE"

# Rotating log files
if [ -f "$LOG_FILE" ]; then
    if [ "$(du -k "$LOG_FILE" | awk '{print $1}')" -gt "$LOG_MAX_SIZE" ]; then
        log_message >&2 "I: Rotating log files"
        mv "$LOG_FILE" "${LOG_FILE}.$(date +%Y%m%d%H%M%S)"
        touch "$LOG_FILE"
        find . -maxdepth 1 -name "${LOG_FILE}*" -type f -exec ls -1t {} + |
            sed 's|^\./||' |
            tail -n +$((LOG_FILES_TO_KEEP + 1)) |
            xargs --no-run-if-empty rm
    fi
fi

if [ -n "$DEBUG" ]; then
    log_message "D: [ OK ]"
fi

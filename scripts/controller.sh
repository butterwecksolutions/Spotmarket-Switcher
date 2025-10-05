#!/bin/bash

VERSION="2.5.1-DEV"

if [ -z "$LANG" ]; then
    export LANG="C"
fi

update_crontab() {
    temp_cron=$(mktemp)
    crontab -l > "$temp_cron"
    if grep -q "*/15 * * * * .*Spotmarket-Switcher/controller.sh" "$temp_cron"; then
        rm "$temp_cron"
        return
    fi
    sed -i 's/^0 \* \* \* \* \(.*Spotmarket-Switcher\/controller\.sh\)$/\/*\/15 \* \* \* \* \1/' "$temp_cron"

    if grep -q "*/15 * * * * .*Spotmarket-Switcher/controller.sh" "$temp_cron"; then
        echo "Spotmarket-Switcher crontab entry successfully updated to 15-minute intervals."
        crontab "$temp_cron"
    else
        echo "The hourly entry was not found. No changes made."
    fi
    rm "$temp_cron"
}

update_crontab

#######################################
###    Begin of the functions...    ###
#######################################

if [[ ${BASH_VERSINFO[0]} -le 4 ]]; then
    valid_config_version=12 # Please increase this value by 1 when changing the configuration variables
else
    declare -A valid_vars=(
    	["config_version"]="12" # Please increase this value by 1 if variables are added or deleted in the valid_vars array
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
        ["ignore_past_hours"]="0|1"
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
    local file="$1"
    local version_valid=false
    local errors=""

    if [[ ${BASH_VERSINFO[0]} -le 4 ]]; then
        # Simplified validation for Bash <= 4 (e.g., macOS Bash 3.2)
        log_message >&2 "W: Due to the older Bash version, detailed configuration validation is skipped."
        valid_config_version=12 # Match the new version requirement
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
        # Source the config file since we can't validate further without associative arrays
        source "$file"
        return 0
    else    
        # Advanced validation for Bash > 4
        declare -A valid_vars=(
            ["config_version"]="12" # Updated to 12 for the new version
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
            ["ignore_past_hours"]="0|1"
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

        rotating_spinner &   # Start the spinner in the background
        local spinner_pid=$! # Get the PID of the spinner

        while IFS='=' read -r key value; do
            key=$(echo "$key" | cut -d'#' -f1 | tr -d ' ')
            value=$(echo "$value" | awk -F'#' '{gsub(/^ *"|"$|^ *| *$/, "", $1); print $1}')
            [[ "$key" == "" || "$value" == "" ]] && continue
            config_values["$key"]="$value"
            if [[ "$key" == "config_version" ]]; then
                version_valid=true
            fi
        done <"$file"

        for var_name in "${!valid_vars[@]}"; do
            local validation_pattern=${valid_vars[$var_name]}
            if [[ -z ${config_values[$var_name]+x} ]]; then
                errors+="E: $var_name is not set.\n"
                continue
            fi
            if [[ "$validation_pattern" == "string" ]]; then
                continue
            elif [[ "$validation_pattern" == "array" && "${config_values[$var_name]}" == "" ]]; then
                continue
            fi
            if ! [[ "${config_values[$var_name]}" =~ ^($validation_pattern)$ ]]; then
                errors+="E: $var_name has an invalid value: ${config_values[$var_name]}.\n"
            fi
        done

        kill $spinner_pid &>/dev/null
        if [[ -n "$errors" ]]; then
            echo -e "$errors"
            return 1
        elif [[ "$version_valid" == false ]]; then
            log_message >&2 "E: Error: config_version=12 is missing."
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

check_tools() {
    local tools="$1"
    local num_tools_missing=0
    for tool in $tools; do
        if ! which "$tool" >/dev/null; then
            log_message >&2 "E: Please ensure the tool '$tool' is found."
            num_tools_missing=$((num_tools_missing + 1))
        fi
    done
    if [ "$num_tools_missing" -gt 0 ]; then
        log_message >&2 "E: $num_tools_missing tools are missing."
        exit_with_cleanup 127
    fi
}

cleanup() {
    rm -f "/tmp/prices_filtered.tmp"
    rm -f "/tmp/prices_sorted_filtered.tmp"
    
    if [ -n "$keepalive_pid" ] && kill -0 "$keepalive_pid" 2>/dev/null; then
        log_message >&2 "I: Attempting to stop keepalive process with PID $keepalive_pid."
        kill "$keepalive_pid" 2>/dev/null
        sleep 1
        if kill -0 "$keepalive_pid" 2>/dev/null; then
            log_message >&2 "I: Keepalive process $keepalive_pid still running, forcing termination with SIGKILL."
            kill -9 "$keepalive_pid" 2>/dev/null
        fi
        wait "$keepalive_pid" 2>/dev/null
        if [ -n "$DEBUG" ]; then
            if ! kill -0 "$keepalive_pid" 2>/dev/null; then
                log_message "D: Keepalive process $keepalive_pid successfully terminated."
            else
                log_message "D: Failed to terminate keepalive process $keepalive_pid."
            fi
        fi
    fi
}

download_awattar_prices() {

        log_message >&2 "I: aWATTar API supports only hourly prices. Converting to 15-min prices."


    local url="$1"
    local file="$2"
    local output_file="$3"
    local sleep_time="$4"

    # Validate inputs
    if [ -z "$url" ]; then
        log_message >&2 "E: aWATTar API URL is empty or unset."
        exit_with_cleanup 1
    fi
    if [ -z "$sleep_time" ] || ! [[ "$sleep_time" =~ ^[0-9]+$ ]]; then
        log_message >&2 "W: Invalid or empty sleep_time '$sleep_time', defaulting to 15 seconds."
        sleep_time=15
    fi

    if [ -z "$DEBUG" ]; then
        log_message >&2 "I: Please be patient. First we wait $sleep_time seconds in case the system clock is not synchronized and not to overload the API."
        sleep "$sleep_time"
    else
        log_message "D: No delay of download of aWATTar data since DEBUG variable set."
    fi

    # Download raw data
    if ! curl -s "$url" >"$file"; then
        log_message >&2 "E: Download of aWATTar prices from '$url' to '$file' failed."
        rm -f "$file"
        exit_with_cleanup 1
    fi
    if [ ! -s "$file" ]; then
        log_message >&2 "E: Downloaded file $file is empty, please check aWATTar API URL."
        exit_with_cleanup 1
    fi
    if [ -n "$DEBUG" ]; then
        log_message "D: Download of file '$file' from URL '$url' successful."
    fi
    echo >>"$file"

    # Parse prices and repeat each hourly price 4 times for 15-min prices
    if [ "$price_unit" = "energy" ]; then
        awk '/data_price_hour_rel_.*_amount: / {
            amount = substr($0, index($0, ":") + 2);
            for (i = 1; i <= 4; i++) print amount
        }' "$file" > "$output_file"
    elif [ "$price_unit" = "total" ]; then
        awk -v vat_rate="$vat_rate" -v energy_fee="$energy_fee" '
        /data_price_hour_rel_.*_amount: / {
            amount = substr($0, index($0, ":") + 2);
            total = amount * (1 + vat_rate) + energy_fee;
            for (i = 1; i <= 4; i++) print total
        }' "$file" > "$output_file"
    elif [ "$price_unit" = "tax" ]; then
        awk -v vat_rate="$vat_rate" -v energy_fee="$energy_fee" '
        /data_price_hour_rel_.*_amount: / {
            amount = substr($0, index($0, ":") + 2);
            tax = (amount * vat_rate) + energy_fee;
            for (i = 1; i <= 4; i++) print tax
        }' "$file" > "$output_file"
    else
        log_message >&2 "E: Invalid value for price_unit in config.txt."
        exit_with_cleanup 1
    fi

    # Validate price count
    local line_count=$(grep -E '^[0-9]+(\.[0-9]+)?$' "$output_file" | wc -l)
    if [ "$line_count" -lt $prices_per_day ]; then
        log_message >&2 "E: $output_file has only $line_count prices, expected $prices_per_day."
        exit_with_cleanup 1
    fi

    sort -g "$output_file" > "${output_file%.*}_sorted.${output_file##*.}"
    timestamp=$(TZ=$TZ date +%d)
    echo "date_now_day: $timestamp" >>"$file"
    echo "date_now_day: $timestamp" >>"$output_file"
    echo "date_now_day: $timestamp" >>"${output_file%.*}_sorted.${output_file##*.}"

    if [ -n "$DEBUG" ]; then
        log_message "D: Contents of $output_file after transformation:"
        cat "$output_file" >&2
        log_message "D: Contents of ${output_file%.*}_sorted.${output_file##*.} after sorting:"
        cat "${output_file%.*}_sorted.${output_file##*.}" >&2
    fi

    # Check for tomorrow data
    if [ -f "$file2" ] && [ "$include_second_day" -eq 1 ]; then
        local tomorrow_count=$(grep -E '^[0-9]+(\.[0-9]+)?$' "$file2" | wc -l)
        if [ "$tomorrow_count" -lt $prices_per_day ]; then
            log_message >&2 "I: File '$file2' has insufficient tomorrow data ($tomorrow_count prices), retry later."
            rm -f "$file2"
        fi
    fi
}

get_tibber_api() {
    resolution_param="(resolution: QUARTER_HOURLY)"

    curl --location --request POST $link6 \
        --header 'Content-Type: application/json' \
        --header "Authorization: Bearer $tibber_api_key" \
        --data-raw "{\"query\":\"{viewer{homes{currentSubscription{priceInfo${resolution_param}{current{total energy tax startsAt}today{total energy tax startsAt}tomorrow{total energy tax startsAt}}}}}}\"}" |
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

    log_message "D: Starting Tibber price download from $url to $file"
    if [ -z "$DEBUG" ]; then
        log_message >&2 "I: Please be patient. First we wait $sleep_time seconds in case the system clock is not synchronized and not to overload the API." false
        sleep "$sleep_time"
    else
        log_message "D: No delay of download of Tibber data since DEBUG variable set."
    fi
    if ! get_tibber_api | tr -d '{}[]' >"$file"; then
        log_message >&2 "E: Download of Tibber prices from '$url' to '$file' failed."
        exit_with_cleanup 1
    fi
    log_message "D: Raw Tibber response written to $file with $(wc -l < "$file") lines."

    sed -n '/"today":/,/"tomorrow":/p' "$file" | sed '$d' | sed '/"today":/d' >"$file15"
    sort -t, -k4 "$file15" >"$file16"
    sed -n '/"tomorrow":/,$p' "$file" | sed '/"tomorrow":/d' >"$file17"
    sort -t, -k4 "$file17" >"$file18"
    if [ "$include_second_day" = 0 ]; then
        cp "$file16" "$file12"
    else
        cat "$file16" "$file18" > "$file12"
    fi

    timestamp=$(TZ=$TZ date +%d)
    echo "date_now_day: $timestamp" >>"$file"
    echo "date_now_day: $timestamp" >>"$file15"
    echo "date_now_day: $timestamp" >>"$file17"
    echo "date_now_day: $timestamp" >>"$file12"

    if [ ! -s "$file16" ]; then
        log_message >&2 "E: Tibber prices cannot be extracted to '$file16', falling back to aWATTar API."
        use_tibber=0
        rm "$file"
        sleep 120
        select_pricing_api="1"
        use_awattar_api
        if [ -f "$file2" ] && [ "$(wc -l <"$file2")" -gt 10 ]; then
            loop_prices= $((prices_per_day * 2))
        fi
    fi
}

download_entsoe_prices() {
 
    local url="$1"
    local file="$2"
    local output_file="$3"
    local sleep_time="$4"

    if [ -z "$DEBUG" ]; then
        log_message >&2 "I: Please be patient. First we wait $sleep_time seconds in case the system clock is not synchronized and not to overload the API."
        sleep "$sleep_time"
    else
        log_message "D: No delay of download of Entsoe data since DEBUG variable set."
    fi

    if ! curl "$url" >"$file"; then
        log_message >&2 "E: Retrieval of Entsoe data from '$url' into file '$file' failed."
        exit_with_cleanup 1
    fi
    if ! test -f "$file"; then
        log_message >&2 "E: Could not find file '$file' with Entsoe price data. Curl itself reported success."
        exit_with_cleanup 1
    fi
    if [ -n "$DEBUG" ]; then
        log_message "D: Entsoe file '$file' with price data downloaded"
    fi
    if [ ! -s "$file" ]; then
        log_message >&2 "E: Entsoe file '$file' is empty, please check your Entsoe API Key."
        exit_with_cleanup 1
    fi

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
        max_positions = '"$prices_per_day"'
        for (i = 1; i <= max_positions; i++) {
            positions[i] = ""
        }
    }
    /<Period>/ { capture_period = 1 }
    /<\/Period>/ { capture_period = 0; valid_period = 0 }
    capture_period && /<resolution>'"$resolution"'<\/resolution>/ { valid_period = 1 }
    valid_period && /<position>/ {
        gsub("<position>", "", $0); gsub("</position>", "", $0); gsub(/^[\t ]+|[\t ]+$/, "", $0)
        current_position = $0
    }
    valid_period && /<price.amount>/ {
        gsub("<price.amount>", "", $0); gsub("</price.amount>", "", $0); gsub(/^[\t ]+|[\t ]+$/, "", $0)
        last_price = $0
        positions[current_position] = last_price
    }
    /<Reason>/ { in_reason = 1; error_message = "" }
    in_reason && /<code>/ { gsub(/<code>|<\/code>/, ""); gsub(/^[\t ]+|[\t ]+$/, "", $0); error_code = $0 }
    in_reason && /<text>/ { gsub(/<text>|<\/text>/, ""); gsub(/^[\t ]+|[\t ]+$/, "", $0); error_message = $0 }
    /<\/Reason>/ { in_reason = 0 }
    END {
        for (i = 1; i <= max_positions; i++) {
            if (positions[i] == "") positions[i] = (i == 1 ? last_price : positions[i-1])
            if (positions[i] != "") prices = prices positions[i] ORS
        }
        if (error_code == 999) print "E: Entsoe data retrieval error found in the XML data:", error_message
        else if (prices != "") printf "%s", prices > "'"$output_file"'"
        else print "E: No prices found in the XML data."
    }' "$file"

    if [ -f "$output_file" ]; then
        sort -g "$output_file" > "${output_file%.*}_sorted.${output_file##*.}"
        line_count=$(grep -v "^date_now_day" "$output_file" | wc -l)
        if [ "$line_count" -lt $prices_per_day ]; then
            log_message >&2 "E: Warning. $output_file has only price data for $line_count prices. Maybe API error. Please check XML data if prices are missing."
            log_message >&2 "E: Fallback to aWATTar API."
            select_pricing_api="1"
            use_awattar_api
        fi
        timestamp=$(TZ=$TZ date +%d)
        echo "date_now_day: $timestamp" >>"$file"
        echo "date_now_day: $timestamp" >>"$output_file"
        echo "date_now_day: $timestamp" >>"${output_file%.*}_sorted.${output_file##*.}"

        if [ "$include_second_day" = 1 ] && grep -q "$resolution" "$file" && [ "$(wc -l <"$output_file")" -gt 3 ]; then
            cat "$file10" > "$file8"
            if [ -f "$file13" ]; then
                cat "$file13" >> "$file8"
            fi
            sed -i "$((prices_per_day +1))d;$((prices_per_day *2 +1))d" "$file8"
            sort -g "$file8" > "$file19"
            echo "date_now_day: $timestamp" >>"$file8"
            if [ -f "$file9" ]; then
                line_count2=$(grep -v "^date_now_day" "$file9" | wc -l)
                if [ "$line_count2" -lt $prices_per_day ]; then
                    log_message >&2 "E: Warning. $file9 has only price data for $line_count2 prices. Maybe API error. Please check XML data if prices are missing."
                fi
            fi
        else
            cp "$file11" "$file19"
        fi
        if [ -n "$DEBUG" ]; then
            log_message "D: Contents of $output_file after processing:"
            cat "$output_file" >&2
            log_message "D: Contents of $file8 after combining (if applicable):"
            cat "$file8" >&2
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
            log_message "D: Solarenergy data downloaded successfully."
        fi
    fi
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

evaluate_conditions() {
    local -n conditions=$1
    local -n descriptions=$2
    local execute_flag_name=$3
    local -n condition_met_description=$4

    local flag_value=0
    condition_met_description=""

    for i in "${!conditions[@]}"; do
        if (( ${conditions[$i]} )); then
            flag_value=1
            condition_met_description="${condition_met_description}${descriptions[$i]}; "
            if [[ $DEBUG -eq 1 ]]; then
                log_message "D: Condition met: ${descriptions[$i]}"
            fi
        fi
    done

    # Direkte Zuweisung statt printf
    eval "$execute_flag_name=$flag_value"

    if [ "$flag_value" -eq 0 ]; then
        condition_met_description=""
    else
        condition_met_description="${condition_met_description%; }"
    fi
}

is_charging_economical() {
    local reference_price="$1"
    local total_cost="$2"

    local is_economical=1
    [[ $reference_price -ge $total_cost ]] && is_economical=0

    if [ -n "$DEBUG" ]; then
        log_message "D: is_charging_economical [ $is_economical - $([ "$is_economical" -eq 1 ] && echo "false" || echo "true") ]."
        reference_price_euro=$(millicentToEuro "$reference_price")
        total_cost_euro=$(millicentToEuro "$total_cost")
        is_economical_str=$([ "$is_economical" -eq 1 ] && echo "false" || echo "true")
        log_message "D: if [ reference_price $reference_price_euro > total_cost $total_cost_euro ] result is $is_economical_str."
    fi

    return $is_economical
}

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

manage_fritz_sockets() {
    local action=$1
    [ "$action" != "off" ] && action=$([ "$execute_fritzsocket_on" == "1" ] && echo "on" || echo "off")
    if [ "$fritz_sockets_state" = "$action" ]; then
        if [ -n "$DEBUG" ]; then
            log_message "D: Fritz sockets already $action, skipping action."
        fi
        return 0
    fi

    if fritz_login; then
        log_message >&2 "I: Turning $action Fritz sockets."
        for socket in "${sockets[@]}"; do
            [ "$socket" != "0" ] && manage_fritz_socket "$action" "$socket"
        done
        fritz_sockets_state="$action"
    else
        log_message >&2 "E: Fritz login failed."
        fritz_sockets_state="unknown"
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
    # Prüfen, ob bereits eine gültige sid existiert
    if [ -n "$sid" ] && [ "$sid" != "0000000000000000" ]; then
        # Teste die Gültigkeit der aktuellen sid mit einem einfachen Aufruf
        test_sid=$(curl -s "http://$fbox/login_sid.lua?sid=$sid" | grep -o "<SID>[a-z0-9]\{16\}" | cut -d'>' -f 2)
        if [ "$test_sid" = "$sid" ]; then
            if [ -n "$DEBUG" ]; then
                log_message "D: Existing Fritz!Box session with SID $sid is still valid."
            fi
            return 0
        else
            log_message >&2 "I: Current SID $sid is no longer valid, performing new login."
            sid=""
        fi
    fi

    # Login durchführen, wenn keine gültige sid vorhanden ist
    challenge=$(curl -s "http://$fbox/login_sid.lua" | grep -o "<Challenge>[a-z0-9]\{8\}" | cut -d'>' -f 2)
    if [ -z "$challenge" ]; then
        log_message >&2 "E: Could not retrieve challenge from login_sid.lua."
        sid=""
        return 1
    fi

    hash=$(echo -n "$challenge-$passwd" | sed -e 's,.,&\n,g' | tr '\n' '\0' | md5sum | grep -o "[0-9a-z]\{32\}")
    sid=$(curl -s "http://$fbox/login_sid.lua" -d "response=$challenge-$hash" -d "username=$user" |
        grep -o "<SID>[a-z0-9]\{16\}" | cut -d'>' -f 2)

    if [ "$sid" = "0000000000000000" ]; then
        log_message >&2 "E: Login to Fritz!Box failed."
        sid=""
        return 1
    fi

    if [ -n "$DEBUG" ]; then
        log_message "D: Login to Fritz!Box successful with SID $sid."
    fi
    return 0
}

manage_shelly_sockets() {
    local action=$1
    [ "$action" != "off" ] && action=$([ "$execute_shellysocket_on" == "1" ] && echo "on" || echo "off")

    if [ "$shelly_sockets_state" = "$action" ]; then
        if [ -n "$DEBUG" ]; then
            log_message "D: Shelly sockets already $action, skipping action."
        fi
        return 0
    fi

    log_message >&2 "I: Turning $action Shelly sockets."
    local success=true
    for ip in "${shelly_ips[@]}"; do
        if [ "$ip" != "0" ] && [ -n "$ip" ]; then
            manage_shelly_socket "$action" "$ip" || success=false
        else
            log_message >&2 "D: Skipping invalid or empty Shelly IP: $ip"
        fi
    done

    if [ "$success" = true ]; then
        shelly_sockets_state="$action"
    else
        shelly_sockets_state="unknown"
        log_message >&2 "E: One or more Shelly socket actions failed, state set to unknown."
    fi
}

manage_shelly_socket() {
    local action=$1
    local ip=$2
    if [ "$1" != "off" ] && [ "$economic" == "expensive" ] && { [ "$use_charger" != "0" ]; }; then
        log_message >&2 "I: Disabling inverter while switching."
        charger_disable_inverter >/dev/null
    fi
    if [ -n "$ip" ]; then
        curl -s -u "$shellyuser:$shellypasswd" "http://$ip/relay/0?turn=$action" -o /dev/null || log_message >&2 "E: Could not execute switch-$action of Shelly socket with IP $ip - ignored."
    else
        log_message >&2 "D: No valid IP provided for Shelly socket, skipping."
    fi
}

millicentToEuro() {
    local millicents="$1"
    local EURO_FACTOR=100000000000000000
    local DECIMAL_FACTOR=10000000000000
    local euro_main_part=$((millicents / EURO_FACTOR))
    local euro_decimal_part=$(((millicents % EURO_FACTOR) / DECIMAL_FACTOR))
    printf "%d.%04d\n" "$euro_main_part" "$euro_decimal_part"
}

euroToMillicent() {
    euro="$1"
    potency="$2"

    if [ -z "$potency" ]; then
        potency=14
    fi

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

    # Nur ausgeben, wenn DEBUG gesetzt ist oder es keine Debug-Meldung ist
    if [ "$prefix" = "D:" ] && [ -z "$DEBUG" ]; then
        return
    fi

    case "$prefix" in
    "E:") color="\033[1;31m" ;;
    "D:") color="\033[1;34m"; writeToLog=false ;;
    "W:") color="\033[1;33m" ;;
    "I:") color="\033[1;32m" ;;
    esac

    writeToLog="${2:-$writeToLog}"
    printf "${color}%b\033[0m\n" "$msg"
    if [ "$writeToLog" == "true" ]; then
        echo -e "$msg" | sed 's/\x1b\[[0-9;]*m//g' >>"$LOG_FILE"
    fi
}

exit_with_cleanup() {
    local exit_code="$1"
    log_message >&2 "I: Cleanup and exit with error $exit_code"
    if ((use_charger != 0)); then
        manage_charging "off" "Turn off charging."
    fi
    if ((execute_discharging == 0 && use_charger != 0)); then
        manage_discharging "on" "Spotmarket-Switcher is disabling itself. Maybe there is no internet connection."
    fi
    if ((use_fritz_dect_sockets == 1)); then
        manage_fritz_sockets "off"
    fi
    if ((use_shelly_wlan_sockets == 1)); then
        manage_shelly_sockets "off"
    fi
    cleanup
    exit "$exit_code"
}

checkAndClean() {
    scriptFile1="$DIR/$CONFIG"
    scriptFile2="$DIR/controller.sh"
    currentTime=$(date +%s)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        lastModified1=$(stat -f "%m" "$scriptFile1")
        lastModified2=$(stat -f "%m" "$scriptFile2")
    else
        lastModified1=$(stat -c %Y "$scriptFile1")
        lastModified2=$(stat -c %Y "$scriptFile2")
    fi
    difference1=$(( (currentTime - lastModified1) / 60 ))
    difference2=$(( (currentTime - lastModified2) / 60 ))
    if [ "$difference1" -lt 60 ] || [ "$difference2" -lt 60 ]; then
        log_message >&2 "I: Config or Controller was changed within the last 60 minutes. Cleaning /tmp directory."
        rm -f /tmp/tibber*.*
        rm -f /tmp/awattar*.*
        rm -f /tmp/entsoe*.*
        rm -f "$file3"
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

ignore_past_prices() {
    if (( ignore_past_hours == 1 )); then
        local current_hour=$(TZ=$TZ date +%H)
        local current_min=$(TZ=$TZ date +%M)
        local prices_to_skip=$((10#$current_hour * (60 / 15) + 10#$current_min / 15))

        local price_file_source
        local sorted_file_source
        local price_file_filtered="/tmp/prices_filtered.tmp"
        local sorted_file_filtered="/tmp/prices_sorted_filtered.tmp"

        case "$select_pricing_api" in
            1) # aWATTar
                price_file_source="$file6"
                sorted_file_source="$file7"
                ;;
            2) # Entsoe
                price_file_source="$file8"
                sorted_file_source="$file19"
                ;;
            3) # Tibber
                price_file_source="$file12"
                sorted_file_source="$file12"
                ;;
            *)
                log_message >&2 "E: Invalid value for select_pricing_api: $select_pricing_api"
                exit 1
                ;;
        esac

        local available_lines=$(grep -v "date_now_day" "$price_file_source" | wc -l | tr -d ' ')

        if [ "$available_lines" -eq 0 ]; then
            log_message >&2 "E: No price data available in $price_file_source."
            loop_prices=0
            return
        fi

        if [ "$prices_to_skip" -ge "$available_lines" ]; then
            log_message >&2 "W: All $available_lines prices are in the past. No future prices available."
            loop_prices=0
            return
        fi

        log_message >&2 "I: Ignored $prices_to_skip past prices. Remaining prices: $((available_lines - prices_to_skip))."

        grep -v "date_now_day" "$price_file_source" | tail -n +$((prices_to_skip + 1)) > "$price_file_filtered"
        sort -g "$price_file_filtered" > "$sorted_file_filtered"
        echo "date_now_day: $(TZ=$TZ date +%d)" >> "$sorted_file_filtered"

        # Die globalen Variablen, die von anderen Funktionen verwendet werden,
        # werden auf die temporären Dateien umgeleitet.
        if [ "$select_pricing_api" -eq 1 ]; then
            file6="$price_file_filtered"
            file7="$sorted_file_filtered"
        elif [ "$select_pricing_api" -eq 2 ]; then
            file8="$price_file_filtered"
            file19="$sorted_file_filtered"
        elif [ "$select_pricing_api" -eq 3 ]; then
            file11="$price_file_filtered"
            file12="$sorted_file_filtered"
        fi

        loop_prices=$(grep -v "date_now_day" "$price_file_filtered" | wc -l | tr -d ' ')

        if [ -n "$DEBUG" ]; then
            log_message "D: Contents of $price_file_filtered after filtering:"
            cat "$price_file_filtered" >&2
            log_message "D: Contents of $sorted_file_filtered after sorting:"
            cat "$sorted_file_filtered" >&2
        fi
    fi
}

get_current_awattar_day() { current_awattar_day=$(sed -n 3p "$file1" | grep -Eo '[0-9]+'); }
get_current_awattar_day2() { current_awattar_day2=$(sed -n 3p "$file2" | grep -Eo '[0-9]+'); }

use_awattar_api() {

    local tomorrow_check=0
    if [ "$include_second_day" = 1 ] && [ "$(TZ=$TZ date +%H)" -ge 13 ]; then
        tomorrow_check=1
    fi
    
    local api_link="$link1"
    if [ "$tomorrow_check" -eq 1 ]; then
        api_link="$link2" # This should point to the URL with ?tomorrow=include
    fi

    local today=$(TZ=$TZ date +%d)

    # Fetch all data (today + tomorrow if needed) in one call
    if test -f "$file1"; then
        local file_day=$(grep "date_now_day" "$file1" | tail -n1 | awk '{print $2}' | tr -d ':')
        if [ "$file_day" = "$today" ]; then
            log_message >&2 "I: aWATTar today-data is up to date." false
            log_message "D: Using cached today data from $file1."
        else
            log_message >&2 "I: aWATTar today-data is outdated or missing (file day: $file_day, today: $today), fetching new data." false
            rm -f "$file1" "$file6" "$file7"
            download_awattar_prices "$api_link" "$file1" "$file6" $((RANDOM % 21 + 10))
        fi
    else
        log_message >&2 "I: No cached aWATTar data, fetching new data." false
        download_awattar_prices "$api_link" "$file1" "$file6" $((RANDOM % 21 + 10))
    fi

    # After fetching, always sort the combined data to create the sorted file7
    if [ -f "$file6" ]; then
        sort -g "$file6" > "$file7"
    else
        log_message >&2 "E: Failed to create price file."
        exit 1
    fi

    log_message "D: Prices for today+tomorrow combined into $file6 and sorted into $file7."
    log_message "I: A total of $(grep -v "date_now_day" "$file6" | wc -l | tr -d ' ') 15-minute-prices were fetched."
}


get_awattar_prices() {
    if [ "$ignore_past_hours" -eq 1 ]; then
        current_price=$(sed -n "1p" "$file6" | grep -v "date_now_day")
        average_price=$(grep -E '^[0-9]+\.[0-9]+$' "$file7" | awk '{sum+=$1; count++} END {if (count > 0) print sum/count}')
        highest_price=$(grep -E '^[0-9]+\.[0-9]+$' "$file7" | tail -n1)
        mapfile -t sorted_prices < <(grep -E '^[0-9]+\.[0-9]+$' "$file7")
    else
        current_price=$(sed -n "${now_price}p" "$file6" | grep -v "date_now_day")
        average_price=$(grep -E '^[0-9]+\.[0-9]+$' "$file7" | awk '{sum+=$1; count++} END {if (count > 0) print sum/count}')
        highest_price=$(grep -E '^[0-9]+\.[0-9]+$' "$file7" | tail -n1)
        mapfile -t sorted_prices < <(grep -E '^[0-9]+\.[0-9]+$' "$file7")
    fi
    for i in "${!sorted_prices[@]}"; do
        eval "P$((i+1))=${sorted_prices[$i]}"
    done
    if [ -n "$DEBUG" ]; then
        log_message "D: Current price: $current_price, Average price: $average_price, Highest price: $highest_price"
        log_message "D: Sorted prices from $file7:"
        cat "$file7" >&2
    fi
}

process_tibber_data() {
    local raw_file="$1"
    if [ ! -s "$raw_file" ]; then
        log_message >&2 "E: Raw Tibber file $raw_file is empty or missing during processing."
        return 1
    fi

    sed -n '/"today":/,/"tomorrow":/p' "$raw_file" | sed '$d' | sed '/"today":/d' >"$file15"
    sort -t, -k4 "$file15" >"$file16"
    sed -n '/"tomorrow":/,$p' "$raw_file" | sed '/"tomorrow":/d' >"$file17"
    sort -t, -k4 "$file17" >"$file18"

    if [ "$include_second_day" = 0 ]; then
        cp "$file16" "$file12"
    else
        cat "$file16" "$file18" > "$file12"
    fi

    timestamp=$(TZ=$TZ date +%d)
    echo "date_now_day: $timestamp" >>"$file15"
    echo "date_now_day: $timestamp" >>"$file17"
    echo "date_now_day: $timestamp" >>"$file12"

    if [ ! -s "$file16" ]; then
        log_message >&2 "E: Tibber prices cannot be extracted to '$file16' during processing."
        return 1
    fi

    log_message "D: Processed Tibber data into sorted files."
    return 0
}

use_tibber_api() {
    local today=$(TZ=$TZ date +%d)
    local tomorrow=$(TZ=$TZ date -d @$(( $(date +%s) + 86400 )) +%Y-%m-%d)
    local current_hour=$(TZ=$TZ date +%H)
    local needs_processing=true

    # Check for cached raw data
    if test -f "$file14"; then
        local file_day=$(grep "date_now_day" "$file14" | tail -n1 | awk '{print $2}' | tr -d ':')
        if [ "$file_day" = "$today" ]; then
            log_message >&2 "I: Tibber today-data is up to date." false
            log_message "D: Using cached data from $file14 for today."

            # Check if processed files are up-to-date
            if [ -f "$file15" ] && [ "$(grep "date_now_day" "$file15" | tail -n1 | awk '{print $2}' | tr -d ':')" = "$today" ]; then
                needs_processing=false
                log_message "D: Processed Tibber files are up-to-date; skipping reprocessing."
            else
                log_message "D: Processed Tibber files missing or outdated; reprocessing from cached raw data."
            fi
        else
            log_message >&2 "I: Tibber today-data is outdated or missing (file day: $file_day, today: $today), fetching new data." false
            rm -f "$file12" "$file14" "$file15" "$file16" "$file17" "$file18"
            download_tibber_prices "$link6" "$file14" $((RANDOM % 21 + 10))
            return  # Download already processes
        fi
    else
        log_message >&2 "I: No cached Tibber today-data, fetching new data." false
        rm -f "$file12" "$file14" "$file15" "$file16" "$file17" "$file18"
        download_tibber_prices "$link6" "$file14" $((RANDOM % 21 + 10))
        return
    fi

    # Reprocess if needed
    if [ "$needs_processing" = true ]; then
        process_tibber_data "$file14" || {
            log_message >&2 "E: Processing failed on cached data; forcing fresh download."
            rm -f "$file12" "$file14" "$file15" "$file16" "$file17" "$file18"
            download_tibber_prices "$link6" "$file14" $((RANDOM % 21 + 10))
            return
        }
    fi

    # Check if tomorrow’s data is missing after 13:00 and include_second_day=1
    if [ "$include_second_day" = 1 ] && [ "$current_hour" -ge 13 ]; then
        if [ ! -s "$file18" ] || ! grep -q "$tomorrow" "$file18"; then
            log_message >&2 "W: Tomorrow data missing or outdated after 13:00, forcing refresh."
            rm -f "$file12" "$file14" "$file15" "$file16" "$file17" "$file18"
            download_tibber_prices "$link6" "$file14" $((RANDOM % 21 + 10))
            return
        fi
    fi

    # Combine today’s and tomorrow’s data based on include_second_day
    if [ "$include_second_day" = 1 ]; then
        if [ ! -s "$file18" ] || ! grep -q "$tomorrow" "$file18"; then
            log_message >&2 "I: No valid tomorrow data in $file18 for $tomorrow or file empty, using only today’s data." false
            cp "$file16" "$file12"
        else
            log_message "D: Valid tomorrow data found in $file18."
            cat "$file16" "$file18" > "$file12"
            log_message "D: Combined today ($file16) and tomorrow ($file18) into $file12."
        fi
    else
        cp "$file16" "$file12"
        log_message "D: Using only today’s data ($file16) in $file12 as include_second_day=0."
    fi
}


get_tibber_prices() {
    if [ "$ignore_past_hours" -eq 1 ]; then
        current_price=$(sed -n "1p" "$file15" | sed -n "s/.*\"${price_unit}\":\([^,]*\),.*/\1/p" | grep -v "date_now_day" || echo "")
        if [ -z "$current_price" ]; then
            current_price=$(sed -n "1p" "$file12" | sed -n "s/.*\"${price_unit}\":\([^,]*\),.*/\1/p" | grep -v "date_now_day" || echo "0")
            log_message >&2 "W: Could not determine current price for hour $current_hour from $file15, using first filtered price: $current_price"
        fi
        average_price=$(sed -n "s/.*\"${price_unit}\":\([^,]*\),.*/\1/p" "$file12" | grep -v "date_now_day" | awk '{sum+=$1; count++} END {if (count > 0) print sum/count}' || echo "0")
        highest_price=$(sed -n "s/.*\"${price_unit}\":\([^,]*\),.*/\1/p" "$file12" | grep -v "date_now_day" | sort -g | tail -n1 || echo "0")
        mapfile -t sorted_prices < <(sed -n "s/.*\"${price_unit}\":\([^,]*\),.*/\1/p" "$file12" | grep -v "date_now_day" | sort -g)
    else
        current_price=$(sed -n "${now_price}p" "$file15" | sed -n "s/.*\"${price_unit}\":\([^,]*\),.*/\1/p" | grep -v "date_now_day" || echo "0")
        average_price=$(sed -n "s/.*\"${price_unit}\":\([^,]*\),.*/\1/p" "$file12" | grep -v "date_now_day" | awk '{sum+=$1; count++} END {if (count > 0) print sum/count}' || echo "0")
        highest_price=$(sed -n "s/.*\"${price_unit}\":\([^,]*\),.*/\1/p" "$file12" | grep -v "date_now_day" | sort -g | tail -n1 || echo "0")
        mapfile -t sorted_prices < <(sed -n "s/.*\"${price_unit}\":\([^,]*\),.*/\1/p" "$file12" | grep -v "date_now_day" | sort -g)
    fi
    for i in "${!sorted_prices[@]}"; do
        eval "P$((i+1))=${sorted_prices[$i]}"
    done
    if [ -n "$DEBUG" ]; then
        log_message "D: Current price: $current_price, Average price: $average_price, Highest price: $highest_price"
        log_message "D: Sorted prices from $file12:"
        cat "$file12" >&2
    fi
}

get_current_entsoe_day() { current_entsoe_day=$(sed -n 25p "$file10" | grep -Eo '[0-9]+'); }

get_current_tibber_day() { current_tibber_day=$(sed -n 25p "$file15" | grep -Eo '[0-9]+'); }

use_entsoe_api() {
        log_message >&2 "I: EntsoE API supports only 15-min prices. Fallback to quarter-hourly mode."

    local today=$(TZ=$TZ date +%d)
    local tomorrow=$(TZ=$TZ date -d @$(( $(date +%s) + 86400 )) +%Y-%m-%d)
    local current_hour=$(TZ=$TZ date +%H)

    # Fetch today’s data
    if test -f "$file10"; then
        local file_day=$(grep "date_now_day" "$file10" | tail -n1 | awk '{print $2}' | tr -d ':')
        if [ "$file_day" = "$today" ]; then
            log_message >&2 "I: Entsoe today-data is up to date." false
            log_message "D: Using cached today data from $file10."
        else
            log_message >&2 "I: Entsoe today-data is outdated or missing (file day: $file_day, today: $today), fetching new data." false
            rm -f "$file4" "$file5" "$file8" "$file9" "$file10" "$file11" "$file13" "$file19"
            download_entsoe_prices "$link4" "$file4" "$file10" $((RANDOM % 21 + 10))
        fi
    else
        log_message >&2 "I: No cached Entsoe today-data, fetching new data." false
        download_entsoe_prices "$link4" "$file4" "$file10" $((RANDOM % 21 + 10))
    fi
    sort -g "$file10" > "$file11"  # Ensure today’s data is sorted
    cp "$file11" "$file19"         # Default output file

    # Handle tomorrow’s data if include_second_day=1
    if [ "$include_second_day" = 1 ]; then
        if [ "$current_hour" -ge 13 ]; then
            if [ ! -s "$file13" ] || ! grep -q "$tomorrow" "$file5"; then
                log_message >&2 "W: Tomorrow data missing or outdated after 13:00, forcing refresh."
                rm -f "$file5" "$file9" "$file13"
                download_entsoe_prices "$link5" "$file5" "$file13" $((RANDOM % 21 + 10))
                # Combine today and tomorrow
                cat "$file10" "$file13" > "$file8"
                sed -i "$((prices_per_day +1))d;$((prices_per_day *2 +1))d" "$file8"
                sort -g "$file8" > "$file19"
                echo "date_now_day: $today" >> "$file8"
                log_message "D: Combined today ($file10) and tomorrow ($file13) into $file19."
            else
                log_message "D: Cached tomorrow data in $file13 is valid for $tomorrow."
                # Combine cached today and tomorrow
                cat "$file10" "$file13" > "$file8"
                sed -i "$((prices_per_day +1))d;$((prices_per_day *2 +1))d" "$file8"
                sort -g "$file8" > "$file19"
                echo "date_now_day: $today" >> "$file8"
                log_message "D: Combined cached today ($file10) and tomorrow ($file13) into $file19."
            fi
        else
            log_message "D: Before 13:00, not checking tomorrow data."
        fi
    fi
}

get_entsoe_prices() {
if [ "$ignore_past_hours" -eq 1 ]; then
current_price=$(sed -n "1p" "$file8" | grep -v "date_now_day")
average_price=$(grep -E '^-?[0-9]+(.[0-9]+)?$' "$file19" | awk '{sum+=$1; count++} END {if (count > 0) print sum/count}')
highest_price=$(grep -E '^-?[0-9]+(.[0-9]+)?$' "$file19" | tail -n1)
mapfile -t sorted_prices < <(grep -E '^-?[0-9]+(.[0-9]+)?$' "$file19")
else
current_price=$(sed -n "${now_price}p" "$file10" | grep -v "date_now_day")
average_price=$(grep -E '^-?[0-9]+(.[0-9]+)?$' "$file19" | awk '{sum+=$1; count++} END {if (count > 0) print sum/count}')
highest_price=$(grep -E '^-?[0-9]+(.[0-9]+)?$' "$file19" | tail -n1)
mapfile -t sorted_prices < <(grep -E '^-?[0-9]+(.[0-9]+)?$' "$file19")
fi
for i in "${!sorted_prices[@]}"; do
eval "P$((i+1))=${sorted_prices[$i]}"
done
if [ -n "$DEBUG" ]; then
log_message "D: Current price: $current_price, Average price: $average_price, Highest price: $highest_price"
log_message "D: Sorted prices from $file19:"
cat "$file19" >&2
fi
}

convert_vars_to_integer() {
    local potency="$1"
    shift
    for var in "$@"; do
        local integer_var="${var}_integer"
        printf -v "$integer_var" '%s' "$(euroToMillicent "${!var}" "$potency")"
        local value="${!integer_var}"
        if [ -n "$DEBUG" ]; then
            log_message "D: Variable: $var | Original: ${!var} | Integer: $value | Len: ${#value}"
        fi
    done
}

get_awattar_prices_integer() {
    local price_vars=()
    for i in $(seq 1 "$loop_prices"); do
        price_vars+=("P$i")
    done
    price_vars+=(average_price highest_price current_price start_price feedin_price energy_fee abort_price battery_lifecycle_costs_cent_per_kwh)
    convert_vars_to_integer 15 "${price_vars[@]}"
}

get_tibber_prices_integer() {
    local price_vars=()
    for i in $(seq 1 "$loop_prices"); do
        price_vars+=("P$i")
    done
    price_vars+=(average_price highest_price current_price)
    convert_vars_to_integer 17 "${price_vars[@]}"
    convert_vars_to_integer 15 start_price feedin_price energy_fee abort_price battery_lifecycle_costs_cent_per_kwh
}

get_prices_integer_entsoe() {
    local price_vars=()
    for i in $(seq 1 "$loop_prices"); do
        price_vars+=("P$i")
    done
    price_vars+=(average_price highest_price current_price)
    convert_vars_to_integer 14 "${price_vars[@]}"
    convert_vars_to_integer 15 start_price feedin_price energy_fee abort_price battery_lifecycle_costs_cent_per_kwh
}

####################################
###    Begin of the script...    ###
####################################

DIR="$(dirname "$0")"

if [ -z "$LOG_FILE" ]; then
    LOG_FILE="/tmp/spotmarket-switcher.log"
fi
if [ -z "$LOG_MAX_SIZE" ]; then
    LOG_MAX_SIZE=1024
fi
if [ -z "$LOG_FILES_TO_KEEP" ]; then
    LOG_FILES_TO_KEEP=2
fi

if [ -z "$CONFIG" ]; then
    CONFIG="config.txt"
fi

# 1. Konfiguration und Tools prüfen
if [ -f "$DIR/$CONFIG" ]; then
    source "$DIR/$CONFIG"
else
    log_message >&2 "E: The file $DIR/$CONFIG was not found! Configure the existing sample.config.txt file and then save it as config.txt in the same directory." false
    exit 127
fi

if ! parse_and_validate_config "$DIR/$CONFIG"; then
    exit 127
fi

resolution="PT15M"
prices_per_day=$((1440 / 15))

num_tools_missing=0
SOC_percent=-1
tools="awk curl cat sed sort head tail"

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
        log_message >&2 "I: Executing mosquitto_pub -t $MQTT_TOPIC_SUB_SET_SOC -h $venus_os_mqtt_ip -p $venus_os_mqtt_port -m \"{\"value\":$target_soc}\""
        if mosquitto_pub -t "$MQTT_TOPIC_SUB_SET_SOC" -h "$venus_os_mqtt_ip" -p "$venus_os_mqtt_port" -m "{\"value\":$target_soc}" 2>/dev/null || true; then
            log_message >&2 "I: Successfully set SOC target to $target_soc via MQTT."
        else
            log_message >&2 "E: Failed to set SOC target via MQTT. Check broker at $venus_os_mqtt_ip:$venus_os_mqtt_port or topic $MQTT_TOPIC_SUB_SET_SOC."
        fi
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

if [ "$use_charger" == "2" ]; then
    tools="$tools mosquitto_sub mosquitto_pub"
    serial_number=$(mosquitto_sub -h "$venus_os_mqtt_ip" -p "$venus_os_mqtt_port" -t "${MQTT_TOPIC_PREFIX}N/#" -C 1 | grep -o '"value":"[^,]*' | sed 's/"value"://' | cut -d '}' -f 1 | tr -d '"')
    if [[ -z "$serial_number" ]]; then
        log_message >&2 "E: Victron MQTT system not found. Exit."
        exit 1
    fi
    MQTT_TOPIC_SUB="N/$serial_number/system/0/Dc/Battery/Soc"
    MQTT_TOPIC_PUB="R/$serial_number/keepalive"
    MQTT_TOPIC_SUB_CHARGE="W/$serial_number/settings/0/Settings/CGwacs/BatteryLife/Schedule/Charge/0/Day"
    MQTT_TOPIC_SUB_STOP_CHARGE="W/$serial_number/settings/0/Settings/CGwacs/BatteryLife/Schedule/Charge/0/Day"
    MQTT_TOPIC_SUB_SET_SOC="W/$serial_number/settings/0/Settings/CGwacs/BatteryLife/Schedule/Charge/0/Soc"
    MQTT_TOPIC_SUB_DISABLE_INV="W/$serial_number/settings/0/Settings/CGwacs/MaxDischargePower"
    MQTT_TOPIC_SUB_ENABLE_INV="W/$serial_number/settings/0/Settings/CGwacs/MaxDischargePower"

    keepalive_pid=""
    send_keepalive_for_charger2() {
        while [ "$use_charger" == "2" ]; do
            mosquitto_pub -t "$MQTT_TOPIC_PUB" -m "" -h "$venus_os_mqtt_ip" -p "$venus_os_mqtt_port" 2>/dev/null
            sleep 5
        done
    }
    send_keepalive_for_charger2 &
    keepalive_pid=$!

    SOC_percent=$(mosquitto_sub -h "$venus_os_mqtt_ip" -p "$venus_os_mqtt_port" -t "$MQTT_TOPIC_SUB" -C 1 | grep -o '"value":[^,]*' | sed 's/"value"://' | cut -d '.' -f 1)
    charger_command_charge() {
        log_message >&2 "I: Executing mosquitto_pub -t "$MQTT_TOPIC_SUB_STOP_CHARGE" -h "$venus_os_mqtt_ip" -p $venus_os_mqtt_port -m \"{\"value\":7}\""
        mosquitto_pub -t "$MQTT_TOPIC_SUB_STOP_CHARGE" -h "$venus_os_mqtt_ip" -p "$venus_os_mqtt_port" -m "{\"value\":7}"
    }
    charger_command_stop_charging() {
        log_message >&2 "I: Executing mosquitto_pub -t "$MQTT_TOPIC_SUB_STOP_CHARGE" -h "$venus_os_mqtt_ip" -p $venus_os_mqtt_port -m \"{\"value\":-7}\""
        mosquitto_pub -t "$MQTT_TOPIC_SUB_STOP_CHARGE" -h "$venus_os_mqtt_ip" -p "$venus_os_mqtt_port" -m "{\"value\":-7}"
    }
    charger_command_set_SOC_target() {
        log_message >&2 "I: Executing mosquitto_pub -t $MQTT_TOPIC_SUB_SET_SOC -h $venus_os_mqtt_ip -p $venus_os_mqtt_port -m \"{\"value\":$target_soc}\""
        mosquitto_pub -t "$MQTT_TOPIC_SUB_SET_SOC" -h "$venus_os_mqtt_ip" -p "$venus_os_mqtt_port" -m "{\"value\":$target_soc}"
    }
    charger_disable_inverter() {
        log_message >&2 "I: Executing mosquitto_pub -t "$MQTT_TOPIC_SUB_DISABLE_INV" -h "$venus_os_mqtt_ip" -p "$venus_os_mqtt_port" -m \"{\"value\":0}\""
        mosquitto_pub -t "$MQTT_TOPIC_SUB_DISABLE_INV" -h "$venus_os_mqtt_ip" -p "$venus_os_mqtt_port" -m "{\"value\":0}"
    }
    charger_enable_inverter() {
        log_message >&2 "I: Executing mosquitto_pub -t "$MQTT_TOPIC_SUB_ENABLE_INV" -h "$venus_os_mqtt_ip" -p "$venus_os_mqtt_port" -m \"{\"value\":$limit_inverter_power_after_enabling}\""
        mosquitto_pub -t "$MQTT_TOPIC_SUB_ENABLE_INV" -h "$venus_os_mqtt_ip" -p "$venus_os_mqtt_port" -m "{\"value\":$limit_inverter_power_after_enabling}"
    }
    if [ -z "$SOC_percent" ] || ! [[ "$SOC_percent" =~ ^[0-9]+$ ]] || (( SOC_percent < 0 || SOC_percent > 100 )); then
        log_message >&2 "E: Invalid SOC value: $SOC_percent. Must be an integer between 0 and 100."
        exit 1
    fi
fi

if [ "$use_charger" == "3" ]; then
    if ! command -v mosquitto_pub &> /dev/null || ! command -v mosquitto_sub &> /dev/null; then
        log_message >&2 "E: Error. mosquitto_pub or mosquitto_sub command not found. Please install mosquitto-clients."
        exit 1
    fi
    if ! [[ "$mqtt_broker_port_publish" =~ ^[1-9][0-9]{0,4}$ && "$mqtt_broker_port_publish" -le 65535 ]]; then
        log_message >&2 "E: Error. Invalid mqtt_broker_port_publish: $mqtt_broker_port_publish. Port must be between 1 and 65535."
        exit 1
    fi
    if ! [[ "$mqtt_broker_port_subscribe" =~ ^[1-9][0-9]{0,4}$ && "$mqtt_broker_port_subscribe" -le 65535 ]]; then
        log_message >&2 "E: Error. Invalid mqtt_broker_port_subscribe: $mqtt_broker_port_subscribe. Port must be between 1 and 65535."
        exit 1
    fi

    num_tools_missing=0
    SOC_percent=-1
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

if [ "$num_tools_missing" -gt 0 ]; then
    log_message >&2 "E: $num_tools_missing tools are missing."
    exit 127
fi

unset num_tools_missing

if [ -f "$DIR/license.txt" ]; then
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
file1=/tmp/awattar_today_prices.json
file2=/tmp/awattar_tomorrow_prices.json
file3=/tmp/expected_solarenergy.csv
file4=/tmp/entsoe_today_prices.xml
file5=/tmp/entsoe_tomorrow_prices.xml
file6=/tmp/awattar_prices.txt
file7=/tmp/awattar_prices_sorted.txt
file8=/tmp/entsoe_prices.txt
file9=/tmp/entsoe_tomorrow_prices_sorted.txt
file10=/tmp/entsoe_today_prices.txt
file11=/tmp/entsoe_today_prices_sorted.txt
file12=/tmp/tibber_prices_sorted_combined.txt
file13=/tmp/entsoe_tomorrow_prices.txt
file14=/tmp/tibber_prices.json
file15=/tmp/tibber_prices.txt
file16=/tmp/tibber_prices_sorted.txt
file17=/tmp/tibber_tomorrow_prices.txt
file18=/tmp/tibber_tomorrow_prices_sorted.txt
file19=/tmp/entsoe_prices_sorted.txt

########## Start ##########

echo >>"$LOG_FILE"

log_message >&2 "I: Bash Version: $(bash --version | head -n 1)"
log_message >&2 "I: Spotmarket-Switcher - Version $VERSION"

checkAndClean

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

    if [ -f "$file3" ] && [ -s "$file3" ]; then
        log_message >&2 "I: Sunrise today will be $sunrise_today and sunset will be $sunset_today. Suntime will be $suntime_today minutes."
        log_message >&2 "I: Solarenergy today will be $solarenergy_today megajoule per sqaremeter with $cloudcover_today percent clouds. The temperature is "$temp_today"°C with "$snow_today"cm snowdepth."
        log_message >&2 "I: Solarenergy tomorrow will be $solarenergy_tomorrow megajoule per squaremeter with $cloudcover_tomorrow percent clouds. The temperature will be "$temp_tomorrow"°C with "$snow_tomorrow"cm snowdepth."
        
        if ((abort_solar_yield_today_integer <= solarenergy_today_integer)) && ((abort_solar_yield_tomorrow_integer <= solarenergy_tomorrow_integer)); then
            log_message >&2 "I: There is enough solarenergy today and tomorrow. ESS can be used normally and no need to switch or charge. Spotmarket-Switcher will be disabled."
            execute_charging=0
            execute_discharging=1
            execute_fritzsocket_on=0
            execute_shellysocket_on=0
            if ((use_charger != 0)); then
                manage_discharging "on" "Sufficient solar energy available."
            fi
            exit_with_cleanup 0
        fi

        if ((abort_suntime <= suntime_today)); then
            log_message >&2 "I: There are enough sun minutes today. Spotmarket-Switcher will be disabled."
            execute_charging=0
            execute_discharging=1
            execute_fritzsocket_on=0
            execute_shellysocket_on=0
            if ((use_charger != 0)); then
                manage_discharging "on" "Sufficient suntime available."
            fi
            exit_with_cleanup 0
        fi
    else
        log_message >&2 "E: No solar data. Please check your internet connection and API Key or wait if it is a temporary error."
    fi
else
    log_message "D: Skipping Solarweather. Not activated."
fi



if ((select_pricing_api == 1)); then
    use_awattar_api  # Now handles both today and tomorrow if include_second_day=1
elif ((select_pricing_api == 2)); then
    use_entsoe_api   # Now handles both today and tomorrow if include_second_day=1
elif ((select_pricing_api == 3)); then
    use_tibber=1
    use_tibber_api   # Now handles both today and tomorrow if include_second_day=1
    if [ "$use_tibber" -eq 0 ]; then
        select_pricing_api="1"
        use_awattar_api
    fi
fi

loop_prices=$prices_per_day
if [ "$include_second_day" = 1 ]; then
    if [ "$select_pricing_api" = 1 ] && [ -f "$file2" ] && [ "$(wc -l <"$file2")" -gt 10 ]; then
        loop_prices=$((prices_per_day * 2))
    elif [ "$select_pricing_api" = 2 ] && [ -f "$file13" ] && [ "$(wc -l <"$file13")" -gt 10 ]; then
        loop_prices=$((prices_per_day * 2))
    elif [ "$select_pricing_api" = 3 ] && [ -f "$file17" ] && [ "$(wc -l <"$file17")" -gt 10 ]; then
        loop_prices=$((prices_per_day * 2))
    fi
fi

ignore_past_prices
fetch_prices

# 4. Aktuellen Preis prüfen
log_message >&2 "I: Please verify correct system time and timezone:\n   $(TZ=$TZ date)"
log_message >&2 "I: Current price is $current_price $Unit."

if ((abort_price_integer <= current_price_integer)); then
    log_message >&2 "I: Current price ($(millicentToEuro "$current_price_integer")€) is too high. Spotmarket-Switcher will be disabled if higher than ($(millicentToEuro "$abort_price_integer")€)."
    execute_charging=0
    execute_discharging=1
    execute_fritzsocket_on=0
    execute_shellysocket_on=0
    if ((use_charger != 0)); then
        manage_discharging "on" "Price exceeds abort threshold."
    fi
    exit_with_cleanup 0
fi

# 5. Preisdaten verarbeiten
    if [ "$loop_prices" -le 96 ]; then
        log_message >&2 "I: Using 96-price config matrix as base, adapting to $loop_prices prices."
        charge_array=("${config_matrix96_charge[@]}")
        discharge_array=("${config_matrix96_discharge[@]}")
        fritzsocket_array=("${config_matrix96_fritzsocket[@]}")
        shellysocket_array=("${config_matrix96_shellysocket[@]}")
        
        if [ "$loop_prices" -lt 96 ]; then
            log_message >&2 "D: Trimming arrays to $loop_prices prices."
            charge_array=("${charge_array[@]:0:$loop_prices}")
            discharge_array=("${discharge_array[@]:0:$loop_prices}")
            fritzsocket_array=("${fritzsocket_array[@]:0:$loop_prices}")
            shellysocket_array=("${shellysocket_array[@]:0:$loop_prices}")
        fi
    else
        log_message >&2 "I: Using 192-price config matrix as base, adapting to $loop_prices prices."
        charge_array=("${config_matrix192_charge[@]}")
        discharge_array=("${config_matrix192_discharge[@]}")
        fritzsocket_array=("${config_matrix192_fritzsocket[@]}")
        shellysocket_array=("${config_matrix192_shellysocket[@]}")
        
        if [ "$loop_prices" -lt 192 ]; then
            log_message >&2 "I: Trimming arrays to $loop_prices prices."
            charge_array=("${charge_array[@]:0:$loop_prices}")
            discharge_array=("${discharge_array[@]:0:$loop_prices}")
            fritzsocket_array=("${fritzsocket_array[@]:0:$loop_prices}")
            shellysocket_array=("${shellysocket_array[@]:0:$loop_prices}")
        fi
    fi

if [ "$loop_prices" -gt $((prices_per_day * 2)) ]; then
    log_message >&2 "E: Invalid loop_prices: $loop_prices. Maximum supported prices is $((prices_per_day * 2))."
    exit 1
fi

if [ -n "$DEBUG" ]; then
    log_message "D: charge_array after adjustment: ${charge_array[*]}"
    log_message "D: discharge_array after adjustment: ${discharge_array[*]}"
    log_message "D: fritzsocket_array after adjustment: ${fritzsocket_array[*]}"
    log_message "D: shellysocket_array after adjustment: ${shellysocket_array[*]}"
fi

charge_table=""
discharge_table=""
sid=""
shelly_sockets_state="unknown"
fritz_sockets_state="unknown"
fritz_switchable_sockets_table=""
shelly_switchable_sockets_table=""
for idx in "${!sorted_prices[@]}"; do
    i=$((idx + 1))
    charge_value="${charge_array[$idx]}"
    discharge_value="${discharge_array[$idx]}"
    fritzsocket_value="${fritzsocket_array[$idx]}"
    shellysocket_value="${shellysocket_array[$idx]}"

    if [ "$charge_value" -eq 1 ]; then
        charge_table="$charge_table $i"
    fi
    if [ "$use_charger" -ne 0 ] && [ "$SOC_percent" -ge "$discharge_value" ]; then
        discharge_table="$discharge_table $i"
    fi
    if [ "$fritzsocket_value" -eq 1 ]; then
        fritz_switchable_sockets_table="$fritz_switchable_sockets_table $i"
    fi
    if [ "$shellysocket_value" -eq 1 ]; then
        shelly_switchable_sockets_table="$shelly_switchable_sockets_table $i"
    fi
done

log_message >&2 "I: The average price will be $average_price $Unit."
log_message >&2 "I: Highest price will be $highest_price $Unit."
price_table=""
i=1
while true; do
    eval price=\$P$i
    if [ -z "$price" ]; then
        break
    fi
    price_table+="$i:$price "
    if [ $((i % 12)) -eq 0 ]; then
        price_table+="\n                  "
    fi
    i=$((i+1))
done
log_message >&2 "I: Sorted prices (low to high): $price_table"
log_message >&2 "I: Charge at price ranks:$charge_table"
log_message >&2 "I: Discharge at price ranks (if SOC >= min):$discharge_table"
log_message >&2 "I: Fritz switchable sockets at price ranks:$fritz_switchable_sockets_table"
log_message >&2 "I: Shelly switchable sockets at price ranks:$shelly_switchable_sockets_table"

# 6. Entscheidungen treffen

evaluate_conditions() {
    local -n conditions=$1
    local -n descriptions=$2
    local execute_flag_name=$3
    local -n condition_met_description=$4

    local flag_value=0
    condition_met_description=""

    for i in "${!conditions[@]}"; do
        if (( ${conditions[$i]} )); then
            flag_value=1
            condition_met_description="${condition_met_description}${descriptions[$i]}; "
            if [[ $DEBUG -eq 1 ]]; then
                log_message "D: Condition met: ${descriptions[$i]}"
            fi
        fi
    done

    # Direkte Zuweisung statt printf
    eval "$execute_flag_name=$flag_value"

    if [ "$flag_value" -eq 0 ]; then
        condition_met_description=""
    else
        condition_met_description="${condition_met_description%; }"
    fi
}

# 6. Entscheidungen treffen
charging_condition_met=""
discharging_condition_met=""
switchablesockets_condition_met=""
execute_charging=0
execute_discharging=0
execute_fritzsocket_on=0
execute_shellysocket_on=0

charging_conditions=(
    $((use_start_stop_logic == 1 && start_price_integer > current_price_integer))
    $((charge_at_solar_breakeven_logic == 1 && feedin_price_integer > current_price_integer + energy_fee_integer))
)
charging_descriptions=(
    "use_start_stop_logic ($use_start_stop_logic) == 1 && start_price_integer ($start_price_integer) > current_price_integer ($current_price_integer)"
    "charge_at_solar_breakeven_logic ($charge_at_solar_breakeven_logic) == 1 && feedin_price_integer ($feedin_price_integer) > current_price_integer ($current_price_integer) + energy_fee_integer ($energy_fee_integer)"
)

for i in "${!sorted_prices[@]}"; do
    ((i++))
    price_var="P${i}_integer"
    price_diff=$(( ${!price_var} - current_price_integer ))

    # Charging conditions
    if [ "${charge_array[$((i-1))]}" -eq 1 ]; then
        if [ "$price_diff" -ge -1 ] && [ "$price_diff" -le 1 ]; then
            charging_conditions+=(1)
            charging_descriptions+=("Charge at price rank $i because ${!price_var} ~= $current_price_integer")
            if [[ $DEBUG -eq 1 ]]; then
                log_message "D: Charge condition met at rank $i: Price=${!price_var} ~= $current_price_integer (diff=$price_diff)"
            fi
        else
            charging_conditions+=(0)
            if [[ $DEBUG -eq 1 ]]; then
                log_message "D: Charge condition not met at rank $i: Price mismatch (${!price_var} != $current_price_integer, diff=$price_diff)"
            fi
        fi
    else
        charging_conditions+=(0)
        if [[ $DEBUG -eq 1 ]]; then
            log_message "D: Charge condition not met at rank $i: charge_array[$((i-1))]=${charge_array[$((i-1))]} != 1"
        fi
    fi

    # Discharging conditions
    if [ "$SOC_percent" -ge "${discharge_array[$((i-1))]}" ]; then
        if [ "$price_diff" -ge -1 ] && [ "$price_diff" -le 1 ]; then
            discharging_conditions+=(1)
            discharging_descriptions+=("Discharge at price rank $i because SOC ($SOC_percent) >= ${discharge_array[$((i-1))]} and ${!price_var} ~= $current_price_integer")
            if [[ $DEBUG -eq 1 ]]; then
                log_message "D: Discharge condition met at rank $i: SOC=$SOC_percent >= ${discharge_array[$((i-1))]}, Price=${!price_var} ~= $current_price_integer (diff=$price_diff)"
            fi
        else
            discharging_conditions+=(0)
            if [[ $DEBUG -eq 1 ]]; then
                log_message "D: Discharge condition not met at rank $i: Price mismatch (${!price_var} != $current_price_integer, diff=$price_diff)"
            fi
        fi
    else
        discharging_conditions+=(0)
        if [[ $DEBUG -eq 1 ]]; then
            log_message "D: Discharge condition not met at rank $i: SOC=$SOC_percent < ${discharge_array[$((i-1))]}"
        fi
    fi

    # Fritz socket conditions
    if [ "${fritzsocket_array[$((i-1))]}" -eq 1 ]; then
        if [ "$price_diff" -ge -1 ] && [ "$price_diff" -le 1 ]; then
            fritzsocket_conditions+=(1)
            fritzsocket_conditions_descriptions+=("Fritz socket on at price rank $i because ${!price_var} ~= $current_price_integer")
            if [[ $DEBUG -eq 1 ]]; then
                log_message "D: Fritz socket condition met at rank $i: Price=${!price_var} ~= $current_price_integer (diff=$price_diff)"
            fi
        else
            fritzsocket_conditions+=(0)
            if [[ $DEBUG -eq 1 ]]; then
                log_message "D: Fritz socket condition not met at rank $i: Price mismatch (${!price_var} != $current_price_integer, diff=$price_diff)"
            fi
        fi
    else
        fritzsocket_conditions+=(0)
        if [[ $DEBUG -eq 1 ]]; then
            log_message "D: Fritz socket condition not met at rank $i: fritzsocket_array[$((i-1))]=${fritzsocket_array[$((i-1))]} != 1"
        fi
    fi

    # Shelly socket conditions
    if [ "${shellysocket_array[$((i-1))]}" -eq 1 ]; then
        if [ "$price_diff" -ge -1 ] && [ "$price_diff" -le 1 ]; then
            shellysocket_conditions+=(1)
            shellysocket_conditions_descriptions+=("Shelly socket on at price rank $i because ${!price_var} ~= $current_price_integer")
            if [[ $DEBUG -eq 1 ]]; then
                log_message "D: Shelly socket condition met at rank $i: Price=${!price_var} ~= $current_price_integer (diff=$price_diff)"
            fi
        else
            shellysocket_conditions+=(0)
            if [[ $DEBUG -eq 1 ]]; then
                log_message "D: Shelly socket condition not met at rank $i: Price mismatch (${!price_var} != $current_price_integer, diff=$price_diff)"
            fi
        fi
    else
        shellysocket_conditions+=(0)
        if [[ $DEBUG -eq 1 ]]; then
            log_message "D: Shelly socket condition not met at rank $i: shellysocket_array[$((i-1))]=${shellysocket_array[$((i-1))]} != 1"
        fi
    fi
done

evaluate_conditions charging_conditions charging_descriptions "execute_charging" "charging_condition_met"
log_message "D: discharging_conditions before evaluate: ${discharging_conditions[*]}"
evaluate_conditions discharging_conditions discharging_descriptions "execute_discharging" "discharging_condition_met"
log_message "D: After evaluate_conditions for discharging: execute_discharging=$execute_discharging, condition_met='$discharging_condition_met'"
evaluate_conditions fritzsocket_conditions fritzsocket_conditions_descriptions "execute_fritzsocket_on" "fritzsocket_condition_met"
evaluate_conditions shellysocket_conditions shellysocket_conditions_descriptions "execute_shellysocket_on" "shellysocket_condition_met"

if ((reenable_inverting_at_fullbatt == 1)) && ((SOC_percent >= reenable_inverting_at_soc)); then
    log_message >&2 "I: The battery is getting full. Re-enabling inverter. This is important on a DC-AC system to enable grid-feedin."
    execute_discharging=1
fi

percent_of_current_price_integer=$(awk "BEGIN {printf \"%.0f\", $current_price_integer*$energy_loss_percent/100}")
total_cost_integer=$((current_price_integer + percent_of_current_price_integer + battery_lifecycle_costs_cent_per_kwh_integer))

# 7. Steuerung ausführen
if ((use_charger != 0)); then
    if ((use_solarweather_api_to_abort == 1)) && [ -f "$file3" ] && [ -s "$file3" ]; then
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
    elif ((use_solarweather_api_to_abort == 1)); then
        if (($SOC_percent != -1)); then    
            target_soc=$(get_target_soc "$solarenergy_today")
            log_message >&2 "E: A SOC charge-target of $target_soc% will be used without valid solarweather-data."
            charger_command_set_SOC_target >/dev/null
        fi
    fi

    if ((execute_charging == 1)); then
        economic=""
        if [ "$economic_check" -eq 0 ]; then
            manage_charging "on" "Economical check was not activated. Total charging costs: $(millicentToEuro "$total_cost_integer")€"
        elif [ "$economic_check" -eq 1 ] && is_charging_economical "$highest_price_integer" "$total_cost_integer"; then
            manage_charging "on" "Charging based on highest price ($(millicentToEuro "$highest_price_integer") €) comparison makes sense. Total charging costs: $(millicentToEuro "$total_cost_integer")€"
        elif [ "$economic_check" -eq 2 ] && is_charging_economical "$average_price_integer" "$total_cost_integer"; then
            manage_charging "on" "Charging based on average price ($(millicentToEuro "$average_price_integer") €) comparison makes sense. Total charging costs: $(millicentToEuro "$total_cost_integer")€"
        else
            reason_msg="Considering charging losses and costs, charging is too expensive."
            economic="expensive"
            manage_charging "off" "$reason_msg Total charging costs: $(millicentToEuro "$total_cost_integer")€"
        fi
    else
        manage_charging "off" "Charging was not executed. Total charging costs: $(millicentToEuro "$total_cost_integer")€"
    fi

    if ((reenable_inverting_at_fullbatt == 1 && SOC_percent >= reenable_inverting_at_soc)); then
        # Wenn die Batterie voll ist und die Bedingung erfüllt, bleibt der Inverter aktiviert
        manage_discharging "on" "Battery is full (SOC >= $reenable_inverting_at_soc%). Re-enabling inverter for grid-feedin."
    elif ((disable_inverting_while_only_switching == 1 && execute_charging == 0 && (execute_fritzsocket_on == 1 || execute_shellysocket_on == 1))); then
        # Nur wenn die Batterie nicht voll ist, wird der Inverter deaktiviert, falls nur Schaltvorgänge aktiv sind
        manage_discharging "off" "Only switching active and charging is too expensive. Disabling inverter to preserve battery."
    else
        # Normale Logik für das Entladen
        if ((execute_discharging == 1)); then
            manage_discharging "on" "$discharging_condition_met Total charging costs: $(millicentToEuro "$total_cost_integer")€"
        else
            manage_discharging "off" "Discharging was not executed. Total charging costs: $(millicentToEuro "$total_cost_integer")€"
        fi
    fi
else
    log_message "D: Skip charger. Not activated."
fi

if ((use_fritz_dect_sockets == 1)); then
    manage_fritz_sockets
else
    log_message "D: Skip Fritz DECT. Not activated."
fi

if ((use_shelly_wlan_sockets == 1)); then
    manage_shelly_sockets
else
    log_message "D: Skip Shelly Api. Not activated."
fi

# 8. Cleanup und Logging
echo >>"$LOG_FILE"

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

log_message >&2 "I: Script execution completed."
if ((use_charger != 0)); then
    # Respect the last state set by the script
    if ((charging == 1)); then
        log_message >&2 "I: Charging remains ON as per script logic."
    else
        log_message >&2 "I: Charging remains OFF as per script logic."
    fi
    if ((inverting == 1)); then
        log_message >&2 "I: Discharging remains ON as per script logic."
    else
        log_message >&2 "I: Discharging remains OFF as per script logic."
    fi
fi
cleanup # Only stop keepalive, no state changes
exit 0

CONFIG_IF_SHOW_LIST_TO_LOGIN_AT_STARTUP="false"
CONFIG_IF_COVER_PASSWORD_WITH_MD5="false"

PROFILE_CURRENT_PROFILE_NAME=""
PROFILE_CURRENT_PROFILE_ENCRIPTION_PASSWORD=""
PROFILE_CURRENT_IP=""
PROFILE_CURRENT_PORT=""
PROFILE_CURRENT_USERNAME=""
PROFILE_CURRENT_PASSWORD=""
PROFILE_CURRENT_SSH_KEY_PATH=""
PROFILE_CURRENT_SSH_KEY_PASSWORD=""

############### XOR UNITS ###############
encrypt_text() {
    local text="$1"
    local password="$2"
    local encrypted=""
    local pass_len=${#password}
    
    for ((i=0; i<${#text}; i++)); do
        local char="${text:$i:1}"
        local pass_char="${password:$(($i % $pass_len)):1}"
        local char_ascii=$(printf "%d" "'$char")
        local pass_ascii=$(printf "%d" "'$pass_char")
        local encrypted_ascii=$(( $char_ascii ^ $pass_ascii ))
        
        # Convert to hex to make it storable as text
        encrypted="${encrypted}$(printf "%02x" $encrypted_ascii)"
    done
    
    echo "$encrypted"
}

decrypt_text() {
    local encrypted="$1"
    local password="$2"
    local decrypted=""
    local pass_len=${#password}
    
    # Process hex pairs
    for ((i=0; i<${#encrypted}; i+=2)); do
        local hex_pair="${encrypted:$i:2}"
        local encrypted_ascii=$(printf "%d" "0x$hex_pair")
        local pass_char="${password:$((($i/2) % $pass_len)):1}"
        local pass_ascii=$(printf "%d" "'$pass_char")
        local decrypted_ascii=$(( $encrypted_ascii ^ $pass_ascii ))
        
        # Convert back to character
        decrypted="${decrypted}$(printf "\\$(printf '%03o' $decrypted_ascii)")"
    done
    
    echo "$decrypted"
}

# Example usage
encrypted=$(encrypt_text "迷失谁" "吃食")
echo "Encrypted: $encrypted"
decrypted=$(decrypt_text "$encrypted" "吃食")
echo "Decrypted: $decrypted"


#^^^^^^^^^^^^^^^ XOR UNITS ^^^^^^^^^^^^^^^

############### DATA UNITS ###############
list_to_login() {
    echo "Profiles to login:"
    for profile in "${!profiles[@]}"; do
        echo "$profile"
    done
}

add_profile() {
    read -p "profile name: " profile
    read -p "username: " username
    read -p "password: " password
    profiles["$profile"]=$(encrypt_text "$username" "$password")
}

read_profile() {
    read -p "profile name: " profile
    if [ -z "${profiles["$profile"]}" ]; then
        echo "Profile not found"
        return
    fi
    decrypted=$(decrypt_text "${profiles["$profile"]}" "$password")
    echo "Username: $profile"
    echo "Password: $decrypted"
}

delete_profile() {
    read -p "profile name: " profile
    unset profiles["$profile"]
}
#^^^^^^^^^^^^^^ DATA UNITS ^^^^^^^^^^^^^^^

############### CONFIG UNITS ###############
# options:
# if_let_user_choose_to_login_at_startup
# if_cover_password_with_md5
#

config_file_path="./config.sshman"

#read config
read_config(){
    if [ -f "$config_file_path" ]; then
        while IFS='=' read -r key value
        do
            if [ "$key" == "CONFIG_IF_SHOW_LIST_TO_LOGIN_AT_STARTUP" ]; then
                CONFIG_IF_SHOW_LIST_TO_LOGIN_AT_STARTUP="$value"
                echo "CONFIG_IF_SHOW_LIST_TO_LOGIN_AT_STARTUP=$CONFIG_IF_SHOW_LIST_TO_LOGIN_AT_STARTUP"
            elif [ "$key" == "CONFIG_IF_COVER_PASSWORD_WITH_MD5" ]; then
                CONFIG_IF_COVER_PASSWORD_WITH_MD5="$value"
                echo "CONFIG_IF_COVER_PASSWORD_WITH_MD5=$CONFIG_IF_COVER_PASSWORD_WITH_MD5"
            fi
        done < "$config_file_path"
    fi
}

prompt_user_set_and_save_config(){

    IF_SUCCEED=false

    read -p "if show list to login at startup (true/false): " CONFIG_IF_SHOW_LIST_TO_LOGIN_AT_STARTUP
    # verify
    if [ "$CONFIG_IF_SHOW_LIST_TO_LOGIN_AT_STARTUP" != "true" ] && [ "$CONFIG_IF_SHOW_LIST_TO_LOGIN_AT_STARTUP" != "false" ]; then
        echo "invalid input"
        return
    fi

    read -p "if cover password with md5 (true/false): " CONFIG_IF_COVER_PASSWORD_WITH_MD5

    # verify
    if [ "$CONFIG_IF_COVER_PASSWORD_WITH_MD5" != "true" ] && [ "$CONFIG_IF_COVER_PASSWORD_WITH_MD5" != "false" ]; then
        echo "invalid input"
        return
    else
        IF_SUCCEED=true
    fi


    if [ "$IF_SUCCEED" == "true" ]; then
        # clear old
        if [ -f "$config_file_path" ]; then
            rm "$config_file_path"
        fi

        #save config
        echo "CONFIG_IF_SHOW_LIST_TO_LOGIN_AT_STARTUP=$CONFIG_IF_SHOW_LIST_TO_LOGIN_AT_STARTUP" > "$config_file_path"
        echo "CONFIG_IF_COVER_PASSWORD_WITH_MD5=$CONFIG_IF_COVER_PASSWORD_WITH_MD5" >> "$config_file_path"
    elif [ "$IF_SUCCEED" == "false" ]; then
        echo "config not saved due to invalid input"
    fi

}

#^^^^^^^^^^^^^^^ CONFIG UNITS ^^^^^^^^^^^^^^^

################ UI UNITS ################
main_menu() {

while true; do
    echo "1. list profiles to login"
    echo "2. add profile"
    echo "3. delete profile"
    echo "4. config"
    echo "5. exit"
    read -p "choice: " choice

    case $choice in
        1) list_to_login ;;
        2) add_profile ;;
        3) delete_profile ;;
        4) prompt_user_set_and_save_config ;;
        5) exit ;;
        *) echo "invalid" ;;
    esac
done

}

read_config

if [ "$CONFIG_IF_SHOW_LIST_TO_LOGIN_AT_STARTUP" == "true" ]; then
    list_to_login
elif [ "$CONFIG_IF_SHOW_LIST_TO_LOGIN_AT_STARTUP" == "false" ]; then
    main_menu
fi


#^^^^^^^^^^^^^^^ UI UNITS ^^^^^^^^^^^^^^^
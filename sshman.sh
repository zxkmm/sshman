CONFIG_IF_SHOW_LIST_TO_LOGIN_AT_STARTUP="false"
CONFIG_IF_COVER_PASSWORD_WITH_MD5="false"

PROFILE_CURRENT_PROFILE_NAME=""
PROFILE_CURRENT_PROFILE_ENCRIPTION_PASSWORD=""
PROFILE_CURRENT_IP=""
PROFILE_CURRENT_PORT="22"
PROFILE_CURRENT_USERNAME=""
PROFILE_CURRENT_PASSWORD=""
PROFILE_CURRENT_SSH_KEY_PATH=""
PROFILE_CURRENT_SSH_KEY_PASSWORD=""

# ensure dir
profiles_dir="./profiles"
mkdir -p "$profiles_dir"

declare -a profiles=()

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
        
        # convert to hex to save
        encrypted="${encrypted}$(printf "%02x" $encrypted_ascii)"
    done
    
    echo "$encrypted"
}

decrypt_text() {
    local encrypted="$1"
    local password="$2"
    local decrypted=""
    local pass_len=${#password}
    
    for ((i=0; i<${#encrypted}; i+=2)); do
        local hex_pair="${encrypted:$i:2}"
        local encrypted_ascii=$(printf "%d" "0x$hex_pair")
        local pass_char="${password:$((($i/2) % $pass_len)):1}"
        local pass_ascii=$(printf "%d" "'$pass_char")
        local decrypted_ascii=$(( $encrypted_ascii ^ $pass_ascii ))
        
        decrypted="${decrypted}$(printf "\\$(printf '%03o' $decrypted_ascii)")"
    done
    
    echo "$decrypted"
}
#^^^^^^^^^^^^^^^ XOR UNITS ^^^^^^^^^^^^^^^

############### PROFILE MANAGEMENT ###############
load_profiles() {
    # reset profile arr
    profiles=()
    if [ -d "$profiles_dir" ]; then
        for profile_file in "$profiles_dir"/*.sshman; do
            if [ -f "$profile_file" ]; then
                profile_name=$(basename "$profile_file" .sshman)
                profiles+=("$profile_name")
            fi
        done
    fi
    echo "Loaded ${#profiles[@]} profiles"
}

save_profile() {
    local profile_file="$profiles_dir/$PROFILE_CURRENT_PROFILE_NAME.sshman"
    local encryption_password="$PROFILE_CURRENT_PROFILE_ENCRIPTION_PASSWORD"
    
    local encrypted_ip=$(encrypt_text "$PROFILE_CURRENT_IP" "$encryption_password")
    local encrypted_port=$(encrypt_text "$PROFILE_CURRENT_PORT" "$encryption_password")
    local encrypted_username=$(encrypt_text "$PROFILE_CURRENT_USERNAME" "$encryption_password")
    local encrypted_password=$(encrypt_text "$PROFILE_CURRENT_PASSWORD" "$encryption_password")
    local encrypted_key_path=$(encrypt_text "$PROFILE_CURRENT_SSH_KEY_PATH" "$encryption_password")
    local encrypted_key_password=$(encrypt_text "$PROFILE_CURRENT_SSH_KEY_PASSWORD" "$encryption_password")
    
    # save
    cat > "$profile_file" << EOF
ip=$encrypted_ip
port=$encrypted_port
username=$encrypted_username
password=$encrypted_password
key_path=$encrypted_key_path
key_password=$encrypted_key_password
EOF
    
    # check if profile already exists in the array
    local profile_exists=false
    for i in "${!profiles[@]}"; do
        if [ "${profiles[$i]}" == "$PROFILE_CURRENT_PROFILE_NAME" ]; then
            profile_exists=true
            break
        fi
    done
    
    # add
    if [ "$profile_exists" == "false" ]; then
        profiles+=("$PROFILE_CURRENT_PROFILE_NAME")
    fi
    
    echo "Profile '$PROFILE_CURRENT_PROFILE_NAME' saved successfully"
}

load_profile_details() {
    local profile_name="$1"
    local encryption_password="$2"
    local profile_file="$profiles_dir/$profile_name.sshman"
    
    if [ ! -f "$profile_file" ]; then
        echo "Profile file not found: $profile_file"
        return 1
    fi
    
    PROFILE_CURRENT_PROFILE_NAME="$profile_name"
    PROFILE_CURRENT_PROFILE_ENCRIPTION_PASSWORD="$encryption_password"
    
    while IFS='=' read -r key value; do
        case "$key" in
            ip) PROFILE_CURRENT_IP=$(decrypt_text "$value" "$encryption_password") ;;
            port) PROFILE_CURRENT_PORT=$(decrypt_text "$value" "$encryption_password") ;;
            username) PROFILE_CURRENT_USERNAME=$(decrypt_text "$value" "$encryption_password") ;;
            password) PROFILE_CURRENT_PASSWORD=$(decrypt_text "$value" "$encryption_password") ;;
            key_path) PROFILE_CURRENT_SSH_KEY_PATH=$(decrypt_text "$value" "$encryption_password") ;;
            key_password) PROFILE_CURRENT_SSH_KEY_PASSWORD=$(decrypt_text "$value" "$encryption_password") ;;
        esac
    done < "$profile_file"
    
    return 0
}

delete_profile_file() {
    local profile_name="$1"
    local profile_file="$profiles_dir/$profile_name.sshman"
    
    if [ -f "$profile_file" ]; then
        rm "$profile_file"
        
        # rm profile
        local new_profiles=()
        for i in "${!profiles[@]}"; do
            if [ "${profiles[$i]}" != "$profile_name" ]; then
                new_profiles+=("${profiles[$i]}")
            fi
        done
        profiles=("${new_profiles[@]}")
        
        echo "Profile '$profile_name' deleted successfully"
    else
        echo "Profile file not found: $profile_file"
        return 1
    fi
}

list_profiles() {
    echo "Available profiles:"
    if [ ${#profiles[@]} -eq 0 ]; then
        echo "No profiles available"
    else
        for i in "${!profiles[@]}"; do
            echo "$((i+1)). ${profiles[$i]}"
        done
    fi
}

add_profile_menu() {
    echo "=== Add New SSH Profile ==="
    
    while true; do
        read -p "Profile name: " PROFILE_CURRENT_PROFILE_NAME
        
        if [ -z "$PROFILE_CURRENT_PROFILE_NAME" ]; then
            echo "Profile name cannot be empty"
            continue
        fi
        
        # 5xxxx
        if [[ "$PROFILE_CURRENT_PROFILE_NAME" =~ ^[0-9] ]]; then
            echo "Profile name cannot start with a number"
            continue
        fi
        
        break
    done
    
    if [ -f "$profiles_dir/$PROFILE_CURRENT_PROFILE_NAME.sshman" ]; then
        read -p "Profile already exists. Overwrite? (y/n): " confirm
        if [ "$confirm" != "y" ]; then
            return
        fi
    fi
    
    read -p "Encryption password for this profile: " PROFILE_CURRENT_PROFILE_ENCRIPTION_PASSWORD
    read -p "SSH Server IP: " PROFILE_CURRENT_IP
    read -p "SSH Port [22]: " port_input
    PROFILE_CURRENT_PORT=${port_input:-22}
    read -p "Username: " PROFILE_CURRENT_USERNAME
    
    echo "Authentication method:"
    echo "1. Password only"
    echo "2. SSH key only"
    echo "3. SSH key with password"
    read -p "Select authentication method [1]: " auth_method
    
    case "${auth_method:-1}" in
        1)
            read -sp "SSH Password: " PROFILE_CURRENT_PASSWORD
            echo
            PROFILE_CURRENT_SSH_KEY_PATH=""
            PROFILE_CURRENT_SSH_KEY_PASSWORD=""
            ;;
        2)
            PROFILE_CURRENT_PASSWORD=""
            read -p "SSH Key Path: " PROFILE_CURRENT_SSH_KEY_PATH
            PROFILE_CURRENT_SSH_KEY_PASSWORD=""
            ;;
        3)
            PROFILE_CURRENT_PASSWORD=""
            read -p "SSH Key Path: " PROFILE_CURRENT_SSH_KEY_PATH
            read -sp "SSH Key Password: " PROFILE_CURRENT_SSH_KEY_PASSWORD
            echo
            ;;
        *)
            echo "Invalid choice, using password authentication"
            read -sp "SSH Password: " PROFILE_CURRENT_PASSWORD
            echo
            PROFILE_CURRENT_SSH_KEY_PATH=""
            PROFILE_CURRENT_SSH_KEY_PASSWORD=""
            ;;
    esac
    
    save_profile
}

edit_profile_menu() {
    echo "Available profiles:"
    if [ ${#profiles[@]} -eq 0 ]; then
        echo "No profiles available"
        return
    fi
    
    for i in "${!profiles[@]}"; do
        echo "$((i+1)). ${profiles[$i]}"
    done
    
    read -p "Enter profile number or name to edit: " selection
    local profile_name=""
    
    # sel a num
    if [[ "$selection" =~ ^[0-9]+$ ]]; then
        # is a number
        if [ "$selection" -ge 1 ] && [ "$selection" -le "${#profiles[@]}" ]; then
            profile_name="${profiles[$((selection-1))]}"
        else
            echo "Invalid profile number"
            return
        fi
    else
        # is not a number, check if profile exists
        profile_name="$selection"
        local profile_exists=false
        for p in "${profiles[@]}"; do
            if [ "$p" == "$profile_name" ]; then
                profile_exists=true
                break
            fi
        done
        
        if [ "$profile_exists" == "false" ]; then
            echo "Profile not found"
            return
        fi
    fi
    
    read -p "Encryption password: " encryption_password
    
    if ! load_profile_details "$profile_name" "$encryption_password"; then
        return
    fi
    
    echo "Profile loaded. Edit details (press Enter to keep current value):"
    
    read -p "SSH Server IP [$PROFILE_CURRENT_IP]: " ip_input
    PROFILE_CURRENT_IP=${ip_input:-$PROFILE_CURRENT_IP}
    
    read -p "SSH Port [$PROFILE_CURRENT_PORT]: " port_input
    PROFILE_CURRENT_PORT=${port_input:-$PROFILE_CURRENT_PORT}
    
    read -p "Username [$PROFILE_CURRENT_USERNAME]: " username_input
    PROFILE_CURRENT_USERNAME=${username_input:-$PROFILE_CURRENT_USERNAME}
    
    echo "Current authentication method:"
    if [ -n "$PROFILE_CURRENT_SSH_KEY_PATH" ] && [ -n "$PROFILE_CURRENT_SSH_KEY_PASSWORD" ]; then
        echo "SSH key with password"
        current_method=3
    elif [ -n "$PROFILE_CURRENT_SSH_KEY_PATH" ]; then
        echo "SSH key only"
        current_method=2
    else
        echo "Password only"
        current_method=1
    fi
    
    echo "Authentication method:"
    echo "1. Password only"
    echo "2. SSH key only"
    echo "3. SSH key with password"
    echo "4. Keep current method"
    read -p "Select authentication method [$current_method]: " auth_method
    
    case "${auth_method:-4}" in
        1)
            read -sp "SSH Password: " password_input
            echo
            PROFILE_CURRENT_PASSWORD=${password_input:-$PROFILE_CURRENT_PASSWORD}
            PROFILE_CURRENT_SSH_KEY_PATH=""
            PROFILE_CURRENT_SSH_KEY_PASSWORD=""
            ;;
        2)
            PROFILE_CURRENT_PASSWORD=""
            read -p "SSH Key Path: " key_path_input
            PROFILE_CURRENT_SSH_KEY_PATH=${key_path_input:-$PROFILE_CURRENT_SSH_KEY_PATH}
            PROFILE_CURRENT_SSH_KEY_PASSWORD=""
            ;;
        3)
            PROFILE_CURRENT_PASSWORD=""
            read -p "SSH Key Path: " key_path_input
            PROFILE_CURRENT_SSH_KEY_PATH=${key_path_input:-$PROFILE_CURRENT_SSH_KEY_PATH}
            read -sp "SSH Key Password: " key_password_input
            echo
            PROFILE_CURRENT_SSH_KEY_PASSWORD=${key_password_input:-$PROFILE_CURRENT_SSH_KEY_PASSWORD}
            ;;
        4)
            # ft
            ;;
        *)
            echo "Invalid choice, keeping current authentication method"
            ;;
    esac
    
    save_profile
}

view_profile_menu() {
    # list profiles with numbers
    echo "Available profiles:"
    if [ ${#profiles[@]} -eq 0 ]; then
        echo "No profiles available"
        return
    fi
    
    for i in "${!profiles[@]}"; do
        echo "$((i+1)). ${profiles[$i]}"
    done
    
    read -p "Enter profile number or name to view: " selection
    local profile_name=""
    
    # if selection is a number
    if [[ "$selection" =~ ^[0-9]+$ ]]; then
        # is a number
        if [ "$selection" -ge 1 ] && [ "$selection" -le "${#profiles[@]}" ]; then
            profile_name="${profiles[$((selection-1))]}"
        else
            echo "Invalid profile number"
            return
        fi
    else
        # not a number, check if profile exists
        profile_name="$selection"
        local profile_exists=false
        for p in "${profiles[@]}"; do
            if [ "$p" == "$profile_name" ]; then
                profile_exists=true
                break
            fi
        done
        
        if [ "$profile_exists" == "false" ]; then
            echo "Profile not found"
            return
        fi
    fi
    
    read -p "Encryption password: " encryption_password
    
    if ! load_profile_details "$profile_name" "$encryption_password"; then
        return
    fi
    
    echo "=== Profile: $PROFILE_CURRENT_PROFILE_NAME ==="
    echo "IP Address: $PROFILE_CURRENT_IP"
    echo "Port: $PROFILE_CURRENT_PORT"
    echo "Username: $PROFILE_CURRENT_USERNAME"
    
    if [ -n "$PROFILE_CURRENT_PASSWORD" ]; then
        if [ "$CONFIG_IF_COVER_PASSWORD_WITH_MD5" == "true" ]; then
            echo "Password: *****"
        else
            echo "Password: $PROFILE_CURRENT_PASSWORD"
        fi
        echo "Authentication: Password"
    elif [ -n "$PROFILE_CURRENT_SSH_KEY_PATH" ]; then
        echo "SSH Key: $PROFILE_CURRENT_SSH_KEY_PATH"
        if [ -n "$PROFILE_CURRENT_SSH_KEY_PASSWORD" ]; then
            if [ "$CONFIG_IF_COVER_PASSWORD_WITH_MD5" == "true" ]; then
                echo "Key Password: *****"
            else
                echo "Key Password: $PROFILE_CURRENT_SSH_KEY_PASSWORD"
            fi
            echo "Authentication: SSH Key with Password"
        else
            echo "Authentication: SSH Key"
        fi
    fi
}

connect_ssh() {
    # first list available profiles with numbers
    echo "Available profiles:"
    if [ ${#profiles[@]} -eq 0 ]; then
        echo "No profiles available"
        return
    fi
    
    for i in "${!profiles[@]}"; do
        echo "$((i+1)). ${profiles[$i]}"
    done
    
    read -p "Enter profile number or name to connect: " selection
    local profile_name=""
    
    # check if selection is a number
    if [[ "$selection" =~ ^[0-9]+$ ]]; then
        # if number
        if [ "$selection" -ge 1 ] && [ "$selection" -le "${#profiles[@]}" ]; then
            profile_name="${profiles[$((selection-1))]}"
        else
            echo "Invalid profile number"
            return
        fi
    else
        # not number, check if profile exists
        profile_name="$selection"
        local profile_exists=false
        for p in "${profiles[@]}"; do
            if [ "$p" == "$profile_name" ]; then
                profile_exists=true
                break
            fi
        done
        
        if [ "$profile_exists" == "false" ]; then
            echo "Profile not found"
            return
        fi
    fi
    
    read -p "Encryption password: " encryption_password
    
    if ! load_profile_details "$profile_name" "$encryption_password"; then
        return
    fi
    
    echo "Connecting to $PROFILE_CURRENT_IP:$PROFILE_CURRENT_PORT as $PROFILE_CURRENT_USERNAME..."
    
    if [ -n "$PROFILE_CURRENT_SSH_KEY_PATH" ]; then
        if [ -n "$PROFILE_CURRENT_SSH_KEY_PASSWORD" ]; then
            # SSH key + password
            echo "Using SSH key with password"
            echo "Note: You may be prompted for the key password"
            ssh -i "$PROFILE_CURRENT_SSH_KEY_PATH" -p "$PROFILE_CURRENT_PORT" "$PROFILE_CURRENT_USERNAME@$PROFILE_CURRENT_IP"
        else
            # SSH key
            echo "Using SSH key without password"
            ssh -i "$PROFILE_CURRENT_SSH_KEY_PATH" -p "$PROFILE_CURRENT_PORT" "$PROFILE_CURRENT_USERNAME@$PROFILE_CURRENT_IP"
        fi
    else
        # password
        echo "Using password authentication"
        # use sshpass if available
        if command -v sshpass &> /dev/null; then
            sshpass -p "$PROFILE_CURRENT_PASSWORD" ssh -p "$PROFILE_CURRENT_PORT" "$PROFILE_CURRENT_USERNAME@$PROFILE_CURRENT_IP"
        else
            echo "Note: Install 'sshpass' for automatic password entry"
            echo "You will be prompted for password"
            ssh -p "$PROFILE_CURRENT_PORT" "$PROFILE_CURRENT_USERNAME@$PROFILE_CURRENT_IP"
        fi
    fi
}
#^^^^^^^^^^^^^^^ PROFILE MANAGEMENT ^^^^^^^^^^^^^^^

############### CONFIG UNITS ###############
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
    local if_succeed=false

    read -p "Show profile list at startup (true/false) [$CONFIG_IF_SHOW_LIST_TO_LOGIN_AT_STARTUP]: " show_list_input
    show_list_input=${show_list_input:-$CONFIG_IF_SHOW_LIST_TO_LOGIN_AT_STARTUP}
    
    # verify
    if [ "$show_list_input" != "true" ] && [ "$show_list_input" != "false" ]; then
        echo "Invalid input for show list setting"
        return
    fi
    CONFIG_IF_SHOW_LIST_TO_LOGIN_AT_STARTUP="$show_list_input"

    read -p "Mask passwords in profile view (true/false) [$CONFIG_IF_COVER_PASSWORD_WITH_MD5]: " mask_pwd_input
    mask_pwd_input=${mask_pwd_input:-$CONFIG_IF_COVER_PASSWORD_WITH_MD5}

    # verify
    if [ "$mask_pwd_input" != "true" ] && [ "$mask_pwd_input" != "false" ]; then
        echo "Invalid input for mask passwords setting"
        return
    else
        CONFIG_IF_COVER_PASSWORD_WITH_MD5="$mask_pwd_input"
        if_succeed=true
    fi

    if [ "$if_succeed" == "true" ]; then
        # save
        cat > "$config_file_path" << EOF
CONFIG_IF_SHOW_LIST_TO_LOGIN_AT_STARTUP=$CONFIG_IF_SHOW_LIST_TO_LOGIN_AT_STARTUP
CONFIG_IF_COVER_PASSWORD_WITH_MD5=$CONFIG_IF_COVER_PASSWORD_WITH_MD5
EOF
        echo "Configuration saved successfully"
    else
        echo "Configuration not saved due to invalid input"
    fi
}
#^^^^^^^^^^^^^^^ CONFIG UNITS ^^^^^^^^^^^^^^^

################ UI UNITS ################
main_menu() {
    load_profiles
    
    while true; do
        echo "===== SSH Manager ====="
        echo "1. List profiles"
        echo "2. Connect to SSH server"
        echo "3. Add new profile"
        echo "4. Edit profile"
        echo "5. View profile details"
        echo "6. Delete profile"
        echo "7. Settings"
        echo "8. Exit"
        read -p "Enter your choice: " choice

        case $choice in
            1) list_profiles ;;
            2) connect_ssh ;;
            3) add_profile_menu ;;
            4) edit_profile_menu ;;
            5) view_profile_menu ;;
            6)
                # list profiles with numbers
                echo "Available profiles:"
                if [ ${#profiles[@]} -eq 0 ]; then
                    echo "No profiles available"
                else
                    for i in "${!profiles[@]}"; do
                        echo "$((i+1)). ${profiles[$i]}"
                    done
                    
                    read -p "Enter profile number or name to delete: " selection
                    local profile_name=""
                    
                    # check if selection is a number
                    if [[ "$selection" =~ ^[0-9]+$ ]]; then
                        # if it's a number
                        if [ "$selection" -ge 1 ] && [ "$selection" -le "${#profiles[@]}" ]; then
                            profile_name="${profiles[$((selection-1))]}"
                        else
                            echo "Invalid profile number"
                            break
                        fi
                    else
                        # if not a number, check if profile exists
                        profile_name="$selection"
                        local profile_exists=false
                        for p in "${profiles[@]}"; do
                            if [ "$p" == "$profile_name" ]; then
                                profile_exists=true
                                break
                            fi
                        done
                        
                        if [ "$profile_exists" == "false" ]; then
                            echo "Profile not found"
                            break
                        fi
                    fi
                    
                    read -p "Are you sure you want to delete '$profile_name'? (y/n): " confirm
                    if [ "$confirm" == "y" ]; then
                        delete_profile_file "$profile_name"
                    fi
                fi
                ;;
            7) prompt_user_set_and_save_config ;;
            8) 
                echo "Exiting SSH Manager"
                exit 0
                ;;
            *) echo "Invalid choice. Please try again." ;;
        esac
        
        echo
        read -p "Press Enter to continue..."
        clear
    done
}

# init
read_config
load_profiles

if [ "$CONFIG_IF_SHOW_LIST_TO_LOGIN_AT_STARTUP" == "true" ]; then
    list_profiles
    read -p "Press Enter to continue to main menu..."
fi

main_menu
#^^^^^^^^^^^^^^^ UI UNITS ^^^^^^^^^^^^^^^

var() {
    # Method to parse args from Stackoverflow (https://stackoverflow.com/questions/192249/how-do-i-parse-command-line-arguments-in-bash)
    local POSITIONAL_ARGS=()
    local reset=false
    local list=false
    local help=false
    local reload=false
    local dir=false
    local unset=false

    # TODO: maybe make it so that the --reset flag not only clears the file but also goes through the file one by one unsetting each variable that was set in the file
    # TODO: I realize now that using my current method for detecting flags there is still some weirdness that comes up
    #       specifically when a user accidentally uses multiple flags
    # CONSIDERATION: when unsetting a variable, maybe show which lines specifically were unset. this allows for restoration
    # CONSIDERATION: when unsetting variables maybe add a confirmation after the variables that would be unset have been printed. Right now I am conflicted on this
    # CONSIDERATION: how will I deal with the fact that even when unsetting variables (or resetting) in one shell, that other active shells will still have that variable loaded
    #                the only real way I think I could do this is if I add extra logic that makes the variable command able to communicate with other instances of itself for example
    #                by using a temporary file. I think this is too complicated to do for this level of script so for now at least I will leave it as is

    local variables_path=~/Main/Additional_Config/current_variables.sh

    # Check which flags are set
    while [[ $# -gt 0 ]]; do
      case $1 in
        -h|--help)
            help=true
            shift
            ;;
        -l|--list)
            list=true
            shift
            ;;
        -u|--unset)
            unset=true
            shift
            ;;
        -R|--reset)
            reset=true
            shift
            ;;
        -r|--reload)
            reload=true
            shift
            ;;
        -d|--dir)
            dir=true
            shift
            ;;
        *)
            POSITIONAL_ARGS+=("$1")
            shift
            ;;
      esac
    done

    # Set args that weren't flags back as normal args
    set -- "${POSITIONAL_ARGS[@]}"

    help() {
        echo "Help page still WIP. This script allows you to quickly set variables that are persistent in between bash sessions"
        echo "Usage: var <var_name> <var_value>"
        echo ""
        echo "for the current session this is pretty much equivalent to writing <var_name>=<var_value>"
        echo "However the value will get saved into a file so that you can use it in other bash sessions as well"
        echo ""
        echo "New bash sessions will load these set variables automatically. But if you want to manually reload them you can use var --reload (or -r)"
        echo ""
        echo "Options (currently)"
        echo "  -h|--help: show this page"
        echo "  -l|--list: show all set variables"
        echo "  -r|--reload: reload all set variables"
        echo "  -u|--unset <var>: removes specified variable from the list and unsets it in the current shell"
        echo "  -d|--dir: uses the current working dir automatically for <var_value> meaning only the variable name is needed (example: var -d home_dir - will save the current working dir path into variable with name home_dir)"
        echo "  -R|--reset: delete all saved variables from the file (hint: this will not unset them for currently active sessions)"
    }

    # Helper function, used in two places
    # unsets variable with given name and deletes it from the variables file. returns code 1 if variable didn't exist
    myUnset() {
        if [ $# -ne 1 ]; then
            echo "ERROR: Flag -u or --unset should only be used with exactly one additional argument"
            return 1
        fi
        matching_lines=$(sed -n "/^$1=/p" $variables_path)   # Print out all lines that will be deleted
        if [ -n "$matching_lines" ]; then
            echo -n "WARNING: Deleting and unsetting the following Variable - "
            echo "$matching_lines"
            sed -i "/^$1=/d" $variables_path   # Delete the lines
            unset $1
            return 0
        else
            return 1
        fi
    }

    setVariable() {
        myUnset $1
        if [ $? -eq 1 ]; then
            echo "Nothing will be overridden."
        fi
        echo "$1='$2'" >> $variables_path
        . $variables_path
        echo ""
        echo "Variable '$1' set"
    }

    showVariables() {
        while IFS= read -r line; do
            var_name=$(echo "$line" | cut -d'=' -f1)
            var_value=$(echo "$line" | cut -d'=' -f2)
            printf "%-15s = \t%s\n" "$var_name" "$var_value"
        done < "$variables_path"
    }
    
    if [ $help = true ]; then
        help
        return 0
    elif [ $list = true ]; then
        if [ $# -ne 0 ]; then
            echo "ERROR: Flag -l or --list should only be used without additional arguments"
            return 1
        fi
        showVariables
        return 0
    elif [ $reset = true ]; then
        if [ $# -ne 0 ]; then
            echo "ERROR: Flag -R or --reset should only be used without additional arguments. Are you sure you wanted to reset all variables?"
            return 1
        fi
        echo "WARNING: These are the variables that would be deleted."
        cat "$variables_path"
        echo ""
        read -p "Are you sure you want to proceed in resetting all set variables? (y/n) " answer
        if [[ "$answer" != [Yy]* ]]; then
            echo "Operation cancelled."
            return 1
        fi
        while IFS= read -r line; do
            var_name=$(echo "$line" | cut -d'=' -f1)
            unset "$var_name"
        done < "$variables_path"
        echo "Reset set variables"
        echo -n > $variables_path
        return 0
    elif [ $reload = true ]; then
        if [ $# -ne 0 ]; then
            echo "ERROR: Flag -r or --reload should only be used without additional arguments"
            return 1
        fi
        echo "Reloading set variables"
        . $variables_path
        return 0
    elif [ $dir = true ]; then
        if [ $# -ne 1 ]; then
            echo "ERROR: Flag -d or --dir should only be used with exactly one additional argument"
            return 1
        fi
        setVariable "$1" "$(pwd)"
        return 0
    elif [ $unset = true ]; then
        myUnset $1
        if [ $? -eq 1 ]; then
            echo "No variable with name '$1' found."
        fi
        return 0
    elif [ $# -eq 0 ]; then
        help
        return 0
    elif [ $# -eq 1 ]; then
        echo "${!1}"
    elif [ $# -ne 2 ]; then
        echo "Error: Exactly two input arguments are required (name of variable, Value of variable)."
        return 1
    else
        setVariable "$1" "$2"
    fi
}

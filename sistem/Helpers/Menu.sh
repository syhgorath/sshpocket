#!/usr/bin/env bash
# Menu.sh - Menü gösterimi ve seçim sistemi (bash 3.2+ uyumlu)

# Display a menu for a group and return selected module function name
# Parameters:
#   $1 - Group name (e.g., "MainMenu")
# Returns: Selected module function name via echo
Menu() {
  local group="$1"
  
  if [ -z "$group" ]; then
    echo "Error: Menu requires a group name" >&2
    return 1
  fi
  
  # Get modules in group
  local modules=$(GetModulesInGroup "$group")
  
  if [ -z "$modules" ]; then
    echo "Error: No modules found in group: $group" >&2
    return 1
  fi
  
  # Convert space-separated to array (bash 3.2 compatible)
  local module_array
  local count=0
  local i=1
  
  # Count modules and build array
  # IFS'i geçici olarak space'e ayarla (bash 3.2 uyumlu)
  local OLD_IFS="$IFS"
  IFS=' '
  set -- $modules
  for module; do
    # Boş modül adlarını atla
    [ -z "$module" ] && continue
    module_array[$i]="$module"
    ((i++))
    ((count++))
  done
  IFS="$OLD_IFS"
  
  # Display menu (stderr'e yaz, böylece stdout sadece seçimi içerir)
  echo "" >&2
  echo "=== $group ===" >&2
  i=1
  while [ $i -le $count ]; do
    local func_name="${module_array[$i]}"
    local label=$(GetModuleLabel "$func_name")
    if [ -z "$label" ]; then
      label="$func_name"
    fi
    printf "  %2d) %s\n" "$i" "$label" >&2
    ((i++))
  done
  echo "  0) Exit" >&2
  echo "" >&2
  
  # Get user selection
  while true; do
    read -p "Select option [0-$count]: " selection
    
    # Trim whitespace
    selection=$(echo "$selection" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
    
    # Validate input
    if [[ "$selection" =~ ^[0-9]+$ ]]; then
      if [ "$selection" -eq 0 ]; then
        echo -n "exit"
        return 0
      elif [ "$selection" -ge 1 ] && [ "$selection" -le "$count" ]; then
        local selected_module="${module_array[$selection]}"
        if [ -n "$selected_module" ]; then
          echo -n "$selected_module"
          return 0
        else
          echo "Error: Module not found for selection: $selection" >&2
        fi
      else
        echo "Invalid selection. Please enter a number between 0 and $count." >&2
      fi
    else
      echo "Invalid selection. Please enter a number between 0 and $count." >&2
    fi
  done
}

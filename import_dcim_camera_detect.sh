#!/bin/bash
set -x  # Enable verbose output for debugging

# Função para logging
log() {
    local level=$1
    local message=$2
    logger -t "HazelCameraImport" -p "user.$level" "$message"
    echo "$message"  # Também imprime no stdout para o Hazel
}

# Function to show macOS notification
show_notification() {
    local title="$1"
    local message="$2"
    osascript -e "display notification \"$message\" with title \"$title\""
}

# Function to show dialog and get user response
show_dialog() {
    local title="$1"
    local message="$2"
    local default_button="$3"
    osascript -e "button returned of (display dialog \"$message\" with title \"$title\" buttons {\"Não\", \"Sim\"} default button \"$default_button\")"
}

# Function to show info dialog with OK button
show_info_dialog() {
    local title="$1"
    local message="$2"
    osascript -e "display dialog \"$message\" with title \"$title\" buttons {\"OK\"} default button \"OK\""
}

# Diretório de destino para as importações
SOURCE_FOLDER=$1
log "info" "Starting import process for source folder: $SOURCE_FOLDER"
DEST_ROOT="$HOME/Pictures/Importacoes"
DCIM_PATH=$(find "$1" -maxdepth 2 -type d -name "DCIM" 2>/dev/null)

# Verifica se a pasta DCIM existe
log "info" "Checking if DCIM folder exists ($DCIM_PATH)..."
if [ ! -d "$DCIM_PATH" ]; then
    log "error" "No DCIM folder found in $SOURCE_FOLDER"
    show_info_dialog "Import Error" "No DCIM folder found in $SOURCE_FOLDER"
    exit 0
fi

# Caminho para o log de importações
mkdir -p "$DEST_ROOT"
log "info" "Created destination root directory: $DEST_ROOT"

# Lista as subpastas do DCIM
find "$DCIM_PATH" -mindepth 1 -maxdepth 1 -type d | while read SUBDIR; do
    log "info" "Processing folder: $SUBDIR"
    BASENAME=$(basename "$SUBDIR")
    RELATIVE_PATH=$(realpath "$SUBDIR")
    
    # Get folder timestamp
    FOLDER_TIMESTAMP=$(stat -f "%Sm" -t "%Y-%m-%d_%H-%M" "$SUBDIR")
    log "info" "Folder timestamp: $FOLDER_TIMESTAMP"

    # Detectar tipo de câmera pelo nome da pasta ou arquivos
    SUFFIX=""
    if [[ "$BASENAME" == DJI_* ]] || ls "$SUBDIR"/DJI* &>/dev/null; then
        SUFFIX="DJI"
    elif ls "$SUBDIR"/*.ARW &>/dev/null; then
        SUFFIX="Sony"
    elif ls "$SUBDIR"/*.CR2 &>/dev/null; then
        SUFFIX="Canon"
    elif ls "$SUBDIR"/*.NEF &>/dev/null; then
        SUFFIX="Nikon"
    elif ls "$SUBDIR"/*.RW2 &>/dev/null; then
        SUFFIX="Panasonic"
    elif ls "$SUBDIR"/*.MP4 &>/dev/null || ls "$SUBDIR"/*.MOV &>/dev/null; then
        SUFFIX="Video"
    elif ls "$SUBDIR"/*.JPG &>/dev/null; then
        SUFFIX="JPG"
    elif ls "$SUBDIR"/*.insv &>/dev/null; then
        SUFFIX="Insta360"
    fi
    log "info" "Detected camera type: $SUFFIX"

    # Ask for import confirmation
    import_response=$(show_dialog "Import Confirmation" "Quer importar os arquivos $SUFFIX na pasta $BASENAME?" "Sim")
    if [ "$import_response" != "Sim" ]; then
        log "info" "Skipping import of $BASENAME"
        continue
    fi

    # Cria a pasta de destino com timestamp e sufixo
    DEST="$DEST_ROOT/${FOLDER_TIMESTAMP}${SUFFIX:+_$SUFFIX}/$BASENAME"
    log "info" "Creating destination folder: $DEST"

    # Notify start of import
    show_info_dialog "Import Started" "Importing $BASENAME from $SUFFIX camera"

    echo "Criando pasta: $DEST"
    mkdir -p "$DEST"
    log "info" "Copying from $SUBDIR to $DEST"
    
    # Use rsync to copy only new files and capture statistics
    RSYNC_OUTPUT=$(rsync -av --ignore-existing --stats "$SUBDIR/" "$DEST/" 2>&1)
    log "info" "Rsync output: $RSYNC_OUTPUT"
    
    # Extract statistics from rsync output
    FILES_COPIED=$(echo "$RSYNC_OUTPUT" | grep "Number of regular files transferred:" | awk '{print $6}')
    FILES_SKIPPED=$(echo "$RSYNC_OUTPUT" | grep "Number of regular files skipped:" | awk '{print $6}')
    
    # Format the statistics message
    if [ -z "$FILES_COPIED" ]; then
        FILES_COPIED=0
    fi
    if [ -z "$FILES_SKIPPED" ]; then
        FILES_SKIPPED=0
    fi
    
    STATS_MESSAGE="Copiados: $FILES_COPIED arquivos\nIgnorados: $FILES_SKIPPED arquivos"
    log "info" "Import statistics: $STATS_MESSAGE"

    # Notify completion with statistics
    show_info_dialog "Import Complete" "Finished importing $BASENAME\n$STATS_MESSAGE"

    # Ask about deleting the imported folder
    delete_response=$(show_dialog "Delete Files" "Deseja apagar os arquivos importados da pasta $BASENAME?" "Não")
    if [ "$delete_response" = "Sim" ]; then
        log "info" "Attempting to delete folder: $SUBDIR"
        
        # Check if folder exists and is accessible
        if [ ! -d "$SUBDIR" ]; then
            log "error" "Folder $SUBDIR does not exist"
            show_info_dialog "Delete Error" "Folder $BASENAME does not exist"
            continue
        fi
        
        # Check folder permissions
        if [ ! -w "$SUBDIR" ]; then
            log "error" "No write permission for folder $SUBDIR"
            show_info_dialog "Delete Error" "No permission to delete $BASENAME"
            continue
        fi
        
        # Try to delete the folder
        if rm -rf "$SUBDIR"; then
            log "info" "Successfully deleted folder: $SUBDIR"
            show_info_dialog "Files Deleted" "Successfully deleted $BASENAME"
        else
            log "error" "Failed to delete folder $SUBDIR"
            show_info_dialog "Delete Error" "Failed to delete $BASENAME"
        fi
    else
        log "info" "Keeping files in $BASENAME..."
    fi
done

# Show completion message
log "info" "Import process completed. Files are in $DEST_ROOT"
show_info_dialog "Importação Concluída" "Todas as pastas foram processadas. Os arquivos importados estão em $DEST_ROOT"

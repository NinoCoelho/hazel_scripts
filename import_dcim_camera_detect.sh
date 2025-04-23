#!/bin/bash
set -x  # Enable verbose output for debugging

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
echo "Source folder $SOURCE_FOLDER"
DEST_ROOT="$HOME/Pictures/Importacoes"
DCIM_PATH=$(find "$1" -maxdepth 2 -type d -name "DCIM" 2>/dev/null)

# Verifica se a pasta DCIM existe
echo "Checking if DCIM folder exists ($DCIM_PATH)..."
if [ ! -d "$DCIM_PATH" ]; then
    echo "Exiting script at this point."
    show_notification "Import Error" "No DCIM folder found in $SOURCE_FOLDER"
    exit 0
fi

# Caminho para o log de importações
mkdir -p "$DEST_ROOT"

# Lista as subpastas do DCIM
find "$DCIM_PATH" -mindepth 1 -maxdepth 1 -type d | while read SUBDIR; do
    echo "Verificando pasta: $SUBDIR"
    BASENAME=$(basename "$SUBDIR")
    RELATIVE_PATH=$(realpath "$SUBDIR")
    
    # Get folder timestamp
    FOLDER_TIMESTAMP=$(stat -f "%Sm" -t "%Y-%m-%d_%H-%M" "$SUBDIR")

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
    fi
    echo "Sufixo: $SUFFIX"

    # Ask for import confirmation
    import_response=$(show_dialog "Import Confirmation" "Quer importar os arquivos $SUFFIX na pasta $BASENAME?" "Sim")
    if [ "$import_response" != "Sim" ]; then
        echo "Skipping import of $BASENAME"
        continue
    fi

    # Cria a pasta de destino com timestamp e sufixo
    DEST="$DEST_ROOT/${FOLDER_TIMESTAMP}${SUFFIX:+_$SUFFIX}/$BASENAME"

    # Notify start of import
    show_notification "Import Started" "Importing $BASENAME from $SUFFIX camera"

    echo "Criando pasta: $DEST"
    mkdir -p "$DEST"
    echo "Copiando de $SUBDIR para $DEST"
    
    # Use rsync to copy only new files and capture statistics
    RSYNC_OUTPUT=$(rsync -av --ignore-existing --stats "$SUBDIR/" "$DEST/" 2>&1)
    
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

    # Notify completion with statistics
    show_notification "Import Complete" "Finished importing $BASENAME\n$STATS_MESSAGE"

    # Ask about deleting the imported folder
    delete_response=$(show_dialog "Delete Files" "Deseja apagar os arquivos importados da pasta $BASENAME?" "Não")
    if [ "$delete_response" = "Sim" ]; then
        echo "Deleting imported files from $BASENAME..."
        rm -rf "$SUBDIR"
        show_notification "Files Deleted" "Files from $BASENAME have been deleted"
    else
        echo "Keeping files in $BASENAME..."
    fi
done

# Show completion message
show_info_dialog "Importação Concluída" "Todas as pastas foram processadas. Os arquivos importados estão em $DEST_ROOT"

# Hazel Scripts

A collection of utility scripts for macOS, including a camera import tool with advanced features.

## Camera Import Script (`import_dcim_camera_detect.sh`)

A sophisticated script for importing photos and videos from digital cameras and memory cards to your Mac, with automatic camera detection and user-friendly notifications.

### Features

- 🔍 Automatic camera type detection (DJI, Sony, Canon, Nikon, Panasonic)
- 🎥 Video file detection (.MP4, .MOV)
- 📁 Organized import structure with timestamps
- 🔔 macOS notifications for import status
- ✅ Per-folder import confirmation
- 🗑️ Optional file deletion after import
- 🔄 Incremental imports (only new files are copied)
- 📊 Progress dialog during file copying

### Usage

```bash
./import_dcim_camera_detect.sh /path/to/memory/card
```

### Import Process

1. The script searches for a DCIM folder in the specified path
2. For each folder found:
   - Detects the camera type based on file extensions
   - Asks for confirmation before importing
   - Creates a timestamped destination folder
   - Shows a progress dialog while copying files
   - Copies only new files with progress notifications
   - Offers option to delete source files
3. Shows completion message when done

### Supported File Types

- DJI (drones)
- Sony (.ARW files)
- Canon (.CR2 files)
- Nikon (.NEF files)
- Panasonic Lumix (.RW2 files)
- Video files (.MP4, .MOV)
- Generic JPG files

### Destination Structure

Files are organized in the following structure:
```
~/Pictures/Importacoes/
└── YYYY-MM-DD_HH-MM_CAMERA/
    └── ORIGINAL_FOLDER_NAME/
        └── [your photos and videos]
```

### Requirements

- macOS
- Bash shell
- Basic system permissions for file operations
- rsync (included with macOS)

### Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/NinoCoelho/hazel_scripts.git
   ```

2. Make the script executable:
   ```bash
   chmod +x import_dcim_camera_detect.sh
   ```

### Notes

- The script uses rsync to ensure only new files are copied
- All operations are confirmed via macOS native dialogs
- Source files are only deleted after explicit user confirmation
- The script handles multiple camera types and video files in the same import session
- You can safely run the script multiple times on the same card - it will only copy new files
- A progress dialog shows during file copying and automatically closes when complete

### License

This project is open source and available under the MIT License. 
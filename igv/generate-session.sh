#!/bin/bash

# Script to automatically discover genomic files and create an IGV custom data modal CSV
# This runs after connect-client mounts data at /workspace/data/

WORKSPACE_DATA="/workspace/data"
APP_DATA="/app/data"
CSV_FILE="/app/resources/tracks/auto-discovered.csv"
JSON_CONFIG="/app/resources/tracks/auto-discovered.json"
GENOME=${IGV_GENOME:-"hg38"}

# Create resources/tracks directory if it doesn't exist
mkdir -p /app/resources/tracks

# Create symlink from /workspace/data to /app/data
if [ -d "$WORKSPACE_DATA" ] && [ ! -e "$APP_DATA" ]; then
    ln -s "$WORKSPACE_DATA" "$APP_DATA"
fi

# Check if workspace data directory exists and has content
if [ ! -d "$WORKSPACE_DATA" ] || [ -z "$(ls -A $WORKSPACE_DATA 2>/dev/null)" ]; then
    echo "No data mounted at $WORKSPACE_DATA - IGV will start without pre-loaded tracks"
    exit 0
fi

echo "Scanning for genomic files in $WORKSPACE_DATA..."

# Initialize CSV file with header
echo "Subfolder,name,type,url,displayMode,height,description" > "$CSV_FILE"

# Function to check if index file exists
has_index() {
    local file="$1"
    local base="${file%.*}"

    # Check for various index file extensions
    if [ -f "${file}.bai" ] || [ -f "${file}.tbi" ] || [ -f "${file}.csi" ] || \
       [ -f "${file}.crai" ] || [ -f "${base}.bai" ] || [ -f "${base}.tbi" ]; then
        return 0
    fi
    return 1
}

# Function to get file format based on extension
get_format() {
    local file="$1"
    case "${file,,}" in
        *.bam) echo "bam" ;;
        *.cram) echo "cram" ;;
        *.vcf) echo "vcf" ;;
        *.vcf.gz) echo "vcf" ;;
        *.bed) echo "bed" ;;
        *.bed.gz) echo "bed" ;;
        *.gff|*.gff.gz) echo "gff" ;;
        *.gff3|*.gff3.gz) echo "gff3" ;;
        *.gtf|*.gtf.gz) echo "gtf" ;;
        *.bigwig|*.bw) echo "bigwig" ;;
        *.bedgraph) echo "bedgraph" ;;
        *.bedgraph.gz) echo "bedgraph" ;;
        *.seg) echo "seg" ;;
        *) echo "auto" ;;
    esac
}

# Function to get track type category
get_track_type() {
    local file="$1"
    case "${file,,}" in
        *.bam|*.cram) echo "Alignment" ;;
        *.vcf|*.vcf.gz) echo "Variant" ;;
        *.bed|*.bed.gz) echo "Annotation" ;;
        *.gff|*.gff.gz|*.gff3|*.gff3.gz|*.gtf|*.gtf.gz) echo "Annotation" ;;
        *.bigwig|*.bw|*.bedgraph|*.bedgraph.gz) echo "Coverage" ;;
        *.seg) echo "Segment" ;;
        *) echo "Other" ;;
    esac
}

# Find all compatible genomic files and add to CSV
TRACK_COUNT=0
while IFS= read -r -d '' file; do
    # Get filename and extract name without extension
    filename=$(basename "$file")
    name="${filename%.*}"
    # Handle double extensions like .vcf.gz
    if [[ "$name" == *.vcf || "$name" == *.bed || "$name" == *.gff || "$name" == *.gff3 || "$name" == *.gtf || "$name" == *.bedgraph ]]; then
        name="${name%.*}"
    fi

    # Get format
    format=$(get_format "$file")

    # Get subfolder (immediate parent directory)
    file_dir=$(dirname "$file")
    subfolder=$(basename "$file_dir")

    # Convert path to be relative to /app (use data/ prefix)
    url="${file#$WORKSPACE_DATA/}"
    url="data/$url"

    # Check if indexed (for warnings only)
    if ! has_index "$file" && [[ "$file" =~ \.(bam|cram)$ ]]; then
        echo "Warning: $filename has no index file (.bai/.crai) - may not load properly"
    fi

    # Add row to CSV: Subfolder,name,type,url,displayMode,height,description
    echo "$subfolder,$name,$format,$url,,," >> "$CSV_FILE"

    TRACK_COUNT=$((TRACK_COUNT + 1))
    echo "Found: $filename"

done < <(find "$WORKSPACE_DATA" -type f \( \
    -iname "*.bam" -o \
    -iname "*.cram" -o \
    -iname "*.vcf" -o -iname "*.vcf.gz" -o \
    -iname "*.bed" -o -iname "*.bed.gz" -o \
    -iname "*.gff" -o -iname "*.gff.gz" -o \
    -iname "*.gff3" -o -iname "*.gff3.gz" -o \
    -iname "*.gtf" -o -iname "*.gtf.gz" -o \
    -iname "*.bigwig" -o -iname "*.bw" -o \
    -iname "*.bedgraph" -o -iname "*.bedgraph.gz" -o \
    -iname "*.seg" \
\) -print0)

echo "Found $TRACK_COUNT compatible track(s)"

if [ $TRACK_COUNT -eq 0 ]; then
    echo "No tracks found - IGV will start without custom tracks"
    exit 0
fi

# Generate custom data modal JSON configuration
echo "Generating custom data modal configuration: $JSON_CONFIG"
cat > "$JSON_CONFIG" << 'EOF'
{
  "label": "Auto-discovered Tracks",
  "type": "custom-data-modal",
  "description": "Genomic tracks automatically discovered from mounted data",
  "columns": [
    "Subfolder",
    "name"
  ],
  "columnDefs": {
    "name": {
      "title": "Track Name"
    },
    "Subfolder": {
      "title": "Source Folder"
    }
  },
  "delimiter": ",",
  "data": "resources/tracks/auto-discovered.csv"
}
EOF

# remove trailing end of line
truncate -s -1 "$CSV_FILE"
# Update trackRegistry.json to include our auto-discovered tracks
TRACK_REGISTRY="/app/resources/tracks/trackRegistry.json"

if [ -f "$TRACK_REGISTRY" ]; then
    echo "Updating track registry: $TRACK_REGISTRY"

    # Check if the genome exists in the registry using a simple grep check
    if grep -q "\"$GENOME\"" "$TRACK_REGISTRY"; then
        # Genome exists - add our track to the beginning of its array
        # Use sed to insert after the genome's opening bracket
        sed -i "s|\"$GENOME\": \\[|\"$GENOME\": [\\n    \"resources/tracks/auto-discovered.json\",|" "$TRACK_REGISTRY"
        echo "Added auto-discovered tracks to existing $GENOME entry"
    else
        # Genome doesn't exist - create a new entry
        # Add new genome entry at the start of the JSON object
        sed -i "s|^{|{\\n  \"$GENOME\": [\\n    \"resources/tracks/auto-discovered.json\"\\n  ],|" "$TRACK_REGISTRY"
        echo "Created new $GENOME entry with auto-discovered tracks"
    fi
else
    # No existing trackRegistry - create one
    echo "Creating new track registry: $TRACK_REGISTRY"
    cat > "$TRACK_REGISTRY" << EOF
{
  "$GENOME": [
    "resources/tracks/auto-discovered.json"
  ]
}
EOF
fi

echo "Track catalog created successfully with $TRACK_COUNT track(s)"
echo "IGV will show 'Auto-discovered Tracks' in the Tracks menu under $GENOME genome"

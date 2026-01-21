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
    # Don't exit - let http-server start anyway
else
    echo "Scanning for genomic files in $WORKSPACE_DATA..."

# Initialize CSV file with header
echo "Subfolder,name,type,format,url,indexURL,displayMode,height,description" > "$CSV_FILE"

# Function to check if index file exists
has_index() {
    local file="$1"
    local base="${file%.*}"

    # Check for various index file extensions
    # For VCF files: .vcf.gz.tbi, .vcf.gz.csi
    # For BAM files: .bam.bai, .bai (same base name)
    # For CRAM files: .cram.crai, .crai (same base name)
    if [ -f "${file}.bai" ] || [ -f "${file}.tbi" ] || [ -f "${file}.csi" ] || \
       [ -f "${file}.crai" ] || [ -f "${base}.bai" ] || [ -f "${base}.tbi" ] || \
       [ -f "${base}.csi" ] || [ -f "${base}.crai" ]; then
        return 0
    fi
    return 1
}

# Function to get the index file URL if it exists
get_index_url() {
    local file="$1"
    local base="${file%.*}"
    local index_file=""

    # Check for index files in order of preference
    if [ -f "${file}.bai" ]; then
        index_file="${file}.bai"
    elif [ -f "${base}.bai" ]; then
        index_file="${base}.bai"
    elif [ -f "${file}.crai" ]; then
        index_file="${file}.crai"
    elif [ -f "${base}.crai" ]; then
        index_file="${base}.crai"
    elif [ -f "${file}.tbi" ]; then
        index_file="${file}.tbi"
    elif [ -f "${base}.tbi" ]; then
        index_file="${base}.tbi"
    elif [ -f "${file}.csi" ]; then
        index_file="${file}.csi"
    elif [ -f "${base}.csi" ]; then
        index_file="${base}.csi"
    fi

    # If index file found, convert to relative URL
    if [ -n "$index_file" ]; then
        local index_url="${index_file#$WORKSPACE_DATA/}"
        echo "data/$index_url"
    else
        echo ""
    fi
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

# Get track type category (IGV track types)
get_track_type() {
    local file="$1"
    case "${file,,}" in
        *.bam|*.cram) echo "alignment" ;;
        *.vcf|*.vcf.gz) echo "variant" ;;
        *.bed|*.bed.gz) echo "annotation" ;;
        *.gff|*.gff.gz|*.gff3|*.gff3.gz|*.gtf|*.gtf.gz) echo "annotation" ;;
        *.bigwig|*.bw|*.bedgraph|*.bedgraph.gz) echo "wig" ;;
        *.seg) echo "seg" ;;
        *) echo "" ;;
    esac
}

# Get default height for track type
get_default_height() {
    local file="$1"
    case "${file,,}" in
        *.bam|*.cram) echo "200" ;;
        *.vcf|*.vcf.gz) echo "100" ;;
        *.bigwig|*.bw|*.bedgraph|*.bedgraph.gz) echo "100" ;;
        *.bed|*.bed.gz) echo "50" ;;
        *.gff|*.gff.gz|*.gff3|*.gff3.gz|*.gtf|*.gtf.gz) echo "100" ;;
        *.seg) echo "50" ;;
        *) echo "" ;;
    esac
}

# Get description for track type
get_description() {
    local file="$1"
    case "${file,,}" in
        *.bam) echo "BAM alignment file" ;;
        *.cram) echo "CRAM alignment file" ;;
        *.vcf) echo "VCF variant file" ;;
        *.vcf.gz) echo "VCF variant file (compressed)" ;;
        *.bigwig|*.bw) echo "BigWig coverage/signal track" ;;
        *.bedgraph|*.bedgraph.gz) echo "BedGraph coverage track" ;;
        *.bed) echo "BED annotation file" ;;
        *.bed.gz) echo "BED annotation file (compressed)" ;;
        *.gff|*.gff.gz) echo "GFF annotation file" ;;
        *.gff3|*.gff3.gz) echo "GFF3 annotation file" ;;
        *.gtf|*.gtf.gz) echo "GTF gene annotation file" ;;
        *.seg) echo "Segmentation file" ;;
        *) echo "" ;;
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

    # Get track type
    track_type=$(get_track_type "$file")

    # Get subfolder (immediate parent directory)
    file_dir=$(dirname "$file")
    subfolder=$(basename "$file_dir")

    # Convert path to be relative to /app (use data/ prefix)
    url="${file#$WORKSPACE_DATA/}"
    url="data/$url"

    # Get index URL if available
    index_url=$(get_index_url "$file")

    # Get default height for this track type
    height=$(get_default_height "$file")

    # Get description for this track type
    description=$(get_description "$file")

    # Check if indexed (for warnings only)
    if [ -z "$index_url" ] && [[ "$file" =~ \.(bam|cram|vcf\.gz)$ ]]; then
        echo "Warning: $filename has no index file (.bai/.crai/.tbi) - may not load properly"
    fi

    # Add row to CSV: Subfolder,name,type,format,url,indexURL,displayMode,height,description
    echo "$subfolder,$name,$track_type,$format,$url,$index_url,,$height,$description" >> "$CSV_FILE"

    TRACK_COUNT=$((TRACK_COUNT + 1))
    if [ -n "$index_url" ]; then
        echo "Found: $filename (with index: $(basename "$index_url"))"
    else
        echo "Found: $filename"
    fi

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

if [ $TRACK_COUNT -gt 0 ]; then
    # Generate custom data modal JSON configuration
echo "Generating custom data modal configuration: $JSON_CONFIG"
cat > "$JSON_CONFIG" << 'EOF'
{
  "label": "Auto-discovered Tracks",
  "type": "custom-data-modal",
  "description": "Genomic tracks automatically discovered from mounted data",
  "columns": [
    "Subfolder",
    "name",
    "description"
  ],
  "columnDefs": {
    "name": {
      "title": "Track Name"
    },
    "Subfolder": {
      "title": "Source Folder"
    },
    "description": {
      "title": "Data Type"
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
fi

# Close the data check conditional
fi

# IGV Web App Studio

This example demonstrates how to deploy the [IGV (Integrative Genomics Viewer) web application](https://igv.org/doc/webapp/) in Seqera Studios. IGV is a high-performance visualization tool for interactive exploration of large, integrated genomic datasets.

## Features

- Interactive genome browser accessible through web interface
- **Automatic track discovery**: Automatically scans mounted data and loads all compatible genomic files
- **Smart track table**: Displays track name, source folder, and data type description for easy identification
- Support for multiple genomic data formats (BAM, CRAM, VCF, BED, BigWig, BedGraph, GFF/GTF, etc.)
- **Automatic index detection**: Detects and uses `.bai`, `.crai`, `.tbi`, and `.csi` index files
- Real-time visualization of aligned sequencing reads
- Integration with cloud storage (S3, GCS, Azure) through Seqera Studios data mounting
- Session auto-generation for immediate data visualization
- No authentication required for quick access

## Prerequisites

- [Docker](https://www.docker.com/) installed for local testing
- [Wave](https://docs.seqera.io/platform-cloud/wave/) configured in your Seqera Platform workspace
- Access to a container registry for pushing your images

## Building the Image

### Using Docker

Build the image for the linux/amd64 platform:

```bash
docker build --platform linux/amd64 -t your-registry/igv-webapp:latest .
```

Push to your container registry:

```bash
docker push your-registry/igv-webapp:latest
```

### Using Wave (Recommended for Seqera Platform)

Wave can build and push your container automatically. See the [Wave documentation](https://docs.seqera.io/platform-cloud/wave/) for setup instructions.

## Testing Locally

The repository includes a `run_local.sh` script for easy local testing with sample data.

### Quick Start

```bash
# From the igv directory
cd /path/to/custom-studios-examples/igv

# Download test data (first time only)
./download-test-data.sh

# Run the local test script (builds, runs container, and mounts test data)
./run_local.sh
```

This script will:
1. Stop and remove any existing `igv-test` container
2. Build the Docker image as `igv-webapp-test`
3. Run the container with test data mounted from `test-data/`
4. Start IGV on http://localhost:8080

### Manual Testing

#### 1. Build the Image

```bash
docker build -t igv-webapp-test .
```

#### 2. Run with Test Data

```bash
docker run -d --name igv-test \
  -p 8080:8080 \
  -e CONNECT_TOOL_PORT=8080 \
  -v $(pwd)/test-data:/workspace/data \
  --entrypoint /bin/bash \
  igv-webapp-test \
  -c "generate-session.sh && http-server /app -p 8080 -a 0.0.0.0 --cors"
```

#### 3. Access IGV

Open your browser to http://localhost:8080

#### 4. View Auto-Discovered Tracks

1. Click the **Tracks** menu in IGV
2. Select **"Auto-discovered Tracks"** - you'll see a table with:
   - **Source Folder**: Directory containing the file
   - **Track Name**: Filename without extension
   - **Data Type**: Description of the file type (e.g., "BAM alignment file", "BigWig coverage/signal track")
3. Select tracks and click to load them into IGV

### Test Data Included

The `test-data/` directory contains sample genomic files for testing. These files are not included in the repository but can be downloaded using the provided script:

```bash
# Download test data from nf-core test-datasets
./download-test-data.sh
```

This will download the following files:
- `NA12878.chr21_22.bam` (+ `.bai` index) - BAM alignment file
- `NA12878_GIAB.chr22.vcf.gz` (+ `.csi` index) - VCF variant file (compressed)
- `NA24385_coverage.bed` - BED annotation file
- `cutandtag_h3k27me3_test_1.bedGraph` - BedGraph coverage track
- `test_S2.RPKM.bw` - BigWig coverage/signal track

**Note**: Test data files are sourced from the [nf-core test-datasets repository](https://github.com/nf-core/test-datasets/tree/modules/data/genomics/homo_sapiens/illumina).

### Using Your Own Data

To test with your own genomic files:

```bash
# Create a custom test directory
mkdir -p my-data

# Copy your files (ensure index files are included)
cp /path/to/your/file.bam my-data/
cp /path/to/your/file.bam.bai my-data/

# Run container with your data
docker run -d --name igv-test \
  -p 8080:8080 \
  -e CONNECT_TOOL_PORT=8080 \
  -v $(pwd)/my-data:/workspace/data \
  --entrypoint /bin/bash \
  igv-webapp-test \
  -c "generate-session.sh && http-server /app -p 8080 -a 0.0.0.0 --cors"
```

### Container Logs

To view the track discovery process:

```bash
docker logs igv-test
```

You'll see output like:
```
Scanning for genomic files in /workspace/data...
Found: NA12878.chr21_22.bam (with index: NA12878.chr21_22.bam.bai)
Found: NA12878_GIAB.chr22.vcf.gz (with index: NA12878_GIAB.chr22.vcf.gz.csi)
Found: NA24385_coverage.bed
Found: cutandtag_h3k27me3_test_1.bedGraph
Found: test_S2.RPKM.bw
Found 5 compatible track(s)
```

### Stopping the Container

```bash
docker stop igv-test && docker rm igv-test
```

## Deploying to Seqera Studios

### Step 1: Build and Push Your Container Image

#### Option A: Using Docker and GitHub Container Registry

```bash
# Build the image
docker build -t igv-webapp-test .

# Tag for GitHub Container Registry
docker tag igv-webapp-test ghcr.io/YOUR_USERNAME/igv-webapp:latest

# Authenticate with GitHub (create a classic PAT with write:packages scope at https://github.com/settings/tokens/new?scopes=write:packages)
echo $GITHUB_TOKEN | docker login ghcr.io -u YOUR_USERNAME --password-stdin

# Push to GitHub Container Registry
docker push ghcr.io/YOUR_USERNAME/igv-webapp:latest
```

**After pushing:**
1. Make the package public (optional): Go to `https://github.com/users/YOUR_USERNAME/packages/container/igv-webapp/settings` → Change visibility to Public
2. Link to repository (recommended): Connect the package to your repository for better organization

#### Option B: Using Wave (Recommended)

Wave can build and push your container automatically from the Dockerfile. See the [Wave documentation](https://docs.seqera.io/platform-cloud/wave/) for setup instructions.

### Step 2: Create a Studio in Seqera Platform

1. Navigate to the **Studios** tab in your Seqera Platform workspace
2. Click **Add Studio**
3. Configure the studio:

   **Basic Configuration:**
   - **Container template**: Select "Prebuilt container image"
   - **Container image URI**: Enter your image URI (e.g., `ghcr.io/YOUR_USERNAME/igv-webapp:latest`)
   - **Studio name**: Enter a descriptive name (e.g., "IGV Genome Browser")
   - **Description**: Optional description of the studio

   **Compute and Data:**
   - **Compute environment**: Select your preferred compute environment
   - **CPU**: Recommended 2 CPUs
   - **Memory**: Recommended 4-8 GB RAM
   - **Mount data**: Add datalinks to your genomic data files
     - Click "Add datalink" and select your cloud storage locations
     - Data will be mounted at `/workspace/data/` in the container
     - All compatible genomic files will be automatically discovered and loaded
     - Organize data in subdirectories if needed - the script scans recursively

   **Environment Variables (Optional):**
   - `IGV_GENOME`: Set to customize the reference genome (default: `hg38`)
     - Examples: `hg38`, `hg19`, `mm10`, `mm39`, or any IGV-supported genome ID

4. Review the configuration in the **Summary** section
5. Click **Add and start** to launch the Studio

### Step 3: Access and Use IGV

Once the Studio starts:

1. **The IGV web interface will open automatically** in your browser
2. **Load auto-discovered tracks:**
   - Click the **Tracks** menu in IGV
   - Select **"Auto-discovered Tracks"**
   - A table will display showing all genomic files found in your mounted data:
     - **Source Folder**: Directory where the file is located
     - **Track Name**: Filename without extension
     - **Data Type**: Description of the file format (e.g., "BAM alignment file", "VCF variant file (compressed)", "BigWig coverage/signal track")
   - Select tracks from the table and click to load them into IGV
3. **Manual data loading** (if needed):
   - Click **File** → **Load from URL**
   - For mounted data, use the path: `data/your-file-path.bam`
   - Or drag and drop files directly into the browser
4. **Select reference genome** from the dropdown (or load a custom genome)
5. **Navigate and visualize** your genomic data using IGV's interactive tools

## Using IGV Web App

### Automatic Track Discovery

The container includes a startup script (`generate-session.sh`) that:
- Scans all mounted data at `/workspace/data/` for compatible genomic files
- Automatically detects file types and generates descriptive labels
- Detects and associates index files (`.bai`, `.crai`, `.tbi`, `.csi`)
- Generates a CSV catalog of all discovered tracks with metadata
- Creates a custom data modal configuration for IGV
- Provides a user-friendly table showing:
  - **Source Folder**: Subdirectory containing the file
  - **Track Name**: Filename without extension
  - **Data Type**: Human-readable description (e.g., "BAM alignment file", "VCF variant file (compressed)", "BigWig coverage/signal track")
- Warns in logs if required index files are missing for alignment/variant files

### Supported File Formats

The auto-discovery script recognizes these genomic file formats:

| Format | Extensions | Data Type Description | Index Required |
|--------|-----------|----------------------|----------------|
| BAM | `.bam` | BAM alignment file | `.bai` (recommended) |
| CRAM | `.cram` | CRAM alignment file | `.crai` (recommended) |
| VCF | `.vcf`, `.vcf.gz` | VCF variant file | `.tbi` or `.csi` (for `.vcf.gz`) |
| BED | `.bed`, `.bed.gz` | BED annotation file | Optional |
| BigWig | `.bigwig`, `.bw` | BigWig coverage/signal track | Not needed |
| BedGraph | `.bedgraph`, `.bedgraph.gz` | BedGraph coverage track | Optional |
| GFF | `.gff`, `.gff.gz` | GFF annotation file | Optional |
| GFF3 | `.gff3`, `.gff3.gz` | GFF3 annotation file | Optional |
| GTF | `.gtf`, `.gtf.gz` | GTF gene annotation file | Optional |
| SEG | `.seg` | Segmentation file | Not needed |

**Note on Index Files:**
- BAM files require `.bai` index files for proper visualization
- CRAM files require `.crai` index files
- Compressed VCF files (`.vcf.gz`) require `.tbi` (Tabix) or `.csi` index files
- The script automatically detects and uses index files when present
- Missing index files will generate warnings in the container logs

### Loading Tracks

Once the Studio is running:

1. The IGV web interface opens automatically
2. Click the **Tracks** menu → **"Auto-discovered Tracks"**
3. Review the track table with source folder, track name, and data type
4. Select tracks to load them into IGV
5. Alternatively, use **File** → **Load from URL** for manual loading
   - For mounted data, use paths like: `data/your-file.bam`
6. Select a reference genome from the dropdown or load a custom genome
7. Navigate and interact with your genomic data

### Customizing the Reference Genome

By default, auto-discovered tracks are loaded with the `hg38` reference genome. You can change this by setting the `IGV_GENOME` environment variable in the Studios configuration or Docker run command:

**Supported genome IDs:**
- `hg38` - Human (GRCh38/hg38) - **Default**
- `hg19` - Human (GRCh37/hg19)
- `mm10` - Mouse (GRCm38/mm10)
- `mm39` - Mouse (GRCm39/mm39)
- Any other genome ID supported by IGV

**Example for Docker:**
```bash
docker run -d --name igv-test \
  -p 8080:8080 \
  -e CONNECT_TOOL_PORT=8080 \
  -e IGV_GENOME=mm10 \
  -v $(pwd)/test-data:/workspace/data \
  --entrypoint /bin/bash \
  igv-webapp-test \
  -c "generate-session.sh && http-server /app -p 8080 -a 0.0.0.0 --cors"
```

**For Seqera Studios:**
Add `IGV_GENOME=mm10` in the Environment Variables section during studio creation.

## Data Organization Best Practices

For optimal track discovery and organization:

1. **Use descriptive filenames**: Track names are derived from filenames
2. **Organize in subdirectories**: The "Source Folder" column helps identify track origin
3. **Include index files**: Always include `.bai`, `.crai`, `.tbi`, or `.csi` files alongside data files
4. **Use standard extensions**: Ensures proper format detection and data type labeling
5. **Compress when appropriate**: Use `.gz` compression for VCF, BED, GFF, and GTF files

**Example directory structure:**
```
/workspace/data/
├── sample1/
│   ├── alignment.bam
│   ├── alignment.bam.bai
│   ├── variants.vcf.gz
│   └── variants.vcf.gz.tbi
├── sample2/
│   ├── alignment.bam
│   ├── alignment.bam.bai
│   ├── variants.vcf.gz
│   └── variants.vcf.gz.csi
└── annotations/
    ├── genes.gtf.gz
    └── peaks.bed
```

## Troubleshooting

### Browser Compatibility
IGV web app requires a modern browser with JavaScript ES2015 support:
- Chrome (recommended)
- Firefox
- Safari
- Edge

### Large Files and Performance
For optimal performance with large genomic files:
- **Always include index files**: `.bai` for BAM, `.crai` for CRAM, `.tbi` or `.csi` for compressed VCF
- **Use BigWig for coverage data**: More efficient than BedGraph or WIG for large datasets
- **Increase memory**: Adjust memory allocation in Studios settings if needed (8+ GB for large files)
- **Use compressed formats**: `.vcf.gz`, `.bed.gz`, `.gtf.gz` to reduce file size

### Missing Index Files
If tracks fail to load or load slowly:
- Check container logs: `docker logs igv-test`
- Look for warnings like: "Warning: file.bam has no index file (.bai) - may not load properly"
- Ensure index files are present and named correctly:
  - BAM: `file.bam.bai` or `file.bai`
  - CRAM: `file.cram.crai` or `file.crai`
  - VCF.GZ: `file.vcf.gz.tbi` or `file.vcf.gz.csi`

### Tracks Not Appearing in Auto-Discovered List
If the "Auto-discovered Tracks" menu is empty:
- **Verify data mounting**: Check that data is mounted at `/workspace/data/` via datalinks (in Studios) or volume mount (locally)
- **Check file extensions**: Ensure files have supported extensions (case-insensitive)
- **Review container logs**: Check for scan results showing what was found
  ```bash
  docker logs igv-test
  ```
- **Verify file presence**: The script scans recursively through all subdirectories
- **Check the CSV file**: View `/app/resources/tracks/auto-discovered.csv` in the container
  ```bash
  docker exec igv-test cat /app/resources/tracks/auto-discovered.csv
  ```

### Data Access Issues
- **Local testing**: Ensure the volume mount path is correct: `-v $(pwd)/test-data:/workspace/data`
- **Studios**: Verify datalinks are configured correctly in the Studio settings
- **File permissions**: Ensure files have read permissions
- **Path format**: In IGV, use `data/your-file.bam` (not `/workspace/data/your-file.bam`)

### Network or Connection Errors
- Verify the port is not in use by another service
- Check firewall settings if accessing remotely
- In Studios, the port is automatically configured via `CONNECT_TOOL_PORT`

## Architecture

This Docker container uses a multi-stage build for efficiency:

### Build Stages

1. **Stage 1 - Connect Client**: Fetches the Seqera connect-client for cloud data mounting
2. **Stage 2 - IGV Build**: Builds the IGV web app from source
3. **Stage 3 - Runtime**: Creates a minimal runtime image with the built app served via http-server

### Startup Process

When the container starts (in Seqera Studios):

1. **connect-client starts** and mounts data from cloud storage (S3, GCS, Azure) to `/workspace/data/`
2. **generate-session.sh executes** and:
   - Scans `/workspace/data/` recursively for compatible genomic files
   - Detects file formats and generates data type descriptions
   - Identifies and associates index files (`.bai`, `.crai`, `.tbi`, `.csi`)
   - Creates `/app/resources/tracks/auto-discovered.csv` with track metadata:
     - Subfolder, name, type, format, url, indexURL, displayMode, height, description
   - Creates `/app/resources/tracks/auto-discovered.json` with custom data modal configuration
   - Updates `/app/resources/tracks/trackRegistry.json` to register tracks with IGV
   - Logs all discovered tracks and warnings for missing index files
3. **http-server starts** and serves the IGV web app on the port specified by `CONNECT_TOOL_PORT`
4. **User accesses IGV** in their browser and can view all discovered tracks via the Tracks menu

### Local Testing

For local testing (without connect-client):
- The container bypasses connect-client using `--entrypoint /bin/bash`
- Data is mounted directly via Docker volume: `-v $(pwd)/test-data:/workspace/data`
- The script runs manually: `generate-session.sh && http-server /app -p 8080 -a 0.0.0.0 --cors`
- This simulates the Studios environment without FUSE dependencies

### Files Generated

- `/app/resources/tracks/auto-discovered.csv` - Track catalog with metadata
- `/app/resources/tracks/auto-discovered.json` - Custom data modal configuration
- `/app/resources/tracks/trackRegistry.json` - IGV track registry (updated)
- `/app/data` - Symlink to `/workspace/data` for web access

## Resources

- [IGV Web App Documentation](https://igv.org/doc/webapp/)
- [IGV User Guide](https://igv.org/doc/)
- [IGV GitHub Repository](https://github.com/igvteam/igv-webapp)
- [Seqera Studios Documentation](https://docs.seqera.io/platform-cloud/studios/)
- [Wave Documentation](https://docs.seqera.io/platform-cloud/wave/)

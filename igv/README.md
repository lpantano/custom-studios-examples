# IGV Web App Studio

This example demonstrates how to deploy the [IGV (Integrative Genomics Viewer) web application](https://igv.org/doc/webapp/) in Seqera Studios. IGV is a high-performance visualization tool for interactive exploration of large, integrated genomic datasets.

## Features

- Interactive genome browser accessible through web interface
- **Automatic track discovery**: Automatically scans mounted data and loads all compatible genomic files
- Support for multiple genomic data formats (BAM, VCF, BED, BigWig, etc.)
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

### Quick Test (Without Track Discovery)

To test IGV without the FUSE error, bypass the connect-client and run the app directly:

```bash
docker run --platform linux/amd64 -p 3000:3000 \
  --entrypoint /bin/bash \
  your-registry/igv-webapp:latest \
  -c "http-server /app -p 3000 -a 0.0.0.0 --cors"
```

Then open your browser to http://localhost:3000 to access the IGV web app.

**Note**: This method skips the connect-client and track discovery script, so no tracks will be auto-discovered. Use this for basic functionality testing.

### Full Test (With Track Discovery)

To test the complete functionality including track discovery:

1. **Create a test data directory** with some sample genomic files:
   ```bash
   mkdir -p test-data
   # Add your test BAM, VCF, or BED files to test-data/
   ```

2. **Run with data volume mounted**:
   ```bash
   docker run --platform linux/amd64 -p 3000:3000 \
     -v $(pwd)/test-data:/workspace/data \
     -e CONNECT_TOOL_PORT=3000 \
     --entrypoint /bin/bash \
     your-registry/igv-webapp:latest \
     -c "generate-session.sh && http-server /app -p 3000 -a 0.0.0.0 --cors"
   ```

3. **Open your browser** to http://localhost:3000

4. **Check the Tracks menu** - you should see "Auto-discovered Tracks" with your test files listed

**Note**:
- By using `--entrypoint /bin/bash` and running commands directly, we bypass connect-client and avoid FUSE errors
- The track discovery script will scan `/workspace/data` (your mounted `test-data/` directory)
- In Data Studio, the full connect-client integration works seamlessly with proper FUSE support

### Testing with Sample Data

If you don't have test genomic files, you can download samples:

```bash
mkdir -p test-data
cd test-data

# Download a small test BAM file
wget https://github.com/samtools/samtools/raw/develop/examples/toy.sam
samtools view -b toy.sam > toy.bam
samtools index toy.bam

cd ..
```

Then run the full test command above.

### Port Configuration

You can use any available port by changing it in the command (e.g., port 8081):

```bash
docker run --platform linux/amd64 -p 8081:8081 \
  --entrypoint /bin/bash \
  your-registry/igv-webapp:latest \
  -c "http-server /app -p 8081 -a 0.0.0.0 --cors"
```

## Deploying to Seqera Studios

1. Navigate to the **Studios** tab in your Seqera Platform workspace
2. Click **Add Studio**
3. Configure the studio:
   - **Container template**: Select "Prebuilt container image"
   - **Container image URI**: Enter your image URI (e.g., `cr.seqera.io/your-org/igv-webapp:latest`)
   - **Studio name**: Enter a descriptive name (e.g., "IGV Genome Browser")
   - **Description**: Optional description
4. In the **Compute and Data** section:
   - Select your compute environment
   - Adjust CPU and memory as needed (recommended: 2 CPU, 4-8 GB RAM)
   - **Mount data**: Add datalinks to your genomic data files (BAM, VCF, BED, etc.)
     - Data will be available at `/workspace/data/` in the container
     - All compatible files will be automatically discovered and loaded
   - **(Optional) Environment variables**: Set `IGV_GENOME` to customize the reference genome (default: `hg38`)
5. Review the configuration in the **Summary** section
6. Click **Add and start** to launch the Studio

## Using IGV Web App

Once the Studio is running:

1. The IGV web interface will open automatically
2. If you've mounted data via datalinks, click the **Tracks** menu in IGV
3. Select **"Auto-discovered Tracks"** from the dropdown - this will open a modal showing all genomic files found in your mounted data
4. The track table displays:
   - **Track Name**: Filename of the genomic file
   - **File Path**: Full path to the file
   - **File Format**: Detected format (bam, vcf, bed, etc.)
   - **Track Type**: Category (Alignment, Variant, Annotation, Coverage, Segment)
   - **Has Index**: Whether index files (.bai, .tbi, .crai) are present
5. Select tracks from the table and click to load them into IGV
6. You can also manually load additional data:
   - Click **File** → **Load from URL**
   - For data mounted in Studios, use the path: `file:///workspace/data/your-bucket-name/path/to/file.bam`
   - Or drag and drop files directly into the browser
7. Select a reference genome from the dropdown (or load a custom genome)
8. Interact with your genomic data using IGV's visualization tools

### Automatic Track Discovery

The container includes a startup script that:
- Scans all mounted data at `/workspace/data/` for compatible genomic files
- Automatically detects file types (BAM, VCF, BED, BigWig, etc.)
- Generates a CSV catalog of all discovered tracks
- Creates a custom data modal configuration for IGV
- Provides metadata about each track (format, type, indexing status)
- Warns in logs if index files (.bai, .tbi, .crai) are missing for alignment files

Supported file formats for auto-discovery:
- Alignments: `.bam`, `.cram`
- Variants: `.vcf`, `.vcf.gz`
- Annotations: `.bed`, `.gff`, `.gtf` (and `.gz` versions)
- Coverage: `.bigwig`, `.bw`, `.bedgraph`
- Segments: `.seg`

### Customizing the Reference Genome

By default, tracks are loaded with the `hg38` reference genome. You can change this by setting the `IGV_GENOME` environment variable in the Studios configuration:

- `hg38` - Human (GRCh38/hg38)
- `hg19` - Human (GRCh37/hg19)
- `mm10` - Mouse (GRCm38/mm10)
- `mm39` - Mouse (GRCm39/mm39)
- Or any other genome ID supported by IGV

## Data Formats Supported

IGV supports a wide range of genomic data formats including:
- **Alignment**: BAM, CRAM
- **Variants**: VCF, BCF
- **Annotations**: BED, GFF, GTF
- **Coverage**: BigWig, TDF, WIG
- **Sequences**: FASTA, 2bit

## Example Data

If you want to test with public data:
1. Use IGV's built-in example datasets from **File** → **Load from Server**
2. Or mount public data from cloud storage through Seqera Studios datalinks

## Troubleshooting

### Browser Compatibility
IGV web app requires a modern browser with JavaScript ES2015 support (Chrome, Firefox, Safari, Edge).

### Large Files
For optimal performance with large BAM/CRAM files:
- Ensure files are indexed (`.bai` or `.crai` files present)
- Consider using BigWig format for coverage data
- Increase memory allocation in Studios settings if needed

### Data Access
- Verify that data paths in Studios use the correct `/workspace/data/` prefix
- Check that index files (.bai, .tbi, .crai, etc.) are present alongside data files for alignment files
- Ensure file permissions allow read access
- The startup script will log warnings for missing index files

### No Tracks Showing in Custom Data Modal
If tracks aren't appearing in the "Auto-discovered Tracks" menu:
- Check that data is mounted at `/workspace/data/` via datalinks
- Verify your files have supported extensions (case-insensitive)
- Check the container logs for scan results to see what was found
- The script scans recursively through all subdirectories
- Verify the `/app/resources/tracks/auto-discovered.csv` file was created

## Resources

- [IGV Web App Documentation](https://igv.org/doc/webapp/)
- [IGV User Guide](https://igv.org/doc/)
- [IGV GitHub Repository](https://github.com/igvteam/igv-webapp)
- [Seqera Studios Documentation](https://docs.seqera.io/platform-cloud/studios/)

## Architecture

This Dockerfile uses a multi-stage build:
1. **Stage 1**: Fetches the Seqera connect-client
2. **Stage 2**: Builds the IGV web app from source
3. **Stage 3**: Creates a minimal runtime image with the built app served via http-server

### Startup Process

1. **connect-client starts** and mounts data from cloud storage to `/workspace/data/`
2. **generate-session.sh runs** and:
   - Scans `/workspace/data/` for compatible genomic files
   - Creates `resources/tracks/auto-discovered.csv` with track metadata
   - Creates `resources/tracks/auto-discovered.json` with custom data modal config
   - Creates `resources/tracks.json` that IGV reads to populate the Tracks menu
3. **http-server starts** and serves the IGV web app on `CONNECT_TOOL_PORT`
4. **User opens IGV** and can access all discovered tracks via the Tracks menu

The app is served on the port specified by the `CONNECT_TOOL_PORT` environment variable, which is automatically set by Seqera Studios.

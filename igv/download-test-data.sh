#!/bin/bash

# Script to download test data from nf-core test-datasets repository
# Source: https://github.com/nf-core/test-datasets/tree/modules/data/genomics/homo_sapiens/illumina

set -e

BASE_URL="https://raw.githubusercontent.com/nf-core/test-datasets/modules/data/genomics/homo_sapiens/illumina"
TEST_DATA_DIR="test-data"

echo "Creating test-data directory..."
mkdir -p "$TEST_DATA_DIR"

echo "Downloading test files from nf-core test-datasets..."

# BAM alignment files
echo "  - Downloading BAM alignment file..."
curl -L -o "$TEST_DATA_DIR/NA12878.chr21_22.bam" \
    "$BASE_URL/bam/NA12878.chr21_22.bam"

echo "  - Downloading BAM index..."
curl -L -o "$TEST_DATA_DIR/NA12878.chr21_22.bam.bai" \
    "$BASE_URL/bam/NA12878.chr21_22.bam.bai"

# VCF variant files
echo "  - Downloading VCF file..."
curl -L -o "$TEST_DATA_DIR/NA12878_GIAB.chr22.vcf.gz" \
    "$BASE_URL/vcf/NA12878_GIAB.chr22.vcf.gz"

echo "  - Downloading VCF CSI index..."
curl -L -o "$TEST_DATA_DIR/NA12878_GIAB.chr22.vcf.gz.csi" \
    "$BASE_URL/vcf/NA12878_GIAB.chr22.vcf.gz.csi"

# BED annotation file
echo "  - Downloading BED file..."
curl -L -o "$TEST_DATA_DIR/NA24385_coverage.bed" \
    "$BASE_URL/bed/NA24385_coverage.bed"

# BedGraph coverage track
echo "  - Downloading BedGraph file..."
curl -L -o "$TEST_DATA_DIR/cutandtag_h3k27me3_test_1.bedGraph" \
    "$BASE_URL/bedgraph/cutandtag_h3k27me3_test_1.bedGraph"

# BigWig coverage track
echo "  - Downloading BigWig file..."
curl -L -o "$TEST_DATA_DIR/test_S2.RPKM.bw" \
    "$BASE_URL/bigwig/test_S2.RPKM.bw"

echo ""
echo "Download complete! Test data is ready in $TEST_DATA_DIR/"
echo "You can now run: ./run_local.sh"

#!/bin/bash
# Copyright 2019 Google LLC.
# This script builds a Docker image and runs DeepVariant for PacBio data.
# Main purpose of this script is to evaluate the total runtime of DeepVariant on
# different computer (cloud instance) types.
# Runtime measurements do not include the time for building the Docker image and
# localizing test data.

set -euo pipefail

## Preliminaries
# Set a number of shell variables, to make what follows easier to read.
BASE="${HOME}/pacbio-case-study"

INPUT_DIR="${BASE}/input"
DATA_DIR="${INPUT_DIR}/data"
REF="hs37d5.fa.gz"
BAM="pacbio.8M.30x.bam"
TRUTH_VCF="HG002_GRCh37_GIAB_highconf_CG-IllFB-IllGATKHC-Ion-10X-SOLID_CHROM1-22_v.3.3.2_highconf_triophased.vcf.gz"
TRUTH_BED="HG002_GRCh37_GIAB_highconf_CG-IllFB-IllGATKHC-Ion-10X-SOLID_CHROM1-22_v.3.3.2_highconf_noinconsistent.bed"

N_SHARDS=$(nproc)

OUTPUT_DIR="${BASE}/output"
OUTPUT_VCF="${OUTPUT_DIR}/HG002.output.vcf.gz"
OUTPUT_GVCF="${OUTPUT_DIR}/HG002.output.g.vcf.gz"
LOG_DIR="${OUTPUT_DIR}/logs"

# Build Docker image.
function build_docker_image() {
  echo "Start building Docker image."
  sudo docker build -t deepvariant .
  echo "Done building Docker image."
}

function setup_test() {
  ## Create local directory structure
  mkdir -p "${OUTPUT_DIR}"
  mkdir -p "${DATA_DIR}"
  mkdir -p "${LOG_DIR}"

  ## Download extra packages
  sudo apt-get -y update
  sudo apt-get -y install docker.io
  sudo apt-get -y install aria2

  # Copy the data
  aria2c -c -x10 -s10 -d "${DATA_DIR}" http://storage.googleapis.com/deepvariant/case-study-testdata/${TRUTH_BED}
  aria2c -c -x10 -s10 -d "${DATA_DIR}" http://storage.googleapis.com/deepvariant/case-study-testdata/${TRUTH_VCF}
  aria2c -c -x10 -s10 -d "${DATA_DIR}" http://storage.googleapis.com/deepvariant/case-study-testdata/${TRUTH_VCF}.tbi
  aria2c -c -x10 -s10 -d "${DATA_DIR}" http://storage.googleapis.com/deepvariant/pacbio-case-study-testdata/${BAM}
  aria2c -c -x10 -s10 -d "${DATA_DIR}" http://storage.googleapis.com/deepvariant/pacbio-case-study-testdata/${BAM}.bai
  aria2c -c -x10 -s10 -d "${DATA_DIR}" http://storage.googleapis.com/deepvariant/case-study-testdata/hs37d5.fa.gz
  aria2c -c -x10 -s10 -d "${DATA_DIR}" http://storage.googleapis.com/deepvariant/case-study-testdata/hs37d5.fa.gz.fai
  aria2c -c -x10 -s10 -d "${DATA_DIR}" http://storage.googleapis.com/deepvariant/case-study-testdata/hs37d5.fa.gz.gzi
  aria2c -c -x10 -s10 -d "${DATA_DIR}" http://storage.googleapis.com/deepvariant/case-study-testdata/hs37d5.fa.gzi
  aria2c -c -x10 -s10 -d "${DATA_DIR}" http://storage.googleapis.com/deepvariant/case-study-testdata/hs37d5.fa.fai
}

function run_deepvariant() {
  echo "Start running run_deepvariant...Log will be in the terminal and also to ${LOG_DIR}/deepvariant_runtime.log."
  sudo docker run \
    -v "${DATA_DIR}":"${DATA_DIR}" \
    -v "${OUTPUT_DIR}":"${OUTPUT_DIR}" \
    deepvariant:latest \
    /opt/deepvariant/bin/run_deepvariant \
    --model_type "PACBIO" \
    --num_shards "${N_SHARDS}" \
    --output_gvcf "${OUTPUT_GVCF}" \
    --output_vcf "${OUTPUT_VCF}" \
    --reads "${DATA_DIR}/${BAM}" \
    --ref "${DATA_DIR}/${REF}"
  echo "Done."
  echo
}

function main() {
  echo 'Starting the test...'

  setup_test
  build_docker_image

  (time run_deepvariant) 2>&1 | tee "${LOG_DIR}/deepvariant_runtime.log"
}

main "$@"

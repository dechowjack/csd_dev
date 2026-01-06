#!/usr/bin/env bash
set -euo pipefail

# Usage:
#   bash fix_smoothed_attrs.sh 2016

# ---------------- PATH CONFIG ----------------
base_dir="/discover/nobackup/projects/coressd/Blender/SmoothedInputs"
nco_module="nco/5.1.7"
# --------------------------------------------

WY="${1:-}"
if [[ -z "${WY}" ]]; then
  echo "Usage: $0 <4-digit WY>   e.g. $0 2016"
  exit 2
fi

# Load NCO 
module load "${nco_module}"

year_dir="${base_dir}/WY${WY}"

fix_snowf="${base_dir}/fix_snowf_attrs.sh"
fix_swe="${base_dir}/fix_swe_attrs.sh"

snowf_smooth="${year_dir}/Snowf_tavg_smooth.nc"
swe_smooth="${year_dir}/SWE_tavg_smooth.nc"

snowf_final="${year_dir}/Snowf_tavg.nc"
swe_final="${year_dir}/SWE_tavg.nc"

# ---- sanity checks ----
[[ -d "${year_dir}" ]] || { echo "ERROR: Missing directory: ${year_dir}"; exit 1; }
[[ -x "${fix_snowf}" ]] || { echo "ERROR: Missing/non-executable: ${fix_snowf}"; exit 1; }
[[ -x "${fix_swe}"   ]] || { echo "ERROR: Missing/non-executable: ${fix_swe}"; exit 1; }

[[ -f "${snowf_smooth}" ]] || { echo "ERROR: Missing file: ${snowf_smooth}"; exit 1; }
[[ -f "${swe_smooth}"   ]] || { echo "ERROR: Missing file: ${swe_smooth}"; exit 1; }

# Optional: confirm ncatted is available (helps debugging)
command -v ncatted >/dev/null 2>&1 || { echo "ERROR: ncatted not found after module load"; exit 1; }

echo "Processing WY${WY} in ${year_dir}"

bash "${fix_snowf}" "${snowf_smooth}"
bash "${fix_swe}"   "${swe_smooth}"

mv -f "${snowf_smooth}" "${snowf_final}"
mv -f "${swe_smooth}"   "${swe_final}"

echo "Done WY${WY}"

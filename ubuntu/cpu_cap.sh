#!/usr/bin/env bash
set -euo pipefail

# Grab a single, deduplicated flags string
get_flags() {
  if command -v lscpu >/dev/null 2>&1; then
    # lscpu reports "Flags:" on one line; normalize spaces
    lscpu | awk -F: '/Flags/ { $1=""; sub(/^:[[:space:]]*/,""); print }' \
          | tr '[:upper:]' '[:lower:]' | tr -s ' '
  elif [[ -r /proc/cpuinfo ]]; then
    awk -F: '/^flags/{print $2}' /proc/cpuinfo \
      | tr '[:upper:]' '[:lower:]' | tr '\n' ' ' | tr -s ' ' | sed 's/^ //; s/ $//'
  else
    echo ""
  fi
}

get_field() {
  local key="$1"
  if command -v lscpu >/dev/null 2>&1; then
    lscpu | awk -F: -v k="$key" '$1 ~ k { $1=""; sub(/^:[[:space:]]*/,""); print; exit }'
  elif [[ -r /proc/cpuinfo ]]; then
    awk -F: -v k="$key" '$1 ~ k { gsub(/^[ \t]+/,"",$2); print $2; exit }' /proc/cpuinfo
  fi
}

has_flag() {
  local f="$1"
  [[ " $FLAGS " == *" $f "* ]]
}

print_group() {
  local title="$1"; shift
  printf "\n%s:\n" "$title"
  local found=0
  for f in "$@"; do
    # label prettifier: avx512_vnni -> AVX512_VNNI, amx_bf16 -> AMX_BF16
    local label
    label="$(echo "$f" | tr '[:lower:]' '[:upper:]')"
    if has_flag "$f"; then
      printf "  ✓ %-18s\n" "$label"
      found=1
    fi
  done
  if [[ $found -eq 0 ]]; then
    echo "  (none detected)"
  fi
}

# -------- Main --------
MODEL="$(get_field '^Model name')"
VENDOR="$(get_field '^Vendor ID')"
if [[ -z "$MODEL" ]]; then MODEL="$(get_field '^model name')"; fi
if [[ -z "$VENDOR" ]]; then VENDOR="$(get_field '^vendor_id')"; fi
CORES="$(get_field '^CPU\\(s\\)')"
if [[ -z "$CORES" ]]; then CORES="$(nproc 2>/dev/null || echo '?')" ; fi

FLAGS="$(get_flags)"

echo "CPU Model : ${MODEL:-unknown}"
echo "Vendor    : ${VENDOR:-unknown}"
echo "CPU(s)    : ${CORES:-unknown}"

if [[ -z "$FLAGS" ]]; then
  echo "Flags     : (could not read CPU flags)"
  exit 0
fi

# --- Groups of interest ---
# Classic SIMD & helpers
SIMD_FLAGS=(
  sse sse2 sse3 ssse3 sse4_1 sse4_2 sse4a  # sse4a mostly AMD
  f16c fma                                  # half conversion + fused multiply-add
  avx avx2
  bmi1 bmi2
)
# AVX-512 family (Intel + AMD Zen4+ where present)
AVX512_FLAGS=(
  avx512f avx512cd avx512dq avx512bw avx512vl
  avx512_vnni avxvnni         # VNNI: INT8 dot-prod
  avx512_bf16                 # bfloat16
  avx512_fp16                 # fp16 in AVX-512
  avx512_vbmi avx512_vbmi2    # byte/bit matrix instr (not AMX)
  avx512_bitalg avx512_ifma avx512_vpopcntdq
)
# Matrix / AI specific blocks
AMX_FLAGS=(amx_tile amx_int8 amx_bf16 amx_fp16)   # Intel AMX (Sapphire/Raptor w/ AMX, Granite, etc.)
AI_MISC_FLAGS=(
  avx_vnni          # AVX-VNNI (non-512 variant on newer Intel/AMD)
  avx_ifma          # AVX IFMA (rare; AVX512_IFMA is more common)
)
CRYPTO_ACCEL=(aes sha_ni vpclmulqdq pclmul)
AMD_EPY_API_FLAGS=(
  svm             # AMD-V virtualization (Secure Virtual Machine)
  sev             # Secure Encrypted Virtualization base API
  sev_es          # SEV Encrypted State (guest register encryption)
  sev_snp         # SEV Secure Nested Paging (memory integrity)
  sme             # System Memory Encryption for bare-metal API usage
  avic            # Advanced Virtual Interrupt Controller (reduces VM exits)
  pausefilter     # Hardware pause filtering exposed via AMD-V APIs
  vgif            # Virtual Global Interrupt Flag (fewer VM exits on STI)
)

print_group "SIMD & Arithmetic" "${SIMD_FLAGS[@]}"
print_group "AVX-512 Extensions" "${AVX512_FLAGS[@]}"
print_group "Matrix Engines (AMX)" "${AMX_FLAGS[@]}"
print_group "AI-leaning Vector Ext." "${AI_MISC_FLAGS[@]}"
print_group "Related (crypto/bit ops)" "${CRYPTO_ACCEL[@]}"

MODEL_LC="${MODEL,,}"
AMD_EPY_DETECTED=0
if [[ "${MODEL_LC}" == *"epyc"* ]]; then
  AMD_EPY_DETECTED=1
fi

if [[ $AMD_EPY_DETECTED -eq 1 ]]; then
  print_group "AMD EPYC Virtualization APIs" "${AMD_EPY_API_FLAGS[@]}"
fi

# Extra notes for clarity
echo
echo "Notes:"
echo "  • Flags shown are what the OS has enabled. Some CPUs support AVX-512 but firmware/OS may disable it."
echo "  • AMX_* flags indicate on-die matrix tiles (Intel). AMD currently relies on vector paths (e.g., AVX512_VNNI/BF16) instead."
echo "  • AVX_VNNI / AVX512_VNNI accelerate INT8 dot-products common in inferencing."
if [[ $AMD_EPY_DETECTED -eq 1 ]]; then
  echo "  • AMD EPYC SEV*/SVM flags surface the firmware-backed APIs for confidential VMs (SEV, SEV-ES, SEV-SNP)."
  echo "  • SME/AVIC/pausefilter/vgif help hypervisors expose AMD-V APIs with fewer VM exits and encrypted memory."
fi

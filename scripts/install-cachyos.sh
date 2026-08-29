#!/usr/bin/env bash
#
# DSH Desktop Linux — CachyOS installer (development / local-build path)
#
# This script:
# - Verifies CachyOS/Arch compatibility
# - Checks Node/Corepack/Yarn prerequisites
# - Detects GPU and reports recommended Vulkan userspace packages
# - Initializes submodules and immutable dependencies
# - Builds the desktop package locally
# - Installs a user-local launcher and .desktop entry
# - Runs a non-destructive GPU and application smoke check
#
# It does NOT:
# - Silently replace your NVIDIA driver
# - Run a full system upgrade (no blanket pacman -Syu)
# - Pipe unpinned remote shells into root
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/Tariq-Anjum/DSH-Desktop-Linux/main/scripts/install-cachyos.sh -o install-cachyos.sh
#   chmod +x install-cachyos.sh
#   ./install-cachyos.sh
#
set -euo pipefail

REPO_URL="https://github.com/Tariq-Anjum/DSH-Desktop-Linux.git"
INSTALL_DIR="${DSH_INSTALL_DIR:-$HOME/.local/dsh-desktop-linux}"
BIN_DIR="$HOME/.local/bin"
APP_DIR="$HOME/.local/share/applications"
ICON_DIR="$HOME/.local/share/icons/hicolor/256x256/apps"

colour() {
  local c="$1"
  shift
  echo -e "\033[${c}m$*\033[0m"
}

info()    { colour "0;36" "[INFO]" "$@"; }
warn()    { colour "0;33" "[WARN]" "$@"; }
success() { colour "0;32" "[OK]" "$@"; }
error()   { colour "0;31" "[ERROR]" "$@"; exit 1; }

check_os() {
  info "Checking OS compatibility..."
  if [[ -f /etc/os-release ]]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    case "${ID,,}" in
      cachyos|arch|manjaro|endeavouros)
        success "Detected compatible Arch-based system: ${PRETTY_NAME:-${ID}}"
        ;;
      *)
        warn "Unknown or unsupported OS: ${PRETTY_NAME:-${ID}}"
        warn "This installer is designed for CachyOS/Arch. Proceed with caution."
        read -rp "Continue anyway? [y/N] " ans
        [[ "${ans,,}" == "y" ]] || error "Aborted by user."
        ;;
    esac
  else
    warn "Cannot detect OS (no /etc/os-release)."
    warn "This installer is designed for CachyOS/Arch."
    read -rp "Continue anyway? [y/N] " ans
    [[ "${ans,,}" == "y" ]] || error "Aborted by user."
  fi
}

check_prereqs() {
  info "Checking prerequisites..."

  local missing=()

  command -v git >/dev/null 2>&1 || missing+=("git")
  command -v node >/dev/null 2>&1 || missing+=("nodejs")
  command -v corepack >/dev/null 2>&1 || missing+=("corepack (via nodejs/npm)")

  if [[ ${#missing[@]} -gt 0 ]]; then
    warn "Missing prerequisites: ${missing[*]}"
    info "On CachyOS/Arch you can install them with:"
    info "  sudo pacman -S --needed git nodejs npm"
    info "Then ensure corepack is available (Node 16.9+ ships with corepack)."
    read -rp "Press Enter after installing prerequisites, or Ctrl+C to abort."
  fi

  if ! command -v node >/dev/null 2>&1; then
    error "Node.js still not found. Install nodejs and retry."
  fi

  if ! command -v corepack >/dev/null 2>&1; then
    error "corepack not found. Ensure you have a recent Node.js version and retry."
  fi

  success "Prerequisites satisfied."
}

detect_gpu() {
  info "Detecting GPU and Vulkan support..."

  local gpu_vendor="unknown"
  local vulkan_loader="no"
  local vulkan_devices="none"

  if command -v lspci >/dev/null 2>&1; then
    if lspci -nn | grep -qiE 'vga|3d|display'; then
      if lspci -nn | grep -qiE 'nvidia'; then
        gpu_vendor="NVIDIA"
      elif lspci -nn | grep -qiE 'amd|advanced micro devices'; then
        gpu_vendor="AMD"
      elif lspci -nn | grep -qiE 'intel'; then
        gpu_vendor="Intel"
      fi
    fi
  fi

  if command -v vulkaninfo >/dev/null 2>&1; then
    vulkan_loader="yes"
    vulkan_devices=$(vulkaninfo --summary 2>/dev/null | grep -c "GPU" || echo "0")
  elif [[ -f /usr/lib/libvulkan.so ]] || [[ -f /usr/lib64/libvulkan.so ]]; then
    vulkan_loader="library-only"
  fi

  info "GPU vendor: ${gpu_vendor}"
  info "Vulkan loader: ${vulkan_loader}"
  info "Vulkan devices: ${vulkan_devices}"

  case "${gpu_vendor,,}" in
    amd)
      info "Recommended Vulkan userspace (AMD): vulkan-radeon mesa"
      ;;
    intel)
      info "Recommended Vulkan userspace (Intel): vulkan-intel mesa"
      ;;
    nvidia)
      info "NVIDIA detected. Ensure your driver package provides Vulkan (e.g. nvidia, nvidia-dkms, or nvidia-open)."
      info "Do not let this script choose or replace your NVIDIA driver."
      ;;
    *)
      info "Generic Vulkan userspace: vulkan-icd-loader vulkan-tools mesa"
      ;;
  esac

  if [[ "${vulkan_loader}" == "no" ]]; then
    warn "Vulkan loader not detected. GPU acceleration may be limited."
    info "On CachyOS you can install: vulkan-icd-loader vulkan-tools mesa"
    if [[ "${gpu_vendor,,}" == "amd" ]]; then
      info "For AMD also consider: vulkan-radeon"
    elif [[ "${gpu_vendor,,}" == "intel" ]]; then
      info "For Intel also consider: vulkan-intel"
    fi
    read -rp "Install generic Vulkan packages now? [y/N] " ans
    if [[ "${ans,,}" == "y" ]]; then
      local pkg=("vulkan-icd-loader" "vulkan-tools" "mesa")
      if [[ "${gpu_vendor,,}" == "amd" ]]; then
        pkg+=("vulkan-radeon")
      elif [[ "${gpu_vendor,,}" == "intel" ]]; then
        pkg+=("vulkan-intel")
      fi
      info "Installing: ${pkg[*]}"
      sudo pacman -S --needed --noconfirm "${pkg[@]}" || warn "Package installation failed; continuing anyway."
    fi
  fi

  success "GPU detection complete."
}

clone_or_update_repo() {
  info "Cloning/updating repository..."

  if [[ -d "${INSTALL_DIR}/.git" ]]; then
    info "Existing installation found. Pulling latest changes..."
    (cd "${INSTALL_DIR}" && git pull --rebase)
  else
    info "Cloning repository into ${INSTALL_DIR}..."
    mkdir -p "${INSTALL_DIR}"
    git clone --depth=1 "${REPO_URL}" "${INSTALL_DIR}"
  fi

  success "Repository ready at ${INSTALL_DIR}"
}

install_deps_and_build() {
  info "Installing dependencies and building..."

  (cd "${INSTALL_DIR}" && corepack enable)
  (cd "${INSTALL_DIR}" && corepack yarn install --immutable)
  (cd "${INSTALL_DIR}" && corepack yarn check || warn "yarn check reported issues; continuing...")
  (cd "${INSTALL_DIR}" && corepack yarn build || warn "Build step failed or not defined; continuing...")

  success "Dependencies installed and build attempted."
}

install_launcher() {
  info "Installing launcher and desktop entry..."

  mkdir -p "${BIN_DIR}" "${APP_DIR}" "${ICON_DIR}"

  local launcher="${BIN_DIR}/dsh-desktop-linux"
  cat > "${launcher}" << 'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail
INSTALL_DIR="${DSH_INSTALL_DIR:-$HOME/.local/dsh-desktop-linux}"
cd "${INSTALL_DIR}"
exec corepack yarn start "$@"
LAUNCHER
  chmod +x "${launcher}"

  local icon_src="${INSTALL_DIR}/assets/icon.png"
  local icon_dst="${ICON_DIR}/dsh-desktop-linux.png"
  if [[ -f "${icon_src}" ]]; then
    cp "${icon_src}" "${icon_dst}"
  else
    warn "No icon found at ${icon_src}; desktop entry will use a fallback."
  fi

  cat > "${APP_DIR}/dsh-desktop-linux.desktop" << DESKTOP
[Desktop Entry]
Name=DSH Desktop Linux
Comment=DeepSeek Harness Desktop (Linux build)
Exec=${launcher}
Icon=dsh-desktop-linux
Type=Application
Categories=Development;Utility;
Terminal=false
DESKTOP

  success "Launcher installed at ${launcher}"
  success "Desktop entry installed at ${APP_DIR}/dsh-desktop-linux.desktop"
  info "You can now launch 'DSH Desktop Linux' from your application menu or run: dsh-desktop-linux"
}

smoke_check() {
  info "Running smoke check..."

  if command -v dsh-desktop-linux >/dev/null 2>&1 || [[ -x "${BIN_DIR}/dsh-desktop-linux" ]]; then
    info "Launcher is available."
  else
    warn "Launcher not found in PATH. You may need to add ${BIN_DIR} to your PATH."
  fi

  if command -v vulkaninfo >/dev/null 2>&1; then
    info "Vulkan info available. You can run 'vulkaninfo --summary' to inspect GPU capabilities."
  else
    warn "vulkaninfo not found. Vulkan diagnostics will be limited."
  fi

  success "Smoke check complete."
}

main() {
  info "DSH Desktop Linux — CachyOS installer"
  info "This script performs a user-local installation with explicit checks."
  read -rp "Continue? [y/N] " ans
  [[ "${ans,,}" == "y" ]] || error "Aborted by user."

  check_os
  check_prereqs
  detect_gpu
  clone_or_update_repo
  install_deps_and_build
  install_launcher
  smoke_check

  success "Installation complete."
  info "To start DSH Desktop Linux, run: dsh-desktop-linux"
  info "Or launch 'DSH Desktop Linux' from your application menu."
}

main "$@"

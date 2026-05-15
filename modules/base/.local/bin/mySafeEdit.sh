#!/usr/bin/env bash

# This file contains mainly AI generated code
set -euo pipefail

prog="$(basename "$0")"

mode="auto"
output_file=""
no_shred=0
timeout_duration=""
unsafe_tmp=0

usage() {
  cat <<EOF
Usage:
  $prog [OPTIONS] FILE

Options:
  --plain              Force plaintext mode
  --encrypted          Force GPG-encrypted mode
  --output FILE        Write encrypted result to FILE instead of replacing input
  --no-shred           Use rm instead of shred for temporary plaintext cleanup
  --timeout DURATION   Kill Vim after duration, e.g. 10m, 1h
  --unsafe-tmp         Use /tmp if /dev/shm is unavailable or not tmpfs
  -h, --help           Show this help

Examples:
  $prog secret.gpg
  $prog --encrypted secret.txt
  $prog --output copy.gpg secret.gpg
  $prog --plain notes.txt
EOF
}

die() {
  printf 'Error: %s\n' "$*" >&2
  exit 1
}

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || die "Required command not found: $1"
}

is_gpg_file() {
  gpg --batch --quiet --list-packets "$1" >/dev/null 2>&1
}

is_tmpfs() {
  local path="$1"
  [[ -d "$path" ]] || return 1
  [[ "$(findmnt -n -o FSTYPE --target "$path" 2>/dev/null || true)" == "tmpfs" ]]
}

file_hash() {
  sha256sum -- "$1" | awk '{print $1}'
}

cleanup_file() {
  local path="${1:-}"

  [[ -n "$path" && -e "$path" ]] || return 0

  if [[ "$no_shred" -eq 1 ]]; then
    rm -f -- "$path"
  elif command -v shred >/dev/null 2>&1; then
    shred -u -- "$path" 2>/dev/null || rm -f -- "$path"
  else
    rm -f -- "$path"
  fi
}

safe_vim() {
  local file="$1"
  local cmd=(
    vim
    -n
    -i NONE
    -u NONE
    -U NONE
    --cmd 'set noswapfile'
    --cmd 'set nobackup'
    --cmd 'set nowritebackup'
    --cmd 'set backupskip=*'
    --cmd 'set noundofile'
    --cmd 'silent! set viminfo='
    --cmd 'silent! set shada='
    --cmd 'set nomodeline'
    --cmd 'silent! set clipboard='
    --cmd 'set secure'
    "$file"
  )

  if [[ -n "$timeout_duration" ]]; then
    need_cmd timeout
    timeout "$timeout_duration" "${cmd[@]}"
  else
    "${cmd[@]}"
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --plain)
      [[ "$mode" == "auto" ]] || die "Only one mode flag may be used."
      mode="plain"
      shift
      ;;
    --encrypted)
      [[ "$mode" == "auto" ]] || die "Only one mode flag may be used."
      mode="encrypted"
      shift
      ;;
    --output)
      [[ $# -ge 2 ]] || die "--output requires a file."
      output_file="$2"
      shift 2
      ;;
    --no-shred)
      no_shred=1
      shift
      ;;
    --timeout)
      [[ $# -ge 2 ]] || die "--timeout requires a duration."
      timeout_duration="$2"
      shift 2
      ;;
    --unsafe-tmp)
      unsafe_tmp=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    --)
      shift
      break
      ;;
    -*)
      die "Unknown option: $1"
      ;;
    *)
      break
      ;;
  esac
done

[[ $# -eq 1 ]] || die "Exactly one file must be provided."

input_file="$1"

need_cmd gpg
need_cmd vim
need_cmd findmnt
need_cmd stat
need_cmd mktemp
need_cmd sha256sum
need_cmd awk

[[ -e "$input_file" ]] || die "File does not exist: $input_file"
[[ -f "$input_file" ]] || die "Not a regular file: $input_file"
[[ -r "$input_file" ]] || die "File is not readable: $input_file"

if [[ "$mode" == "auto" ]]; then
  if is_gpg_file "$input_file"; then
    mode="encrypted"
  else
    mode="plain"
  fi
fi

# Plain mode: safe Vim only. No GPG. No encryption. No output file.
if [[ "$mode" == "plain" ]]; then
  [[ -z "$output_file" ]] || die "--output is only supported in encrypted mode."
  [[ -w "$input_file" ]] || die "File is not writable: $input_file"

  safe_vim "$input_file"
  exit $?
fi

# Encrypted mode starts here.

input_dir="$(cd -- "$(dirname -- "$input_file")" && pwd)"
input_base="$(basename -- "$input_file")"

if [[ -n "$output_file" ]]; then
  if [[ -e "$output_file" ]]; then
    die "Output file already exists: $output_file"
  fi

  output_dir="$(cd -- "$(dirname -- "$output_file")" && pwd)"
  output_base="$(basename -- "$output_file")"
  final_file="$output_dir/$output_base"
else
  [[ -w "$input_file" ]] || die "File is not writable: $input_file"
  [[ -w "$input_dir" ]] || die "Directory is not writable: $input_dir"
  final_file="$input_dir/$input_base"
fi

final_dir="$(dirname -- "$final_file")"
[[ -w "$final_dir" ]] || die "Final output directory is not writable: $final_dir"

tmp_root="/dev/shm"

if ! is_tmpfs "$tmp_root"; then
  if [[ "$unsafe_tmp" -eq 1 ]]; then
    tmp_root="/tmp"
  else
    die "/dev/shm is unavailable or not tmpfs. Use --unsafe-tmp to allow /tmp."
  fi
fi

tmp_dir="$(mktemp -d "$tmp_root/mySafeEdit.XXXXXX")"
chmod 700 "$tmp_dir"

plain_tmp="$tmp_dir/edit.txt"
enc_tmp=""

cleanup() {
  cleanup_file "$plain_tmp"

  if [[ -n "${enc_tmp:-}" && -e "$enc_tmp" ]]; then
    rm -f -- "$enc_tmp"
  fi

  if [[ -d "${tmp_dir:-}" ]]; then
    rmdir -- "$tmp_dir" 2>/dev/null || true
  fi
}

trap cleanup EXIT INT TERM

umask 077

if ! gpg --quiet --decrypt -- "$input_file" > "$plain_tmp"; then
  die "Decryption failed or was cancelled."
fi

before_hash="$(file_hash "$plain_tmp")"

if ! safe_vim "$plain_tmp"; then
  die "Vim exited unsuccessfully. Original file left unchanged."
fi

after_hash="$(file_hash "$plain_tmp")"

if [[ "$before_hash" == "$after_hash" ]]; then
  printf 'No changes detected. Original encrypted file left unchanged.\n'
  exit 0
fi

enc_tmp="$(mktemp "$final_dir/.mySafeEdit.${input_base}.XXXXXX")"

if ! gpg --quiet --yes --symmetric --output "$enc_tmp" -- "$plain_tmp"; then
  die "Encryption failed or was cancelled. Original file left unchanged."
fi

[[ -s "$enc_tmp" ]] || die "Encrypted output was not created or is empty."

if [[ -z "$output_file" ]]; then
  orig_mode="$(stat -c '%a' -- "$input_file")"
  chmod "$orig_mode" -- "$enc_tmp" 2>/dev/null || true
fi

mv -f -- "$enc_tmp" "$final_file"
enc_tmp=""

printf 'Encrypted file updated: %s\n' "$final_file"
